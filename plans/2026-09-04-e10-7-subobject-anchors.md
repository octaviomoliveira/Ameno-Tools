# E10.7 — Âncoras por vértice em Editable Poly e Editable Mesh

**Data:** 2026-09-04
**Estado:** implementação e instalação concluídas; gate Batch bloqueado pelo executor e gate interativo pendente
**Origem:** ADR 0015

## Por que E10.7

O ADR 0015 sugeria originalmente o número E10.5. Enquanto a correção era planejada,
a `main` passou a usar E10.5 para benchmarks de escala e E10.6 para o pacote alpha.
Para preservar o histórico publicado, a mesma correção funcional passa a se chamar
**E10.7**, sem mudança de escopo.

## Objetivo

Quando uma cota for criada ou reancorada sobre um vértice de um objeto Editable Poly
ou Editable Mesh, armazenar o ID desse vértice e recalcular a extremidade da cota após
edições de subobjeto. Cotas antigas continuam usando o ponto local já persistido.

## Contrato de compatibilidade

- schema CA v5, mantendo o mesmo `attribID` global;
- os seis parâmetros v5 são anexados ao fim do ParameterBlock para não deslocar os
  ParamIDs das propriedades v4;
- `anchorVertexIdA/B = -1` significa comportamento legado por `localPointA/B`;
- IDs válidos começam em 1, como exige o MAXScript;
- `anchorEdgeIdA/B = -1` e `anchorEdgeMidA/B = false` entram no schema v5, mas ficam
  reservados até a etapa específica de midpoint de aresta;
- IDs removidos ou renumerados não fazem a cota saltar silenciosamente: a última
  coordenada mundial é preservada e a cota fica órfã/vermelha;
- mover, rotacionar ou escalar o nó inteiro continua funcionando;
- cotas alinhadas, horizontais e verticais usam `layoutForMode` também no update rápido.

## Incrementos e gates

### E10.7-a — Schema v5 e migração implícita

- [x] adicionar os seis campos de vértice/aresta ao record e ao Custom Attribute;
- [x] leitura e escrita protegidas por `isProperty`;
- [x] propagar os campos por `createDimension` e `createController`;
- [x] atualizar `dataSchemaVersion` para 5;
- [ ] executar o teste real de uma instância CA v4 criada antes do bootstrap v5.

**Gate:** v4 continua resolvendo por `localPoint`; novas cotas persistem schema v5.

### E10.7-b — Captura do vértice

- [x] `detectHitNode` retorna nó, ID e posição mundial do vértice;
- [x] localizar o vértice mais próximo via `polyOp`/`meshOp`;
- [x] usar tolerância física de 10 mm para não capturar vértices distantes;
- [x] limpar o estado temporário em commit, cancelamento e novo início.

**Gate:** clique com snap sobre vértice persiste o ID correto; clique fora da tolerância
mantém a âncora legada por ponto local.

### E10.7-c — Resolução e falha segura

- [x] resolver IDs válidos no sistema mundial sem aplicar o transform duas vezes;
- [x] fallback por `localPoint` somente quando o ID é `-1`;
- [x] ID inválido preserva a última posição e marca a cota órfã;
- [x] reancoragem tenta detectar vértice e limpa IDs antigos de forma consistente;
- [x] reparo de órfãs converte referência de vértice inválida em ponto mundial estático.

**Gate:** mover vértice altera a medida; remover/renumerar o ID não desloca a cota
para outro vértice silenciosamente.

### E10.7-d — Reatividade de geometria

- [x] reutilizar o único `NodeEventCallback geometryChanged` já retido pelo serviço;
- [x] manter índice reverso nó → controladores e fluxo `markDirty` → `flushQueue`;
- [x] evitar registrar um segundo callback global;
- [x] corrigir update rápido para respeitar aligned/horizontal/vertical.

**Gate:** uma notificação `geometryChanged` atualiza somente as cotas do nó afetado.

### E10.7-e — Testes e instalação

- [x] criar `tests/maxscript/test_e10_7_subobject_anchors.ms`;
- [x] cobrir CA v4, Editable Poly, Editable Mesh, modo horizontal, ID inválido e callback;
- [!] executar no `3dsmaxbatch.exe` com a instância interativa do Max fechada —
  bloqueado: o lançador não concluiu nem criou os logs após mais de sete minutos;
- [!] executar regressão E10.1, E10.2, E10.4 e bootstrap — a regressão E10.1
  reproduziu o mesmo bloqueio antes de executar o script;
- [x] instalar o pacote de desenvolvimento;
- [ ] validar manualmente criação com snap e edição Vertex no Max.

## Estado da validação anterior

- `main` auditada em `ec3038b`, limpa e sincronizada com `origin/main`;
- pacote estrutural aprovado por `tools/validate-package.ps1`;
- E10.1–E10.6 estão presentes nos commits publicados;
- tentativa de Batch em 2026-09-04 não iniciou enquanto outra instância do Max estava
  ativa; nenhum arquivo ou sessão do usuário foi fechado ou modificado;
- revisão estática encontrou e corrigiu uma regressão: `updateDimensionFast` ainda
  chamava `alignedLayout`, ignorando os modos horizontal e vertical da E10.1.
- nova tentativa em 2026-09-04 foi feita com o Max fechado: tanto o teste E10.7 quanto
  o E10.1 conhecido ficaram presos no lançador `3dsmaxbatch.exe`; o processo filho do
  Max só surgiu depois de seis a sete minutos, sem `listener.log` ou `system.log`, e o
  harness não devolveu resultado. Isso impede atribuir a falha ao código do E10.7;
- `tools/validate-package.ps1` aprovou novamente a estrutura do pacote;
- a cópia de desenvolvimento foi instalada em
  `C:\Users\octav\AppData\Roaming\Autodesk\ApplicationPlugins\AmenoTools`.

## Limites conhecidos

- nesta entrega, IDs de aresta estão somente reservados no schema;
- operações topológicas como delete, weld, subdivide e attach podem renumerar IDs;
- Edit Poly como modificador e deformadores que alteram somente a malha avaliada exigem
  uma etapa posterior de avaliação segura do modifier stack;
- o gate automático do callback depende do message loop do Max; o teste determinístico
  chama o mesmo handler com o handle do nó e o gate manual confirma o evento real.

## Próximo gate

Abrir o 3ds Max 2026, validar uma cota criada com Vertex Snap sobre um Editable Poly e
mover o vértice em modo subobjeto. Depois validar um Editable Mesh e confirmar que
cotas antigas continuam acompanhando apenas o transform do objeto. O gate Batch deve
ser retomado separadamente após estabilizar o executor, sem bloquear o gate manual.
