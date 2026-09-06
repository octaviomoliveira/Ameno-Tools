# E13 — handoff da etapa 1

Data: 2026-09-06 00:25 (America/Fortaleza)
Estado: PENDENTE — base integrada e smoke tests passam, mas a regressão E12-R0 continua falhando no baseline.

## Escopo executado

- Base: main local e origin/main em f131f089af03892f33a9c86e2df8d3e3288d75a9.
- Fonte: feature/e13-unified-ui em 676e008c200c91478242630defef4f607d671452.
- Branch/worktree: integration/e13-on-e12 em D:\Ameno\_worktrees\e13-integration.
- A tentativa de git fetch origin --prune falhou com SEC_E_NO_CREDENTIALS; os refs locais foram conferidos e coincidiam com os hashes auditados.
- A E13 foi mesclada no worktree isolado sobre a main. Não houve merge, push ou publicação na main.
- PLAN.md, este runbook e a alteração preexistente de tests/maxscript/batch-isolated.ini foram preservados e transportados para a integração.
- Nenhuma instalação foi feita em ApplicationPlugins; a instalação existente foi apenas inspecionada.

## Resolução/revisão

- ameno_dimension_graphics.ms: E12 allocation registry/rollback/useUndo/transação externa preservados; terminais mesh, campos termNodeA/B e style:style integrados. Terminais novos entram no registro de rollback.
- ameno_dimension_tool.ms: picking/resolução E12 preservados; exclusão de mesh técnico usa AMENO_TERMINAL, metadados Ameno.*, CA/IDs e o resolver contínuo. Nome AMENO não é o único critério.
- ameno_main_panel.ms: stub WPF E13 adotado, com globals e entry points legados mantidos para compatibilidade.
- Auto-merges revisados: runtime mantém startContinuousDimensionTool, lifecycle e fecha WPF; bootstrap carrega math/input/diagnostics/continuous E12 e ameno_dimension_terminal_mesh.ms antes dos consumidores; test_bootstrap.ms mantém E12 e valida terminais E13.
- Não restam marcadores de conflito; git diff --check passou.

## Testes e evidências

| Verificação | Resultado |
|---|---|
| tools/validate-package.ps1 | PASS |
| test_bootstrap.ms | exit 0; PASS=1; FAIL=0 |
| test_e13_audit_fixes.ms | exit 0; 7 PASS; 0 FAIL |
| E13-A…H | 8/8 suítes; 57 PASS agregados; 0 FAIL |
| E12 chain/input/math/continuous/R1/R2/R3/R4 | 8/8 passaram |
| E12-R0 | PENDENTE; 3 falhas comportamentais |

O runner em tools/test-maxscript.ps1 foi corrigido para exigir exit code 0, pelo menos um marcador PASS e zero marcadores PASS/FAIL de falha. Ele gera configuração por worktree e isola PlugCFG, MaxData, Temp, Additional Macros e LOCALAPPDATA.

Logs identificados por suíte (listener, system e config gerada):

D:\Ameno\_worktrees\e13-integration\.test-output\stage1-evidence\

## Pendência bloqueadora

test_e12_r0_diagnostics.ms falha com:

- instrumentation preserves reference outcome: esperado #referenceAdded, obtido #duplicateStation;
- instrumentation preserves draft: esperado 1, obtido 0;
- log records unchanged outcome: esperado verdadeiro, obtido falso.

A mesma reprodução ocorreu usando a suíte da própria main em f131f08. A causa está no comportamento baseline de hasConflictingStation quando o modo é #aligned; nenhuma expectativa foi alterada e nenhum ajuste E12 foi feito para mascarar a falha. A falha inicial de escrita do log em LOCALAPPDATA foi separada e resolvida pelo isolamento do runner.

Também não foi executado gate manual ou teste destrutivo na cena interativa. A instância interativa aberta permaneceu intocada.

## Commit e próximo passo

- Commit da integração: será preenchido após a criação deste handoff e o commit local do worktree; permanece fora da main.
- Alterações pendentes no momento deste registro: documentação, runner, INI preservado e conteúdo integrado ainda precisam ser staged/commitados no branch de integração.
- Próximo passo: decidir/corrigir explicitamente o R0 baseline, repetir a bateria da etapa 1 e só então decidir se a etapa 1 pode ser marcada OK. Não avançar para a etapa 2, não instalar e não publicar.
