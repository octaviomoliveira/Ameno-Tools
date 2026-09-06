# E13 — roteiro de implementação e aceitação por etapas

Data: 2026-09-05. Documento operacional para troca de agente/modelo.
Pedido: integrar a interface E13 feita no Antigravity com a E12 aprovada, corrigindo os problemas auditados, uma etapa por vez.
Estado: ETAPAS 5 E 6 IMPLEMENTADAS/TESTADAS NO WORKTREE `develop`; candidato da etapa 7 empacotado e auditado. Sem instalação/publicação. Os gates manuais 2–6, a aprovação do usuário e a publicação permanecem pendentes.

## 1. Contexto que o executor precisa preservar

- Repositório principal: `D:\Ameno\_tools`; main publicada em `f131f089af03892f33a9c86e2df8d3e3288d75a9` na última verificação.
- Fonte E13: `feature/e13-unified-ui`, commit auditado `676e008c200c91478242630defef4f607d671452`; checkout `D:\Ameno\_worktrees\e13-unified-ui`.
- E13 NÃO contém a E12: nasceu antes dela. Não instalar diretamente esse checkout e não substituir arquivos inteiros escolhendo indiscriminadamente um lado do merge.
- E12 R0–R6: aprovada em Batch e pelo usuário no Max, incluindo cadeia H/V, mesmo vértice da geometria reutilizado H→V, finalização e Ctrl+Z/Y. Código instalado aprovado era R4 `688c8bc`; commits seguintes foram documentação/testes. Confirmar instalação atual antes de qualquer cópia, pois outro agente pode ter trabalhado nela.
- Branches antigas E12 foram apagadas após merge. Histórico permanece na main. Não recriá-las para implementar E13.
- Main tem modificação preexistente em `tests/maxscript/batch-isolated.ini`. Preservar; não publicar nem descartar automaticamente.
- A E12 não entrega cadeia alinhada oblíqua nem identidade persistente de cadeia para edição conjunta. Não ampliar esse escopo implicitamente. Cota individual alinhada é uma funcionalidade distinta.
- Reuso é geometria→cota; não criar vínculos cota→cota por inferência.
- Este documento e a entrada em PLAN.md são alterações de documentação ainda não necessariamente commitadas. Transportá-las para a branch de integração sem perdê-las.

## 2. Protocolo obrigatório de continuidade

1. Ler PLAN.md, este roteiro e eventuais AGENTS.md aplicáveis. Inspecionar status, branches, worktrees e último handoff antes de editar.
2. Executar somente a próxima etapa liberada. Um pedido genérico de seguir avança uma etapa; não instalar/publicar etapas seguintes por conta própria.
3. Marcar checkbox apenas após evidência. Distinguir código pronto, teste automatizado e aprovação manual; não chamar tudo de OK após apenas carregar o bootstrap.
4. Ao terminar cada etapa, atualizar este checklist, PLAN.md e `plans/2026-09-05-e13-etapa-N-handoff.md`. Registrar arquivos, commit se houver, testes/contagens, logs, limitações, estado da instalação e próximo passo.
5. Se houver falha, registrar PENDENTE com reprodução; não ajustar expectativa de teste só para obter PASS.
6. Trabalhar em cenas descartáveis. Não rodar scripts destrutivos na cena interativa do usuário. Não fechar Max sem sua concordância.
7. Instalação e publicação são estados separados. Nenhuma autorização de push/merge da E12 deve ser interpretada como publicação automática da E13.

### Painel de progresso

| Etapa | Código + testes | Manual | Estado |
|---|---|---|---|
| 0 — Plano e direcionamento | [x] | não se aplica | OK documental |
| 1 — Base integrada | [x] | não exige instalação | OK — base E12/E13 integrada, pacote/bootstrap/regressões aprovados em Batch; sem instalação |
| 2 — Criar e ciclo de vida | [x] | [ ] | IMPLEMENTADA/TESTADA |
| 3 — Estilos e rascunho | [x] | [ ] | IMPLEMENTADA/TESTADA |
| 4 — Editar e reancorar | [x] | [ ] | IMPLEMENTADA/TESTADA |
| 5 — Terminais e transações | [x] | [ ] | IMPLEMENTADA/TESTADA |
| 6 — Render e restauração | [x] | [ ] | IMPLEMENTADA/TESTADA |
| 7 — Candidato, aceitação e publicação | [x] | [ ] | CANDIDATO PRONTO / AGUARDA MANUAL |

Os gates manuais 2–6 podem ser executados juntos no candidato da etapa 7. Até lá manter a coluna manual pendente; etapa pode ficar IMPLEMENTADA/TESTADA, nunca APROVADA FINAL.

