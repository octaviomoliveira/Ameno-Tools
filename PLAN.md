# Plano compartilhado — Ameno Tools

> Fonte de continuidade do projeto para qualquer pessoa ou agente (incluindo Antigravity).
> Atualizado: 2026-09-09

## Regra de trabalho

Cada solicitação nova deve atualizar este arquivo **antes de encerrar a tarefa**:

1. registrar o pedido no histórico;
2. mover itens concluídos para **Concluído** com evidência (arquivo, teste ou commit);
3. atualizar **Em andamento** e **Próximo passo**;
4. quando a decisão for duradoura, criar ou atualizar uma ADR em `docs/decisions/`.

Não substituir o histórico: acrescentar uma entrada datada. O plano corrente é este arquivo; `plans/` guarda marcos e handoffs mais detalhados.

## Objetivo do MVP

Entregar, no 3ds Max 2026, o primeiro módulo do Ameno Tools: **Ameno Dimensions**. Ele deve criar cotas rápidas, editáveis e persistentes para plantas humanizadas, com apresentação controlável e uma saída de render independente para composição.

## Concluído

- **E14.1–E14.5 implementadas em branch de entrega (2026-09-08):** criado o
  contrato de plano ortonormal U/V/N, matemática de fachada, CA v6 aditivo,
  gráficos 3D orientados, seletor Planta/Fachada, captura congelada e cadeia
  contínua H/V com baseline absoluta. A implementação está em
  `feature/e14-facade-planes`; `test_e14_plane_math.ms` passou 35/35,
  `test_e14_tools.ms` 31/31, `test_e14_graphics.ms`, bootstrap, E10.7, E12 e
  lifecycle WPF passaram com exit code 0/zero FAIL. E14.6 (gates completos) e
  E14.7 (render e aceite manual/publicação) permanecem em andamento; a `main`
  continua intacta. Depois dos gates automatizados, o candidato foi instalado
  localmente e conferido por 42/42 hashes de conteúdo; backup recuperável em
  `D:\Ameno\backups\AmenoTools-before-e14-hardening-20260908-204556`.

- Hotfix E12/E13 do crash no Enter (2026-09-06): o usuário reproduziu que pressionar Enter durante a cotação contínua derrubava o 3ds Max; o dump tinha exceção CLR 0xE0434352/E_FAIL. O caminho foi isolado ao DispatcherTimer que chamava MaxScript por callback assíncrono. Como o clique na viewport já funciona dentro das paredes, o monitor de Enter foi removido do fluxo interativo; a confirmação permanece por clique, Esc/botão direito cancelam e confirmPoints() fica somente programático/testável. O logger persistente foi concluído em %LOCALAPPDATA%\AmenoTools\Logs. Commit 2135b3b; pacote AmenoTools-0.0.1-e13-no-enter-20260906.zip; 239 PASS/0 FAIL nas regressões E13, E12 e logger, 42/42 hashes instalados e teste instalado aprovado. Handoff: plans/2026-09-06-e13-enter-crash-fix-handoff.md; validação manual pendente.

- Hotfix E13 de recuperação após modo incorreto (2026-09-06): o fluxo contínuo agora identifica, no segundo ponto, quando a direção dominante contradiz o modo Horizontal/Vertical ativo; cancela a sessão, restaura o painel e exibe uma mensagem em vez de deixar a coleta presa. O `MouseTool` arma temporariamente `escapeEnable` durante a sessão, restaura a preferência anterior ao sair e retorna explicitamente `#stop` no `mouseAbort`, protegendo o cancelamento por Esc/botão direito mesmo se a limpeza falhar. Commit `5a31643`; `test_e12_r1_lifecycle.ms` passou com 70/70 verificações, e as regressões E12 contínua/picking e E13 etapa 2 terminaram com PASS/0 FAIL. Pacote `dist/AmenoTools-0.0.1-e13-mode-recovery-20260906.zip`, SHA-256 `D029DEC315250DBE8947C47A52128F9945FC051FBD9897BA312A7AC4C9940B3F`; instalação conferida (`SOURCE_FILES=41`, ausentes 0, divergências 0), teste pelo ApplicationPlugins exit 0 / 1 PASS / 0 FAIL. Backup recuperável: `D:\Ameno\backups\AmenoTools-before-mode-recovery-20260906-175430`. O gate manual após reiniciar o Max permanece pendente.

- Correção E13 de perfis, cor de render e identificação segura do renderer (2026-09-06): estilos agora têm biblioteca global em `%LOCALAPPDATA%\AmenoTools\Profiles\styles.library`, com `.bak`/`.tmp` e precedência scene-local por `styleId`; `annotationColor` é convertido em RGB e aplicado ao material temporário do overlay, agrupando materiais por cor. O probe passou a exibir nome e classe real (`Corona [Corona]`, `Arnold [Arnold]`) no painel, diagnóstico e log; o despacho não usa mais Corona como fallback para renderer desconhecido, e o serviço revalida o adapter antes de chamar `render()`. O crash registrado em `C:\Users\octav\AppData\Local\AmenoTools\Logs\ameno-20260906-180520-144.log` ocorreu numa sessão identificada como Arnold e terminou em `EXCEPTION_ACCESS_VIOLATION`; a reprodução Batch confirmou que o caminho antigo escolhia adapter indevido e que a guarda nova o rejeita. Batch: bootstrap 1, E10.3 18, E13 global/cor 13, E13 estilos 25, E13 render/restauração 20, E13-E 9, E10.4 1, E11.5 1, E12-R0 1 e Corona 15 Hotfix 1 real 1 PASS, todos exit 0/0 FAIL. PNG real: `.test-output/e9_corona_real.png`. Após o Max fechar, `tools/install-dev.ps1` validou e instalou a versão atual; 41/41 arquivos de conteúdo mais o manifesto ficaram idênticos por SHA-256, e `test_installed_package.ms` terminou com exit 0/1 PASS/0 FAIL. Backup: `D:\Ameno\backups\AmenoTools-before-e13-render-guard-20260906`. Commit local: `b8fd640`. O gate manual após reabrir o Max continua pendente.

- Hotfix E13 para o render com `Isolate Selection` ativo (2026-09-06): três ocorrências na cena real chegaram ao mesmo `EXCEPTION_ACCESS_VIOLATION` nativo do Corona 15 Hotfix 1 antes de criar o PNG; o `Max.log` confirmou que a cena estava isolada. O render comum continua podendo usar Isolate; o risco está na sobreposição com o isolamento transacional do Ameno. O serviço consulta a API oficial `IsolateSelection.IsolateSelectionModeActive()` e bloqueia o passe antes de configurar adapter, materiais ou cena, orientando finalizar o isolamento com Alt+Q/End Isolate. O painel agora oferece `Renderizar somente as cotas (sem a planta)`, marcado por padrão, e a caixa desmarcada preserva a planta. O preflight registra câmera, tipo, resolução, pixel aspect, modo somente-cotas, isolamento e destino. Commit funcional final `5844730`; pacote válido; bootstrap 1 PASS, serviço transacional 28 PASS, UI 11 PASS, lifecycle 12 PASS e Corona 15 real sem isolamento 1 PASS, todos com exit 0 e zero FAIL. A versão foi instalada após o Max fechar: 41/41 arquivos de conteúdo e manifesto iguais por SHA-256; smoke instalado 1 PASS/0 FAIL. O gate na cena real aguarda o reinício do Max. Handoff: `plans/2026-09-06-e13-render-isolate-hotfix-handoff.md`.

- Hotfix E13 de posição do texto (2026-09-06): após o commit de uma cota vertical, o `TextPlus` girava também sua posição em torno da origem e saltava para fora da linha. A criação/atualização agora zera a posição, aplica a rotação e reposiciona o rótulo depois. O diagnóstico reproduziu o defeito (`[32,36;50]` esperado contra `[-50;32,36]` observado) e a correção passou com 4 PASS; visual 18, Criar 21 e Estilos 25 também passaram, todos exit 0/zero FAIL. Hotfix instalado com 42/42 hashes conferidos e teste instalado 1 PASS/0 FAIL; aceitação visual pendente.

- Correções do feedback visual E13 implementadas e instaladas em `develop` (2026-09-06): tema escuro compartilhado, nome antes de salvar/criar estilo, aplicação a todas as cotas e opção de orientação por cota. Teste específico 18 PASS, regressão Criar 21 PASS e Estilos 25 PASS; todos exit 0 / zero FAIL após corrigir a conversão Nullable do checkbox. Pacote instalado com 42/42 hashes conferidos e teste instalado 1 PASS/0 FAIL; aceitação visual ainda pendente. Detalhes em `plans/2026-09-06-e13-feedback-visual-handoff.md`.

- E12-R0 concluído em 2026-09-05 no commit instalado `e1bc114`: seis suítes MAXScript e a validação estrutural passaram; 25/25 arquivos instalados corresponderam por SHA-256; trace real comprovou que o commit Horizontal cria a cadeia mas mantém o MouseTool em `stage=collecting | active=true`, e que Alinhado entra na captura antes de ser recusado como `unsupported-mode`. A reutilização Horizontal→Vertical permanece apenas como relato, pois não houve sessão Vertical no trace. Evidência: `docs/e12-r0-diagnostics.md`.

- E12-R5 concluído em 2026-09-05 como gate de definição: o relato foi confirmado como reuso do vértice da geometria original entre cadeias Horizontal e Vertical. O vínculo cota→cota (ponta/terminal/texto como âncora) não será inferido nesta E12-R. Evidência: `docs/decisions/0021-e12-reference-reuse-scope.md`, `plans/2026-09-05-e12-r5-handoff.md` e gate R2 aprovado pelo usuário.

- Planejamento de recuperação da E12 concluído em 2026-09-05, baseado na inspeção de `db88f1b`: interação estilo Revit, linha comum, reutilização do núcleo e gates E12-A a F. Somente documentação; implementação, testes e instalação desta recuperação ainda pendentes. Plano: `plans/2026-09-05-e12-continuous-revit-implementation.md`.

