# 0015 — Limitação: Âncoras não rastreiam edições de sub-objeto (EditPoly/EditMesh)

**Data:** 2026-09-04  
**Status:** E10.7.2 corrigida e reinstalada · gate diagnóstico pendente
**Contexto:** Detectado durante gate manual da E10.1

---

## Problema

O sistema de ancoras (E8) rastreia movimentos de geometria via `when transform X changes`.
Esse watcher dispara apenas quando a **matriz de transform do no** muda — ou seja, quando
o objeto inteiro e movido, rotacionado ou escalado.

Ao editar sub-objetos (arrastar vertices, edges ou polys no EditPoly/EditMesh), o transform
do no **nao muda**. So a geometria em espaco local muda. O watcher de transform nao dispara
e a cota permanece na posicao original.

### Como o localPoint e armazenado

```
ao ancorar: localPointA = worldPoint * (inverse nodeA.transform)
ao resolver: worldA     = localPointA * nodeA.transform
```

Para transform rigido (mover o objeto): funciona — o transform muda, o watcher dispara,
`resolvePoints` recompoe a posicao correta.

Para sub-objeto (arrastar edge no EditPoly): falha — o transform nao muda, localPointA
continua apontando para a posicao antiga do vertice em espaco local, o watcher nao
dispara, a cota nao se move.

---

## Escopo do problema

- EditPoly (Vertex / Edge / Poly sub-object drag)
- EditMesh (idem)
- Modificadores que alteram geometria sem mover o no (FFD, Bend, Twist, etc.)
- Morphs e shapes animados

**Nao afeta:**

- Mover/rotacionar/escalar o objeto inteiro
- Reancoragem manual
- Cotas de mundo (anchorType = "world")

---

## Solucao parcial (workaround rapido)

Adicionar `NodeEventCallback #geometryChanged` ao `rebuildIndex`:

```maxscript
NodeEventCallback id:#ameno_geom_watchers events:#(#geometryChanged) function:fn
```

O callback dispara ao terminar a edicao → chama `flushQueue`.

**Limitacao do workaround:** a cota atualiza ao soltar o mouse, mas vai para a posicao
do `localPointA` antigo (que nao corresponde ao vertice novo). Em sub-objeto puro, a
posicao exibida sera incorreta. Nao ha preview em tempo real durante o arraste.

---

## Solucao definitiva — Ancoragem por ID de vertice

Armazenar o **indice do vertice** (ou edge) do objeto ancora, em vez de um ponto em
espaco local. Na resolucao, ler a posicao atual do vertice via `meshOp.getVert` /
`polyOp.getVert`.

### Schema adicional necessario no CA

```
anchorVertexIdA   type:#integer  default:-1   -- -1 = ancora por ponto local (retrocompat)
anchorVertexIdB   type:#integer  default:-1
anchorEdgeMidA    type:#boolean  default:false -- usar midpoint da edge se true
anchorEdgeIdA     type:#integer  default:-1
anchorEdgeMidB    type:#boolean  default:false
anchorEdgeIdB     type:#integer  default:-1
```

### Logica de resolucao (ainda com retrocompat)

```
se anchorVertexIdA >= 0 entao:
    worldA = polyOp.getVert nodeA anchorVertexIdA * nodeA.transform
senao:
    worldA = localPointA * nodeA.transform   -- comportamento atual
```

### Deteccao automatica ao clicar o ponto

No `detectHitNode` (ameno_dimension_tool.ms), alem de detectar o no tambem detectar
o vertice mais proximo do ponto clicado e armazenar o ID.

### Watcher complementar

`NodeEventCallback #geometryChanged` para disparar `flushQueue` quando EditPoly
modifica a geometria do no anchorado.

---

## Impacto de implementacao

| Arquivo | Mudanca |
|---|---|
| `ameno_dimension_ca.ms` | Schema v4 → v5: campos `anchorVertexIdA/B`, `anchorEdgeIdA/B`, `anchorEdgeMidA/B` |
| `ameno_dimension_tool.ms` | `detectHitNode` detecta e armazena vertex/edge ID no clique |
| `ameno_dimension_ca.ms` | `resolvePoints` com ramificacao por tipo de ancora |
| `ameno_anchor_service.ms` | `rebuildIndex` registra `NodeEventCallback #geometryChanged` |
| `ameno_anchor_service.ms` | `flushQueue` ja existente (sem mudanca) |
| `tests/maxscript/test_e10_7_subobject_anchors.ms` | Testes automatizados |

**Schema e retrocompat:** campos `anchorVertexId` com default `-1` — cotas existentes
continuam usando `localPoint` (comportamento atual). Nenhuma migração destrutiva é necessária.
Os novos parâmetros são anexados ao final do ParameterBlock v5, preservando a ordem e
os ParamIDs de todos os campos existentes no schema v4.

---

## Prioridade sugerida

Implementar como **E10.7**. A sugestao original E10.5 foi renumerada porque a `main`
publicada passou a usar E10.5 para benchmarks e E10.6 para empacotamento alpha. O
escopo tecnico permanece o mesmo e o plano incremental esta em
`plans/2026-09-04-e10-7-subobject-anchors.md`.

---

## Referencias

- `ameno_anchor_service.ms` — `rebuildIndex`, `AmenoRegisterTransformWatcher`
- `ameno_dimension_ca.ms` — `resolvePoints`, `AmenoDimensionRecord`
- `ameno_dimension_tool.ms` — `detectHitNode`
- ADR 0011 (E8 — Sistema de Ancoras)

---

## Adendo E10.7.1 — resultado do primeiro gate manual

O primeiro teste no 3ds Max mostrou que mover o vértice ainda não atualizava a cota.
A implementação inicial consultava primeiro o `baseObject`, o que não representa a
geometria produzida por Edit Poly/Edit Mesh acima dele na modifier stack. Além disso,
a captura do nó dependia do primeiro objeto interceptado pelo raycast.

A correção passa a:

- resolver e localizar IDs com `snapshotAsMesh`, que avalia o topo da modifier stack;
- buscar o vértice globalmente pelo ponto exato devolvido pelo Vertex Snap;
- manter um change handler `when geometry` diretamente em cada nó ancorado, além do
  `NodeEventCallback` global;
- ouvir também `topologyChanged` para falhar com segurança quando IDs forem removidos.

Cotas criadas antes da captura de vertex ID continuam retrocompatíveis por `localPoint`.
Para fazê-las rastrear subobjetos, é necessário reancorar A/B ou criar uma nova cota.

### Adendo E10.7.2 — eliminar inferência silenciosa

O segundo gate também falhou e a interface não informava se o ID havia sido persistido.
A API do Max já fornece o resultado exato do Snap em `snapMode.node` e
`snapMode.worldHitpoint`; esses dados passam a ter precedência sobre qualquer inferência
por raycast ou bounding box. O painel passa a exibir os IDs capturados para separar
objetivamente falha de captura e falha de atualização. A reancoragem A/B também foi
corrigida para extrair `.node` do record `AmenoDimensionAnchorHit`.
