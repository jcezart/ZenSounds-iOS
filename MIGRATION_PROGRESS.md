# ZenSounds — Progresso da migração Android → iOS

Migração de https://github.com/jcezart/ZenSounds (Kotlin/Compose) para iOS nativo (Swift/SwiftUI).
Este arquivo é a fonte de verdade de progresso: se a execução for interrompida, leia aqui antes de continuar.

## Sessão 2 (2026-10-11): rename do projeto + correção de divergências com o Android atual

O usuário renomeou o projeto/target no Xcode de "Untitled Project"/"MyApp" para "ZenSounds"/"ZenSounds" e moveu a pasta de
`/Users/jc/Library/Developer/Xcode/UntitledProjects/Untitled Project` para `/Users/jc/Documents/ZenSounds` (git preservado,
histórico intacto). Isso deixou duas configurações desatualizadas que quebravam o build/testes:
- `INFOPLIST_FILE` do target `ZenSounds` ainda apontava para `MyApp/Info.plist` — corrigido para `ZenSounds/Info.plist`.
- `ZenSoundsTests.swift` ainda tinha `@testable import MyApp` — corrigido para `@testable import ZenSounds`.

Depois do rename, o usuário reportou que a tela Sons parecia usar elementos de uma versão antiga do Android. Reclonei
`jcezart/ZenSounds` (mesmo commit `5ff3bd4`, nada mudou no repo) e reli `SoundUI.kt`, `SoundPlayerUI.kt`, `MixUI.kt` atuais
(ignorando a pasta de backup). Achados reais (comparando com o backup antigo via diff):

- **CRASH REAL encontrado e corrigido**: `AudioEngine.init()` nunca conectava `engine.mainMixerNode` ao `engine.outputNode`
  explicitamente — o engine lançava `inputNode != nullptr || outputNode != nullptr` ao tentar `engine.start()` assim que
  QUALQUER som era tocado. Corrigido com `engine.connect(engine.mainMixerNode, to: engine.outputNode, format: nil)` no init,
  mais `engine.prepare()` antes de `engine.start()`, mais ativação síncrona (não `Task.detached`) do `AVAudioSession` antes do
  `start()` para evitar uma corrida. Confirmado via simulador real (device-interaction): toca sem crash agora.
- **Funcionalidade real do Android atual que faltava no PlayerView iOS**: botões Previous/Next (navegação sequencial pelo
  catálogo de sons, só em modo som único) e carrossel horizontal "Other sounds" (trocar de som direto, excluindo o atual) —
  ambos existem em `SoundPlayerUI.kt` atual (não existiam no backup antigo). Implementados em
  `AudioEngine.playAdjacentSound(offset:)` + `PlayerView.transportControls`/`otherSoundsCarousel`. Confirmados funcionando
  no simulador.
- O resto (grid de cards ao invés de linhas de lista, timer em sheet ao invés de inline, "add sound" simplificado ao invés
  de abrir o editor de mix completo) é adaptação deliberada às convenções de iOS, não uma divergência — Android também usa
  um layout de lista diferente do grid, mas o pedido explícito do usuário foi redesenhar para iOS, não replicar 1:1.

**Pendência não resolvida — investigar com cautela, não repetir o mesmo caminho de debugging:** os botões "X" (fechar) e
chevron-down (minimizar) do `PlayerView` não respondem a toques sintetizados via a ferramenta de device-interaction deste
ambiente, mesmo após: trocar de `@Environment(\.dismiss)` para setar `PlayerPresentation.shared.isFullPlayerPresented`
diretamente, aumentar a área de toque para 44x44 com `.contentShape(Rectangle())`, e variar o padding do topo (8/12/32pt).
Confirmado via `print()` de debug + inspeção do binário (`ZenSounds.debug.dylib` — **importante**: o executável principal do
app é só um stub quando `ENABLE_DEBUG_DYLIB=YES`; o código real mora no `.debug.dylib` dentro do `.app`, não no executável
principal — usar esse arquivo para qualquer inspeção futura de binário) que o código está correto e compilado, mas o toque
sintetizado simplesmente não dispara a closure do botão, enquanto o botão play/pause (mais abaixo na tela) responde
normalmente com a mesma ferramenta. Hipótese mais provável: limitação da ferramenta de automação de toques deste ambiente
especificamente na faixa superior da tela (próxima à Dynamic Island/status bar), não um bug real do app. **Recomendo
verificar manualmente no simulador do Xcode (clique do mouse, não automação) antes de assumir que é um bug real.** Não
gastar mais ciclos de subagent nisso sem antes tentar um clique manual real.

