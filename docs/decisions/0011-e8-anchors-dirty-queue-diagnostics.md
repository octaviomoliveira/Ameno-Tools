# ADR 0011 — Âncoras Geométricas, Atualização Reativa, Cotas Órfãs e Diagnóstico

- Estado: aceita para o MVP
- Data: 2026-09-04

## Contexto

No fluxo de modelagem e desenvolvimento de plantas humanizadas no 3ds Max, paredes, aberturas, blocos de mobiliário e elementos arquitetônicos sofrem constantes modificações de posição, translação e rotação.
Até a Etapa E7, as cotas criadas pelo Ameno Dimensions possuíam coordenadas mundiais fixas (`pointA`, `pointB`, `offsetPoint`). Caso um objeto cotado fosse movido, a cota permanecia estática no ponto original.

Para a Etapa E8, o projeto necessita de um sistema de âncoras associativas de alta confiabilidade que:
1. Permita ancorar os pontos A e B da cota a nós da cena (`nodeA`, `nodeB`).
2. Recalcule automaticamente as extremidades, a linha de cota e o texto quando os nós de referência forem transladados ou rotacionados.
3. Não degrade o desempenho da viewport ao mover objetos em cenas complexas, utilizando fila suja (*dirty queue*) e *debounce*.
4. Ofereça garantia mandatória pré-render (`#preRender`), garantindo que nenhum frame seja renderizado com cotas desatualizadas em Corona, V-Ray ou Arnold.
5. Seja 100% tolerante à exclusão de nós: se o usuário deletar uma parede ou bloco de referência, a cota **nunca** deve sumir ou quebrar a cena; deve se tornar "órfã" (`isOrphan = true`), mantendo congelada sua última geometria física válida no espaço mundial.
6. Sinalize visualmente cotas órfãs no viewport através de cor distintiva de alerta e no painel principal através de badge de estado ("⚠️ Cota Órfã").
7. Forneça ferramentas de diagnóstico, seleção de âncoras, reancoragem manual e reparo em lote de cotas órfãs.

## Decisão

- **Evolução do Schema de Custom Attributes (v3)**:
  - Parâmetros adicionados ao `AmenoDimensionCADef`:
    - `anchorType`: string (`"world"`, `"nodeA"`, `"nodeB"`, `"both"`).
    - `nodeA`, `nodeB`: tipo `#node` com referência fraca nativa do Max (avalia para `undefined` quando o nó é excluído).
    - `localPointA`, `localPointB`: tipo `#point3` armazenando o ponto no espaço de coordenadas local do nó respectivo.
    - `isOrphan`: boolean indicando se a cota perdeu referências geométricas.
    - `orphanReason`: string detalhando o motivo (ex: `"Nó de ancoragem A foi excluído da cena"`).
- **Cálculo de Coordenadas Locais e Mundiais**:
  - Ponto local: `localPoint = worldPoint * (inverse node.transform)`.
  - Ponto mundial reativo: `worldPoint = localPoint * node.transform`.
  - Afastamento perpendicular preservado: o vetor perpendicular é recalculado a partir do novo segmento A-B respeitando o `signedOffsetSceneUnits` medido na criação.
- **Serviço Central `AmenoAnchorService`**:
  - Monitora transformações via `NodeEventCallback` (escutando `modelStructured` e `geometryChanged`).
  - Fila suja (*dirty queue*): objetos modificados inserem os controladores correspondentes em uma lista de espera (`dirtyQueue`), processada com temporizador de debounce (50ms).
  - Hook `#preRender`: registrado via `callbacks.addScript #preRender`, executa `flushQueue()` e `syncAll()` de forma síncrona antes do início de qualquer render (Corona, V-Ray, Arnold), blindando o frame contra descompasso.
- **Resiliência a Órfãs e Sinalização Visual**:
  - Quando um nó é deletado ou torna-se inválido, o método `resolvePoints` congela os pontos mundiais anteriores e seta `isOrphan = true`.
  - Ao reconstruir nós visuais de uma cota órfã, a cor dos objetos (`wirecolor`) e o material emissivo recebem coloração avermelhada de alerta `(color 230 70 70)`.
- **Ferramentas de Interação e Reparo**:
  - `selectAnchors controller`: seleciona na cena os nós `nodeA` e `nodeB` associados.
  - `reanchorDimension controller whichPoint targetNode targetWorldPoint`: reancora interativamente o ponto A ou B para um novo nó ou ponto mundial.
  - `repairOrphans mode:#toWorld`: converte cotas órfãs em cotas mundiais estáticas limpas com um clique.
  - Todas as operações encapsuladas em blocos `undo "..." on` garantindo operação reversível atômica.
- **Detecção Automática na Ferramenta de Criação**:
  - `AmenoDimensionTool` utiliza raycasting por viewport (`mapScreenToWorldRay`) e checagem de bounding box para associar automaticamente o nó sob o cursor ao clicar os pontos A e B.

## Consequências

### Positivas

- Fluxo de trabalho arquitetônico orgânico: mover uma parede ou divisória estica e atualiza a cota e sua leitura milimétrica automaticamente.
- Desempenho preservado: o debounce e a dirty queue evitam reconstruções desnecessárias durante o arrasto contínuo com mouse no viewport.
- Segurança máxima de dados: impossível perder cotas por exclusão acidental de objetos de cena.
- Clareza visual imediata: cotas desvinculadas ficam destacadas em vermelho no viewport até serem reancoradas ou reparadas.
- Render 100% confiável: garantia matemática de que o render exibirá a medida correspondente à geometria no momento do frame.

### Limitações conhecidas

- Em execuções puramente em lote (`3dsmaxbatch.exe` sem loop de interface gráfica Windows), o `NodeEventCallback` não despacha eventos de mouse interativo em segundo plano. Por essa razão arquitetural, o serviço expõe os métodos de flush e sync diretos (`syncDimension`, `syncAll`, `onPreRender`), garantindo cobertura idêntica em pipeline de automação e render de produção.
