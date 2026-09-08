# E14 — Planos de cotação e fachadas

**Data:** 2026-09-08

**Alvo inicial:** 3ds Max 2026

**Estado:** planejada; implementação não iniciada

**Quantidade de subetapas:** 7 (`E14.1` a `E14.7`)

## Contexto

O Ameno Cotas foi construído para plantas. O núcleo projeta todos os pontos no
plano mundial XY, a cotação contínua posiciona sua linha por interseção com
`Z = 0` e o TextPlus é orientado somente por rotação ao redor do eixo Z. Por
isso o modo atual chamado `Vertical` mede a componente Y da planta, não a altura
Z de uma fachada.

A E14 generaliza o núcleo para trabalhar em um plano ortográfico persistente.
O plano XY atual passa a ser o preset `Planta`; o novo preset `Fachada pela
vista` captura os eixos da vista ortográfica ativa e permite cotas alinhadas,
horizontais e verticais sem perder os snaps 3D reais.

## Objetivo

Permitir criar, editar, atualizar e renderizar cotas individuais e contínuas em
fachadas frontais, laterais e ortográficas personalizadas, preservando integralmente
as cotas antigas de planta e o fluxo de render separado existente.

## Decisões de produto

### Plano e direção são escolhas diferentes

A interface da aba Criar deverá separar:

```text
PLANO DA COTA
[ Planta ] [ Fachada pela vista ]

DIREÇÃO
[ Alinhada ] [ Horizontal ] [ Vertical ]

[ Cota individual ] [ Cota contínua ]
```

- Em `Planta`, o comportamento permanece equivalente ao atual.
- Em `Fachada pela vista`, Horizontal mede no eixo horizontal da vista.
- Em `Fachada pela vista`, Vertical mede no eixo vertical do plano, alinhado ao
  Z mundial sempre que a vista permitir.
- Alinhada mede o vetor A–B projetado dentro do plano escolhido.

### Perspectiva fora do MVP

A primeira versão aceita vistas Front/Back/Left/Right e câmeras ortográficas.
Câmera ou viewport em perspectiva deve ser recusada antes de iniciar a captura,
com mensagem explicativa. Isso evita confundir medida real, medida projetada e
posição aparente na imagem.

### O plano é congelado por cota

O plano da vista é capturado ao iniciar a ferramenta e persistido junto da cota.
Trocar de viewport posteriormente não altera sua geometria. Durante uma sessão
individual ou contínua, não será possível trocar o plano ou a direção.

## Modelo geométrico

Criar um contrato `AmenoDimensionPlane` com:

- `planeType`: `worldXY` ou `viewPlane`;
- `origin`: origem mundial do plano de anotação;
- `axisU`: eixo horizontal normalizado;
- `axisV`: eixo vertical normalizado;
- `normal`: normal normalizada do plano;
- metadado diagnóstico da vista/câmera de origem, sem vínculo obrigatório.

O pipeline matemático passa a ser:

```text
ponto mundial -> coordenadas locais U/V -> layout 2D -> ponto mundial no plano
```

Os pontos A e B continuam sendo os snaps 3D verdadeiros e mantêm nó, vértice ou
coordenada local. A projeção é usada para medir e desenhar a anotação; ela não
substitui a âncora real.

## Subetapas

### E14.1 — Núcleo de plano e matemática

**Objetivo:** introduzir o sistema genérico de plano sem alterar o resultado XY
das cotas existentes.

**Trabalho:**

- criar a estrutura e os validadores de base ortonormal;
- implementar conversões mundo↔plano;
- generalizar `aligned`, `horizontal`, `vertical` e `layoutForMode` para receber
  um plano;
- remover projeções XY internas dos cálculos novos, mantendo wrappers
  retrocompatíveis;
- generalizar também o layout de cadeia contínua.

**Gate:** testes matemáticos cobrem XY, XZ, YZ e plano ortográfico rotacionado;
os fixtures antigos produzem os mesmos valores e pontos de antes.

### E14.2 — Persistência v6 e compatibilidade

**Objetivo:** salvar o plano por cota e reabrir cenas sem depender da viewport.

**Trabalho:**

- evoluir `AmenoDimensionCA` de v5 para v6, anexando ao fim `planeType`,
  `planeOrigin`, `planeAxisU`, `planeAxisV` e `planeNormal`;
- gravar metadados equivalentes no controlador para diagnóstico e reparo;
- tratar cotas v1–v5 sem plano como `worldXY`;
- preservar migração somente na próxima alteração real, sem reescrever a cena ao
  abri-la;
- validar bases degeneradas e oferecer reparo não destrutivo.

**Gate:** save/load e rebuild de cotas de fachada preservam a geometria; cenas
antigas continuam visualmente idênticas e sem migração destrutiva.

### E14.3 — Representação gráfica orientada em 3D

**Objetivo:** desenhar linha, extensões, terminais, texto e marcador no plano da
fachada.

**Trabalho:**

- consumir `axisU`, `axisV` e `normal` em todos os nós gráficos;
- reutilizar o suporte a `planeNormal` dos terminais mesh;
- substituir a rotação exclusivamente em Z do TextPlus por uma matriz completa;
- impedir texto espelhado ou invertido quando a normal da vista mudar;
- aplicar a mesma orientação ao marcador manual e ao preview;
- manter linha, texto e terminais coplanares.

**Gate:** preview e commit coincidem em Front, Back, Left, Right e em uma câmera
ortográfica rotacionada; texto permanece legível nos dois lados da fachada.

### E14.4 — Ferramenta individual e interface