- Repositório Git local criado e fundação `0.0.1` do pacote `ApplicationPlugins` estruturada.
- Pacote carregado e smoke testado no 3ds Max 2026.3.
- Validação manual no 3ds Max concluída: painel `Ameno Tools 0.0.1 · Max 2026` aberto e Corona identificado como `suportado`.
- E1 implementada e aprovada em testes automatizados no 3ds Max 2026.3: `Preparar esta cena` cria infraestrutura idempotente, protege conflitos de layer e restaura a layer corrente.
- Cópia de desenvolvimento atualizada em `ApplicationPlugins` e validada em processo separado do 3ds Max Batch.
- E1 aprovada visualmente no 3ds Max: painel exibiu `Cena preparada`, `AMENO_COTAS` e `AMENO_SYSTEM`; registro e estilo padrão apareceram na layer de sistema.
- E2 implementada e aprovada em testes automatizados no 3ds Max 2026.3: layout de cota alinhada no plano XY, conversão canônica para milímetros, arredondamento por incremento e formatação determinística.
- E2 não cria objetos, layers, callbacks ou histórico de Undo; ela recebe pontos e devolve dados prontos para a representação gráfica da E3.
- E3 implementada e validada em Batch isolado no 3ds Max 2026.3: construtor gráfico cria controlador oculto, cinco segmentos de spline e rótulo TextPlus a partir de três pontos conhecidos; a reconstrução remove e recria somente os filhos gráficos.
- E3 aprovada no uso visual informado pelo usuário: Arnold exibiu a cota no render, V-Ray exibiu a cota com a iluminação da cena e `Limpar cotas de teste` removeu a cota sem resíduos. A diferença observada no Corona sem luz fica registrada como requisito da E9 (overlay independente), não como bloqueio da criação gráfica da E3.
- E4 implementada e aprovada em Batch isolado no 3ds Max 2026.3: o `MouseTool` conduz A/B/afastamento, atualiza uma prévia temporária, cria a cota permanente pelo construtor da E3 e cancela sem deixar nós. Após o primeiro teste manual, o encerramento automático no terceiro evento foi removido: a ferramenta agora só termina quando o commit confirma sucesso e mostra a exceção real se houver falha.
- E4 aprovada manualmente no 3ds Max em 2026-09-04: o fluxo de três cliques criou uma cota permanente de `4,05 m`, o painel mostrou `1 cota(s) ativa(s)` e a geometria permaneceu visível no viewport.
- E5 implementada e aprovada manualmente no 3ds Max 2026.3 em 2026-09-04: controlador Point técnico utiliza Custom Attributes versionados (`AmenoDimensionCA` v1); persistência comprovada em ciclo save/load de arquivo `.max`; renomeação livre de nós preserva a identidade da cota; rotina de inspeção e reparo não-destrutivo (`inspectDimension`, `repairDimension`, botão `Reparar cotas` no painel) regenera nós visuais ausentes sem duplicar controladores; callbacks de ciclo de vida (`#filePostOpen`, `#postSceneReset`) sincronizam diagnósticos ao abrir cenas; Undo atômico (`max undo`) validado em um único passo.
- E6 implementada e aprovada manualmente no 3ds Max 2026.3 em 2026-09-04: valores medidos, arredondados e manuais com auditoria de delta e motivo; marcador `[M]` com cor âmbar exibido apenas na viewport (`renderable = false`), mantendo o render de produção 100% limpo e sem advertência visual; persistência de overrides em `.max` e reversão para medido.
- E7 implementada e aprovada manualmente no 3ds Max 2026.3 em 2026-09-04: serviço de estilos de cena (`AmenoStyleService`), presets Arquitetônico, Editorial e Técnico, tipografia avançada via TextPlus (peso, itálico, tracking, tamanho, fontes instaladas), 5 tipos de terminais vetoriais na mesma spline (`#tick`, `#arrowClosed`, `#arrowOpen`, `#dot`, `#none`), espessura de render configurável (0.8, 1.5, 2.5) com atalhos, atualização de estilos em lote em 1 único Undo, persistência de estilos em UserProps de `rootNode` da cena `.max` e editor visual dedicado (`AmenoStyleEditorRollout`).
- E8 implementada e aprovada manualmente no 3ds Max 2026.3 em 2026-09-04: serviço de âncoras reativas (`AmenoAnchorService`), Schema CA v3 com nós e coordenadas locais (`nodeA`, `localPointA`, `nodeB`, `localPointB`), detecção automática de nós ao criar cotas, recálculo dinâmico da linha de cota ao mover/rotacionar objetos, resiliência total com detecção de cotas órfãs (`isOrphan = true`) e coloração de alerta avermelhada `(color 230 70 70)` no viewport sem sumir da cena, seleção de âncoras (`selectAnchors`), reancoragem interativa A/B no painel, reparo em lote para coordenadas mundiais (`repairOrphans`), persistência de nós em arquivo `.max` e garantia mandatória de sincronização pré-render (`#preRender`).
- E8.1 implementada e aprovada manualmente no 3ds Max 2026.3 em 2026-09-04: reatividade contínua e em tempo real a movimentos Select-and-Move via watchers nativos `when transform (getAnimByHandle h) changes` compilados em runtime por `execute()` para cada nó âncora; índice reverso $O(1)$ por `Dictionary #string`; histórico de Undo do usuário 100% limpo com `with undo off`; persistência atômica de estilos via Custom Attribute `AmenoStyleRegistryCA` no helper `AMENO_STYLE_REGISTRY` (suportando `max undo` e `max redo`); escala física real em milímetros (`toSceneUnits`) em todas as dimensões de estilo; suporte a `extensionGap` na spline; hierarquia de prioridade visual no viewport (1º Órfã vermelha `230 70 70` > 2º Manual âmbar `245 166 35` > 3º Normal); atualização rápida in-place (`updateDimensionFast`); interface compacta (altura <= 640 px) com `subRollout` nativo; e reancoragem interativa com `pickPoint snap:#3D`.
- E9 implementada e aprovada em testes automatizados no 3ds Max 2026.3 com Corona 13: painel `Render Separado de Cotas`, escopos Todas/Selecionadas, PNG transparente com nome automático e proteção contra sobrescrita, herança da viewport/câmera ativa, frame, resolução, pixel aspect e Crop/Region, material `CoronaLightMtl` visível diretamente e no alpha com emissão desligada, isolamento temporário dos nós e restauração transacional após sucesso, exceção e cancelamento. Um render Corona real confirmou cotas opacas sobre fundo transparente, sem a geometria comum da cena.
- E9 implementada e aprovada interativamente no 3ds Max 2026.3 com Corona 13 em 2026-09-04: rollout `Render Separado de Cotas` no painel, PNG com fundo transparente e somente linhas/textos de cotas, nome automático e proteção contra sobrescrita (`_001`), herança de câmera/frame/resolução/pixel aspect/Crop do Render Setup, restauração transacional da cena confirmada ("A cena foi restaurada."); bugs corrigidos durante o gate: `renderOutputFilename`/`renderSaveFile` obrigatórios para Corona gravar o PNG (`outputfile` ignorado), critérios de parada do Corona agora forçados para 1 % de noise e 20 passes máximos no passe de overlay.
- E10.7.2 implementada e aprovada manualmente no 3ds Max 2026 em 2026-09-04: Vertex Snap registra `A=vN / B=vN`, as extremidades resolvem a malha avaliada e a cota acompanha o deslocamento dos vértices em edição de subobjeto. O usuário confirmou o gate final como "sucesso absoluto".
- E11.0–E11.5 implementadas e integradas na `main` em 2026-09-04: editor visual WPF .NET 8, `StyleDraft` transacional, preview vetorial 2D ao vivo, aplicação/persistência, fallback para o rollout legado e correção do tema escuro. O pacote estrutural foi aprovado e a instalação unificada E10.7 + E11 foi verificada por 22/22 arquivos idênticos por SHA-256.
- E13 — etapa 1 concluída e validada em `develop`: a E13 auditada (`676e008`) foi integrada sobre a E12 publicada (`f131f08`) no merge `d1e9e22`, com os três conflitos previstos resolvidos preservando as transações, picking e input E12. O wrapper de compatibilidade `AmenoRuntime.startContinuousDimensionTool`, o fixture válido do diagnóstico R0 e a verificação estrita do runner foram registrados; pacote, bootstrap, auditoria, E13-A…H e E12 passaram em Batch isolado. Evidência: `plans/2026-09-05-e13-executor-runbook.md`, `plans/2026-09-06-e13-etapa-1-handoff.md` e `.test-output/stage1-evidence-develop/`.
- E13 — etapa 2 implementada e testada em `develop`: a aba Criar agora usa os campos existentes dos serviços E12/E4, sincroniza modo/unidade/precisão/estilo, encaminha botão e macro pelo mesmo comando contínuo, congela alterações durante a sessão, preserva a rejeição de cadeia alinhada e mantém a contagem/foco do painel após o ciclo interativo. Evidência: `ameno_cotas_criar_tab.ms`, `ameno_runtime.ms`, `ameno_cotas_window.ms`, `Contents/macroscripts/AmenoTools.mcr`, `tests/maxscript/test_e13_stage2_create.ms`, pacote válido e logs em `.test-output/stage2-evidence-develop/`. O gate manual H/V e Undo/Redo continua pendente.
- E13 — etapa 3 implementada e testada em `develop`: a aba Estilos preserva host e rascunho entre abas/refresh, separa refresh genérico de troca explícita, implementa salvar/descartar/cancelar, invalida rascunhos ao trocar de cena, revisa fechamento/callbacks e mantém persistência, presets, duplicação, exclusão protegida e aplicação com Undo/Redo. A suíte dedicada passou com 24 verificações internas, 25 marcadores PASS e 0 FAIL; pacote, bootstrap, E13-A…H, E11.1–E11.5 e E12 9/9 também passaram em Batch. Evidência: `plans/2026-09-05-e13-etapa-3-handoff.md` e `.test-output/stage3-evidence-develop/`. Sem instalação/publicação; gate manual da etapa 3 pendente.
- E13 — etapa 4 implementada e testada em `develop`: a aba Editar valida somente o campo do modo escolhido, rejeita vazio/letras/notação científica/zero/negativo sem mutação nem Undo vazio, converte cm→mm e m→mm, preserva medição/auditoria/unidades, sincroniza seleção e Undo/Redo, bloqueia cancelamento de reancoragem como mundial, filtra geometria técnica e persiste `vertexId` no serviço de âncoras. A suíte dedicada passou com 44 verificações internas, 45 marcadores PASS e 0 FAIL; pacote, bootstrap, E13-A…H, E11.1–E11.5, E10.7 e E12 9/9 também passaram em Batch isolado. Evidência: `plans/2026-09-05-e13-etapa-4-handoff.md` e `.test-output/stage4-evidence-develop/`. Sem instalação/publicação; gates manuais das etapas 3 e 4 permanecem pendentes.
- E13 — etapas 5 e 6 implementadas/testadas e etapa 7 preparada em `develop` (2026-09-06): terminais mesh estáveis (`arrowClosed`, `diamond`, `dot`) com normal de plano, metadados, rollback transacional, atualização rápida, preview e snap/persistência; render com câmera explícita, restauração transacional e adapter Corona validado em render real. A suíte E13 final passou com 14/14 testes, 217 marcadores PASS e 0 FAIL; E10.1/E10.2 foram corrigidos no próprio teste (bloco MaxScript e marcadores estritos) e passaram com 28/11 PASS; E10.3/E10.4/E10.5/E10.7, E11, E12 e Corona real também passaram. O candidato `dist/AmenoTools-0.0.1-e13-candidate.zip` foi validado e tem SHA-256 registrado em `plans/2026-09-06-e13-candidate-manifest.sha256`. Sem instalação/publicação; gates manuais 2–6, V-Ray CPU real, aprovação do usuário e publicação permanecem pendentes. Handoffs: `plans/2026-09-06-e13-etapa-5-handoff.md`, `plans/2026-09-06-e13-etapa-6-handoff.md` e `plans/2026-09-06-e13-etapa-7-handoff.md`.
- Pacote instalado com E1 a E9 validado em Batch isolado e aprovado em sessão interativa no 3ds Max 2026.
- Ação `Ameno Tools` e painel inicial registrados; bootstrap modular e validação de pacote incluídos.
- Modelo de dados inicial para cotas, estilos, referências e valores medidos/arredondados/manuais documentado.
- Regras decididas para `AMENO_COTAS`, geometria renderizável, render separado de cotas e preservação do Beauty, LightMix e Render Elements existentes.
- Fluxo do valor manual definido: a substituição não altera a medida real, é persistida no dado da cota e aparece em âmbar apenas na viewport.
- Editor de estilo especificado com inspiração na edição direta do TextPlus: fonte, tamanho, linhas, espessuras e tipos de seta com prévia.
- Estratégia de render definida: Corona como referência obrigatória; V-Ray CPU como segundo adapter oficial; V-Ray GPU separado e experimental até ser validado.
- Escopo inicial definido para 3ds Max 2026; compatibilidade 2021–2025 será avaliada após o MVP estar estável.