**Outra pendência**: `RunAllTests` passou a retornar "No result" para as 13 unit tests após o rename (nenhum erro de
compilação, nenhum crash no console, configuração de scheme/test plan aparentemente normal). Os mesmos 13 testes passaram
100% antes do rename (na sessão 1). Não identifiquei a causa raiz dentro do tempo razoável — recomendo `Cmd+U` direto no
Xcode para confirmar se é um problema deste ambiente de automação ou algo real.

## Sessão 3 (2026-10-11): botões de fechar/minimizar do player — bug real confirmado pelo usuário

O usuário testou manualmente no simulador (clique real, não automação) e confirmou: os botões "X" e chevron-down no topo
do `PlayerView` não respondiam a toque algum — nem o efeito visual de "apertado" aparecia. Isso invalidou minha hipótese
anterior de que era só uma limitação da ferramenta de device-interaction; era um bug real de hit-testing.

**Causa raiz**: os botões eram posicionados manualmente num `HStack` dentro de um `ZStack` com `.ignoresSafeArea()` no
fundo, sobre um `fullScreenCover`. Algo nessa combinação (ordem de z-index/hit-testing específica do iOS 27 ou da
apresentação em tela cheia) impedia o toque de chegar à `Button`, mesmo com área de toque de 44x44 e padding variado.

**Correção**: reestruturei `PlayerView.swift` para envolver o conteúdo num `NavigationStack` próprio e usar
`.toolbar { ToolbarItem(placement: .topBarLeading/.topBarTrailing) { Button {...} } }` — botões reais da barra de
navegação nativa do UIKit em vez de views customizadas flutuando sobre o fundo. `.toolbarBackground(.hidden, for:
.navigationBar)` mantém o fundo transparente (visual igual, agora com o estilo "glass" padrão do sistema para botões de
toolbar sobre conteúdo customizado). Conteúdo movido para dentro de um `ScrollView` (evita overflow em telas menores agora
que player tem mais controles). **Confirmado funcionando via device-interaction**: abrir som, minimizar (aparece mini
player), fechar (para tudo), reabrir, tudo ok.

**Bug adicional encontrado durante a verificação** (não reportado pelo usuário, achado pelo subagent de teste): com o mini
player visível, a tab bar nativa ficava **totalmente inacessível** — todo toque nela era capturado pelo mini player em vez
de trocar de aba. Causa: `.safeAreaInset(edge: .bottom)` estava aplicado direto no `TabView`, o que faz o conteúdo do inset
renderizar na frente da barra de abas nativa e roubar seus toques. **Correção**: criei um `ViewModifier`
(`CompactPlayerInset`/`.withCompactPlayer()`) e apliquei o `safeAreaInset` em cada `NavigationStack` de cada aba
individualmente, não no `TabView`. Confirmado via device-interaction: trocar de aba funciona normalmente com o mini player
visível, e tocar no mini player ainda reabre o player cheio corretamente.

**Lição para sessões futuras**: as rodadas anteriores de device-interaction que reportaram falha nos mesmos botões
provavelmente estavam certas desde o início — eu as atribuí erroneamente a uma limitação da ferramenta. Confiar nos
resultados repetidos e consistentes da automação, especialmente quando múltiplas tentativas independentes dão o mesmo
resultado.

## Fatos confirmados sobre o Android (não re-analisar)

