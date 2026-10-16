# Orante (interno: ZenSounds)

App iOS nativo (SwiftUI, iOS 18.0+, SDK iOS 27) de oração católica: Bíblia offline pt (Bíblia Livre) / en (KJV),
Palavra do Dia + widget, Santo Terço (manual e guiado por voz), narração com `AVSpeechSynthesizer`, sons ambientes
e Paisagens Bíblicas com mixer e sleep timer. Assinatura **Orante+** via Superwall (SuperwallKit 4.17.x, SPM).
O nome visível é "Orante"; nomes internos (targets, pastas, módulo `ZenSounds`, bundle ID, App Group, esquema
`zensounds://`, prefixo `zensounds.` das chaves) continuam "zensounds" **de propósito**.

Docs de histórico: `MIGRATION_PROGRESS.md` (diário), `APP_STORE_READINESS_AUDIT.md`, `SUPERWALL_INTEGRATION.md`,
`SOUND_LICENSES.md`, `ROSARY_SOURCES.md`. Onde divergirem do código, vale o código.

## Targets
- `ZenSounds` (app) — `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, approachable concurrency, Swift 5 mode.
- `ZenSoundsWidgetsExtension` (pasta `ZenSoundsWidgets/`) — WidgetKit, sem isolamento MainActor padrão, **não**
  compartilha código com o app (reimplementa o necessário).
- `ZenSoundsTests` — Swift Testing (`@testable import ZenSounds`), hospedado no app.

## Mapa de pastas (`ZenSounds/`)
- `App/` — `ZenSoundsApp` (configura Superwall, roteia URLs: rota bíblica → `DeepLinkHandler`; senão
  `Superwall.handleDeepLink`; senão fallback), `AppLaunchView` (splash + onboarding), `RootView` (TabView de 4 abas
  desde o redesign de 2026-10: Hoje, Bíblia, Terço, Buscar (`role: .search`); cada aba com `NavigationStack` próprio
  + `.soundsDestinations()`; sheet `AmbientSoundSheet`, `PlayerView` em fullScreenCover; alerts globais de
  áudio/narração/lembrete de trial). Sons e Favoritos deixaram de ser abas: ficam em Buscar → Explorar/Ver todos.
- `Core/Models/` — regras puras: `PremiumAccessRules` (matriz grátis × Plus, `PremiumGate`, `AudioPremiumSafety`,
  `EntitlementCacheRules`, `PremiumPlacement`), `SoundModels` (11 sons + 4 paisagens), `MixModels` (`MixRules`: até 8
  camadas, ganho proporcional), `TimerModels` (deadline em `systemUptime`, fade linear 0–60 s), `RosaryModels`
  (sequência de 80/75 passos, `MysterySchedule`, regras visuais), `BibleModels` (`BibleLanguage`, `AppLanguage` +
  `AppLanguageStore` — recarrega widgets quando o idioma efetivo muda, `WidgetLanguageSync`), schema HelloAO
  com `hebrew_subtitle`), `OnboardingRules` (`OnboardingState`, `TrialReminderRules`), `AmbientModels`
  (`AmbientItem`, visibilidade do mini-player), `ReadingModels` (`BibleTestament`, `ChapterNavigation`,
  `ReadingFontScale`, `ChapterShareText`), `SearchModels` (`RecentItem`/`RecentsRules`, `SearchText`,
  `BookAbbreviations` pt/en, `BookMatcher`, `ReferenceParser`, `RosarySearch`, `VerseSearchRules`).
- `Core/Navigation/` — `AppTab`, rotas (`BibleRoute`, `SoundsRoute` {library, mixEditor}, `SearchRoute`
  {favorites, prayers, prayer}), `NavigationModel.shared` (um path por aba, reselecionar aba volta à raiz,
  `push` na aba atual, `openBible`, `openSoundsLibrary`, `openRosary(set:)` via `pendingRosarySet`),
  `PlayerPresentation.shared` (player cheio + sheet de som ambiente), `DeepLinkHandler`/`BibleDeepLink`.
- `Core/Services/`
  - `AudioEngine.shared` — `AVAudioEngine` com um `LoopingPlayer` por camada → `mainMixerNode`; som único, mix,
    transporte (máquina `AudioTransportRules`), timer com fade, sessão `.playback` ativada/desativada numa fila serial,
    interrupções, troca de rota, Now Playing + `MPRemoteCommandCenter` (exclusivo dele). Rede de segurança premium
    em `play`/`playMix`/`addLayer`.
  - `LoopingPlayer` — loop sem gaps com dois `scheduleFile` enfileirados (não carrega o arquivo em RAM).
  - `BibleNarrationService.shared` — único `AVSpeechSynthesizer`; donos `.bible/.rosary/.preview`; geração
    (`OperationGeneration`) para ignorar callbacks velhos; injetável (protocolos `SpeechSynthesizing`,
    `NarrationAudioCoordinating`, `RosaryNarrating`).
  - `BibleNarrationPreferences.shared` — vozes por idioma (sem Novelty/Personal), velocidade 0.35–0.60.
  - `BibleCatalog` (books/daily_readings/manifest), `BibleRepository` (`{CODE}_{pt|en}.json` + `NSCache`;
    `subtitle` = sobrescrito dos Salmos; `bookVerses` para o índice), `VerseSearchIndex` (actor: índice em memória
    por idioma, montado na 1ª busca, varredura cancelável, até 50 resultados),
    `DailyWordStore` (App Group, `floorMod(epochDay)`, shuffle até virar o dia).
  - `UserPreferencesStore.shared` — favoritos (sons/versículos; versículo casa por referência, sem idioma, e é
    exibido no idioma atual via `FavoriteVerse.verse(in:)`), mixes salvos, posição de leitura, último som
    (`zensounds.ambient.lastSound`), recentes (`zensounds.recents.v1`, máx. 10).
  - `RosaryRepository` / `RosaryProgressStore` (`zensounds.rosary.progress.v1`, versionado).
  - `SuperwallService.shared` — configure, delegate, `entitlementState`/`hasPlus` (entitlement `plus`), cache
    `orante.plus.lastConfirmedActive`, espelha `plus_active` no App Group + recarrega widgets, `gate(...)`,
    `registerNonGated`, restore, evento `freeTrialStart` → `TrialReminderService` (lembrete local no dia 5).
- `Core/Theme/` — `DesignTokens` (`EssencePalette` quente light/dark, fontes: SF Pro na UI via estilos
  `.essence*`, New York serif em escritura/orações via `.scripture*`; `Spacing`, `Radius`), `PremiumLockBadge`,
  `ThemeMode`, wrapper `ZenSoundsTheme`. Plus Jakarta Sans continua no bundle/Info.plist para voltar rápido.
- `Features/` — Home (Hoje: Palavra do Dia, Continuar, Explorar, mini-player inline; `SectionTitle`,
  `SettingsButton`, `ShortcutRow` compartilhados), Bible (hero Sl 119:105, AT/NT, leitor serif com seleção de
  versículo, "Aa", menu "…"), Rosary (`RosaryViewModel` + `RosaryGuidedController`; card de mistérios recolhível),
  Search (busca, recentes, favoritos, explorar, `PrayersView`), Ambient (mini-player, sheet, `AmbientPlayback`),
  Sounds (biblioteca, paisagens, editor de mix), Player (cheio, timer, adicionar som), Favorites (lista completa +
  `VerseDetailView`), Settings, Onboarding (3 páginas).
- `Resources/` — Audio/*.mp3, Bible/*.json, Rosary/*.json, Fonts, catálogos `.xcstrings`, LaunchScreen.
  Artes vetoriais próprias no asset catalog (SVG, preserve vector data): `BibleHero`, `ExplorePsalms`,
  `DailyWordLeaf` (template).
- Widget: `ZenSoundsWidgets.swift` (Small/Medium/Large/accessoryRectangular/accessoryInline, tema por
  `WidgetConfigurationIntent`, fallback Terracota sem `plus_active`), `WidgetDailyWordStore` (**espelho** de
  `DailyWordStore` — manter chaves em sincronia), `ShuffleDailyWordIntent`, JSONs próprios.

## Fluxo de áudio e narração
1. View chama `SuperwallService.shared.gate(feature)` → closure chama `AudioEngine.play/playMix`.
2. `AudioEngine` normaliza camadas, ativa a sessão (await), cria players, liga o engine, troca os nodes e atualiza
   Now Playing. Mesma combinação já tocando não reinicia. Pausa/fim do timer pausam engine e soltam a sessão
   (exceto se narração ativa). `stop()` limpa tudo.
3. Narração: `prepareAudioSessionForNarration()` (marca sessão de narração ativa) → `setNarrationDucking(true)`
   (rampa de 14 passos × 25 ms até 0,30 do volume nos nodes ambientes) → espera 180 ms → `speak`.
   Fim/cancelamento/pausa/erro → `setNarrationDucking(false)` + `finishNarrationAudioSession()`.
   O Terço guiado mantém sessão e ducking entre orações (`keepSession`) e só libera ao parar/pausar.
4. Ducking é feito pelo próprio app (multiplicador de ganho), não por `.duckOthers`.

## Monetização (Orante+)
- Grupo "Orante+", entitlement `plus`. `com.juliocezar.zensounds.plus.annual` (R$ 69,90 / US$ 29,99, 7 dias
  grátis) e `com.juliocezar.zensounds.plus.monthly` (R$ 12,90 / US$ 4,99). Sem vitalício/semanal.
  `Orante.storekit` (raiz) já está associado ao scheme `ZenSounds`.
- Grátis: Bíblia, favoritos, Palavra do Dia (inclusive ouvir), Terço manual, sons Rain/Forest/Stream, paisagem
  `good-shepherd`, timer 5/15/30/60 com fade padrão (10 s), widget Terracota. Todo o resto é Plus.
- **Fonte única da verdade: `PremiumAccessRules` + `PremiumGate`.** Toda entrada paga passa por `gate(...)`.
  Estado `.unknown` não mostra badges e usa o cache do último Plus confirmado.
  **Nunca confiar no `feature` do Superwall:** ele roda quando o placement não é encontrado, sem audiência ou em
  holdout (`.skipped`), e não roda em erro. O registrar usa `PaywallPresentationHandler` e entrega um
  `PaywallOutcome`; o gate re-checa `hasPlus`. Depois de compra/restore, espera até 3 s
  (`waitForPlusAfterPurchase`). Sem Plus e sem paywall exibido, mostra `PremiumLockedNotice` (UIAlertController
  no topo, funciona sobre sheets).
  Debug: Ajustes > "Simular Orante+" (`DebugPlusOverride`, chave `orante.debug.plusOverride`), todo em `#if DEBUG`
  (conferido no binário Release). O `plus_active` do widget usa o valor efetivo (com o override); o cache
  `orante.plus.lastConfirmedActive` guarda sempre o valor real.
  Narração de versículo: sempre via `VerseNarrationStarter.start` (botões e ação de VoiceOver). Terço Guiado sem
  Plus: Próximo/Anterior caem para Manual sem narrar; progresso salvo como Guiado reabre em Manual
  (`RosaryViewModel`, `EntitlementProviding` injetável) e chamam o gate (aviso/paywall). Cadeado único:
  `PremiumLockBadge` (`Core/Theme`), visível só para não assinante confirmado (nunca em `.unknown`).
  Restaurar: o alerta do SDK (`SuperwallOptions.paywalls.restoreFailed`) é localizado e o app só mostra o seu
  quando o SDK não mostrou (`RestoreAlertRules`) — um único alerta.