## Em andamento

- **E14 — Planos de cotação e fachadas em validação:** E14.1–E14.5 foram
  implementadas em `feature/e14-facade-planes`, com persistência CA v6,
  orientação 3D, captura de fachada, snaps 3D preservados e baseline fixa na
  cadeia H/V. A E14.6 está parcialmente integrada na reatividade/rebuild; faltam
  seus gates completos de reancoragem, bake e órfãs. A E14.7 ainda precisa do
  render real, aceite manual e publicação. O candidato local está instalado e
  foi verificado por `test_installed_package.ms`; ZIP/SHA-256 já gerados.
  Plano detalhado: `plans/2026-09-08-e14-planos-de-cotacao-fachadas.md`.

- **Incidente E14 — crash nativo e lentidão recorrente (2026-09-08):** o WER
  registrou `0xc0000005` em `3dsmax.exe` (módulo desconhecido, RIP `0xC`) às
  21:09:52, um segundo após o evento do Windows de memória virtual mínima baixa;
  o dump não permite atribuir a falha a E14, Corona ou GPU. Na nova sessão, a
  cadeia contínua concluiu 3 cotas, mas o Max ficou temporariamente
  `Responding=False` com mais de 90 mil páginas/s e pressão de commit, impedindo
  a navegação. O mesmo log registrou falhas WPF de reparenting
  ("element already the logical child" / "Visual is not a child") ao alternar
  abas, no `contentBorder.Child = tabControl`; isso é uma falha independente de
  ciclo de vida da UI que precisa de detach explícito dos controles em cache.
  Também existem dois diretórios de backup descobertos como pacotes em
  `ApplicationPlugins`, um risco ambiental ainda não causalmente confirmado.
  Não houve novo crash no segundo episódio; o Max encerrou normalmente. E14 fica
  bloqueada para o gate manual até corrigir o reparenting WPF, reduzir o pico de
  memória/paginação e repetir o teste em cena descartável com telemetria.

- **Novo incidente — recarga em processo provocou exceção do mxsdotNet (2026-09-08):**
  após a orientação de reinício pelo Listener, o mesmo PID do Max carregou todos
  os scripts Ameno às 21:48:20 e novamente às 21:48:30; dois novos logs de sessão
  foram abertos e, às 21:48:39, o Max escreveu `3dsmax_minidump.dmp` com exceção
  C++ `0xe06d7363` cujo contexto aponta para `mxsdotNet.dlx`. O serviço
  `ADPClientService.exe` também falhou às 21:48:37, mas é um processo separado e
  não explica o minidump do Max. A recarga via `AmenoBootstrap.start()` em
  processo vivo fica proibida até existir um teardown determinístico da janela,
  handlers e objetos .NET; o procedimento seguro passa a ser fechar o Max
  normalmente e reabrir sem repetir `fileIn`/bootstrap.

- **Hotfix de contenção do travamento (2026-09-08):** o bootstrap passou a ter
  estado de geração (`#starting/#started/#failed`) e recusa qualquer segunda
  inicialização no mesmo processo; a janela WPF ganhou guarda contra navegação
  reentrante, detach explícito do `ContentArea` e liberação dos hosts de todas
  as abas ao fechar. O preview contínuo limita a entrada interativa a 25 Hz e
  reposiciona o TextPlus sem `ResetString/AppendString` quando a etiqueta não
  mudou. A suíte `test_e13_ui_lifecycle.ms` passou com 13/13 PASS, incluindo
  fechar/reabrir e tentativa de bootstrap duplicado. As sete cópias alteradas
  foram instaladas no `ApplicationPlugins` com o Max aberto somente para o
  próximo processo; a sessão já carregada continua com os scripts antigos até
  ser encerrada. Backup recuperável em
  `D:\Ameno\backups\AmenoTools-before-stability-hotfix-20260908-220807`;
  ZIP `dist/AmenoTools-0.0.1-stability-hotfix-20260908.zip`, SHA-256
  `75B4F0209B5CBB689F7D602D54FE8D19F50345B8D092DA7F6DA73F1DFBE60869`.

- **Verificação de peso das cotas verticais (2026-09-08):** `verticalLayout()`
  usa as mesmas três projeções, três coordenadas e operações vetoriais do
  caminho horizontal; não há laço ou consulta de cena exclusivo do modo
  Vertical. O benchmark isolado `tests/maxscript/test_vertical_performance.ms`
  mediu 5.000 layouts e quatro atualizações de preview por modo, com diferença
  inferior a 10% e custo absoluto de aproximadamente 0,3 ms por layout e 1 ms
  por segmento no preview. Na cena real, o commit vertical de 2 segmentos levou
  5,4 s (2,7 s/segmento), contra 18,1 s para 7 segmentos horizontais
  (2,6 s/segmento). O gargalo confirmado é a criação/atualização de spline,
  TextPlus, terminais e consultas de picking da viewport, comum aos dois modos;
  não foi encontrado cálculo vertical pesado.

- **E15 — transição WPF → Python/Qt decidida (2026-09-09):** o plano misto de
  UI e desempenho foi substituído por uma reescrita integral da apresentação,
  do zero e sem copiar/importar WPF. A UI nova terá Login obrigatório, chrome
  nativo e Criar/Estilos/Editar/Render/Config. O primeiro candidato fica
  restrito ao Max 2026; serviços de domínio permanecem atrás de um bridge novo. A
  otimização do preview/commit fica em backlog separado; a E15 deverá provar que
  navegação, lifecycle e autenticação não acrescentam bloqueios à viewport.
  Plano ativo: `plans/2026-09-09-e15-transicao-wpf-python-qt.md`; ADR 0024.

- **E15 — candidato Python/Qt implementado e instalado (2026-09-09):** criada a
  interface do zero em `Contents/python/ameno_ui/`, com Login/token em memória,
  janela Qt nativa (minimizar/maximizar/fechar), navegação local sem refresh
  implícito e páginas Criar/Estilos/Editar/Render/Configuração. O
  `AmenoUiBridge` troca apenas snapshots primitivos com os serviços MAXScript;
  fechamento cancela uma coleta interativa antes do teardown. O bootstrap não
  carrega os módulos de apresentação WPF e os scripts de instalação/empacotamento
  os excluem do candidato. Python 3.11/PySide6, suíte MAXScript, smoke da ponte,
  smoke instalado e pacote alpha passaram; o gate visual/soak no Max 2026 ainda
  depende de uma sessão gráfica real. O endpoint de autenticação e a otimização
  do núcleo de viewport permanecem fora deste corte.

- **E16 — otimização da viewport concluída e validada (2026-09-09):** o
  `mouseMove` contínuo publica somente um modelo primitivo e o `gw` desenha o
  preview sem nós; picking completo e criação de objetos ficam no clique. O
  commit usa contexto preparado uma vez por cadeia, um Undo e rollback integral.
  A matriz E16 passou overlay, 1.000 movimentos sem mutação de cena, lifecycle
  de callback e commit de 7 segmentos; não foram observadas novas exceções Qt,
  WPF ou minidumps no gate. Evidência: `plans/2026-09-09-e16-otimizacao-preview-commit-viewport.md`,
  `work/e17-gates/summary.txt` e commit `f763059`.

- **E17 — candidato técnico Qt com aceite visual reprovado
  (2026-09-09):** a interface foi escrita do zero em Python/PySide6, sem
  reutilizar WPF, com Login obrigatório, logo/tema Ameno, chrome nativo,
  navegação local, divulgação progressiva, mensagens acionáveis e cinco páginas
  fixas. O launcher ganhou estado explícito de abertura/fechamento após o gate
  confirmar que `python.Execute` retorna `#success`, não o valor da expressão.
  Os gates passaram em 17/17 testes Python e 18/18 suites MaxScript (E12–E17),
  incluindo close/reopen do host, logout que limpa o token, regressões E16 e
  instalação com o Max fechado. O candidato está instalado no
  `ApplicationPlugins`; backup recuperável em
  `D:\Ameno\backups\AmenoTools-before-e17-launcher-20260909-125919`.
  O gate humano encontrou clipping, rolagem horizontal, excesso de conteúdo e
  uma prévia 2D que não responde/representa todos os parâmetros. E17.10.3 foi
  reprovada; as etapas funcionais humanas e a promoção foram suspensas. Nenhuma
  promoção para `develop` ou `main` foi feita. Commit funcional:
  `ae3e576`. Plano:
  `plans/2026-09-09-e17-identidade-ux-qt.md`.

- **E18 — experiência Qt 10/10 e prévia reativa em execução
  (2026-09-09):** runbook preparado para execução no Antigravity em 12 etapas
  e 118 subetapas. A E18.0 já criou a branch isolada e transformou a falha
  da prévia e o overflow de 780×560 em dois testes RED reproduzíveis; a suíte
  legada permanece em 17/17 PASS. A E18.1 introduziu o `StyleDraft` sempre
  válido e integrou a Aparência sem chamadas externas; os contratos unitários
  passaram. A E18.2 adicionou sliders + entrada técnica sincronizados para os
  parâmetros de estilo, também sem bridge. A ordem começa pelos testes, depois
  implementa preview geométrico puro — já coberto em `dimension_preview.py`
  com cinco contratos de paridade; a E18.4 reorganizou Aparência em fluxo
  vertical sem splitter fixo e com quatro contratos novos; a E18.5 aplicou
  shell responsivo com rail compacto, margens adaptativas, cinco larguras e
  DPI 100–200% sem rolagem horizontal; a E18.6 simplificou Cotar com três
  passos, resumo vivo e CTA único visível; depois trata primeiro uso,
  ícones, acessibilidade e canary. O E16 permanece congelado e nenhuma interação
  visual pode chamar bridge, cena ou viewport. Plano:
  `plans/2026-09-09-e18-ux-10-10-preview-reativo.md`; ADR 0027.