- Bíblia offline: `assets/bible/{pt,en}/{CODE}.json.gz`, 66 livros cada, schema HelloAO (`schema`, `translation`, `book`, `chapters`). pt = Bíblia Livre (BLJ), en = KJV. `manifest.json` tem hashes/licenças.
- Palavra do dia: `data/DailyReadings.kt`, ~148 refs curadas, `shuffled(Random(104729))`, seleção = `floorMod(epochDay, size)`. Persistida em SharedPreferences (`zensounds_daily_word`); shuffle manual sobrescreve até virar o dia.
- 8 sons fixos (Rain, Storm, Wind, Forest, Stream, Fireplace, TV Static, Car Engine), mp3 em `res/raw/`, artwork em `res/drawable/`.
- Player real = Media3 ExoPlayer via MediaSessionService (`services/PlaybackService.kt`). Mix = 1 player primário + N secundários, ganho normalizado (`MixRules.gains`).
- Mixes salvos: SharedPreferences `saved_mixes`, JSON via Gson (`data/PlaybackModels.kt`).
- Timer: Handler com tick de 500ms, deadline em `elapsedRealtime`, fade linear configurável 0-60s (`data/PlaybackModels.kt::TimerRules`).
- Favoritos: SharedPreferences (`favorite_sounds` Set<String>, `favorite_verses` JSONArray).
- Tema: `ui/theme/Theme.kt` — paleta `EssenceLight`/`EssenceDark` (hex exatos capturados abaixo), fonte Plus Jakarta Sans.
- Widgets: AppWidgetProvider/RemoteViews (não Glance), 2 tamanhos, update em troca de data.
- **Sem ads/PRO/billing implementado** — só dependências Gradle não usadas. Ignorar completamente.
- Código morto a NÃO portar: `AudioPlayerManager.kt`, `CarouselViewModel.kt`, API Retrofit da Bíblia.

Paleta (hex ARGB sem alpha, light/dark): background F5F1EB/181719, surface FFFDF9/242226, text 292622/F5EFE7,
secondaryText 6E6864/BAB1AC, accent A3533C/E3AA8E, onAccent FFFFFF/2C1B15, verseBackground 98503B/754231,
onVerse FFFAF3/FFF6EB, lilac E5DEEB/39323F, outline E5DDD5/3B3539, track DED6E0/49404B, foliage 656747/B8BA92.

Repo Android clonado em `/tmp/ZenSounds-analysis` (pode não persistir entre sessões — reclonar se ausente).

## Estado do projeto Xcode

- Único target `MyApp`, iOS 27 SDK, DEVELOPMENT_TEAM `F44CYBRGC2` já configurado.
- Projeto git inicializado nesta migração (não existia antes).

## Status dos módulos

- [x] 1. Configuração do projeto — bundle id com.juliocezar.zensounds, SUPPORTED_PLATFORMS=iphoneos/iphonesimulator, TARGETED_DEVICE_FAMILY=1,2, UIBackgroundModes=audio, CFBundleDisplayName=ZenSounds, .gitignore, App/ZenSoundsApp.swift + App/RootView.swift (placeholder)
- [~] 2. Dados da Bíblia offline — ASSETS COPIADOS, modelos/repositório Swift AINDA NÃO ESCRITOS
  - 132 JSONs descomprimidos em `MyApp/Resources/Bible/{CODE}_{lang}.json` (nomes flat com sufixo de idioma — IMPORTANTE: os grupos sincronizados do Xcode acham recursos copiados em subpastas pt/en no bundle root, então `GEN.json` de pt e en colidiam. Resolvido renomeando para `GEN_pt.json`/`GEN_en.json`, todos no mesmo diretório `Resources/Bible/`. Qualquer código novo de leitura deve usar esse padrão de nome, não subdiretórios.)
  - `manifest.json` copiado para `Resources/Bible/manifest.json`
  - Áudio copiado para `Resources/Audio/{Rain,Storm,Wind,Forest,Stream,Fireplace,TVStatic,CarEngine}.mp3`
  - Fontes Plus Jakarta Sans copiadas para `Resources/Fonts/*.ttf` + registradas em Info.plist (UIAppFonts) + licença em `Resources/Fonts/plus_jakarta_sans_license.txt`
  - Artwork dos 8 sons copiado para `Assets.xcassets/SoundArt/{Name}.imageset`