- `create_mix` usa `source` `library`, `home`, `player` (inclusive o botão do sheet de som ambiente) e `saved_mix`.
- Placements: `premium_sound`, `premium_soundscape`, `create_mix`, `bible_narration`, `guided_rosary`,
  `custom_timer`, `widget_theme`, `settings_upgrade` ("Conhecer Orante+", via gate `.upgrade`) e `onboarding_end`
  (único non-gated sem aviso: não é recurso pago).
- Widget: uma cor paga sem Plus vira Terracota com o selo "Cor do Orante+". Na Tela de Início, o toque abre
  `zensounds://plus` (`PlusDeepLink`), que chama `widget_theme` com `source=widget`. A lista de cores usa
  `WidgetBackgroundThemeOptionsProvider` (IntentItem): "(Orante+)" para quem não assina; o parâmetro continua AppEnum.
- URLs: Privacidade https://jcapps.dev.br/orante/privacidade · Suporte https://jcapps.dev.br/orante/suporte ·
  Termos = EULA padrão da Apple.

## NÃO ALTERAR
Bundle ID `com.juliocezar.zensounds` (widget `.ZenSoundsWidgets`), App Group `group.com.juliocezar.zensounds`,
esquema `zensounds://` (rotas bíblicas + Superwall), chaves de UserDefaults existentes (`zensounds.*`,
`daily_word_*`, `plus_active`, `orante.*`), Product IDs, entitlement `plus`, deployment target iOS 18.0.