- **Gate de render adiado durante a E15:** o commit `5844730` permanece instalado
  e validado estruturalmente, mas o gate manual da tela WPF não é prioridade
  enquanto a apresentação é substituída.

- **Gate de lifecycle WPF cancelado como próximo passo:** o hotfix instalado e
  seu backup continuam como evidência/rollback, mas não haverá novo investimento
  nem gate de aceitação no shell que será removido pela E15.

- **Issues abertas no GitHub:** [#1 — preview visual das fontes](https://github.com/octaviomoliveira/Ameno-Tools/issues/1), [#2 — janela redimensionável/responsiva](https://github.com/octaviomoliveira/Ameno-Tools/issues/2) e [#3 — falha de fontes específicas como Fredoka](https://github.com/octaviomoliveira/Ameno-Tools/issues/3).

- **Gate adicional — concluir o hotfix de render com segurança:** a versão atual já está instalada em `ApplicationPlugins` após o Max fechar normalmente; 41/41 arquivos de conteúdo e o manifesto conferem por SHA-256, e o teste instalado passou. Ao reabrir, confirmar que o painel mostra a classe real; em Arnold/outro renderer sem adapter o botão deve permanecer desabilitado e o serviço deve retornar erro explicável, sem chamar `render()`.

- **Correção implementada — cor de render, biblioteca global e renderer:** o passe agora recebe `annotationColor` do estilo, a biblioteca global preserva perfis entre cenas/reinícios e a compatibilidade é validada por família/classe real imediatamente antes do render. A validação automatizada e a instalação/teste pelo `ApplicationPlugins` passaram; falta apenas o gate visual/manual. V-Ray CPU real e GPU continuam fora da evidência desta rodada.

- **Roteiro prioritário de recuperação:** `plans/2026-09-05-e12-executor-runbook.md` (R0–R6). R0–R6 estão concluídos para a E12-R; R4 foi aprovada em Batch, instalada e validada manualmente, R5 foi fechado como decisão de escopo e R6 foi aprovado com automação e gate manual. Handoff final: `plans/2026-09-05-e12-r6-handoff.md`.

- Pesquisa da finalização E12 concluída: `plans/2026-09-05-e12-finalization-research.md`. O C1 equivalente foi encerrado pelo R0; ciclo de vida pelo R1; e a causa do vértice ignorado foi tratada na R2 removendo o bloqueio causado pelo snap em gráfico Ameno e resolvendo o vértice geométrico pelo pixel.

- **Instalação ativa:** hotfix E13 de perfis/cor/renderer do worktree `develop`, instalado em 2026-09-06 com o Max fechado; 41 arquivos de conteúdo e o manifesto conferidos por SHA-256, 0 ausentes e 0 divergências, e `test_installed_package.ms` aprovado (exit 0, 1 PASS, 0 FAIL). Backup: `D:\Ameno\backups\AmenoTools-before-e13-render-guard-20260906`. O Enter continua removido deliberadamente após o crash reproduzido; a aceitação manual do banner, bloqueio de Arnold, Corona 15 e persistência global permanece pendente.

- **R6 — automação e gate manual executados:** com o Max interativo fechado, `validate-package.ps1` passou; as 11 suítes do lote e a R2 repetida passaram após o fixture E12-A declarar explicitamente o modo Horizontal. O usuário abriu o Max, repetiu o caso H/V com o vértice compartilhado e confirmou “tudo funcionando”. Evidência por suíte em `work/r6-test-logs` e handoff final em `plans/2026-09-05-e12-r6-handoff.md`.

- Validação interativa das funcionalidades acumuladas restantes da **E10** no 3ds Max 2026 (modos H/V, lote/bake, V-Ray CPU, diagnóstico e pacote alpha).
- Gate manual do **Editor Visual E11** no 3ds Max 2026 com a versão unificada instalada.

## E11 integrada

- E11 — Editor Visual e Preview ao Vivo: implementação mesclada da branch `feature/e11-visual-editor`, validada estruturalmente e instalada. Falta somente o gate visual e funcional do usuário no 3ds Max. Plano detalhado em `plans/2026-09-04-e11-editor-visual-preview.md`.

## Próximo passo executável

- **E18.0 — baseline e reprodução concluída:** a branch
  `feature/e18-ux-10-10` foi criada a partir de `feature/e17-ameno-ux` em
  `01e32cd`; os dois defeitos foram convertidos em RED reproduzíveis e a
  evidência está em `work/e18-baseline/README.md`.

- **E18.1–E18.6 concluídas; E18.7 em execução:** draft local, controles slider +
  número, geometria pura/paridade da prévia, fluxo vertical da Aparência e
  shell responsivo e fluxo Cotar guiado estão implementados e testados,
  incluindo DPI 100–200%, zero rolagem horizontal e CTA no primeiro viewport.
  Próximo passo é igualar o microcopy e a hierarquia das páginas auxiliares.

- **E17 não deve ser promovida:** preservar o backup
  `D:\Ameno\backups\AmenoTools-before-e17-launcher-20260909-125919`; não fazer
  push, merge, tag ou alteração em `develop`/`main` sem pedido explícito e sem
  o aceite completo do E18.

- **E16 preservada como regressão:** qualquer alteração futura na UI ou na
  ferramenta deve repetir a matriz E16 (preview `gw`, 1.000 movimentos,
  callback 0/1/0, commit/rollback) e não pode reintroduzir criação de nós ou
  acesso ao bridge durante `mouseMove`. Runbook:
  `plans/2026-09-09-e16-otimizacao-preview-commit-viewport.md`.

- **E14 e compatibilidade de versões:** os gates funcionais finais de fachada
  serão repetidos pelo shell Qt depois do aceite do canary. Max 2021–2025/2027,
  endpoint de autenticação e novos renderers continuam adiados até o candidato
  2026 permanecer estável.

- **E14:** executar os gates E14.6–E14.7 na branch `feature/e14-facade-planes`:
  repetir E10.1 contra o candidato instalado, validar reancoragem/bake/órfãs e
  Undo/Redo, testar Front/Back/Left/Right e câmera ortográfica rotacionada,
  depois renderizar e registrar o aceite. O ZIP/SHA-256 já estão em
  `dist/AmenoTools-0.0.1-e14-facade-20260908.zip` e o candidato está instalado
  no perfil local; manter `main` em `e406929` até o aceite.

- **Gate WPF anterior supersedido:** a matriz Criar → Estilos → Editar → Render
  será executada no shell Qt novo, não na interface WPF instalada.

- **Depois do corte Qt:** repetir em cena descartável os gates de Corona/V-Ray,
  persistência e bloqueio informativo do Arnold. O Enter continua removido.

- **Pendências conhecidas:** gate manual do pacote atualizado; render V-Ray CPU real; confirmar comportamento visual do diálogo de cor, biblioteca global e bloqueio de Arnold no Max interativo. A compatibilidade com outras versões de Corona/V-Ray continua dependente das capacidades detectadas pelo adapter; não declarar universalidade sem esses gates.

**Para retomar a E12:** publicar os três commits locais com autorização explícita e, se desejado, preparar um merge revisado para `main`. Não fazer merge automático.

1. Abrir o 3ds Max e executar o **gate manual interativo da E10 no 3ds Max 2026** com a versão de desenvolvimento já instalada:
   - Validar criação de cotas nos modos Horizontal, Vertical e Alinhada;
   - Validar seleção múltipla e alteração em lote de unidades/precisão e Bake de âncoras;
   - Validar render de overlay no Corona ou V-Ray CPU;
   - Emitir Relatório de Diagnóstico no painel.
2. Abrir o **Editor de Estilos E11** e executar o gate visual: preview ao vivo, tema escuro, Cancelar, Aplicar às selecionadas, Salvar estilo, Undo/Redo e persistência após reabrir a cena.
3. Retomar o gate Batch E10.7 e as regressões E10.1/E10.2/E10.4 quando o executor isolado estiver estável.


## Decisões que ainda exigem validação

- Endpoint, protocolo, expiração e política offline do token de Login da E15.
- Portabilidade e ambientes para Max 2021–2025 e 2027, somente depois do aceite
  estável do candidato 2026.
- Versões mínimas de Corona e V-Ray disponíveis no ambiente real.
- Se a interface inicial será somente em português ou já bilíngue.
- Serviço/visibilidade do repositório Git remoto e política de acesso.
- Licença e modelo de distribuição.

## Histórico de solicitações

- **2026-09-09 — Planejar a interface 10/10 para execução no Antigravity:** o
  feedback real reprovou o aceite visual E17 por clipping, rolagem horizontal,
  carga cognitiva e prévia 2D sem resposta/paridade. Foi criado o E18 em 12
  etapas/118 subetapas com diagnóstico de código, critérios mensuráveis,
  `StyleDraft` local, sliders sincronizados, preview geométrico puro, layout
  adaptativo, fluxo de primeiro uso, ícones próprios, acessibilidade,
  performance, gates humanos, 30 guardrails e prompt pronto para o executor.
  Somente documentação; implementação E18 não iniciada. Evidências:
  `plans/2026-09-09-e18-ux-10-10-preview-reativo.md`, ADR 0027 e
  `work/e18-baseline/README.md`.

- **2026-09-09 — Executar o E17 do início ao fim no canary do Max 2026:** a
  interface Qt foi escrita do zero com identidade Ameno, Login/token em
  memória, chrome nativo, cinco páginas fixas, divulgação progressiva e
  mensagens operacionais. A correção final do launcher trata corretamente o
  contrato `python.Execute` (`#success`) e cobre show/close/reopen. A validação
  terminou com 17/17 testes Python e 18/18 suites MaxScript E12–E17; a cópia
  ativa foi instalada com o Max fechado após backup recuperável. O ZIP canary e
  a paridade por hash serão registrados no mesmo plano após o empacotamento.
  O ZIP canary `dist/AmenoTools-0.0.1-e17-canary.zip` foi validado sem WPF/cache
  (SHA-256 `7F3ACAA4BE5D2F1BE7E9EEF90DFEAE2BC57F7B3589ABE7CD8145A59E5E09B406`)
  e a instalação conferiu 68 arquivos com zero divergências, além das sete
  ausências WPF esperadas. Aceite gráfico/DPI/soak e promoção continuam
  pendentes por exigirem ação manual/autorização. Evidências:
  `plans/2026-09-09-e17-identidade-ux-qt.md`, `work/e17-gates/summary.txt`,
  branch `feature/e17-ameno-ux`.

- **2026-09-09 — Criar plano extremamente detalhado para a otimização das
  cotas:** criada a E16 em 10 etapas/78 subetapas, com diagnóstico do caminho
  quente, separação formal entre hover leve e picking completo, arquitetura de
  `OverlayModel`/`gw`, contexto preparado de commit, 15 guardrails, sentinelas,
  métricas, matriz de regressão, rollout/rollback, critérios GO/STOP e prompt de
  handoff. Somente documentação; implementação não iniciada. Evidências:
  `plans/2026-09-09-e16-otimizacao-preview-commit-viewport.md` e ADR 0025.

- **2026-09-09 — Renovar o plano com reescrita total da UI, Login e suporte
  2021–2027:** definida E15 com 10 etapas/72 subetapas. A apresentação será
  escrita do zero em Python/Qt e não importará/copyará WPF; os serviços de domínio
  continuam atrás de um bridge novo. Login/token precede o app; a janela usará
  minimizar, maximizar/restaurar e fechar nativos. A matriz Autodesk confirma
  PySide2/Qt5 de 2021 a 2024 e PySide6/Qt6 de 2025 a 2027; ambientes locais
  completos foram confirmados para 2021/2024/2026. O plano separa compatibilidade
  por contrato de certificação real e inclui gates para a UI não bloquear a
  viewport. Somente documentação; nenhuma implementação ou instalação ocorreu.
  Evidências: `plans/2026-09-09-e15-transicao-wpf-python-qt.md` e ADR 0024.

- **2026-09-09 — Priorizar somente a transição WPF → Python/Qt e avaliar Max
  2021:** a portabilidade da interface foi confirmada como viável. O ambiente
  local possui Max 2021 com Python 3.7.6/PySide2 5.12.5 e Max 2026 com Python
  3.11.12/PySide6 6.5.3; a implementação deverá usar uma camada de compatibilidade
  e sintaxe Python 3.7. O pacote completo ainda não pode ser declarado compatível:
  manifesto e `AmenoVersion` estão fixados em 2026, e núcleo/renderers exigem
  smoke real no host antigo. S2/S4 foram adiadas; nenhuma mudança de código ou
  instalação ocorreu. Evidência:
  `plans/2026-09-09-substituicao-wpf-qt-viewport.md`.

- **2026-09-09 — Procurar uma substituição sustentável para o WPF após novo
  travamento:** o log mais recente não registrou nova exceção de reparenting;
  registrou commits Vertical e Horizontal com o mesmo custo de aproximadamente
  2,6 s por segmento na thread principal. A documentação Autodesk e o ambiente
  local confirmam PySide6/Qt como stack suportada. Foi recomendada a arquitetura
  PySide6/Qt + overlay `gw`, com rollout seguro, criação de nós somente no commit
  e migração em 6 etapas/23 subetapas. Somente planejamento; código e instalação
  não foram alterados. Evidência:
  `plans/2026-09-09-substituicao-wpf-qt-viewport.md`.

- **2026-09-08 — Corrigir comando de reinício no Scripting Listener:** o bloco
  multilinha anterior foi rejeitado pelo parser do Listener (`at ), expected
  <factor>`). A orientação foi simplificada para três expressões independentes:
  `AmenoApp.shutdown()`, `AmenoBootstrap.start()` e
  `AmenoApp.openMainPanel()`, executadas nessa ordem; isso preserva a ordem de
  descarte antes da recarga e evita o erro de parsing.

- **2026-09-08 — Revogar a recarga em processo após novo crash:** a sequência
  `shutdown → AmenoBootstrap.start()` não é segura para o shell WPF atual porque
  o bootstrap recompila/substitui os singletons antes de conseguir descartar
  integralmente a janela anterior. O log comprovou duas cargas consecutivas e
  um minidump `mxsdotNet.dlx`; até a re-arquitetura, usar somente reinício completo
  do 3ds Max, com a cena salva/copiada.

- **2026-09-08 — Aplicar hotfix de estabilidade após travamento recorrente:**
  implementadas a barreira de geração do bootstrap, a navegação WPF não
  reentrante, o detach/limpeza dos hosts ao fechar e a redução de custo do
  preview contínuo durante `mouseMove`. O Batch `test_e13_ui_lifecycle.ms`
  terminou com exit code 0 e 13 PASS/0 FAIL; a etapa de terminais terminou com
  40 PASS/0 FAIL. A cópia ativa foi atualizada após backup, mas exige reinício
  completo do Max para entrar em memória. Alterações locais estão na branch
  `feature/e14-facade-planes`; nenhuma publicação no GitHub foi executada.

- **2026-09-08 — Verificação após o reinício:** o Max carregou a cena real e
  permaneceu responsivo (`Responding=True`); o log do Ameno registrou a abertura
  das abas Criar e Render sem exceção WPF. A carga da cena levou cerca de dois
  minutos e elevou o processo para aproximadamente 15 GB, portanto a primeira
  espera após abrir um arquivo grande não deve ser confundida com o travamento
  do plugin.

- **2026-09-08 — Orientar reinício do plugin pelo Scripting Listener:** para uma
  recarga dentro do 3ds Max, primeiro executar `AmenoApp.shutdown()` enquanto os
  objetos atuais ainda estão referenciados, depois `AmenoBootstrap.start()` e
  reabrir o painel. Recarregar somente os módulos ou o bootstrap sem o shutdown
  pode deixar handlers/uma janela WPF antiga vivos. Essa recarga reinicia scripts
  e UI, mas não substitui fechar/reabrir o Max quando houver pressão de memória.

- **2026-09-08 — Avaliar outra forma de refazer a interface da fachada:** após
  nova lentidão recorrente, a inspeção encontrou duas camadas independentes de
  risco: reparenting de controles WPF em cache e atualização de geometria pesada
  em cada `mouseMove`. Foram comparadas três rotas (rollout nativo persistente,
  Qt/PySide6 e híbrida UI nativa + preview `gw`). A recomendação provisória é a
  rota híbrida com shell nativo, preservando os serviços/CA e adiando a criação de
  nós para o commit; decisão e implementação permanecem pendentes.

- **2026-09-08 — Analisar a lentidão e o novo travamento da fachada:** o
  diagnóstico cruzou o log persistente do Ameno, `Max.log`, WER, dump e eventos
  do Windows. A lentidão foi reproduzida como pressão severa de memória e
  paginação durante a sessão (não há evidência de erro de GPU, disco ou
  renderer); o crash anterior é uma violação de acesso nativa correlacionada ao
  evento de memória virtual baixa, com módulo exato desconhecido. Após uma
  cadeia concluída, a navegação passou a falhar com exceções WPF de reparenting
  dos controles em cache. Nenhum código foi alterado nesta análise; o próximo
  gate exige correção explícita do detach WPF, budget de memória e teste
  instrumentado em cena descartável.

- **2026-09-08 — Implementar a nova função de cotação de fachadas:** a execução
  foi iniciada na branch `feature/e14-facade-planes`. E14.1–E14.5 foram
  implementadas e validadas em Batch; o plano E14 foi atualizado com evidências,
  riscos resolvidos e gates restantes. O aceite manual e o gate de render ainda
  aguardam conclusão. Candidato
  `dist/AmenoTools-0.0.1-e14-facade-20260908.zip`, SHA-256
  `C8246D50AFC56B77A16941AE140D78226C7ADD9FFC180331847505B2A5E79405`, instalado
  localmente após backup recuperável.

- **2026-09-08 — Endurecer o candidato E14 antes da entrega:** a auditoria
  passou a rejeitar tipos de plano desconhecidos, câmeras ortográficas invertidas
  e bases persistidas inválidas sem fallback silencioso para XY. O teste de plano
  ficou em 35/35 e o teste gráfico ganhou cobertura do caminho de recuperação.
  Commit `03346c5`; ZIP regenerado com SHA-256
  `C8246D50AFC56B77A16941AE140D78226C7ADD9FFC180331847505B2A5E79405`, instalado
  no `ApplicationPlugins` após backup
  `D:\Ameno\backups\AmenoTools-before-e14-hardening-20260908-204556`; smoke
  instalado PASS/0 FAIL.

- **2026-09-08 — Detalhar preventivamente a implementação E14:** plano revisado com contratos U/V/N, câmera nivelada, origem no primeiro snap, preservação das âncoras 3D, baseline fixa de cadeias de fachada, migração v6, transações, lifecycle, render e matriz de evidências por subetapa. As sete subetapas permanecem; implementação não iniciada. Documento: `plans/2026-09-08-e14-planos-de-cotacao-fachadas.md`.

- **2026-09-06 — Instalar o hotfix de lifecycle WPF:** Max e Batch confirmados fechados; instalação anterior preservada em `D:\Ameno\backups\AmenoTools-before-ui-lifecycle-20260906-213520`; commit `dac0601` instalado no `ApplicationPlugins`. Conferência completa: 42 esperados/42 instalados, 0 ausentes, 0 divergentes e 0 extras. `test_installed_package.ms` terminou com exit 0, 1 PASS e 0 FAIL. Gate interativo pendente.

- **2026-09-06 — Corrigir a interface que deixa de responder após usar cotas e listar issues abertas:** os logs provaram que o MouseTool concluía e o Max seguia responsivo; a falha estava no lifecycle síncrono Hide/startTool/Show, nos `catch ()` silenciosos e na reconstrução repetida de Criar/Render. O hotfix mantém a janela visível e temporariamente desabilitada, reutiliza controles, faz rollback da navegação e adiciona logs/teste de estresse. Dez suítes somaram 142 PASS/0 FAIL. As suítes que apagavam a biblioteca global real foram isoladas em `%TEMP%`; o perfil do usuário permaneceu intacto. Issues abertas confirmadas: #1, #2 e #3. Instalação pendente porque o Max está aberto. Handoff: `plans/2026-09-06-e13-ui-lifecycle-fix-handoff.md`.

- **2026-09-06 — Analisar cotas invisíveis no render e perfis que somem após reinício:** confirmado que o material temporário do render é branco e que as cores do estilo ainda ficam restritas ao preview; confirmado também que a persistência atual é scene-local e depende do `.max` ser salvo. A suíte E13 etapa 3 cobre save/load de cena, não uma biblioteca global entre reinícios. Implementação da cor e decisão do escopo global/scene-local ainda pendentes.

- **2026-09-06 — Corrigir risco de crash por renderer sem identificação/adapter:** o log `ameno-20260906-180520-144.log` registrou `Renderer: Arnold · sem adapter` seguido de `EXCEPTION_ACCESS_VIOLATION` no estágio `render`. A causa operacional foi confirmada no código: o despacho antigo tinha fallback para Corona quando a família não era reconhecida. A correção remove o fallback, mostra `displayName [className]` no painel/diagnóstico/log, revalida o adapter antes do passe e impede o caminho nativo para renderer incompatível. A real Corona 15 Hotfix 1 passou; a versão corrigida foi instalada após o Max fechar, com 42/42 hashes e teste instalado aprovados. O gate visual continua pendente.

- **2026-09-06 — Instalar o hotfix de identificação/renderer:** o Max foi confirmado fechado, a instalação anterior foi preservada em `D:\Ameno\backups\AmenoTools-before-e13-render-guard-20260906` e `tools/install-dev.ps1` validou/substituiu o `ApplicationPlugins`. Os 41 arquivos de conteúdo e `PackageContents.xml` conferem por SHA-256; `test_installed_package.ms` terminou com exit 0, 1 `[AMENO_INSTALLED_TEST][PASS]` e 0 FAIL. O log instalado mostra `Renderer: Arnold [Arnold] · sem adapter`; o bloqueio informativo e o render Corona 15 ainda precisam de confirmação visual após reabrir o Max.

- **2026-09-06 — Implementar biblioteca global e cor materializada do overlay:** decisão adotada: salvar perfis globais fora da cena em `%LOCALAPPDATA%\AmenoTools\Profiles\styles.library`, mantendo estilos scene-local com precedência e backup best-effort; `annotationColor` é a fonte de cor do material temporário por cota. Testes Batch cobrem persistência sem `.max`, RGB, materiais por cor e render Corona real. Handoff: `plans/2026-09-06-e13-renderer-profile-handoff.md`.

- **2026-09-06 — Corrigir o travamento ao tentar cotar na orientação errada:** a análise do logger e do ciclo do `MouseTool` confirmou que o painel fica oculto durante a sessão, o modo é congelado no início e não havia uma rejeição explícita para a direção incompatível; o cancelamento também não forçava `#stop` em todos os caminhos. Foi implementada a detecção/cancelamento de modo incompatível, o armamento temporário de `escapeEnable` e o retorno explícito no abort. O usuário precisou fechar o Max; após isso, o pacote foi instalado com backup e o teste instalado passou. Commit `5a31643`; gate interativo após reabrir o Max pendente.

- **2026-09-06 — Remover o Enter após crash reproduzido na cotação contínua:** o caminho CLR assíncrono foi retirado do MouseTool; prompts e lifecycle foram atualizados; logger persistente e teste do logger foram incluídos. Batch E12/E13 passou sem FAIL, pacote sem Enter foi instalado com 42/42 hashes e o teste pelo ApplicationPlugins aprovou. Commit 2135b3b; handoff plans/2026-09-06-e13-enter-crash-fix-handoff.md. A confirmação interativa por clique e o comportamento pós-reabertura do Max são o próximo gate; Enter não deve ser pressionado nesta versão.

- **2026-09-06 — Instalar hotfix de posição E13:** após o Max encerrar normalmente, o commit `715e078` foi instalado no `ApplicationPlugins`; 42/42 arquivos conferidos por SHA-256 e teste instalado exit 0 / 1 PASS / 0 FAIL. O Max ainda precisa ser reaberto para o gate visual do comportamento corrigido.

- **2026-09-06 — Registrar falha de fontes no viewport/render:** criada a issue [#3](https://github.com/octaviomoliveira/Ameno-Tools/issues/3) para investigar Fredoka e famílias semelhantes. As capturas mostram texto deformado/preenchido em uma visualização e contorno legível em Wire Color; a hipótese de triangulação/conversão interna do TextPlus foi registrada sem assumir causa, pois a produção não chama `convertToPoly` diretamente.

- **2026-09-06 — Registrar layout responsivo:** criada a issue [#2](https://github.com/octaviomoliveira/Ameno-Tools/issues/2) para permitir redimensionar/maximizar a janela de cotas e garantir acesso aos controles cortados à direita, com critérios para layout responsivo, rolagem e DPI.

- **2026-09-06 — Registrar preview das fontes:** criada a issue [#1](https://github.com/octaviomoliveira/Ameno-Tools/issues/1) para renderizar cada item do seletor de tipografia usando sua própria família, com fallback, preservação do schema e cobertura de seleção/preview.

- **2026-09-06 — Instalar E13 e corrigir feedback visual:** instalação do candidato autorizada e realizada com Max fechado; após as capturas, foram implementados aplicação a todas as cotas, nome antes de salvar, orientação do texto e contraste legível. A atualização do commit `20d618f` foi instalada depois; 42/42 hashes e o teste instalado passaram. Aceitação visual do usuário ainda pendente. Handoff: `plans/2026-09-06-e13-feedback-visual-handoff.md`.

- **2026-09-06 — Finalizar as etapas 5, 6 e 7 da E13 e fazer pente-fino:** no `develop`, terminais, preview, transação, câmera explícita e restauração foram implementados; a suíte E13 final passou com 217 PASS/0 FAIL. A regressão combinada passou E10.1–E10.7, E11.0–E11.5, E12 chain/R0–R4 e Corona real; E10.1/E10.2 tiveram um defeito de sintaxe/contrato do próprio teste descoberto e corrigido antes da aprovação. Pacote estrutural e candidato `AmenoTools-0.0.1-e13-candidate.zip` foram gerados, SHA-256 registrado, sem instalação, publicação ou merge. Gates manuais 2–6, V-Ray CPU real, aprovação do usuário e publicação permanecem pendentes. Evidências: `plans/2026-09-05-e13-executor-runbook.md`, `plans/2026-09-06-e13-candidate-manifest.sha256`, `plans/2026-09-06-e13-etapa-5-handoff.md`, `plans/2026-09-06-e13-etapa-6-handoff.md` e `plans/2026-09-06-e13-etapa-7-handoff.md`.

- **2026-09-06 — Seguir para a etapa 4 da integração E13:** em `develop`, a aba Editar passou a validar estritamente o modo selecionado, tratar entradas inválidas sem mutar CA/Undo, converter unidades rotuladas para mm, sincronizar seleção/Undo/Redo, filtrar reancoragem por geometria E12 e persistir `vertexId` com proteção contra cancelamento acidental para mundial. A suíte dedicada passou com 44 verificações internas/45 marcadores PASS e 0 FAIL; pacote, bootstrap, E13-A…H, E11.1–E11.5, E10.7 e E12 9/9 passaram. Commit funcional `95a0ee0`; sem instalação, publicação ou etapa 5. Gates manuais das etapas 3 e 4 pendentes. Handoff: `plans/2026-09-05-e13-etapa-4-handoff.md`.

- **2026-09-06 — Seguir para a etapa 3 da integração E13:** em `develop`, a aba Estilos deixou de recriar o rascunho ao navegar; refresh genérico, troca explícita, salvar/descartar/cancelar, troca de cena, fechamento e callbacks foram separados e testados. A suíte dedicada passou com 24 verificações internas/25 marcadores PASS e 0 FAIL; pacote, bootstrap, E13-A…H, E11.1–E11.5 e E12 9/9 passaram. Commit funcional `1fe7039`; sem instalação, publicação ou etapa 4. Gate manual da etapa 3 pendente. Handoff: `plans/2026-09-05-e13-etapa-3-handoff.md`.

- **2026-09-06 — Seguir para a etapa 2 da integração E13:** no `develop`, o comando contínuo da aba Criar e da macro foi unificado; os controles foram ligados aos campos existentes do E12/E4 e sincronizados sem defaults conflitantes; alterações foram bloqueadas durante sessão contínua; foco, retorno, contagem e callbacks de cena foram tratados; e o teste dedicado passou com 20 verificações internas/21 marcadores PASS e 0 FAIL. Bootstrap, E13-H, pacote e regressões E13/E12 passaram. Sem instalação, publicação ou etapa 3. Handoff: `plans/2026-09-05-e13-etapa-2-handoff.md`.

- **2026-09-06 — Continuar a etapa 1 em `develop`:** o wrapper mínimo de compatibilidade contínua foi adicionado em `ameno_runtime.ms`; o teste R0 passou após o fixture declarar `#horizontal`, sem alterar expectativas nem o núcleo E12; a auditoria E13 passou com 8 PASS/0 FAIL; E13-A…H passou com 8/8 suítes, 57 PASS/0 FAIL; e as 9 suítes E12 passaram. Checklist e handoff foram atualizados. Sem instalação, publicação ou etapa 2.

- **2026-09-06 — Executar somente a etapa 1 da integração E13 sobre a E12 aprovada:** worktree `integration/e13-on-e12` criado sobre `f131f08`; E13 `676e008` incorporada, conflitos resolvidos preservando E12, pacote/bootstrap/E13 aprovados e 8/9 regressões E12 aprovadas. O R0 continua PENDENTE por três falhas reproduzidas também na main; runner endurecido contra PASS+FAIL; sem instalação, merge ou publicação em main. Handoff: `plans/2026-09-06-e13-etapa-1-handoff.md`.

- **2026-09-06 — Transferir a situação integrada para `develop` e continuar a etapa 1:** branch `develop` criada a partir de `d5aa9cc`; reexecução de pacote/bootstrap/E13 e regressões E12 concluída com 8/9 suítes E12 aprovadas, R0 reproduzido e compatibilidade do entry point contínuo ainda pendente. Sem instalação, merge ou publicação em main.

- **2026-09-05 — Continuidade E13 para agente mais leve:** usuário solicitou plano Markdown com ações detalhadas por etapa e marcação de OK baseada em evidência. Criado `plans/2026-09-05-e13-executor-runbook.md`, com sete etapas, arquivos-alvo, regressões, gates manuais, implantação e modelo de handoff. Somente documentação nesta entrega; implementação E13 não iniciada. Registrada também limitação do runner: um PASS isolado não comprova ausência de FAIL.

| Data | Pedido / decisão | Situação | Evidência |
| --- | --- | --- | --- |
| 2026-09-06 | Corrigir o render de cotas que falha no Corona 15 na cena real. | Três logs repetem o acesso inválido em `render()` e o log do Max confirma Isolate Selection ativo. Implementada guarda pré-render não destrutiva e caixa `Renderizar somente as cotas`; Batch, Corona real, hashes e smoke instalado passaram. Gate visual após reinício do Max pendente. | commits `888985e`/`5844730`; `plans/2026-09-06-e13-render-isolate-hotfix-handoff.md`; `.test-output/render-scope-option/` |
| 2026-09-05 | Concluir o gate interativo E12-R0 e analisar o trace real. | R0 concluído: Horizontal criou quatro segmentos, mas `commitSuccess` deixou o MouseTool ativo/coletando; Alinhado foi aceito na captura e recusado no commit. Batch, instalação por hash e trace foram comprovados. Reutilização Horizontal→Vertical segue sem causa comprovada. | commit instalado `e1bc114`; `docs/e12-r0-diagnostics.md`; trace `e12-r0-20260905-165149-560.log` |
| 2026-09-05 | Auditar minuciosamente o código e detalhar etapas para execução por agente mais leve. | Runbook R0–R6 com contratos de entrada/estado, mapa de falhas, testes negativos, gates reais e prompt de execução. Sem código alterado ou instalação. | `plans/2026-09-05-e12-executor-runbook.md`, `plans/2026-09-05-e12-agent-prompt.md` |
| 2026-09-05 | Iniciar R0 em worktree própria e preparar observabilidade da interação real. | Código voltou ao comportamento `ba55d95`; probe opt-in instrumenta MouseTool, classificação, commit e cleanup sem correção funcional. Batch/instalação/trace real pendentes porque o Max está aberto. | branch `feature/e12-input-recovery`; `ameno_continuous_diagnostics.ms`; `docs/e12-r0-diagnostics.md`; `test_e12_r0_diagnostics.ms` |
| 2026-09-05 | Preparar a transferência do R0 para outro agente. | Relatório registra commits, arquivos, instalação ainda funcional, testes e trace pendentes, comandos e proibições. Nenhuma correção R1–R6 executada. | `plans/2026-09-05-e12-r0-handoff.md` |
| 2026-09-05 | Pesquisar cotagem Revit/SketchUp e planejar solução da confirmação contínua no Max. | Documentação oficial comparada com código instalado; viabilidade confirmada no nível de APIs, causa runtime ainda pendente. Plano C1–C5; sem implementação. | `plans/2026-09-05-e12-finalization-research.md` |
| 2026-09-05 | Planejar recuperação da cota contínua estilo Revit e salvar no Git para execução por outro agente. | Plano detalhado concluído; nenhuma alteração de código, instalação ou teste de runtime nesta entrega. Execução começa pela E12-A. | `plans/2026-09-05-e12-continuous-revit-implementation.md`, `docs/decisions/0020-e12-shared-dimension-chain.md`; base inspecionada `db88f1b` |
| 2026-09-05 | Executar a E12-A: tornar entrada da cota contínua determinística e testável. | Concluída em Batch: sem timer de duplo clique; estados `#idle/#collecting/#committing`; referência/geometria/vazio/ambíguo separados; abort cancela. Sem instalação ou teste visual nesta etapa. | `ameno_dimension_continuous_tool.ms`, `test_e12_chain_input.ms` 21/21, `test_e12_continuous.ms` 43/43, `docs/e12-a-input-spike.md` |
| 2026-09-05 | Executar a E12-B: calcular uma linha comum H/V para toda a sequência. | Concluída em Batch: módulo puro ordena estações, projeta todos os pontos na mesma baseline e rejeita intervalos zero; nenhuma criação de cena. | `ameno_dimension_chain_math.ms`, `test_e12_chain_math.ms` 29/29, `docs/e12-b-shared-layout.md` |
| 2026-09-05 | Executar a E12-C: conectar preview e commit H/V ao layout compartilhado, com rollback e Undo único. | Implementada, aprovada em Batch e instalada para gate manual. Horizontal e Vertical usam baseline comum, clique vazio confirma `N-1`, falha injetada não deixa cotas permanentes e o draft é preservado. | commit `ba55d95`; `test_e12_chain_commit.ms` 43/43; regressivos e pacote instalado aprovados; 24 hashes conferidos; `docs/e12-c-preview-commit.md` |
| 2026-09-05 | Restaurar a versão trabalhada antes da tentativa de correção feita por outro agente. | Pacote `ApplicationPlugins` restaurado exatamente ao commit `ba55d95`; versão anterior preservada em backup, 24 arquivos validados por SHA-256 e smoke instalado aprovado. A branch continua em `d8ce420`, explicitamente diferente da instalação ativa. | `AmenoTools.backup-before-ba55d95-20260905-124838`; `[AMENO_INSTALLED_TEST][PASS]` |
| 2026-09-03 | Estruturar Ameno Tools e iniciar pelo módulo de cotas para plantas humanizadas. | Concluído na fundação | `README.md`, `docs/`, pacote `0.0.1` |
| 2026-09-03 | Usar layer exclusiva, manter Beauty/LightMix intactos e renderizar cotas separadamente para composição. | Decidido e documentado | `docs/decisions/0002-*`, `0003-*` |
| 2026-09-03 | Permitir valores manuais auditáveis com alerta visível somente no viewport. | Decidido e documentado | `docs/decisions/0004-*`, `docs/manual-overrides.md` |
| 2026-09-03 | Priorizar 3ds Max 2026; Corona primeiro, com compatibilidade planejada para V-Ray. | Decidido e documentado | `docs/decisions/0005-*`, `0006-*` |
| 2026-09-03 | Centralizar o projeto em `D:\Ameno\_tools` e manter planos atualizados para continuidade via Antigravity. | Concluído | Repositório Git íntegro em `D:\Ameno\_tools`; origem removida após confirmação de vazio |
| 2026-09-03 | Confirmar o pacote aberto no 3ds Max e dividir o funcionamento do plugin em etapas pequenas. | Concluído no planejamento; E1 é a próxima implementação | `plans/2026-09-03-mvp-incremental.md` |
| 2026-09-03 | Seguir para E1 e registrar cada etapa em Markdown e GitHub. | E1 implementada, testada em Batch e pronta para validação visual; commit local `92bddd1`; GitHub bloqueado porque nenhum remoto está configurado | `Contents/scripts/ameno/core/ameno_scene_setup.ms`, `.test-output/*e1*` |
| 2026-09-03 | Conectar `github.com/octaviomoliveira/Ameno-Tools` e seguir para E2. | `origin/main` publicado; E2 implementada e aprovada em Batch e no pacote instalado; commits `70c0fb2` e `78e54d7` publicados | `Contents/scripts/ameno/core/ameno_dimensions_math.ms`, `.test-output/*e2*` |
| 2026-09-03 | Conferir a tela atual do Ameno Tools para validar E1. | Instalação confirmada por hash; a tela mostrada pertence à sessão anterior ao reload. Aguardando reinicialização completa do 3ds Max | `ApplicationPlugins\AmenoTools\Contents\scripts\ameno\ui\ameno_main_panel.ms` |
| 2026-09-03 | Reabrir o Max e validar E1; seguir para a próxima etapa. | E1 aprovada visualmente; E3 iniciada | captura do painel e Layer Explorer fornecida pelo usuário |
| 2026-09-03 | Seguir após reiniciar o Max. | E3 implementada e instalada; aguardando gate manual. A validação Batch foi concluída depois em perfil isolado. | `Contents/scripts/ameno/core/ameno_dimension_graphics.ms`, cópia `ApplicationPlugins` conferida por SHA-256 |
| 2026-09-03 | Corrigir tela “O núcleo do Ameno Tools não foi carregado”. | Corrigido, testado no 3ds Max 2026.3 em Batch isolado e no pacote `ApplicationPlugins`; a mensagem futura agora inclui o módulo/erro reais. | `ameno_dimension_graphics.ms`, `ameno_bootstrap.ms`, `AmenoTools.mcr`, `.test-output/*e3*` |
| 2026-09-03 | Confirmar que a E3 funciona no Max após a correção. | Gate visual do viewport aprovado: uma cota ativa aparece com linhas, terminais e TextPlus `5,00 m`; `AMENO_COTAS` está selecionada. Render comum e limpeza ainda pendentes. | captura do viewport/painel fornecida pelo usuário |
| 2026-09-03 | Validar render e limpeza da E3; esclarecer o caso Corona sem luz. | Arnold exibiu a cota; V-Ray exibiu a cota com luz na cena; `Limpar cotas de teste` funcionou. A hipótese de ausência de luz no Corona permanece registrada para a E9, sem novos probes no pacote. | capturas de Arnold/V-Ray e confirmação textual do usuário |
| 2026-09-03 | Seguir para E4 e criar a ferramenta de três cliques com preview. | Implementada em `ameno_dimension_tool.ms`, integrada ao painel/bootstrap/runtime; smoke test E1–E4 passou e a instalação de desenvolvimento foi atualizada. Aguardando validação manual do fluxo no Max. | `.test-output/listener.log`, `ApplicationPlugins\\AmenoTools`, commit `a33139e` |
| 2026-09-03 | Corrigir o desaparecimento da prévia no terceiro clique. | Removido o limite `numPoints:3`: o MouseTool permanece ativo até o commit retornar sucesso, preserva a prévia em erro e o painel exibe a exceção. Teste Batch e teste do pacote instalado passaram. | `ameno_dimension_tool.ms`, `ameno_main_panel.ms`, commit `6ce2200` |
| 2026-09-04 | Confirmar a correção do terceiro clique no uso real. | Fluxo manual aprovado no Max: A/B/afastamento criou e manteve uma cota permanente de `4,05 m`; painel indicou `1 cota(s) ativa(s)`. E4 encerrada; próximo passo é E5. | captura do viewport/painel fornecida pelo usuário; commits `6ce2200` e `a868a4c` |
| 2026-09-04 | Implementar E5: persistência, Custom Attributes e ciclo de vida. | E5 implementada e aprovada em Batch isolado e no pacote ApplicationPlugins; aguardando validação manual no Max. | commit `9c78acf`, `ameno_dimension_ca.ms`, `0008-e5-custom-attributes-persistence.md` |
| 2026-09-04 | Validar manualmente a E5 e iniciar a E6. | E5 aprovada no Max pelo usuário (save/load, reparo de filhos gráficos e Undo); E6 iniciada no planejamento. | confirmação do usuário, commit `3cb9017`, `PLAN.md` |
| 2026-09-04 | Implementar E6: valores medidos, arredondados e manuais com marcador viewport-only. | E6 aprovada no Max pelo usuário (override 1,10m com medido 1,09m, [M] no viewport e ausente no render); E7 iniciada no planejamento. | captura do viewport/Arnold RenderView fornecida pelo usuário, commits `8fed0e0` e `e60a47a`, `PLAN.md` |
| 2026-09-04 | Implementar E7: editor visual de estilo, tipografia TextPlus, terminais vetoriais e espessuras. | E7 aprovada no Max pelo usuário (reatividade ao vivo, presets, fontes, espessuras e Undo); E8 iniciada no planejamento. | confirmação do usuário, commit `557007c`, `0010-e7-style-system-and-visual-editor.md` |
| 2026-09-04 | Implementar E8: âncoras geométricas, atualização reativa, cotas órfãs e diagnóstico. | E8 implementada e validada em Batch isolado e no pacote ApplicationPlugins; aguardando validação interativa no Max. | `ameno_anchor_service.ms`, `0011-e8-anchors-dirty-queue-diagnostics.md`, `.test-output/*` |
| 2026-09-04 | E8.1: Estabilização das âncoras reativas, undo de estilos, escala de cena, prioridade de wirecolor e UI compacta. | Implementada e aprovada em testes automatizados no Batch isolado e pacote instalado; aguardando validação interativa no Max. | `0012-e8-1-anchors-styles-ui-stabilization.md`, `test_bootstrap.ms`, `test_installed_package.ms` |
| 2026-09-04 | Bug: cota não atualiza em tempo real ao mover objeto — precisava reancorar para atualizar. | Causa raiz: `rebuildIndex()` não era chamado após criar cota; o `indexTable` ficava vazio e o `NodeEventCallback` ignorava os eventos. Corrigido com `rebuildIndex()` após `createDimension` e rebuild lazy no `handleNodesChanged`. Testes automatizados passaram (exit code 0). | commit `853b97a`, `ameno_dimension_tool.ms`, `ameno_anchor_service.ms` |
| 2026-09-04 | Bug persistente: reatividade em tempo real ainda não funcionava após `853b97a`. | Causa raiz final: `NodeEventCallback` não captura Select-and-Move interativo — os eventos não chegavam com handles de nó válidos. Solução: `execute()` com `when transform (getAnimByHandle h) changes` compila o watcher em runtime, com handle embutido na string para evitar closure/race condition. E8.1 **aprovada interativamente** pelo usuário. | commit `4373f34`, `ameno_anchor_service.ms` |
| 2026-09-04 | Finalizar e aprovar E8 / E8.1 no 3ds Max; atualizar planos e abrir E9 no GitHub. | E8 e E8.1 concluídas e aprovadas interativamente pelo usuário; documentação e planos incremental e compartilhado sincronizados; E9 é a próxima etapa (render overlay Corona). | Confirmação do usuário; `PLAN.md`, `plans/2026-09-03-mvp-incremental.md`, commits `bb05a41` e subsequente |
| 2026-09-04 | Retomar no GPT após a E8.1 concluída no Antigravity e executar o trabalho bruto da E9. | E9 implementada, validada por testes transacionais e por render real no Corona 13, instalada em `ApplicationPlugins` e pronta para o gate manual; E10 permanece bloqueada até a confirmação do usuário. | `ameno_render_cotas_service.ms`, `ameno_corona_adapter.ms`, `test_e9_corona_render.ms`, `0013-e9-corona-separate-overlay.md` |
| 2026-09-04 | Gate manual da E9 executado e aprovado no 3ds Max 2026.3 com Corona 13. | PNG com fundo transparente gerado, proteção de sobrescrita confirmada, cena restaurada; dois bugs corrigidos durante o gate (`renderOutputFilename` obrigatório, deleção de arquivo parcial ao cancelar); E9 encerrada, E10 aberta. | commits `c1f0488`, `6807b09`; confirmação visual do usuário |
| 2026-09-04 | Registrar que o mockup do Editor de Estilo ainda não foi implementado e planejar sua “viewport” enquanto a E10 segue em desenvolvimento. | E11 planejada como Editor Visual e Preview ao Vivo; preview definido como canvas 2D isolado da cena, com prova tecnológica, `StyleDraft`, interface moderna, testes e gate manual próprios. Alterações paralelas da E10 foram preservadas fora deste trabalho. | `plans/2026-09-04-e11-editor-visual-preview.md`, índice e plano incremental |
| 2026-09-04 | Implementação completa da Etapa E10 (E10.1 a E10.6): Modos H/V, Lote/Bake, V-Ray CPU, Diagnóstico/Fixtures, Benchmarks de Escala (1 a 1000 cotas) e Empacotamento Alpha. | E10.1 (Modos Alinhada, H e V), E10.2 (Seleção múltipla, unidade/precisão/modo e bake em 1 Undo), E10.3 (Adapter V-Ray CPU com VRayLightMtl e despacho dinâmico), E10.4 (Serviço de Diagnóstico e fixtures de planta arquitetônica), E10.5 (Benchmarks de escala 1, 10, 100, 500 e 1000 cotas com zero crashes) e E10.6 (Pacote alpha gerado em dist/AmenoTools-0.0.1-alpha.zip e release notes). Todos os testes unitários e de integração passaram com 100% de sucesso. Pronta para validação do usuário no 3ds Max. | commits E10.1–E10.6, ADRs 0014–0018, tests/maxscript/test_e10_*.ms, dist/AmenoTools-0.0.1-alpha.zip |
| 2026-09-04 | Auditar o trabalho do Antigravity e seguir com a correção de âncoras em edição de subobjeto antes da integração visual. | `main` limpa em `ec3038b`; pacote estrutural válido; E10.1–E10.6 confirmadas no histórico. A correção sugerida como E10.5 no ADR 0015 foi renumerada para E10.7 para evitar colisão. Código e teste dedicados implementados; Batch pendente porque o Max interativo está ativo. | `plans/2026-09-04-e10-7-subobject-anchors.md`, CA v5, `test_e10_7_subobject_anchors.ms` |
| 2026-09-04 | Fechar o Max e concluir a validação/instalação da E10.7. | Pacote estrutural aprovado e versão de desenvolvimento instalada. O teste E10.7 e a regressão E10.1 não chegaram a executar: o lançador Batch demorou mais de seis minutos para criar o processo filho e não produziu logs nem resultado. Gate interativo pendente; gate automático registrado como bloqueio do executor, não como falha do E10.7. | `tools/validate-package.ps1`, `tools/install-dev.ps1`, `plans/2026-09-04-e10-7-subobject-anchors.md` |
| 2026-09-04 | Corrigir a E10.7 após o gate manual continuar sem acompanhar o vértice. | Falha reproduzida visualmente pelo usuário. Identificadas lacunas na leitura de `baseObject` e na captura dependente do primeiro ray hit. E10.7.1 implementa malha avaliada por `snapshotAsMesh`, busca global pelo ponto de snap, watcher direto de geometria e teste com modifier stack; pacote reinstalado e reteste pendente. | `ameno_dimension_ca.ms`, `ameno_dimension_tool.ms`, `ameno_anchor_service.ms`, `test_e10_7_subobject_anchors.ms`, `tools/install-dev.ps1` |
| 2026-09-04 | Avaliar viabilidade após a E10.7.1 ainda falhar no Max. | Viável pela API oficial: o Max expõe nó e ponto mundial do Snap e eventos de geometria. E10.7.2 usa esses dados diretamente, corrige reancoragem que passava o record como nó, força coordenadas mundiais e adiciona feedback `A=vN / B=vN`; pacote reinstalado e novo gate pendente. | `snapMode.node`, `snapMode.worldHitpoint`, `ameno_dimension_tool.ms`, `ameno_main_panel.ms`, `docs/decisions/0015-subobject-anchor-limitation.md`, `tools/install-dev.ps1` |
| 2026-09-04 | Confirmar o resultado final da E10.7.2 em edição de subobjeto. | Concluída e aprovada manualmente: Vertex Snap persistiu os IDs e a cota acompanhou o deslocamento dos vértices; o usuário confirmou "sucesso absoluto". | confirmação textual e vídeo `WhatsApp Video 2026-09-04 at 18.52.27.mp4`; commit funcional `32a00a7` |
| 2026-09-04 | Implementação completa da Etapa E11 (E11.0 a E11.5): Editor Visual de Estilos com Preview Vetorial 2D ao Vivo (WPF .NET 8), StyleDraft transacional, Persistência, Integração e Instalação no ApplicationPlugins. | E11.0 (Spike WPF .NET 8 aprovado, ADR 0019), E11.1 (StyleDraft e Schema v2 retrocompatível), E11.2 (Shell WPF moderno, 2 colunas com GridSplitter, atalhos e preferências INI), E11.3 (Renderer vetorial 2D no Canvas WPF com planta neutra, 5 terminais e zoom), E11.4 (Persistência atômica, deduplicação de nós, rollback de snapshot e reatividade à seleção), E11.5 (Ponto de entrada integrado no painel principal, fallback diagnósticável para rollout legado, ciclo de vida robusto com reset de cena, empacotamento determinístico e instalação funcional no ApplicationPlugins). Suítes automatizadas 100% aprovadas. Pronto para Gate Manual no 3ds Max. | commits `4c61f20`, `e309892`, `6a60dcf`, `acd810d`, `cbc5927`, `ADR 0019`, `tests/maxscript/test_e11_*.ms`, `test_installed_package.ms` |
| 2026-09-04 | Integrar `feature/e11-visual-editor` na `main`, validar, instalar a versão unificada com E10.7 e publicar. | Merge concluído com um único conflito documental em `PLAN.md`, reconciliado preservando os históricos E10.7 e E11. Validação estrutural aprovada; instalação em `ApplicationPlugins` conferida com 22/22 arquivos e zero diferenças SHA-256. Pronto para o gate interativo unificado após reiniciar o Max. | merge `5aa6afc`; `tools/validate-package.ps1`; `tools/install-dev.ps1` |
| 2026-09-05 | Fechar o R5 da recuperação E12. | O caso foi definido como reuso do vértice da geometria original entre cadeias H/V; a ponta de anotação não vira âncora nesta E12-R. R5 documental concluído; R6 é o próximo gate. | `docs/decisions/0021-e12-reference-reuse-scope.md`; `plans/2026-09-05-e12-r5-handoff.md`; R2 aprovado |
| 2026-09-05 | Executar a automação do R6 e corrigir o fixture E12-A obsoleto. | `validate-package.ps1` passou; 11/11 suítes do lote + R2 repetida passaram. E12-A foi ajustada para declarar Horizontal, preservando o contrato de estação H/V. Gate manual final permanece pendente. | `tests/maxscript/test_e12_chain_input.ms`; `work/r6-test-logs`; Batch 3ds Max 2026.3 |
| 2026-09-05 | Aprovar manualmente a aceitação final da E12-R. | Usuário abriu o Max, repetiu Horizontal→Vertical com o mesmo vértice da geometria original e confirmou “tudo funcionando”; encerramento, cancelamento e Undo/Redo foram aceitos. E12-R R6 concluído; publicação dos commits locais pendente de autorização. | `plans/2026-09-05-e12-r6-handoff.md`; confirmação do usuário |
| 2026-09-09 | Executar o primeiro candidato da transição WPF → Python/Qt, priorizando somente o Max 2026. | Fundação Python 3.11/PySide6, Login/token em memória, janela Qt nativa, páginas funcionais, bridge de snapshots primitivos, cancelamento seguro no fechamento e exclusão dos módulos WPF do pacote foram implementados do zero. `validate-package.ps1`, compilação/import do Python embarcado, smoke MAXScript completo, smoke E15 e `test_installed_package.ms` passaram; ZIP `dist/AmenoTools-0.0.1-e15-alpha.zip` gerado (SHA-256 `40D47D5CFA0C7D2D45D4872730F723C5E5B81909DB892D8C79E6445078EDC33F`) e instalação ativa atualizada. Gate visual/soak ainda pendente por exigir Max gráfico. | `plans/2026-09-09-e15-transicao-wpf-python-qt.md`; `docs/decisions/0024-e15-python-qt-interface.md`; `Contents/python/ameno_ui/`; backup `C:\Users\octav\AppData\Roaming\Autodesk\ApplicationPlugins\AmenoTools.backup-before-e15-20260909-020548` |
| 2026-09-09 | Corrigir Login que permanecia visível após a autenticação local. | A causa era `bridge.refresh()` síncrono executado antes de `show_application`; a tela agora troca para o App imediatamente e cada página atualiza a cena somente por ação explícita. Testes Python estático/headless, compilação no Python embarcado, bootstrap e bridge MAXScript passaram; instalação aguarda o Max 2026 ser fechado. | `Contents/python/ameno_ui/application.py`; `tests/python/test_e15_qt_headless.py`; commit E15 subsequente |

## Como retomar sem contexto

1. Leia este arquivo e depois `plans/2026-09-03-mvp-incremental.md`.
2. Execute `git status` e confirme que o estado local é o esperado.
3. Leia `README.md` e a documentação diretamente ligada ao próximo passo.
4. Implemente uma unidade pequena, teste no 3ds Max e registre o resultado aqui.
