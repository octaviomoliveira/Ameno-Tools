# E13 — handoff da etapa 2

Data: 2026-09-06 (America/Fortaleza)
Estado: IMPLEMENTADA/TESTADA em `develop`; gate manual pendente; etapa 3 não iniciada.

## Base e escopo

- Worktree: `D:\Ameno\_worktrees\develop`.
- Branch: `develop`.
- Base anterior: `dd4ba7a` (`docs: record E13 stage 1 commit`).
- Commit desta etapa: `ae694a6` (`feat: integrate E13 stage 2 create workflow`).
- E12/E13 integradas continuam fora da `main`; nenhum merge, push ou publicação foi feito.
- Nenhuma instalação em `ApplicationPlugins` foi feita e nenhuma cena interativa do usuário foi alterada.

## Implementação entregue

- `Contents/scripts/ameno/ui/ameno_cotas_criar_tab.ms`
  - remove o TODO de `onCotaContinua`;
  - botão WPF, macro e runtime usam `executeContinuousCommand()`;
  - modo, estilo, unidade e precisão escrevem os campos existentes de `AmenoDimensionTool` e `AmenoDimensionContinuousTool`;
  - `syncFromServices()` elimina defaults visuais conflitantes e replica a configuração somente em repouso;
  - alterações são rejeitadas durante ferramenta ativa, sem alterar `session*` congelado da E12;
  - alinhada individual continua disponível e cadeia contínua alinhada continua rejeitada pelo contrato E12;
  - contagem é atualizada por caminho estreito, sem chamar o refresh global que pode recriar rascunhos.
- `Contents/scripts/ameno/core/ameno_runtime.ms`
  - oculta a janela WPF antes de `startTool`, restaura no retorno normal e em exceção, atualiza cena/contagem e preserva o retorno/erro.
- `Contents/scripts/ameno/ui/ameno_cotas_window.ms`
  - adiciona suspend/resume de foco;
  - considera uma janela escondida como não aberta para a UI;
  - registra callbacks de criação/remoção limitados à aba Criar e os remove no fechamento.
- `Contents/macroscripts/AmenoTools.mcr`
  - macros individual e contínua usam os comandos da aba quando disponíveis, com fallback ao runtime legado.
- `tests/maxscript/test_e13_stage2_create.ms`
  - cobre comportamento, não apenas presença de funções: botão WPF, macro, sincronização, congelamento, rejeição de modo, foco/runtime e contagem.

## Evidências

| Teste | Resultado |
|---|---|
| `tools/validate-package.ps1` | PASS — pacote válido para 3ds Max 2026 |
| `test_e13_stage2_create.ms` | Batch exit 0; 20 verificações internas; 21 marcadores PASS contando o resumo; 0 FAIL |
| `test_bootstrap.ms` | 1 PASS; 0 FAIL |
| E13-A…H | 8/8 suítes; 57 PASS agregados; 0 FAIL; E13-H repetido após o ajuste final |
| E12 chain commit/input/math/continuous/R0/R1/R2/R3/R4 | 9/9 suítes; 9 PASS; 0 FAIL |

Logs listener/system identificados por suíte:

`D:\Ameno\_worktrees\develop\.test-output\stage2-evidence-develop\`

O runner `tools/test-maxscript.ps1` foi usado com exit code obrigatório, pelo menos um PASS e zero marcadores `[AMENO_TEST][FAIL]`/`[AMENO_INSTALLED_TEST][FAIL]`.

## Pendências e limites

- O gate manual ainda está pendente: criar cadeia H com quatro vértices, finalizar com clique vazio, criar V reutilizando o vértice direito, verificar losangos, Esc/botão direito, Ctrl+Z/Ctrl+Y e ausência de duplicação pelo botão e pela macro.
- A suíte testa o ciclo hide/show do runtime com fakes e os contratos E12 em Batch; não substitui a validação de foco e Undo/Redo no 3ds Max interativo.
- Não avançar para a etapa 3 sem nova autorização explícita. A instalação/publicação continua bloqueada.

## Próximo passo

Executar o gate manual desta etapa no candidato final quando autorizado; depois, em uma solicitação separada, iniciar a etapa 3 (estilos, navegação e preservação de rascunho).