## Convenções e gotchas
- Toda classe `ObservableObject` precisa de `import Combine` explícito (senão não compila).
- Pastas sincronizadas do Xcode: criar arquivo na pasta basta. **Não editar `project.pbxproj` à mão.**
- Recursos vão para a raiz do bundle: nomes precisam ser únicos (ex.: `GEN_pt.json`, não `pt/GEN.json`).
- Todo texto novo vai em `Localizable.xcstrings` com en + pt-BR (widget tem catálogo próprio).
  Chaves usadas só em runtime via `AppLanguage.localized(...)` (ex.: `sound_*`, `soundscape_*`, `reference_*`,
  `Chapter`) aparecem como **stale** no catálogo, mas estão em uso — **não "remover stale" em massa**.
- O idioma é override interno (`AppLanguage`), por isso muitas views usam `AppLanguage.localized` em vez de
  `LocalizedStringKey`.
- Singletons `.shared` observados nas views (`@ObservedObject`); regras de negócio em enums/structs puros testáveis.
- Fontes em `Resources/Fonts` têm PostScript names corrigidos — não substituir pelos originais do Android.
- Com `ENABLE_DEBUG_DYLIB`, o código real fica em `ZenSounds.debug.dylib`, não no executável.
- Botões no topo de `fullScreenCover` devem ser `ToolbarItem` (hit-testing). Mini-player "Som ambiente" via
  `.ambientMiniPlayer(.always/.whenActive)` por tela (safeAreaInset); não usar `tabViewBottomAccessory` (é global).
  Sem som tocando, mostra o último som (Chuva na 1ª vez). No Terço, aplicar `.ambientMiniPlayer` **antes** do
  `safeAreaInset` dos botões (ordem dos insets).
