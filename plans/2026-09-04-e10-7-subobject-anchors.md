# E10.7 — Âncoras por vértice em Editable Poly e Editable Mesh

**Data:** 2026-09-04
**Estado:** E10.7.2 implementada e reinstalada após duas falhas manuais; gate diagnóstico pendente
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

### E10.7-f — Correção após o primeiro gate manual

- [x] registrar que a cota permaneceu na posição anterior após mover o vértice;
- [x] substituir a leitura exclusiva de `baseObject` por `snapshotAsMesh`, avaliando o
  topo da modifier stack em coordenadas mundiais;
- [x] tornar a captura independente do primeiro ray hit, buscando globalmente o vértice
  mais próximo do ponto devolvido pelo Vertex Snap;
- [x] adicionar `when geometry <node> changes` por nó ancorado, mantendo o
  `NodeEventCallback` como segunda rede de eventos;
- [x] incluir `topologyChanged` no callback global;
- [x] ampliar o teste para captura pela ferramenta e geometria avaliada com modificador;
- [x] reinstalar o pacote de desenvolvimento;
- [ ] repetir o gate manual com uma cota nova ou reancorada.

**Gate:** o ID deve ser capturado mesmo quando o raio encontra outra face, e o ponto deve
acompanhar o vértice resultante de Editable Poly/Edit Mesh no topo da modifier stack.

### E10.7-g — Captura explícita e diagnóstico após o segundo gate manual

- [x] registrar que a E10.7.1 ainda não acompanhou o vértice no teste real;
- [x] capturar diretamente `snapMode.node` e `snapMode.worldHitpoint` no evento do
  `MouseTool`, conforme a API oficial do Max;
- [x] dar precedência ao resultado real do Snap sobre raycast e bounding box;
- [x] forçar leitura de vértices dentro de `in coordsys world`;
- [x] corrigir a reancoragem A/B, que tratava `AmenoDimensionAnchorHit` incorretamente
  como se o próprio record fosse um nó;
- [x] registrar erro de compilação do watcher e contar watchers de geometria ativos;
- [x] mostrar no status `A=vN / B=vN`, `obj` ou `mundo`;
- [x] cobrir precedência do Snap e presença do watcher no teste automatizado;
- [x] reinstalar o pacote de desenvolvimento;
- [ ] confirmar primeiro a captura `A=vN / B=vN` antes de mover a malha.

**Gate diagnóstico:** só testar o movimento quando o painel comprovar que as duas pontas
receberam IDs. Se o status não mostrar `vN`, a falha está na captura; se mostrar e a cota
não acompanhar, a falha está no watcher/resolvedor.

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
- o primeiro gate manual falhou: a malha mudou, mas a cota permaneceu na posição antiga;
- a revisão pós-gate identificou duas lacunas concretas: a resolução priorizava
  `baseObject`, ignorando Edit Poly/Edit Mesh acima dele, e a captura dependia do primeiro
  objeto retornado pelo raycast. A E10.7.1 corrige ambas e adiciona watcher direto.
- o segundo gate manual também falhou. Como ainda não havia feedback do ID salvo, não era
  possível separar falha de captura de falha de atualização. A E10.7.2 passa a usar o
  resultado explícito do sistema de Snap e expõe o vínculo no status do painel.

## Limites conhecidos

- nesta entrega, IDs de aresta estão somente reservados no schema;
- operações topológicas como delete, weld, subdivide e attach podem renumerar IDs;
- Edit Poly como modificador e deformadores que alteram somente a malha avaliada exigem
  uma etapa posterior de avaliação segura do modifier stack;
- o gate automático do callback depende do message loop do Max; o teste determinístico
  chama o mesmo handler com o handle do nó e o gate manual confirma o evento real.

## Próximo gate

Reiniciar o 3ds Max 2026. Criar uma cota nova com apenas Vertex Snap ativo e
confirmar no painel `A=vN / B=vN`. Somente então mover o vértice. Se aparecer `obj` ou
`mundo`, registrar exatamente esse status; isso identifica a camada que ainda
falhou sem depender apenas da imagem. O gate Batch será retomado após estabilizar o executor.