## 3. Etapa 1 — Preparar e integrar a base

- [x] Conferir `git status`, `git worktree list`, fetch origin e hashes. A tentativa de `git fetch origin --prune` foi registrada, mas falhou por `SEC_E_NO_CREDENTIALS`; os refs locais auditados continuaram em `main=f131f08` e `feature/e13-unified-ui=676e008`, e o delta além dos commits foi revisado.
- [x] Criar branch proposta `integration/e13-on-e12` a partir da main atual em `D:\Ameno\_worktrees\e13-integration`, após verificar que nome/diretório não pertenciam a outro trabalho. A situação integrada foi transferida para a branch `develop` em `D:\Ameno\_worktrees\develop` para continuidade da etapa 1.
- [x] Transportar este plano e a atualização documental de PLAN.md para a integração. A alteração preexistente de `tests/maxscript/batch-isolated.ini` foi preservada byte a byte.
- [x] Incorporar feature/e13-unified-ui. Os três conflitos previstos foram resolvidos e a árvore ficou sem marcadores: `Contents/scripts/ameno/core/ameno_dimension_graphics.ms`, `ameno_dimension_tool.ms` e `Contents/scripts/ameno/ui/ameno_main_panel.ms`.
- [x] Graphics: conservar alocação rastreada, rollback, `useUndo` e transação externa E12; acrescentar terminais, campos do record e passagem `style:style` E13. Os dois terminais mesh também foram registrados para rollback; não foi introduzido Undo por segmento.
- [x] Tool: conservar resolução geométrica/picking E12 e integrar exclusão de meshes técnicos E13 por terminal, metadados `Ameno.*`, IDs/CA e resolver contínuo; o nome AMENO não ficou como único critério.
- [x] Painel: adotar a entrada WPF E13 e manter os nomes globais/entry points legados necessários ao runtime, macros e ferramenta.
- [x] Revisar auto-merges de runtime/bootstrap/test_bootstrap: math/input/diagnostics/continuous E12 e `ameno_dimension_terminal_mesh.ms` carregam antes dos consumidores; o guard de compatibilidade da macro foi preservado.
- [x] Confirmar o entry point legado `AmenoApp.startContinuousDimensionTool`: `AmenoRuntime.startContinuousDimensionTool` foi exposto como wrapper fino para `AmenoDimensionContinuousTool.start()`, e `test_e13_audit_fixes.ms` passou o Teste 0 de presença da API. A execução interativa da ferramenta não pertenceu à etapa 1 e continua coberta pela etapa 2.
- [x] Conferir desligamento/reload, chamadas ao painel antigo e referências globais por busca de consumidores; o shutdown fecha WPF e mantém guards dos rollouts legados.
- [x] Validar pacote, bootstrap e suítes E12 existentes. Em `develop`, pacote passou; bootstrap passou com exit 0/PASS 1/FAIL 0; auditoria E13 passou com 8 PASS/0 FAIL; E13-A…H passou com 8/8 suítes e 57 PASS/0 FAIL; e as 9 suítes E12 passaram com 0 FAIL. Nenhuma instalação foi feita.

Gate da etapa 1: OK. A árvore `develop` está sem conflitos, os módulos estão presentes, o bootstrap e a integração E13 funcionam, a E12 foi preservada, o runner rejeita FAIL mesmo quando há PASS e todos os lotes executados terminaram sem FAIL. O R0 passou com fixture corrigido para um modo aceito pela cadeia, e o entry point legado está coberto por wrapper e teste estrutural. Naquele ponto, as etapas 2–7 ainda não haviam sido executadas; as etapas 2 e 3 foram implementadas/testadas posteriormente em commits próprios. A etapa 4+ permanece fora do escopo desta execução, sem instalação ou publicação.

### Evidências da execução em 2026-09-06