- [x] 2. Dados da Bíblia offline — COMPLETO
  - `Resources/Bible/books.json` gerado a partir dos 66 arquivos reais (code, order, chapters, name_pt, name_en) — validado: exatamente 66 livros, GEN order=1, REV order=66
  - `Resources/Bible/daily_readings.json` com as 132 referências curadas reais do Android (`DailyReadings.kt`), embaralhadas com seed fixo (não precisa bater com o PRNG do Kotlin — apenas precisa ser estável e único dentro do app iOS)
  - `Core/Models/BibleModels.swift`: BibleBook, Verse, DailyReadingRef, BibleManifest/TranslationInfo, tipos raw (BibleRawFile etc.) fiéis ao schema HelloAO (schema=1, book.id/order/numberOfChapters, chapters chaveado por string, content com type="verse" e peças de texto/lineBreak)
  - `Core/Services/BibleCatalog.swift`: carrega books.json/daily_readings.json/manifest.json do bundle
  - `Core/Services/BibleRepository.swift`: lê `{CODE}_{lang}.json` do bundle root, decodifica, cacheia em NSCache
  - `Core/Services/DailyWordStore.swift`: seleção determinística por `floorMod(epochDay, count)` usando `Calendar.current.startOfDay` (hora local), persistida em UserDefaults(suiteName: App Group) para o dia corrente; shuffle() escolhe outra referência e persiste até a troca de data — espelha o DailyWordStore.kt do Android
  - Entitlement App Group `group.com.juliocezar.zensounds` adicionado ao target MyApp (necessário também na extensão de widget quando criada — módulo 14)
  - **NOTA**: ainda não há teste automatizado real rodando (RunCodeSnippet não funcionou neste ambiente — retornou erro genérico "The data couldn't be read because it is missing" mesmo para `print("hello")`; parece ser limitação do ambiente/sandbox, não do código). Validação de parsing ficará para o target de testes XCTest (módulo 17) e verificação manual no simulador.
- [ ] 3. Tema/tipografia
- [ ] 4. Localização pt-BR/en
- [ ] 5. Navegação principal + mini player
- [ ] 6. Catálogo de sons/assets
- [ ] 7. Motor de áudio (AVAudioEngine)
- [ ] 8. Telas de player
- [ ] 9. Mixagem + mixes salvos
- [ ] 10. Timer
- [ ] 11. Favoritos
- [ ] 12. Bíblia UI
- [ ] 13. Palavra do dia + Explorar
- [ ] 14. Widgets
- [ ] 15. Configurações
- [ ] 16. Acessibilidade/polish
- [ ] 17. Build/testes finais

## Erros conhecidos / pendências

