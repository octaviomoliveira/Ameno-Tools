# E13 — handoff da etapa 4: editar, validar e reancorar

Data: 2026-09-06 (America/Fortaleza)
Estado: IMPLEMENTADA/TESTADA em `develop`; aguarda gates manuais das etapas 3 e 4; etapa 5 não iniciada.

## Base e escopo

- Worktree: `D:\Ameno\_worktrees\develop`.
- Branch: `develop`.
- Base antes da etapa: `6400020` (`docs: record E13 stage 3 handoff`).
- Commit funcional: `95a0ee0` (`feat: complete E13 stage 4 edit and reanchor workflow`).
- A base continua contendo E12 aprovada e E13 integrada; nada foi mesclado ou publicado na `main`.
- Nenhuma instalação em `ApplicationPlugins`, push ou alteração na cena interativa do usuário foi feita.

## Problemas tratados

A aba Editar usava defaults silenciosos de `50 mm`/`1000 mm` quando os campos estavam vazios ou inválidos, podia gerar Undo mesmo sem uma alteração válida, não tinha sincronização própria para seleção/Undo/Redo e permitia que o cancelamento do pick acabasse convertendo a âncora para mundial. A chamada de reancoragem também não recebia de forma explícita o `vertexId` resolvido pelo picking E12.

## Implementação entregue

- `Contents/scripts/ameno/ui/ameno_cotas_editar_tab.ms`
  - valida somente o campo pertencente ao modo selecionado;
  - trata vazio, letras, notação científica, vírgula/ponto decimal, zero e negativos com mensagens no painel;
  - converte os campos rotulados em centímetros/metros para milímetros canônicos antes de chamar o serviço;
  - preserva medição, auditoria, override, motivo e unidade; restaura o valor medido por comando separado;
  - registra callbacks próprios de seleção, `sceneUndo` e `sceneRedo`, protegidos contra recursão e removidos no fechamento;
  - filtra geometrias elegíveis, rejeita textos/terminais/gráficos técnicos e rejeita alvo ausente/cancelado sem mutar a âncora;
  - encaminha `vertexId` explícito e mantém seleção múltipla, órfãs, estilo e aplicação com Undo/Redo cobertos.
- `Contents/scripts/ameno/core/ameno_anchor_service.ms`
  - aceita `anchorVertexId` opcional, resolve o vértice avaliado, conserva ponto mundial/local e grava o ID correto em A/B;
  - valida controlador, ponto, nó e vértice antes de abrir o Undo.
- `Contents/scripts/ameno/core/ameno_runtime.ms`
  - encaminha o novo argumento opcional ao serviço de âncoras sem quebrar chamadas legadas.
- `Contents/scripts/ameno/ui/ameno_cotas_window.ms`
  - transfere registro/limpeza dos callbacks da aba Editar para o ciclo de vida da própria aba e limpa seu host no fechamento.
- `tests/maxscript/test_e13_stage4_edit_reanchor.ms`
  - suíte comportamental em cena descartável Batch; inclui teste de entrada inválida sem mutação/Undo vazio, edição, Undo/Redo, estilos, seleção, reancoragem, vertexId, movimento/exclusão/restauração e callback sentinela.

## Evidências

| Teste | Resultado |
|---|---|
| `tools/validate-package.ps1` | PASS — pacote válido para 3ds Max 2026 |
| `test_e13_stage4_edit_reanchor.ms` | Batch exit 0; 44 verificações internas; 45 marcadores PASS contando o resumo; 0 FAIL |
| Bootstrap, auditoria e E13-A…H | Todos passaram; auditoria 8 PASS e E13-A…H 8/8 suítes, 57 PASS agregados, 0 FAIL |
| E13 etapas 2 e 3 | 21 PASS e 25 PASS, respectivamente; 0 FAIL |
| E11.1–E11.5 e E10.7 | Todas passaram em Batch isolado; 0 FAIL |
| E12 chain commit/input/math/continuous/R0/R1/R2/R3/R4 | 9/9 suítes; exit 0 e 0 FAIL |
| `git diff --check` e marcadores | sem erro de whitespace; nenhum marcador de conflito nos arquivos revisados |

O runner `tools/test-maxscript.ps1` exigiu exit code 0, ao menos um marcador PASS e zero `[AMENO_TEST][FAIL]`/`[AMENO_INSTALLED_TEST][FAIL]`. Os pares listener/system e as saídas do runner estão em:

`D:\Ameno\_worktrees\develop\.test-output\stage4-evidence-develop\`

## Não testado e limites

- O Batch não substitui a aprovação visual/funcional no Max interativo.
- Ainda não foi executado o pickPoint real, incluindo Esc, nem a validação visual da aba, mensagens WPF e foco durante a reancoragem.
- O gate manual da etapa 3 também continua pendente.
- Não foram feitos testes destrutivos na cena interativa, instalação, publicação, push ou merge na `main`.

## Próximo passo exato

Executar, quando autorizado, o gate manual da etapa 4 em uma cena de teste: abrir a aba Editar, conferir mensagens e modos, editar e restaurar valores, usar Undo/Redo, reancorar A/B em geometria real com Esc e selecionar âncoras. Somente após os gates manuais e autorização explícita iniciar a etapa 5 (terminais, preview e transação).