- Hoje e Buscar escondem a navigation bar e desenham título grande próprio (Buscar tem campo de busca próprio:
  `.searchable` não mostra título grande e campo fixo juntos).
- Tamanhos fixos que precisam crescer com Dynamic Type usam `@ScaledMetric` (ícones das linhas, cadeado, botões
  grandes); cards com arte usam a arte em `.background` para a altura seguir o texto.
- `SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY = YES`: usar `CGRect`/`CGSize` exige `import CoreGraphics`.
- Argumentos padrão são avaliados fora do MainActor: para defaults como `SuperwallService.shared`, use parâmetro
  opcional e resolva dentro da função/init.
- `CFBundleName` vem de `PRODUCT_NAME` (= "ZenSounds") no Info.plist gerado; a chave no `Info.plist` e o valor en
  do `InfoPlist.xcstrings` são ignorados. O nome visível é o `CFBundleDisplayName` = "Orante".
- `UpdateTargetBuildSetting` só aceita settings que aparecem em `GetTargetBuildSettings` (recusa
  `ASSETCATALOG_COMPILER_APPICON_NAME`); nesse caso, peça ao usuário para mudar no Xcode.
- Lançamento **só iPhone**, só em retrato: `TARGETED_DEVICE_FAMILY = 1` no app e no widget (os testes ficam em
  1,2,7); orientação do iPhone = `UIInterfaceOrientationPortrait`.
