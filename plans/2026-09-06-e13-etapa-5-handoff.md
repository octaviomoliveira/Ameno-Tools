# E13 — handoff da etapa 5: terminais, preview e transação

Data: 2026-09-06 (America/Fortaleza)
Estado: IMPLEMENTADA/TESTADA em `develop`; aguarda gate manual.

## Base e implementação

- Worktree: `D:\Ameno\_worktrees\develop`.
- Branch: `develop`.
- Base documental/funcional anterior: `9ae60a9`.
- Commit funcional: `d79211a` (`feat: complete E13 terminal and render workflows`).
- A E12 publicada continua referenciada por `f131f08`; nenhuma alteração foi feita na `main`.

## Problemas tratados

- Terminais mesh não acumulam tamanho pela diagonal e `b2` do `arrowClosed` é simétrico a `b1`.
- `arrowClosed`, `diamond` e `dot` persistem tipo, tamanho, normal de plano, material, layer, `DimensionId`, `GraphicRole` e marca técnica.
- A orientação usa a normal do layout; direções incompatíveis são rejeitadas explicitamente.
- Criação, atualização, rebuild, preview, delete e rollback mantêm o par de terminais íntegro; falha no segundo segmento propaga para a transação E12 e limpa alocações parciais.
- `updateDimensionFast` sincroniza meshes com linha/texto; o preview recebe apenas a paridade pertinente de terminais.
- Meshes técnicas ficam inelegíveis para snap quando há um vértice real coincidente.

## Testes e evidências

- `test_e13_stage5_terminals.ms`: Batch exit 0; 40 verificações internas, 41 marcadores `[AMENO_TEST][PASS]` e 0 `[AMENO_TEST][FAIL]`.
- Cobertura: topologia/área/simetria/tamanho, tipos arrow/losango/ponto, normal de plano, metadados/layers, atualização rápida, preview, rollback no segundo segmento, draft/Undo/Redo, snap, save/load, rebuild e troca spline/mesh.
- Logs: `D:\Ameno\_worktrees\develop\.test-output\stage5-6-evidence\stage5-listener.log` e `D:\Ameno\_worktrees\develop\.test-output\stage7-evidence\e13-final\test_e13_stage5_terminals-listener.log`.
- A matriz E11/E12/E13 final e o pacote candidato também passaram; detalhes consolidados no handoff da etapa 7.

## Não testado / limites

- A inspeção visual no Max interativo, incluindo navegação WPF, hover e leitura visual dos terminais em cenas reais, continua pendente.
- Não houve instalação em `ApplicationPlugins`, publicação, push, merge ou teste destrutivo na cena do usuário.

## Instalação, aprovação e próximo passo

- Instalação ativa: não tocada nesta execução; não existe hash de pacote instalado E13 a registrar.
- Candidato separado: `dist\AmenoTools-0.0.1-e13-candidate.zip`, SHA-256 no manifesto `plans\2026-09-06-e13-candidate-manifest.sha256`.
- Aprovação manual: PENDENTE.
- Próximo passo exato: executar os gates manuais 2–6 na cena descartável/interativa quando o usuário autorizar; não publicar automaticamente.
