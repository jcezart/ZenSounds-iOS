# ZenSounds — auditoria de qualidade e prontidão para a App Store

Data: 14 de outubro de 2026. Escopo: app iOS, widget e aba Terço existentes no repositório.

## Resumo executivo

O código compila em Debug, os 48 testes executam e passam, o build final não emite avisos e foram corrigidos defeitos reais de áudio, persistência, deep link, localização, acessibilidade e empacotamento. O envio ainda depende de um Archive/Validate no Organizer, testes físicos de áudio/widget e configuração da ficha no App Store Connect.

## Baseline e resultado final

| Verificação | Baseline | Final |
| --- | --- | --- |
| Build Debug app + widget | OK, 3,183 s + 5,832 s | OK conjunto, 2,453 s |
| Avisos de compilação | 0 no build normal | 0 |
| Testes | 39 `No result` (0 executados) | 48 aprovados, 0 reprovados, 0 não executados |
| Release / Any iOS Device | CLI impedido pelo sandbox/plugin server | Pendente no Organizer |

O `No result` foi causado por `TEST_HOST` ainda apontar para `MyApp.app/MyApp`. Foram corrigidos `TEST_HOST`, `BUNDLE_LOADER` e a equipe do target de testes; depois disso o runner executou normalmente. O build Release via `xcodebuild` foi tentado com o Xcode completo, mas o ambiente restrito retornou respostas malformadas dos macro/plugin servers. Isso não foi registrado como aprovado.

Ferramentas: `/Applications/Xcode.app` usa SDK iOS 27, atendendo ao requisito de SDK iOS 26+. O `xcode-select` global apontava para CommandLineTools.

## Falhas conhecidas investigadas

| Hipótese | Resultado e evidência | Ação |
| --- | --- | --- |
| Engine/sessão ativas na pausa e fim do timer | Confirmada: apenas os nodes pausavam | `engine.pause()` e desativação ordenada da sessão, preservando `resume()` |
| Corrida na desativação da sessão | Confirmada: `Task.detached` podia ultrapassar uma nova ativação | fila serial e activation/deactivation aguardáveis |
| Nome vazio fecha editor | Descartada no código atual: `dismiss()` já fica condicionado ao retorno não nulo | nenhuma |
| Edição gera IDs duplicados / nome sobrescreve | Confirmada no serviço | edição preserva ID; colisão case-insensitive é rejeitada; limite de 40 testado |
| Editar mix inalcançável | Confirmada: só existe rota com `existingMixId: nil` | recomendação; nenhuma UI nova criada |
| Adicionar/remover camada reinicia tudo | Confirmada: ambos recompõem e chamam `play` | recomendação; mudança de áudio considerada arriscada |
| Compartilhamento mostra `PSA` | Confirmada | passa a usar nome localizado do livro |
| Strings inglesas | Confirmada | erros de áudio/narração e 9 strings do widget traduzidos; catálogos pt-BR têm 0 pendentes |
| Recursos mortos | Confirmada por busca | removidos TVStatic, CarEngine, JSON duplicado e ícones PNG legados/Info.plist |
| PNGs pesados | Confirmada | Rain/Storm/Forest convertidos visualmente para JPEG: ~6,8 MB para ~0,95 MB |
| Comentários obsoletos | Confirmada | três comentários corrigidos |

## Testes criados e executados

- Preferências: favoritos, salvar/editar/duplicar/truncar mix, remover mix e posição de leitura.
- Deep link: rota válida, componentes faltantes/extras, livro inexistente e números inválidos.
- Bíblia: 66 livros, ambos idiomas e todos os capítulos declarados; capítulo excedente vazio.
- Recursos: MP3 e arte de cada som, paisagens bíblicas e capítulo, fontes pelos PostScript names.
- Permaneceram os testes existentes de áudio, timer, Terço, leitura diária, widget e modelos.

Resultado final: **48/48 aprovados** no simulador iPhone 17/iOS 27. Não foi criado target XCUITest porque a alteração estrutural seria desproporcional nesta sessão; os fluxos manuais pendentes estão abaixo.

## Diagnóstico Xcode