- `tools/validate-package.ps1`: PASS.
- `test_bootstrap.ms`: Batch exit 0, `PASS=1`, `FAIL=0`; o único `[Ameno][ERROR]` é a falha de render simulada do cenário E9, seguida do PASS da suíte.
- `test_e13_audit_fixes.ms`: Batch exit 0, 8 PASS, 0 FAIL; o Teste 0 confirma o entry point legado.
- `test_e13a.ms`…`test_e13h.ms`: 8/8 suítes, 57 PASS agregados, 0 FAIL, reexecutadas após as alterações finais.
- E12: `test_e12_chain_commit`, `chain_input`, `chain_math`, `continuous`, `r0_diagnostics`, `r1_lifecycle`, `r2_picking`, `r3_preview` e `r4_transaction` passaram (9/9), com 1 PASS por suíte e 0 FAIL. O R0 foi corrigido apenas no fixture: ele agora salva o modo original, usa `#horizontal` durante o diagnóstico (modo aceito pela cadeia E12) e restaura o modo ao cancelar; nenhuma expectativa foi afrouxada e nenhum comportamento do núcleo foi alterado.
- Reexecução final da etapa 1 em `develop`: `tools/validate-package.ps1` retornou sucesso; bootstrap exit 0/PASS 1/FAIL 0; auditoria E13 8 PASS/0 FAIL; E13-A…H 8/8 suítes, 57 PASS agregados/0 FAIL; E12 9/9 suítes, 9 PASS agregados/0 FAIL. A evidência atual está em `.test-output\stage1-evidence-develop\`, com logs `*.after-fix.*`, `*.final.*` e `*.final2.*` identificados por suíte.
- O runner foi endurecido em `tools/test-maxscript.ps1`: mantém a interface `-MaxBatchPath`, `-ConfigPath`, `-TestScript`; isola `PlugCFG`, `MaxData`, `Temp`, `Additional Macros` e `LOCALAPPDATA`; exige exit code 0, pelo menos um PASS e zero marcadores `[AMENO_TEST][FAIL]`/`[AMENO_INSTALLED_TEST][FAIL]`.
- A busca de consumidores confirmou que a macro continua com guard/fallback e que o runtime integrado agora expõe `AmenoRuntime.startContinuousDimensionTool`; o teste de auditoria verifica a propriedade pública em `AmenoApp`. O wrapper foi mantido mínimo e a chamada interativa ficou para a etapa 2.
- Logs identificados por suíte estão em `D:\Ameno\_worktrees\develop\.test-output\stage1-evidence-develop\` (saída gerada e ignorada pelo Git). A instalação existente foi apenas inspecionada; `ApplicationPlugins` não foi alterado.

## 4. Etapa 2 — Aba Criar e interação

Arquivos principais: `ameno_cotas_criar_tab.ms`, `ameno_runtime.ms`, `ameno_cotas_window.ms`, `Contents/macroscripts/AmenoTools.mcr`; consultar contrato de `ameno_dimension_continuous_tool.ms`.

- [x] Substituir TODO do handler onCotaContinua por chamada real ao runtime. Botão WPF e macro passam por `AmenoCotasCriarTab.executeContinuousCommand()`, com fallback somente quando a aba ainda não está carregada.
- [x] Mapear modo/unidade/precisão/estilo para os campos existentes do motor: `activeMode`, `previewOutputUnit`, `previewPrecision` e `activeStyleId` nos serviços individual e contínuo; nenhuma propriedade de modelo nova foi criada.
- [x] Sincronizar controles a partir do serviço ao abrir/voltar à aba; `build`/retorno usa `syncFromServices()` e não impõe os defaults visuais antigos.
- [x] Respeitar modo congelado da sessão contínua E12. Alterações são rejeitadas enquanto `active` e a UI é restaurada ao estado do serviço; o snapshot `session*` do E12 permanece intocado.
- [x] Manter rejeição explícita de cadeia oblíqua não implementada e funcionamento de alinhada individual; ambos foram exercitados na suíte dedicada.
- [x] Revisar foco após clique WPF, Esc/botão direito, término e reinício: runtime oculta a janela antes de `startTool`, restaura em retorno normal/erro e não adiciona duplo clique/temporização.
- [x] Atualizar contagem da cena após criação/remoção/Undo sem apagar rascunhos de outras abas: callbacks de nós ficam restritos à aba Criar e o runtime faz refresh estreito após a ferramenta.
- [x] Criar teste de comportamento do comando compartilhado e sincronização de estado; `test_e13_stage2_create.ms` cobre botão, macro, runtime, estado, congelamento, foco e contagem, não apenas presença de funções.

Manual futuro: criar H com 4 vértices; finalizar; criar V reutilizando vértice direito sob anotação; confirmar losangos, clique vazio e saída; Ctrl+Z remove cadeia inteira e Ctrl+Y restaura. Testar botão e macro, sem duplicação.

### Evidências da etapa 2 em 2026-09-06

- Alterações: `Contents/scripts/ameno/ui/ameno_cotas_criar_tab.ms`, `Contents/scripts/ameno/core/ameno_runtime.ms`, `Contents/scripts/ameno/ui/ameno_cotas_window.ms`, `Contents/macroscripts/AmenoTools.mcr` e `tests/maxscript/test_e13_stage2_create.ms`.
- `tools/validate-package.ps1`: PASS — pacote válido para 3ds Max 2026.
- `test_e13_stage2_create.ms`: Batch exit 0; 20 verificações internas, 21 marcadores `[AMENO_TEST][PASS]` contando o resumo final, 0 `[AMENO_TEST][FAIL]`.
- Comportamento comprovado no Batch: comando compartilhado botão/macro; sincronização de modo, estilo, unidade e precisão; rejeição durante sessão ativa sem alterar o snapshot; cadeia alinhada rejeitada; alinhada individual disponível; hide/show do painel pelo runtime; contagem após criar/remover.
- Regressão: `test_bootstrap.ms` 1 PASS; E13-A…H 8/8 suítes, 57 PASS agregados/0 FAIL na rodada de regressão, com E13-H repetido após o ajuste final; E12 chain commit/input/math/continuous/R0/R1/R2/R3/R4 9/9 suítes, 9 PASS/0 FAIL.
- Logs identificados (listener e system) estão em `D:\Ameno\_worktrees\develop\.test-output\stage2-evidence-develop\`; os logs da suíte dedicada e de E13-H foram regravados após o ajuste final do macro. O runner exige exit code 0, ao menos um PASS e zero marcadores de FAIL.
- Nenhuma instalação em `ApplicationPlugins`, publicação, push, merge na `main` ou teste destrutivo na cena interativa foi feito. O gate manual H/V, losangos e Undo/Redo continua pendente; as etapas 3 e 4 foram implementadas/testadas posteriormente, com seus gates manuais ainda pendentes.

## 5. Etapa 3 — Estilos, navegação e ciclo de cena

Arquivos: `ameno_cotas_estilos_tab.ms`, `ameno_cotas_window.ms:setTabContent`, stub `ameno_main_panel.ms:AmenoRefreshMainPanel`, `ameno_style_editor_wpf.ms`, runtime/callbacks.

- [x] Corrigir build que recria currentDraft a partir de default em toda visita. `ameno_cotas_estilos_tab.ms` mantém o host WPF e o estado do rascunho em cache; a abordagem não recria o default a cada visita.
- [x] Refresh genérico não pode substituir rascunho editado. `refresh()` preserva o rascunho; `requestStyleSwitch()` trata separadamente a troca explícita de estilo/cena.
- [x] Definir salvar/descartar/cancelar para troca de estilo e fechamento com rascunho sujo, reaproveitando contrato E11. O prompt WPF usa Yes/No/Cancel; Cancelar conserva o rascunho e há `dirtyDecisionOverride` somente como seam do teste Batch.
- [x] Ao reset/abrir cena, invalidar referências da cena anterior e recarregar estilos da nova; rascunho antigo não pode ser aplicado silenciosamente à nova cena. `AmenoApp.onSceneOpened/onSceneReset` chama a invalidação da aba depois de carregar a nova cena.
- [x] Revisar salvar, duplicar, excluir estilo em uso, presets e aplicar à seleção; manter persistência e Undo existentes. Exclusão em uso é bloqueada; persistência E11 e Undo/Redo foram exercitados.
- [x] Revisar fechamento/reabertura/reload: remover callbacks/eventos próprios sem remover os de outras funcionalidades. A aba usa o callback próprio `#amenoCotasStyleSelection` e o teste mantém um callback sentinela para verificar que ele não é removido.
- [x] Testar rascunho alterado → outra aba → retorno com valores e dirty preservados; salvar e reabrir cena; cancelamento de descarte; aplicação + Undo/Redo. `test_e13_stage3_styles.ms` passou com 24 verificações internas, 25 marcadores PASS e 0 FAIL.