**Objetivo:** disponibilizar a cotação individual de fachada pelo fluxo de três
cliques já conhecido.

**Trabalho:**

- adicionar o seletor `Planta / Fachada pela vista` na aba Criar;
- capturar e validar a vista ortográfica ao iniciar;
- congelar plano e direção durante a sessão;
- projetar A, B e o terceiro clique no plano capturado;
- manter snaps 3D, associação a nós/vértices, cancelamento, Undo único e limpeza
  transacional;
- recusar perspectiva, base inválida e vista paralela ao Z com mensagens claras.

**Gate:** largura, altura e alinhada são criadas por três cliques em fachada;
cancelar ou falhar não deixa preview, controlador ou gráfico residual.

### E14.5 — Cotação contínua em fachada

**Objetivo:** criar cadeias horizontais e verticais com uma linha comum no plano
da fachada.

**Trabalho:**

- capturar um único plano para toda a sessão;
- classificar e ordenar estações nas coordenadas U/V;
- intersectar o cursor com o plano congelado, não com `Z = 0`;
- compartilhar baseline e afastamento entre todos os segmentos;
- manter reuso de referências, rollback completo e um único Undo;
- preservar a restrição atual de alinhada contínua até existir especificação
  própria para ela.

**Gate:** cadeias H/V funcionam nas quatro vistas ortográficas principais e em
vista rotacionada; preview, commit, cancelamento e Undo/Redo são consistentes.

### E14.6 — Reatividade, edição e reparo

**Objetivo:** fazer a cota de fachada acompanhar suas âncoras e os comandos da
aba Editar.

**Trabalho:**

- resolver A/B em mundo e reprojetá-los no plano persistido a cada atualização;
- preservar o afastamento em U/V quando objetos ou vértices se moverem;
- integrar reancoragem A/B, bake para mundial, órfãs e reparo em lote;
- manter overrides, auditoria, estilos e edição de unidade/precisão;
- impedir que rebuild ou reparo faça a cota retornar ao XY.

**Gate:** mover objeto, transformá-lo e editar vértice atualiza a fachada em
tempo real; save/load, reancoragem, bake e reparo mantêm o plano correto.

### E14.7 — Render, regressão, pacote e aceite

**Objetivo:** fechar a E14 como candidato instalável sem regressões de planta.

**Trabalho:**

- validar overlay separado em Corona e o contrato do adapter V-Ray CPU;
- confirmar enquadramento pela câmera de produção e alpha transparente;
- executar regressões E10–E13 e testes específicos E14;
- validar falhas, restauração de cena, Isolate Selection e render somente-cotas;
- gerar pacote candidato, manifesto SHA-256 e instalar somente após os gates
  automatizados e autorização operacional;
- executar gate manual completo no 3ds Max 2026.

**Gate:** Corona real aprovado; V-Ray CPU real quando disponível; pacote e
instalação conferidos por hash; critérios de aceite abaixo aprovados pelo usuário.

## Critérios de aceite do MVP

1. Criar largura horizontal em vista frontal.
2. Criar altura vertical usando a direção vertical do plano da fachada.
3. Criar uma dimensão inclinada dentro do plano.
4. Funcionar em Front, Back, Left e Right.
5. Funcionar em câmera ortográfica rotacionada.
6. Recusar perspectiva antes de criar qualquer nó.
7. Preview e resultado final serem visualmente equivalentes.
8. Cota contínua produzir uma linha comum.
9. Texto nunca aparecer deitado, espelhado ou fora da linha.
10. Alterar objeto ou vértice atualizar corretamente a cota.
11. Salvar e reabrir preservar o plano.
12. Cotas antigas de planta permanecerem inalteradas.
13. Render separado preservar posição, orientação, cor e alpha.
14. Cancelamento, falha e Undo não deixarem objetos residuais.

## Fora do escopo

- cotação em câmera perspectiva;
- converter uma cota existente de Planta para Fachada;
- fachadas curvas;
- detecção automática de plano a partir de uma face;
- cotas de nível e símbolos altimétricos como `+3,20`;
- geração automática de todas as cotas de uma fachada;
- cotação contínua alinhada/oblíqua.

## Arquivos inicialmente afetados

- `Contents/scripts/ameno/core/ameno_dimensions_math.ms`;
- `Contents/scripts/ameno/core/ameno_dimension_chain_math.ms`;
- `Contents/scripts/ameno/core/ameno_dimension_ca.ms`;
- `Contents/scripts/ameno/core/ameno_dimension_graphics.ms`;
- `Contents/scripts/ameno/core/ameno_dimension_tool.ms`;
- `Contents/scripts/ameno/core/ameno_dimension_continuous_tool.ms`;
- `Contents/scripts/ameno/core/ameno_anchor_service.ms`;
- `Contents/scripts/ameno/ui/ameno_cotas_criar_tab.ms`;
- testes MAXScript novos para E14 e regressões existentes E10–E13.

## Ordem de execução

Executar estritamente `E14.1 → E14.2 → E14.3 → E14.4 → E14.5 → E14.6 → E14.7`.
Cada subetapa deve produzir teste automatizado, evidência e atualização deste
plano antes da seguinte. Não instalar uma implementação parcial no ambiente de
produção do usuário antes do gate correspondente.

## Próximo passo exato

Iniciar a **E14.1 — Núcleo de plano e matemática** em branch própria, primeiro
caracterizando por testes o comportamento XY atual. Só depois introduzir a base
U/V/N e comprovar que XY, XZ, YZ e plano rotacionado retornam layouts válidos.