| Item | Resultado |
| --- | --- |
| Build normal | executado; sucesso; 0 avisos |
| Strict concurrency `complete` | executado temporariamente e revertido |
| Product Analyze | não disponível pela integração; CLI bloqueado pelo sandbox |
| Thread Sanitizer | ferramenta de configuração rejeitou o setting; testes normais passaram, não atribuir a TSan |
| Address Sanitizer | não executado: diagnóstico é de Scheme e não estava exposto com segurança |
| Main Thread Checker | configuração Debug padrão; nenhum incidente observado nas duas telas executadas |
| Instruments Leaks/Allocations/Time/Energy | Instruments não disponível neste ambiente; pendente físico/manual |

Avisos relevantes da compilação estrita: propriedades estáticas não isoladas no widget (`ShuffleDailyWordIntent`, `WidgetModels`, `ZenSoundsWidgets`) e callback de conclusão de `LoopingPlayer` chamando método isolado ao ator principal. O modo estrito não ficou ligado. Recomenda-se resolver antes de elevá-lo à política do projeto.

Revisão estática: `NSCache` da Bíblia não tem limite explícito (a memória é descartável sob pressão, mas merece métrica); observadores e remote-command targets vivem em singletons, portanto não configuram vazamento de instâncias transitórias. Há `try?` em caminhos recuperáveis; erros críticos de áudio/narração agora chegam ao estado apresentado ao usuário.

## Acessibilidade

- VoiceOver: **NEEDS VERIFICATION** física. Labels das duas telas inspecionadas estavam presentes; as cinco abas estavam nomeadas. O audit automatizado completo não rodou por falha do dispositivo remoto.
- Dynamic Type: **FAIL** na auditoria estática global: ainda há textos com `.font(.system(size:))`, sobretudo no widget e em componentes. As fontes Essence usam `relativeTo`, mas isso não cobre todos os textos.
- Contraste: **NEEDS VERIFICATION** nas telas com imagens/gradientes e estados. A paleta já havia sido calculada como adequada nos pares principais, mas não houve varredura visual completa nesta sessão.
- Alvos de toque: a execução encontrou quatro controles de 12–21 pt no cartão diário. Foram ampliados para 44×44 pt; build e testes finais passaram.

No simulador foram efetivamente abertas Início e Bíblia; não houve crash e a lista da Bíblia estava íntegra. Depois, três chamadas seguidas retornaram exatamente `Target device has invalid screen scale. Make sure your machine can access the remote device.`. Rosário, Sons, Favoritos, player, deep link, idioma, timer, rotação e accessibility audit ficaram **não executados**.

## Checklist de upload Apple

| Item | Estado |
| --- | --- |
| Xcode/SDK 26+ | OK: SDK iOS 27 |
| Archive Release + Validate App | Pendente no Organizer |
| Ícone 1024×1024 | Corrigido: sem alpha e sem cantos pré-arredondados |
| Ícone próprio do widget | Não exigido para a extensão embutida; asset vazio não gera aviso |
| Versão/build app e extensão | OK: 1.0 (1) |
| Bundle IDs | OK e não alterados |
| Export compliance | Corrigido: `ITSAppUsesNonExemptEncryption = NO` |
| iPad/orientações | Configurado para família 1,2 e quatro orientações; UI multitarefa ainda pendente |
| Privacy manifests | Criados para app e widget; copiados uma vez por target no build |
| UserDefaults | CA92.1 (app) e 1C8F.1 (App Group) |
| System uptime | 35F9.1 no app, para timer por tempo decorrido |
| Coleta/tracking | código sem analytics, rede ou identificadores; arrays vazios e tracking false |
| App Group | OK e idêntico nos dois entitlements |
| Dependências de terceiros | nenhuma encontrada |

O relatório de privacidade gerado pelo Archive ainda precisa ser conferido no Organizer.

## Riscos de App Review