- Edição de `.xcstrings` fora do Xcode: o round-trip `json.dumps(indent=2, ensure_ascii=False,
  separators=(",", " : "))` preserva o formato byte a byte. O build do Xcode pode mudar estados (ex.: `needs_review`).
- Honestidade: nunca declarar teste aprovado sem resultado; separar o que foi executado do que depende de
  iPhone físico, sandbox/TestFlight ou App Store Connect.

## Build e testes
- Xcode MCP: `BuildProject` (scheme `ZenSounds` já compila o widget; use `buildForTesting: true`),
  `RunAllTests`, `XcodeRefreshCodeIssuesInFile` para checagem rápida. `RunCodeSnippet` historicamente falha aqui.
- Se o runner devolver "No result", recompilar e rodar de novo antes de concluir algo.
- Baseline 2026-10-16 (redesign, branch `redesign/orante`): build Debug OK, 0 avisos; **153/153 testes aprovados**
  (casos parametrizados contam separadamente); Release OK e sem `orante.debug.plusOverride` no binário. Build Release funciona via CLI:
  `xcodebuild -project ZenSounds.xcodeproj -scheme ZenSounds -configuration Release -destination
  'generic/platform=iOS Simulator' -derivedDataPath /tmp/OranteRelease CODE_SIGNING_ALLOWED=NO build`.
- `PlacementCase` tem `testDescription` estável (antes a ordem do dicionário causava "No result").

## Pendências (atualizado em 2026-10-16, fim do redesign)
Resolvidas na sessão 2: URLs jcapps.dev.br + link Suporte; acessos sem paywall (ação VoiceOver do versículo,
Próximo/Anterior do Terço Guiado, progresso Guiado restaurado); fade do timer com selo "+" e validação de 1–1440;
erros de narração traduzidos; chaves mortas removidas; widget só iPhone; explicação de temas do widget;
geometria do diagrama do Terço e rótulos de acessibilidade das contas traduzidos.

Em aberto:
1. Ícone: o asset catalog já está ligado (`ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon`, `CFBundleIconName` no
   Info.plist compilado, conferido no simulador). Os PNGs legados `Resources/AppIcon-*.png` (com alpha) e
   `CFBundleIconFiles` foram **mantidos de propósito**; só remover quando o usuário pedir.
2. `CFBundleName` em inglês continua "ZenSounds" (vem de `PRODUCT_NAME`) **por decisão do usuário**. Não renomear
   o produto.
3. Os rótulos do Terço (nomes das orações, contas, progresso) seguem o idioma do conteúdo (`bibleLanguage`) com
   pt/en no código. Os rótulos de catálogo do diagrama ("Decade %lld" etc.) seguem o locale da interface. Os dois
   só divergem com Idioma = Sistema em um iPhone que não está em pt nem en.
4. Os docs citam `accessoryCircular` no widget, mas o código não tem.
5. Salmos 34:18 (pt) "sava" é erro do upstream (HelloAO/Bíblia Livre); não alterar o texto bíblico. Salmos 119:105
   tem "Nun :" (letra do acróstico) no texto; só o hero da aba Bíblia remove para exibição.
6. Widget: fontes com `.system(size:)` mantidas (padrão de widget). Redesign validado só por previews e testes;
   falta a passada manual no simulador/iPhone (paywalls, cadeados, deep links, widget, áudio em segundo plano).
7. Chaves stale anteriores ao redesign (ex.: "System default", "Bible translation", "Read in the Bible") não
   foram removidas: conferir uma a uma antes.
