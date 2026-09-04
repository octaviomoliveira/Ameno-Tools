# Plano compartilhado — Ameno Tools

> Fonte de continuidade do projeto para qualquer pessoa ou agente (incluindo Antigravity).
> Atualizado: 2026-09-04

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
- Pacote instalado com E1 a E9 validado em Batch isolado e aprovado em sessão interativa no 3ds Max 2026.
- Ação `Ameno Tools` e painel inicial registrados; bootstrap modular e validação de pacote incluídos.
- Modelo de dados inicial para cotas, estilos, referências e valores medidos/arredondados/manuais documentado.
- Regras decididas para `AMENO_COTAS`, geometria renderizável, render separado de cotas e preservação do Beauty, LightMix e Render Elements existentes.
- Fluxo do valor manual definido: a substituição não altera a medida real, é persistida no dado da cota e aparece em âmbar apenas na viewport.
- Editor de estilo especificado com inspiração na edição direta do TextPlus: fonte, tamanho, linhas, espessuras e tipos de seta com prévia.
- Estratégia de render definida: Corona como referência obrigatória; V-Ray CPU como segundo adapter oficial; V-Ray GPU separado e experimental até ser validado.
- Escopo inicial definido para 3ds Max 2026; compatibilidade 2021–2025 será avaliada após o MVP estar estável.

## Em andamento

- E10 — Fluxo de produção e estabilização: cotas horizontal/vertical, seleção múltipla, bake, adapter V-Ray CPU, testes de escala (1–1000 cotas) e empacotamento alpha interno.

## Próximo passo executável

Implementar a **E10 — Fluxo de produção e estabilização**:

1. cotas horizontal e vertical reutilizando o núcleo alinhado;
2. seleção múltipla, atualização em lote e bake;
3. V-Ray CPU pelo mesmo contrato do adapter Corona;
4. cenas-fixture, relatório de diagnóstico e documentação de uso;
5. testes com 1, 10, 100, 500 e 1000 cotas;
6. empacotamento de uma versão alpha interna para uma planta real.


## Decisões que ainda exigem validação

- Versões mínimas de Corona e V-Ray disponíveis no ambiente real.
- Se a interface inicial será somente em português ou já bilíngue.
- Serviço/visibilidade do repositório Git remoto e política de acesso.
- Licença e modelo de distribuição.

## Histórico de solicitações

| Data | Pedido / decisão | Situação | Evidência |
| --- | --- | --- | --- |
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

## Como retomar sem contexto

1. Leia este arquivo e depois `plans/2026-09-03-mvp-incremental.md`.
2. Execute `git status` e confirme que o estado local é o esperado.
3. Leia `README.md` e a documentação diretamente ligada ao próximo passo.
4. Implemente uma unidade pequena, teste no 3ds Max e registre o resultado aqui.