- **2.1 Completude — médio:** fluxos completos e primeiro lançamento offline não foram exercitados após a falha do simulador. Ação: executar o roteiro físico abaixo e remover qualquer placeholder visual encontrado.
- **2.3 Metadados — baixo:** recursos reais são sons/combinações, timer, reprodução em segundo plano, Bíblia offline em dois idiomas, palavra diária, favoritos, narração, Terço guiado/manual e widgets. Screenshots/descrição devem prometer somente isso.
- **2.5.4 Áudio — médio:** a sessão silenciosa foi corrigida estaticamente, mas background, lock screen e consumo noturno exigem iPhone. Ação: teste Energy/Now Playing físico.
- **4.2/4.3 — baixo:** conteúdo offline, mixes, Bíblia, Terço, timer, narração e widgets oferecem diferenciação suficiente.
- **5.1.1 Privacidade — médio:** falta URL de Política de Privacidade no App Store Connect e link dentro do app. Texto sugerido: “O ZenSounds não coleta dados pessoais. Preferências e progresso permanecem no aparelho e no App Group usado pelo widget.” Adicionar a URL em Ajustes quando existir.
- **Licenças — médio:** a tela Sobre lista traduções e links do manifesto e a licença da fonte. Confirmar que os nomes exibidos deixam explícitos Bíblia Livre e KJV; adicionar créditos de artes/sons já documentados seria útil.
- **Acessibilidade — médio:** Dynamic Type incompleto e auditoria física pendente.
- **Widget — médio:** fallback com App Group vazio existe no código, mas fixação, snapshot e virada da meia-noite não foram executados.

## App Store Connect

- Classificação etária: preencher como sem violência, sexualidade, drogas, apostas ou conteúdo gerado por usuários; tema religioso.
- Privacidade: “Dados não coletados”, condicionado à confirmação do Archive e da política operacional.
- Screenshots: iPhone 6,9”/6,5” e iPad 13” enquanto `TARGETED_DEVICE_FAMILY = 1,2`.
- Categoria: **Estilo de Vida** principal (uso cotidiano para oração/relaxamento) e **Referência** secundária; Saúde e Fitness só é preferível se o marketing priorizar relaxamento.
- Exportação: respondida por `ITSAppUsesNonExemptEncryption = NO`.
- Notas ao revisor: explicar como iniciar um som, abrir timer, confirmar controles da tela bloqueada e adicionar o widget; informar que Bíblia/Terço funcionam offline.
- Antes do envio: TestFlight em iPhone físico e iPad.

## Recomendações de código

| Prioridade | Local | Risco | Proposta | Esforço |
| --- | --- | --- | --- | --- |
| Alta | `LoopingPlayer.swift` callback | concorrência futura | hop explícito para `MainActor` e teste de troca rápida | M |
| Alta | views com fontes fixas/widget | acessibilidade | substituir texto fixo por estilos/`relativeTo` e testar AX5 | M |
| Média | `SoundMixEditorView`/rotas | edição inalcançável | expor ação Editar sem mudar IDs | P |
| Média | `AudioEngine.addLayer/removeLayer` | glitch/reinício | anexar/remover apenas o node afetado, com teste de continuidade | M |
| Média | `BibleRepository` | memória/latência | medir e definir política de cache; avaliar índice por capítulo | M/G |
| Média | DailyWord app/widget e BotanicalArtwork | divergência | compartilhar fonte via membership comum, mantendo bundles separados | M |
| Média | singletons nas views | testabilidade | injetar protocolos/objetos por init/environment nas telas críticas | M |
| Baixa | `AppLanguage.localized` | manutenção | avaliar `String(localized:locale:)` no iOS 18 mantendo override interno | P |
| Baixa | nomes de arquivos (`FavoriteVerseDetailView`, `AppTab`) | organização | renomear/mover tipos sem mudança funcional | P |

## Pendências obrigatórias em aparelho/Organizer

1. Áudio em segundo plano e tela bloqueada durante a noite, medindo bateria.
2. Interrupção por ligação e retomada.
3. Desconexão de fone.
4. Now Playing e play/pause/stop na tela bloqueada.
5. Widget na tela inicial/bloqueada, App Group vazio e virada da meia-noite.
6. VoiceOver real e Dynamic Type máximo, claro/escuro e Increase Contrast.
7. Narração com vozes Premium.
8. iPad retrato/paisagem, Split View e Slide Over.
9. Primeiro lançamento sem dados, modo avião e idioma do sistema inglês.
10. Archive, Validate App e Generate Privacy Report.

## Arquivos

Criados: testes de prontidão, dois `PrivacyInfo.xcprivacy` e este relatório. Modificados: engine/sessão de áudio, preferências, deep link, compartilhamento, narração, áreas de toque, catálogos, comentários, Info.plist, build settings, ícone e três assets. Removidos: dois artworks órfãos, JSON duplicado e quatro ícones legados. Nenhum bundle ID, App Group, chave de preferências ou deployment target foi alterado.
