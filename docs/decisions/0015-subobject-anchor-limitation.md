# 0015 — Limitação: Âncoras não rastreiam edições de sub-objeto (EditPoly/EditMesh)

**Data:** 2026-09-04  
**Status:** Conhecido · Pendente de solução  
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
| `tests/maxscript/test_e10_5_subobject_anchors.ms` | Testes automatizados |

**Schema e retrocompat:** campos `anchorVertexId` com default `-1` — cotas existentes
continuam usando `localPoint` (comportamento atual). Nenhuma migrar automatica necessaria.

---

## Prioridade sugerida

Implementar como **E10.5** (apos E10.2 ~ E10.4) ou como **E11** caso as etapas
intermediarias sejam mais urgentes. A decisao de prioridade fica com o usuario.

---

## Referencias

- `ameno_anchor_service.ms` — `rebuildIndex`, `AmenoRegisterTransformWatcher`
- `ameno_dimension_ca.ms` — `resolvePoints`, `AmenoDimensionRecord`
- `ameno_dimension_tool.ms` — `detectHitNode`
- ADR 0008 (E8 — Sistema de Ancoras)