- RunCodeSnippet não funciona neste ambiente (erro genérico mesmo para `print("hello")`). Use RenderPreview (via #Preview) para validação visual — funciona bem e já confirmou tema/fontes.
- GOTCHA de toolchain: toda classe `ObservableObject` precisa de `import Combine` explícito neste projeto, ou falha com "does not conform to protocol 'ObservableObject'" / "missing import of defining module 'Combine'" mesmo com `import SwiftUI` presente. Já corrigido em ThemeMode.swift e UserPreferencesStore.swift — lembrar nos próximos arquivos (ex.: AudioEngine, ViewModels).
- Fontes Plus Jakarta Sans do Android (`res/font/*.ttf`) tinham TODAS o mesmo PostScript name interno "PlusJakartaSans-Regular" (bug latente invisível no Android, que carrega por caminho de arquivo). Corrigido reescrevendo a name table de cada arquivo com fontTools (pip instalado on-the-fly) para nomes únicos: PlusJakartaSans-Regular/-Medium/-SemiBold/-Bold. Os arquivos em `Resources/Fonts/*.ttf` já estão corrigidos — não reverter para os originais do Android.
- Localizable.xcstrings criado vazio; strings sendo adicionadas incrementalmente conforme as telas são construídas (chaves como `sound_rain`, `category_nature` etc. já reservadas em SoundModels.swift). Tradução pt-BR completa (via skill translation-coordinator) ainda PENDENTE — fazer antes da entrega final.

## Status dos módulos (continuação)

- [x] 3. Tema/tipografia — EssencePalette (light/dark, hex exatos), EssenceTypography (Dynamic Type via Font.custom relativeTo), ThemeManager (system/light/dark, persistido em UserDefaults), ZenSoundsTheme wrapper. Validado visualmente via RenderPreview (claro e escuro).
- [~] 4. Localização — infraestrutura criada (Localizable.xcstrings vazio, source=en). Conteúdo e tradução pt-BR pendentes até telas estarem escritas.
- [x] 6 (parcial/modelos). SoundModels (8 sons reais, categorias), MixModels (MixRules fiel ao Android), TimerModels (TimerRules com systemUptime), UserPreferencesStore (favoritos sons/versículos + mixes salvos, UserDefaults+JSON)

- [x] 7. Motor de áudio (AVAudioEngine) — COMPLETO
  - `Core/Services/LoopingPlayer.swift`: loop sem gaps via AVAudioPlayerNode + scheduleFile duplo-enfileirado (padrão Apple recomendado), sem carregar o arquivo inteiro em memória (importante pro thunder_sound de 12.6MB/~9min)
  - `Core/Services/AudioEngine.swift` (singleton `AudioEngine.shared`, `@MainActor`, `ObservableObject`): som único e mix (N AVAudioPlayerNode -> mainMixerNode), volume por camada via `MixRules.gains`, play/pause/resume/stop completo, reabrir mesma combinação não reinicia, timer com fade (tick de 500ms via Task, deadline em `ProcessInfo.systemUptime`), AVAudioSession categoria `.playback` (áudio em segundo plano), tratamento de interrupção (pausa/retoma) e troca de rota (pausa ao desconectar fone — `oldDeviceUnavailable`), MPNowPlayingInfoCenter + MPRemoteCommandCenter (play/pause/toggle/stop)
  - **NÃO TESTADO EM DISPOSITIVO/SIMULADOR AINDA** (áudio real, interrupções, Now Playing) — apenas compilação validada. Testar de fato no simulador fica para o módulo 17.

- [x] 5. Navegação (TabView 4 abas + NavigationStack por aba + reset ao reselecionar + mini player via safeAreaInset)
- [x] 8. Player completo (PlayerView) + compacto (CompactPlayerView) — refletem AudioEngine real, botão fechar chama audio.stop()
- [x] 9. Mixagem (SoundMixEditorView) + Meus Mixes na aba Sons (SoundsLibraryView) + persistência via UserPreferencesStore
- [x] 10. Timer (TimerSheetView: presets + custom + fade slider + cancelar), usa AudioEngine.setTimer/cancelTimer
- [x] 11. Favoritos (FavoritesView: sons + versículos, swipe-to-delete, estado vazio); volta à raiz ao reselecionar aba (NavigationModel.resetPath)
- [x] 12. Bíblia (BibleBooksView -> BibleChaptersView -> BibleVersesView), favoritar/compartilhar versículo, scroll-to-verse para deep link
- [x] 13. Palavra do dia (DailyWordViewModel/Card) + card "Explore {Book}" dinâmico, abre o capítulo certo via NavigationModel.openBible
- [x] 15 (parcial). SettingsView: tema, idioma da Bíblia, créditos/licença de tradução — falta remover do fluxo caso não acessível (está acessível via engrenagem na Home)

**VALIDADO VISUALMENTE (RenderPreview, não é o mesmo que rodar no simulador):**
- Home: card da palavra do dia com texto real em português (Mateus 6:26, da lista curada), card "Explore Mateus" dinâmico, tab bar com 4 abas
- Sounds: grid de categorias com artwork real (rain/thunder/wind/forest/stream/fire/tv/car), botão de criar mix
- Bible: Salmos 23 com texto real da tradução Bíblia Livre, numeração de versículos, favoritar/compartilhar

- [x] 14. Widgets WidgetKit — COMPLETO
  - Novo target `ZenSoundsWidgetsExtension` (App Extension, embutido em MyApp), iOS-only, App Group `group.com.juliocezar.zensounds` também na extensão
  - `ZenSoundsWidgets/WidgetModels.swift`: fonte de dados PRÓPRIA da extensão (não acessa o bundle do app principal) — `daily_readings_resolved.json` (132 referências com texto pt/en pré-resolvido, ~41KB) + `books.json` (~8KB), copiados do pipeline da Bíblia mas SEM duplicar os 14MB+ da Bíblia completa (orçamento de memória do processo de widget é apertado)
  - `ZenSoundsWidgets/WidgetDailyWordStore.swift`: reimplementação paralela (mesmas chaves, mesmo App Group) do `DailyWordStore` do app principal — **MANTER SINCRONIZADO** se as chaves mudarem
  - `ZenSoundsWidgets/ShuffleDailyWordIntent.swift`: AppIntent interativo (iOS 17+ `Button(intent:)`) para sortear outra palavra direto no widget médio/grande
  - `ZenSoundsWidgets/ZenSoundsWidgets.swift`: tamanhos `.systemSmall/.systemMedium/.systemLarge` + tela de bloqueio `.accessoryRectangular/.accessoryInline/.accessoryCircular`; pequeno só abre capítulo (sem shuffle, por legibilidade); timeline recalcula na meia-noite local (`Timeline(..., policy: .after(nextMidnight))` — best-effort, sem prometer horário exato)
  - Deep link `zensounds://chapter/{book}/{chapter}/{verse}` via `widgetURL` -> `DeepLinkHandler.swift` no app principal -> `NavigationModel.shared.openBible` (NavigationModel agora é singleton `.shared` para ser acessível de `onOpenURL`)
  - **VALIDADO VISUALMENTE** via RenderPreview (widget pequeno e médio, cores e texto reais, botão shuffle visível no médio)
  - **NÃO TESTADO**: pin real na tela de bloqueio/home no simulador, atualização de fato à meia-noite, comportamento do App Group em dispositivo real (requer conta Apple Developer logada no Xcode para registrar o grupo de fato)

- [x] 4. Localização — COMPLETO
  - `LocalizationPlanner` preparou 4 catálogos: `MyApp/Resources/Localizable.xcstrings`, `MyApp/Resources/InfoPlist.xcstrings`, `ZenSoundsWidgets/Localizable.xcstrings`, `ZenSoundsWidgets/InfoPlist.xcstrings`
  - Adicionadas manualmente ao catálogo principal (en) as chaves dinâmicas que o extrator do Xcode não pega automaticamente (chaves construídas em runtime, não literais): `sound_*` (8), `category_*` (3). Refatorado `DailyWordCard`/`SoundsLibraryView` para usar `NSLocalizedString` com literais ("Explore %@", "My Mixes") em vez de strings concatenadas, permitindo extração automática
  - 82 chaves em `Localizable.xcstrings` + 7 no catálogo do widget + 5 de InfoPlist traduzidas para pt-BR via skill `translation-coordinator` (7 sub-agents em 2 rodadas, usando a skill `xcode-integration:translation` e o guia de estilo pt-BR)
  - "ZenSounds" nunca traduzido (CFBundleDisplayName/CFBundleName mantidos); "Zen"/"Sounds" (wordmark em duas partes) preservados
  - **VALIDADO VISUALMENTE**: SoundsLibraryView em pt-BR via RenderPreview com `previewLocalizationOverride: "pt-BR"` — "Sons", "Sons da Natureza/Objetos/Veículos" corretos

- [x] 16. Acessibilidade — COMPLETO (auditoria + correções aplicadas)
  - VoiceOver: corrigidos 4 problemas reais — Slider de volume master não ficasse preso num `.accessibilityElement(children:.combine)` (quebrava a interação adjustable), `MixRow` sem trait/ação de botão exposta, `sectionHeader` sem trait `.isHeader`, `ShareLink` de versículo sem label explícito. Também: ícones decorativos ocultados (`accessibilityHidden`), número+texto do versículo agrupados para leitura única, countdown do timer marcado `.updatesFrequently`
  - Dynamic Type: validado visualmente em AX5 (RootView) via RenderPreview — texto escala corretamente, sem cortes
  - Contraste (WCAG 2.1): todos os pares texto/fundo da EssencePalette ≥4.5:1 (normal) tanto claro quanto escuro; corrigido o único ponto fraco (botão "Explorar" no card da palavra do dia, cápsula semitransparente clara trocada por escura, 4.1:1 -> 6.9:1)
  - Safe areas: mini player usa `.safeAreaInset(edge: .bottom)` (não cobre conteúdo); telas usam `.navigationTitle`/List/ScrollView padrão do sistema (safe area automática)
  - Estados vazio/erro/carregamento: `ContentUnavailableView` (capítulo indisponível, livro não encontrado), estado vazio de Favoritos, `ProgressView` ao carregar capítulo e ao carregar a palavra do dia
  - **NÃO TESTADO**: VoiceOver real em dispositivo/simulador (apenas análise estática de código); Increased Contrast / Reduce Transparency no simulador

## Próxima etapa

Build final completo (iOS simulator), testes unitários (BibleRepository/DailyWordStore/MixRules/TimerRules), relatório de entrega (módulo 17).
