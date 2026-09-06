# E13 — handoff da etapa 6: render e restauração

Data: 2026-09-06 (America/Fortaleza)
Estado: IMPLEMENTADA/TESTADA em `develop`; aguarda gate manual e validação V-Ray CPU real.

## Base e implementação

- Worktree: `D:\Ameno\_worktrees\develop`.
- Branch: `develop`.
- Base documental/funcional anterior: `9ae60a9`.
- Commit funcional: `d79211a` (`feat: complete E13 terminal and render workflows`).
- A E12 publicada continua referenciada por `f131f08`; nenhuma alteração foi feita na `main`.

## Problemas tratados

- A câmera selecionada é passada explicitamente no pedido de render; a aba não troca a viewport do usuário.
- A seleção é preservada ao atualizar a lista e câmera removida é rejeitada claramente.
- Isolamento, material, layer, alpha, caminho, renderer e estado da cena/adapters são restaurados em sucesso, cancelamento e exceção.
- Falha de restauração ou verificação do PNG é reportada, sem anunciar cena restaurada indevidamente.
- A verificação de render cobre escopo, sobrescrita, caminho inexistente, cancelamento, renderer não suportado e PNG transparente.

## Testes e evidências

- `test_e13_stage6_render_restore.ms`: Batch exit 0; 19 verificações internas, 20 marcadores `[AMENO_TEST][PASS]` e 0 `[AMENO_TEST][FAIL]` usando adapters simulados.
- `test_e9_corona_render.ms`: Batch exit 0 com Corona 13 real; 1 marcador PASS e 0 FAIL; o pedido usa câmera explícita e não depende da viewport.
- E10.3 validou o adapter/contrato V-Ray CPU com 18 PASS; render V-Ray CPU real não foi executado nesta rodada.
- Logs: `D:\Ameno\_worktrees\develop\.test-output\stage5-6-evidence\stage6-listener.log`, `D:\Ameno\_worktrees\develop\.test-output\stage7-evidence\e13-final\test_e13_stage6_render_restore-listener.log` e `D:\Ameno\_worktrees\develop\.test-output\stage7-evidence\regression\test_e9_corona_render-listener.log`.

## Não testado / limites

- Gate visual partindo de perspectiva livre no Max interativo, fechamento/reabertura do painel/cena e render V-Ray CPU real permanecem pendentes.
- GPU continua experimental e não foi testada.
- Não houve instalação em `ApplicationPlugins`, publicação, push, merge ou teste destrutivo na cena do usuário.

## Instalação, aprovação e próximo passo

- Instalação ativa: não tocada nesta execução; não existe hash de pacote instalado E13 a registrar.
- Candidato separado: `dist\AmenoTools-0.0.1-e13-candidate.zip`, SHA-256 no manifesto `plans\2026-09-06-e13-candidate-manifest.sha256`.
- Aprovação manual: PENDENTE.
- Próximo passo exato: executar os gates manuais 2–6 e, se necessário, o render V-Ray CPU real em cena descartável; não publicar automaticamente.