OK manual: não perder trabalho ao navegar e não carregar dados da cena anterior.

### Evidências da etapa 3 em 2026-09-06

- Arquivos funcionais: `Contents/scripts/ameno/ui/ameno_cotas_estilos_tab.ms`, `ameno_cotas_window.ms`, `ameno_main_panel.ms`, `ameno_style_editor_wpf.ms` e `Contents/scripts/ameno/core/ameno_runtime.ms`. Teste dedicado: `tests/maxscript/test_e13_stage3_styles.ms`.
- `tools/validate-package.ps1`: PASS — pacote válido para 3ds Max 2026.
- `test_e13_stage3_styles.ms`: Batch exit 0; 24 verificações internas, 25 marcadores `[AMENO_TEST][PASS]` contando o resumo final e 0 `[AMENO_TEST][FAIL]`.
- Regressões: bootstrap 1 PASS/0 FAIL; auditoria E13 8 PASS/0 FAIL; E13-A…H 8/8 suítes e 57 PASS agregados/0 FAIL; regressões E11.1–E11.5 passaram; E12 chain commit/input/math/continuous/R0/R1/R2/R3/R4 9/9 suítes, 9 PASS finais/0 FAIL.
- O runner `tools/test-maxscript.ps1` foi usado com exit code obrigatório, pelo menos um PASS e zero marcadores de FAIL. Os logs listener/system estão em `D:\Ameno\_worktrees\develop\.test-output\stage3-evidence-develop\`, incluindo `stage3-dedicated-final.*` e `e12-*-final.*`.
- Commit funcional: `1fe7039` (`feat: complete E13 stage 3 styles workflow`). A atualização documental e este handoff permanecem como alterações separadas até o commit documental.
- Nenhuma instalação em `ApplicationPlugins`, publicação, push ou merge na `main` foi feita; nenhuma cena interativa do usuário foi alterada. Batch não substitui o gate visual/funcional manual.

Gate manual da etapa 3: PENDENTE. A suíte cobre os contratos e o ciclo em Batch, mas ainda falta o usuário validar visualmente a navegação, preservação de trabalho e troca de cena no 3ds Max interativo. A etapa 4 foi implementada/testada posteriormente.

## 6. Etapa 4 — Editar, validar e reancorar

Arquivos: `ameno_cotas_editar_tab.ms`, serviços runtime/graphics/anchors existentes.

- [x] Validar somente campos do modo escolhido antes de escrever dados. Não usar 1000 mm/50 mm como substitutos silenciosos de entradas inválidas; `applyChangeToController` valida antes de chamar o serviço.
- [x] Tratar vazio, letras, vírgula decimal, ponto, zero e negativo. A entrada inválida mostra mensagem clara, não altera CA e não cria Undo vazio; coberto pela suíte dedicada.
- [x] Preservar medição real, override, motivo e unidades; conversões explícitas cm→mm e m→mm foram verificadas, com auditoria/última medição preservadas.
- [x] Atualizar painel na seleção e Undo/Redo, sem recursão de handlers; callbacks próprios de seleção, `sceneUndo` e `sceneRedo` foram registrados e removidos no fechamento.
- [x] Reancorar usando picking geométrico E12; textos/terminais/gráficos técnicos são rejeitados e `vertexId` explícito é resolvido/persistido no serviço de âncoras.
- [x] Cancelar pick não converte uma âncora para mundial: alvo ausente/cancelado é rejeitado e a mudança mundial continua dependente de chamada explícita do serviço.
- [x] Revisar seleção única/múltipla, controlador inválido, órfãs, aplicação de estilo e retorno ao valor medido; todos cobertos na suíte dedicada.
- [x] Exercitar editar → Undo → Redo, reancorar → mover vértice, excluir geometria e restaurar, incluindo entradas inválidas, em cena descartável Batch.

OK automatizado da etapa 4: IMPLEMENTADA/TESTADA. O gate manual permanece pendente.

### Evidências da etapa 4 em 2026-09-06

- Arquivos funcionais: `Contents/scripts/ameno/ui/ameno_cotas_editar_tab.ms`, `Contents/scripts/ameno/ui/ameno_cotas_window.ms`, `Contents/scripts/ameno/core/ameno_anchor_service.ms`, `Contents/scripts/ameno/core/ameno_runtime.ms`. Teste dedicado: `tests/maxscript/test_e13_stage4_edit_reanchor.ms`.
- `tools/validate-package.ps1`: PASS — pacote válido para 3ds Max 2026; saída preservada em `D:\Ameno\_worktrees\develop\.test-output\stage4-evidence-develop\validate-package-final.txt`.
- `test_e13_stage4_edit_reanchor.ms`: Batch exit 0; 44 verificações internas, 45 marcadores `[AMENO_TEST][PASS]` contando o resumo final e 0 `[AMENO_TEST][FAIL]`.
- Regressões: `test_bootstrap.ms` PASS; `test_e13_audit_fixes.ms` 8 PASS; E13-A…H 8/8 suítes e 57 PASS agregados; `test_e13_stage2_create.ms` 21 PASS; `test_e13_stage3_styles.ms` 25 PASS; E11.1–E11.5, E10.7 e E12 chain commit/input/math/continuous/R0/R1/R2/R3/R4 passaram, todos com exit 0 e 0 FAIL.
- O runner `tools/test-maxscript.ps1` exigiu exit code 0, pelo menos um PASS e zero marcadores `[AMENO_TEST][FAIL]`/`[AMENO_INSTALLED_TEST][FAIL]`; não houve falso sucesso PASS+FAIL. Os pares listener/system e a saída do runner estão em `D:\Ameno\_worktrees\develop\.test-output\stage4-evidence-develop\`.
- `git diff --check` não apontou erro de whitespace; a busca por marcadores de conflito não encontrou `<<<<<<<`, `=======` ou `>>>>>>>` nos arquivos revisados.
- Commit funcional: `95a0ee0` (`feat: complete E13 stage 4 edit and reanchor workflow`). O checklist, `PLAN.md` e o handoff da etapa 4 serão registrados em commit documental separado.
- Nenhuma instalação em `ApplicationPlugins`, publicação, push ou merge na `main` foi feita; nenhuma cena interativa do usuário foi alterada. Batch não substitui o gate manual.

Gate manual da etapa 4: PENDENTE. Ainda falta validar no 3ds Max interativo a apresentação visual da aba Editar, mensagens/estado WPF, o pickPoint real (incluindo Esc), reancoragem em geometrias reais, seleção múltipla e o ciclo de edição/Undo/Redo na cena de teste. A etapa 5 não foi iniciada.

## 7. Etapa 5 — Terminais, preview e transação

Arquivos: `ameno_dimension_terminal_mesh.ms`, `ameno_dimension_graphics.ms`, preview renderer, input/picking E12 e testes.

- [x] Buscar todos os consumidores de updateTerminal. `b2` agora é simétrico/oposto a `b1`; tamanho, tipo e normal vêm de parâmetro/metadado estável, nunca de aresta diagonal acumulada.
- [x] Testar área não nula, simetria e tamanho após várias atualizações; criação/atualização/remoção de `arrowClosed`, `diamond` e `dot`.
- [x] Derivar orientação do plano suportado pelo layout; a normal é persistida no layout/terminal e direções paralelas ao plano são rejeitadas claramente.
- [x] Conferir material, layer, `DimensionId`, `GraphicRole` e marca terminal; rebuild/delete/rollback removem todos os nós técnicos, inclusive alocações parciais.
- [x] Conferir `updateDimensionFast`/serviço de âncoras: meshes acompanham linha e texto após movimento e alteração de estilo.
- [x] Implementar paridade de terminal no preview pertinente: hover/posicionamento/editor mantêm o escopo E12 de marcadores de referência sem reintroduzir preview de segmentos.
- [x] Falha ao criar terminal obrigatório propaga para a transação E12; alocações parciais são removidas e a cota incompleta não é publicada.
- [x] Injetar falha no segundo segmento com terminais; zero resíduos, draft preservado, Undo não suspenso; criação posterior e Ctrl+Z/Y passaram.
- [x] Testar snap sobre mesh técnico coincidente com vértice real, persistência save/load, rebuild e troca de terminal spline/mesh.

OK: cadeia e nós técnicos permanecem íntegros em sucesso, falha e reconstrução.

### Evidências da etapa 5 em 2026-09-06

- Arquivos funcionais: `ameno_dimension_terminal_mesh.ms`, `ameno_dimension_graphics.ms`, `ameno_dimensions_math.ms`, `ameno_anchor_service.ms`, `ameno_preview_renderer.ms`, `ameno_style_editor.ms`, `ameno_style_editor_wpf.ms` e `ameno_runtime.ms`. Teste dedicado: `tests/maxscript/test_e13_stage5_terminals.ms`.
- `test_e13_stage5_terminals.ms`: Batch exit 0; 40 verificações internas, 41 marcadores `[AMENO_TEST][PASS]` contando o resumo final e 0 `[AMENO_TEST][FAIL]`.
- Commit funcional: `d79211a` (`feat: complete E13 terminal and render workflows`).
- Evidências: `D:\Ameno\_worktrees\develop\.test-output\stage5-6-evidence\stage5-listener.log` e `D:\Ameno\_worktrees\develop\.test-output\stage7-evidence\e13-final\test_e13_stage5_terminals-listener.log`.
- A suíte cobre setas/losango/ponto, normais de plano, metadados/layers, atualização rápida, preview, rollback no segundo segmento, draft/Undo/Redo, snap, save/load e rebuild. Batch não substitui a inspeção visual interativa.

## 8. Etapa 6 — Render e restauração

Arquivos: `ameno_cotas_render_tab.ms`, serviço render existente e adapters apenas se necessário.

- [x] Preferir câmera explícita no pedido; a aba não troca a viewport para renderizar e o serviço/adapters encaminham `cameraNode` diretamente.
- [x] Restaurar em sucesso, cancelamento e exceção antes de anunciar cena restaurada; falha de restauração/verificação é reportada, não escondida.
- [x] Preservar caminho, câmera e escopo ao alternar abas; manter seleção válida e rejeitar câmera removida.
- [x] Validar saída PNG, caminho inexistente, proteção contra sobrescrita, escopo sem cotas, cancelamento e renderer não suportado com adapter de teste.
- [x] Conferir nós mesh no isolamento/material/alpha e preservar o contrato de elementos existentes; caso real Corona confirmou PNG transparente somente de cotas.
- [x] Cobrir o pedido explícito de câmera partindo de uma cena descartável; o teste real E9 foi ajustado para não depender da viewport ativa.
- [ ] Render real V-Ray CPU e GPU: o adapter/contrato V-Ray passou na regressão E10.3, mas não foi executado um render V-Ray CPU real nesta rodada; GPU continua experimental.

### Evidências da etapa 6 em 2026-09-06

- Arquivos funcionais: `ameno_cotas_render_tab.ms`, `ameno_render_cotas_service.ms`, `ameno_corona_adapter.ms`, `ameno_vray_adapter.ms`, `ameno_runtime.ms` e `tests/maxscript/test_e9_corona_render.ms`.
- `test_e13_stage6_render_restore.ms`: Batch exit 0; 19 verificações internas, 20 marcadores `[AMENO_TEST][PASS]` contando o resumo final e 0 `[AMENO_TEST][FAIL]`.
- `test_e9_corona_render.ms`: Batch exit 0; Corona 13 real ativo, 1 marcador PASS e 0 FAIL; PNG transparente gerado e removido pela rotina descartável.
- Evidências: `D:\Ameno\_worktrees\develop\.test-output\stage5-6-evidence\stage6-listener.log`, `D:\Ameno\_worktrees\develop\.test-output\stage7-evidence\e13-final\test_e13_stage6_render_restore-listener.log` e `D:\Ameno\_worktrees\develop\.test-output\stage7-evidence\regression\test_e9_corona_render-listener.log`.

## 9. Etapa 7 — Candidato e entrega

- [x] Reexecutar conjunto combinado após alterações finais: pacote/bootstrap; E12 input/math/commit/continuous/R0–R4; E13 A–H/audit_fixes; testes novos de integração; E10/E11 impactados e persistência. Todos os processos válidos terminaram com exit 0 e zero FAIL.
- [x] Registrar código exato testado e contagens. A matriz final está nos handoffs e nos logs identificados por suíte.
- [x] Gerar candidato e manifesto SHA-256. `dist\AmenoTools-0.0.1-e13-candidate.zip`, 136888 bytes, SHA-256 `4077049B1858E9CBB3944DF69DB1B7A6CB500C037AD9CA5FFE3F102F8E6A67CA`; manifesto em `plans/2026-09-06-e13-candidate-manifest.sha256`. Não houve instalação.
- [x] Confirmar Max fechado antes de instalar. Instalação do candidato autorizada e realizada em 2026-09-06: 42/42 arquivos idênticos por SHA-256; teste instalado exit 0, 1 PASS, 0 FAIL. Backup `D:\Ameno\backups\AmenoTools-before-e13-20260906-120546`. Isso não abrange as correções posteriores do feedback visual.
- [ ] Executar gates manuais 2–6 em cena de teste e fechar/reabrir painel/cena. Solicitar ao usuário apenas os passos concretos que exigem interação.
- [ ] Registrar aprovação do usuário e limitações por renderer/vista. Não inventar aprovação visual a partir de Batch.
- [x] Atualizar `PLAN.md` e os handoffs, mantendo `f131f08` como referência histórica da E12 publicada.
- [x] Commitar somente arquivos relevantes e conferir diff/status local. Merge/push/publicação seguem bloqueados sem autorização explícita.
- [x] Manter branch E13 e worktrees existentes; nenhuma limpeza destrutiva foi feita.

### Evidências da etapa 7 em 2026-09-06

- E13 final: 14 suítes, exit 0 e 0 FAIL; `test_e13_audit_fixes` 8 PASS, E13-A…H 8 suítes/57 PASS, etapa 2 21 PASS, etapa 3 25 PASS, etapa 4 45 PASS, etapa 5 41 PASS e etapa 6 20 PASS — total 217 marcadores PASS.
- E10 impactado: bootstrap 1 PASS; E10.1 28 PASS; E10.2 11 PASS; E10.3 18 PASS; E10.4 20 PASS; E10.5 21 PASS; E10.7 33 PASS; 0 FAIL. E10.1/E10.2 tiveram erro de sintaxe de teste descoberto no pente-fino, corrigido e reexecutado com exit 0.
- E11: E11.0 2 PASS, E11.1 49, E11.2 44, E11.3 21, E11.4 37 e E11.5 21; todos exit 0/0 FAIL.
- E12: chain commit 49, input 22, math 30, continuous 44, R0 17, R1 55, R2 34, R3 29 e R4 22; todos exit 0/0 FAIL.
- Render: Corona real 1 PASS/0 FAIL; adapter V-Ray validado por E10.3, sem render V-Ray real nesta rodada.
- Evidências serializadas em `D:\Ameno\_worktrees\develop\.test-output\stage7-evidence\regression\` e `D:\Ameno\_worktrees\develop\.test-output\stage7-evidence\e13-final\`. O runner exige exit 0, ao menos um marcador PASS e zero FAIL.
- Candidato estrutural: `tools/validate-package.ps1` passou e `tools/package-alpha.ps1 -Version 0.0.1-e13-candidate -OutputDir dist` gerou o ZIP e o manifesto.
- Commit funcional: `d79211a` (`feat: complete E13 terminal and render workflows`); a atualização documental deste roteiro e dos handoffs será o commit seguinte.

## 10. Execução dos testes: cuidados descobertos

Antes da etapa 1, o runner `tools/test-maxscript.ps1` aceitava qualquer ocorrência de `[AMENO_TEST][PASS]` e não rejeitava explicitamente `[AMENO_TEST][FAIL]`. Isso foi corrigido: agora exige exit code 0, pelo menos um PASS e zero FAIL; a reexecução em `develop` confirmou esse comportamento. O pente-fino também corrigiu E10.1/E10.2, que tinham `local` no topo do script e não emitiam os marcadores exigidos.

Interface real do runner: `-MaxBatchPath`, `-ConfigPath`, `-TestScript`. Usar scripts e config do worktree `develop`. Não inventar switches. O runner sobrescreve `.test-output/listener.log` e `system.log`: executar suítes sequencialmente por worktree e copiar logs após cada uma para diretório identificado por etapa/suíte. Não usar logs antigos como evidência de execução atual. Conferir o INI para garantir isolamento; não publicar mutações geradas pelo Max sem revisão.

## 11. Modelo de handoff a preencher

```text
Etapa: N / título
Estado: PENDENTE | EM IMPLEMENTAÇÃO | IMPLEMENTADA/TESTADA | AGUARDA MANUAL | OK
Branch/worktree:
Base e HEAD atual:
Arquivos alterados:
Problema e comportamento final:
Testes executados / contagens / logs:
Não testado e motivo:
Instalação ativa / backup / hashes:
Aprovação manual (fala/data; ou PENDENTE):
Commit (ou alterações não commitadas):
Próximo passo exato:
```

### Feedback manual posterior à instalação — 2026-09-06

- [x] Registrar as duas capturas: ComboBox branco com texto branco e texto horizontal cruzando cotas verticais.
- [x] Implementar botão de aplicação a todas as cotas, mantendo aplicação às selecionadas.
- [x] Pedir nome ao criar/salvar estilo; cancelar não salva e nome vazio não é aceito.
- [x] Compartilhar o template escuro de ComboBox entre as abas.
- [x] Adicionar opção de texto acompanhando a linha, persistida por cota e preservada na reconstrução. Cotas antigas sem a propriedade mantêm orientação horizontal.
- [x] Reexecutar testes após correção do Nullable Boolean: feedback visual 18 PASS, Criar 21 PASS, Estilos 25 PASS; todos exit 0 e zero FAIL. Pacote estrutural válido; novo ZIP `AmenoTools-0.0.1-e13-feedback1.zip` conferido com 44/44 arquivos idênticos. Logs e hash no handoff do feedback.
- [x] Instalar esta atualização com Max fechado; repetir conferência de hashes e teste instalado. Commit `20d618f`, 42/42 hashes conferidos, teste instalado exit 0 / 1 PASS / 0 FAIL; logs em `.test-output/visual-feedback/`.
- [ ] Validar visualmente dropdowns/diálogo e orientação no viewport com o usuário. Batch não substitui este gate.

Continuidade: `plans/2026-09-06-e13-feedback-visual-handoff.md`. A instalação foi autorizada, mas aguarda fechamento do Max para atualizar. Não fechar a sessão do usuário, não executar testes destrutivos nela e não publicar/merge/push sem autorização.
