# E13 — handoff da etapa 1

Data: 2026-09-06 (America/Fortaleza)
Estado: OK — etapa 1 validada em `develop`; sem instalação/publicação e sem avanço para as etapas seguintes.

## Escopo executado

- Base: main local e origin/main em f131f089af03892f33a9c86e2df8d3e3288d75a9.
- Fonte: feature/e13-unified-ui em 676e008c200c91478242630defef4f607d671452.
- Branch/worktree original: integration/e13-on-e12 em D:\Ameno\_worktrees\e13-integration.
- Continuidade atual: branch `develop` em D:\Ameno\_worktrees\develop, criada a partir de `d5aa9cc`; as correções finais desta etapa estão no working tree antes do commit de encerramento.
- A tentativa de git fetch origin --prune falhou com SEC_E_NO_CREDENTIALS; os refs locais foram conferidos e coincidiam com os hashes auditados.
- A E13 foi mesclada no worktree isolado sobre a main. Não houve merge, push ou publicação na main.
- PLAN.md, este runbook e a alteração preexistente de tests/maxscript/batch-isolated.ini foram preservados e transportados para a integração.
- Nenhuma instalação foi feita em ApplicationPlugins; a instalação existente foi apenas inspecionada.

## Resolução/revisão

- ameno_dimension_graphics.ms: E12 allocation registry/rollback/useUndo/transação externa preservados; terminais mesh, campos termNodeA/B e style:style integrados. Terminais novos entram no registro de rollback.
- ameno_dimension_tool.ms: picking/resolução E12 preservados; exclusão de mesh técnico usa AMENO_TERMINAL, metadados Ameno.*, CA/IDs e o resolver contínuo. Nome AMENO não é o único critério.
- ameno_main_panel.ms: stub WPF E13 adotado, com globals e entry points legados mantidos para compatibilidade.
- Auto-merges revisados: runtime mantém o lifecycle e fecha WPF; bootstrap carrega math/input/diagnostics/continuous E12 e ameno_dimension_terminal_mesh.ms antes dos consumidores; test_bootstrap.ms mantém E12 e valida terminais E13. O guard/fallback da macro foi preservado, e `AmenoRuntime.startContinuousDimensionTool` agora oferece o wrapper mínimo consumido pelo entry point público.
- Compatibilidade final: o wrapper chama `AmenoDimensionContinuousTool.start()` e atualiza os resumos do runtime; `test_e13_audit_fixes.ms` passou o Teste 0 de presença de `AmenoApp.startContinuousDimensionTool`. A execução interativa da ferramenta não foi feita, pois pertence à etapa 2.
- Não restam marcadores de conflito; git diff --check passou.
- A etapa 1 foi reexecutada em `develop`; a árvore continuou sem conflitos e a bateria final passou após o wrapper e o ajuste do fixture R0.

## Testes e evidências

| Verificação | Resultado |
|---|---|
| tools/validate-package.ps1 | PASS |
| test_bootstrap.ms | exit 0; PASS=1; FAIL=0 |
| test_e13_audit_fixes.ms | exit 0; 8 PASS; 0 FAIL |
| E13-A…H | 8/8 suítes; 57 PASS agregados; 0 FAIL |
| E12 chain/input/math/continuous/R0/R1/R2/R3/R4 | 9/9 passaram; 9 PASS; 0 FAIL |

Reexecução final em `develop` em 2026-09-06: pacote validado com sucesso; bootstrap exit 0 com 1 PASS/0 FAIL; auditoria E13 com 8 PASS/0 FAIL; E13-A…H com 8/8 suítes, 57 PASS agregados/0 FAIL; E12 com 9/9 suítes, 9 PASS/0 FAIL. O R0 passou depois de o fixture declarar explicitamente `#horizontal`, modo aceito pela cadeia; o modo original é restaurado no cancelamento. A chamada interativa do wrapper não foi executada nesta etapa.

O runner em tools/test-maxscript.ps1 foi corrigido para exigir exit code 0, pelo menos um marcador PASS e zero marcadores PASS/FAIL de falha. Ele gera configuração por worktree e isola PlugCFG, MaxData, Temp, Additional Macros e LOCALAPPDATA.

Logs identificados por suíte (listener, system e config gerada):

D:\Ameno\_worktrees\e13-integration\.test-output\stage1-evidence\
D:\Ameno\_worktrees\develop\.test-output\stage1-evidence-develop\

## Limites e pendências fora da etapa 1

- Não foi executado gate manual nem teste destrutivo na cena interativa; a instância interativa aberta permaneceu intocada. Isso é esperado para a etapa 1 e fica para os gates das etapas posteriores.
- Não foi feita instalação em `ApplicationPlugins`, publicação, push ou merge na `main`. A instalação existente foi somente inspecionada.
- As etapas 2–7 continuam pendentes. Em especial, o wrapper foi validado estruturalmente, mas o ciclo interativo do botão/macro e os comportamentos de criação, estilo, edição, terminais e render ainda não foram executados.

## Commit e próximo passo

- Commit da integração: d1e9e22f379a52ad5933cbea01a696e33d5d63bf (merge commit com pais f131f08 e 676e008); permanece fora da main.
- A situação foi transferida para `develop` em `d5aa9cc`; o wrapper, o fixture R0, o teste de auditoria e a atualização documental estão registrados no commit `3daba25` (`fix: close E13 stage 1 compatibility gates`).
- Próximo passo: aguardar solicitação/autorização explícita para a etapa 2. Não instalar, não publicar, não fazer merge na `main` e não avançar automaticamente.
