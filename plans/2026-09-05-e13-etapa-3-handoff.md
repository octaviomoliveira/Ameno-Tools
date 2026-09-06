# E13 — handoff da etapa 3: estilos, navegação e ciclo de cena

Data: 2026-09-06 (America/Fortaleza)
Estado: IMPLEMENTADA/TESTADA em `develop`; aguarda gate manual; etapa 4 não iniciada.

## Base e escopo

- Worktree: `D:\Ameno\_worktrees\develop`.
- Branch: `develop`.
- Base anterior: `a544d23` (`docs: record E13 stage 2 handoff`).
- Commit funcional: `1fe7039` (`feat: complete E13 stage 3 styles workflow`).
- A base continua contendo E12 aprovada e E13 integrada; os commits locais ainda não foram mesclados/publicados na `main`.
- Nenhuma instalação em `ApplicationPlugins`, push, publicação ou alteração na cena interativa do usuário foi feita.

## Problema tratado

A visita à aba Estilos reconstruía o `currentDraft` a partir do estilo `default`. A navegação para outra aba, o refresh global e a reabertura do painel podiam apagar alterações sem salvar ou reaplicar dados da cena anterior.

## Implementação entregue

- `Contents/scripts/ameno/ui/ameno_cotas_estilos_tab.ms`
  - mantém host WPF, modelo do rascunho e geração da cena em estado controlado;
  - `build()` reutiliza host/rascunho e `refresh()` não substitui um rascunho editado;
  - separa refresh genérico de troca explícita por `requestStyleSwitch()`;
  - aplica o contrato salvar/descartar/cancelar em troca, novo estilo, preset, exclusão e fechamento;
  - invalida o rascunho ao reset/abertura de cena e recarrega o serviço da cena atual;
  - preserva salvar, duplicar, presets, aplicar à seleção e bloqueio de exclusão de estilo em uso;
  - registra e remove somente o callback próprio `#amenoCotasStyleSelection`.
- `Contents/scripts/ameno/ui/ameno_cotas_window.ms`
  - reutiliza a aba em navegação, atualiza sem recriar o draft e intercepta o fechamento para resolver rascunho sujo;
  - limpa eventos/callbacks próprios na reabertura/fechamento e mantém o singleton coerente.
- `Contents/scripts/ameno/ui/ameno_main_panel.ms`
  - o refresh do painel chama o refresh da aba de estilos, sem recriar o estilo default.
- `Contents/scripts/ameno/ui/ameno_style_editor_wpf.ms`
  - o stub legado encaminha estilo explícito para a troca controlada da aba unificada.
- `Contents/scripts/ameno/core/ameno_runtime.ms`
  - `onSceneOpened/onSceneReset` invalidam o estado da aba após carregar a nova cena, antes do refresh global.
- `tests/maxscript/test_e13_stage3_styles.ms`
  - cobre navegação com rascunho alterado, refresh, salvar/descartar/cancelar, presets, duplicação, fechamento/reabertura, callback sentinela, troca de cena, persistência, estilo em uso, aplicação e Undo/Redo.

## Evidências

| Teste | Resultado |
|---|---|
| `tools/validate-package.ps1` | PASS — pacote válido para 3ds Max 2026 |
| `test_e13_stage3_styles.ms` | Batch exit 0; 24 verificações internas; 25 marcadores PASS contando o resumo; 0 FAIL |
| `test_bootstrap.ms` | 1 PASS; 0 FAIL |
| `test_e13_audit_fixes.ms` | 8 PASS; 0 FAIL |
| E13-A…H | 8/8 suítes; 57 PASS agregados; 0 FAIL |
| Regressões E11.1–E11.5 | Todas passaram em Batch isolado |
| E12 chain commit/input/math/continuous/R0/R1/R2/R3/R4 | 9/9 suítes; 9 PASS finais; 0 FAIL |
| `git diff --check` | sem erros de whitespace; somente avisos de conversão LF/CRLF do ambiente |

O runner `tools/test-maxscript.ps1` foi verificado com exit code obrigatório, pelo menos um marcador PASS e zero marcadores `[AMENO_TEST][FAIL]`/`[AMENO_INSTALLED_TEST][FAIL]`, evitando o falso sucesso PASS+FAIL.

Logs listener/system identificados por suíte:

`D:\Ameno\_worktrees\develop\.test-output\stage3-evidence-develop\`

Os artefatos finais principais são `stage3-dedicated-final.listener.log`, `stage3-dedicated-final.system.log` e os pares `e12-*-final.listener.log`/`e12-*-final.system.log`.

## Pendências e limites

- O gate manual continua pendente: abrir o painel no 3ds Max interativo, alterar estilo, navegar entre abas, confirmar que o rascunho e o indicador dirty permanecem, testar salvar/descartar/cancelar, trocar/abrir cena e confirmar que dados da cena anterior não reaparecem.
- Batch verifica os contratos e o ciclo de estado, mas não comprova aprovação visual, foco, modal WPF ou comportamento na cena real do usuário.
- A etapa 4 (editar e reancorar) não foi iniciada. Não instalar nem publicar sem autorização explícita.

## Próximo passo

Executar o gate manual da etapa 3 no candidato em `develop`, quando autorizado. Somente depois de esse gate ser aceito, iniciar a etapa 4 em solicitação separada.
