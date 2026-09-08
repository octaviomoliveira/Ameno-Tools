# E14 — Planos de cotação e fachadas

**Data:** 2026-09-08

**Alvo inicial:** 3ds Max 2026

**Estado:** E14.1–E14.5 implementadas na branch `feature/e14-facade-planes`; E14.6 parcialmente integrada; candidato local instalado e E14.7 (render/aceite manual/publicação) pendente

**Quantidade de subetapas:** 7 (`E14.1` a `E14.7`)

## Progresso de implementação

O núcleo executável foi implementado sem alterar a `main`. Após os gates Batch,
o candidato foi instalado no perfil local para validar o carregamento real do
`ApplicationPlugins`.

- **E14.1:** `AmenoDimensionPlane` com base U/V/N validada, conversão mundo↔plano,
  interseção raio/plano e matemática alinhada/H/V em XY, XZ, YZ e bases rotacionadas.
  `test_e14_plane_math.ms`: **32/32 PASS**; `test_e14_camera_plane.ms`: **5/5 PASS**
  para câmera ortográfica nivelada, perspectiva e inclinação.
- **E14.2–E14.3:** CA v6 aditivo, migração v1–v5 para XY, rejeição diagnóstica de
  base v6 inválida, UserProps de diagnóstico, orientação 3D do TextPlus/terminais,
  auditoria, rebuild e save/load. `test_e14_graphics.ms`: **PASS**.
- **E14.4:** seletor Planta/Fachada na aba Criar, captura de vista ortográfica,
  origem ancorada no primeiro snap, snaps 3D preservados e cancelamento quando a
  identidade/orientação da vista muda.
- **E14.5:** cadeia H/V com interseção no plano congelado, ordenação U/V, baseline
  absoluta `fixedPlaneBaseline`, rollback e reatividade após mover referência.
  `test_e14_tools.ms`: **31/31 PASS**.
- **Regressão:** `test_bootstrap.ms`, E10.7, E12 (matemática, input, commit e
  contínua) e `test_e13_ui_lifecycle.ms` passaram com exit code 0 e zero FAIL;
  E10.1 e `test_installed_package.ms` passaram contra a cópia instalada após o
  backup `D:\Ameno\backups\AmenoTools-before-e14-20260908-202208`; a conferência
  encontrou 42/42 hashes iguais. `tools/validate-package.ps1` também passou.
- **Candidato:** `dist/AmenoTools-0.0.1-e14-facade-20260908.zip` (48 entradas,
  SHA-256 `EE0270622CCF1533DEE382D52C6B1E51745A6D48954C4771FFC0AD7EE2F6AB26`),
  manifesto em `plans/2026-09-08-e14-candidate-manifest.sha256`.

Ainda faltam o gate manual em Front/Back/Left/Right e câmera ortográfica rotacionada,
render Corona/V-Ray, cenários completos de E14.6 (reancoragem, bake e órfãs),
e a publicação/aceite final. A instalação de desenvolvimento já foi feita após
os gates automatizados e pode ser revertida pelo backup indicado acima.

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
  Z mundial. No MVP, a câmera deve estar nivelada, sem inclinação vertical nem roll.
- Alinhada mede o vetor A–B projetado dentro do plano escolhido.

### Perspectiva fora do MVP

A primeira versão aceita vistas Front/Back/Left/Right e câmeras ortográficas
niveladas, inclusive rotacionadas em torno do Z mundial.
Câmera ou viewport em perspectiva deve ser recusada antes de iniciar a captura,
com mensagem explicativa. Isso evita confundir medida real, medida projetada e
posição aparente na imagem.

### O plano é congelado por cota

A orientação da vista é capturada ao iniciar a ferramenta; a origem é fixada no
primeiro ponto aceito e o plano completo é persistido junto da cota.
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

**Gate:** save/load preserva os dados do plano e os layouts calculados; cenas
antigas mantêm seus dados sem migração destrutiva. O rebuild visual integrado
é validado na E14.3, após existir a representação gráfica orientada.

### E14.3 — Representação gráfica orientada em 3D

**Objetivo:** desenhar linha, extensões, terminais, texto e marcador no plano da
fachada.

**Trabalho:**

- consumir `axisU`, `axisV` e `normal` em todos os nós gráficos;
- reutilizar o suporte a `planeNormal` dos terminais mesh;
- substituir a rotação exclusivamente em Z do TextPlus por uma matriz completa;
- impedir texto espelhado ou invertido na orientação de criação de cada cota;
- aplicar a mesma orientação ao marcador manual e ao preview;
- manter linha, texto e terminais coplanares.

**Gate:** preview e commit coincidem em Front, Back, Left, Right e em uma câmera
ortográfica nivelada rotacionada; texto permanece legível na vista de criação.
Cotas criadas em Back ou Right têm sua própria orientação. Uma cota fixa vista
por trás não tem garantia de leitura e não gira automaticamente com a câmera.

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
- recusar perspectiva, base inválida, inclinação e roll com mensagens claras;
- cancelar com limpeza se a identidade ou orientação da vista mudar na captura;
  permitir pan e zoom mantendo a base e a origem congeladas.

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
5. Funcionar em câmera ortográfica nivelada rotacionada em torno de Z.
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
- `Contents/scripts/ameno/core/ameno_continuous_input.ms`;
- `Contents/scripts/ameno/core/ameno_anchor_service.ms`;
- `Contents/scripts/ameno/ui/ameno_cotas_criar_tab.ms`;
- `Contents/scripts/ameno/ui/ameno_cotas_editar_tab.ms`;
- `Contents/scripts/ameno/core/ameno_runtime.ms` e bootstrap, para integração;
- testes MAXScript novos para E14 e regressões existentes E10–E13.

## Ordem de execução

Executar estritamente `E14.1 → E14.2 → E14.3 → E14.4 → E14.5 → E14.6 → E14.7`.
Cada subetapa deve produzir teste automatizado, evidência e atualização deste
plano antes da seguinte. Não instalar uma implementação parcial no ambiente de
produção do usuário antes do gate correspondente.

## Próximo passo exato

Executar os gates restantes da **E14.6–E14.7** sobre o candidato já instalado:
validar reancoragem/bake/órfãs e Undo/Redo, fazer o gate manual das quatro vistas
e da câmera ortográfica rotacionada, testar render Corona/V-Ray e registrar o
aceite. O ZIP e SHA-256 já estão gerados; a implementação está na branch
`feature/e14-facade-planes` e a `main` continua em `e406929`.

## Roteiro preventivo obrigatório para o executor

As regras abaixo complementam as sete subetapas e prevalecem sobre frases
genéricas anteriores. Elas são o contrato preventivo usado na implementação;
onde houver indicação de gate pendente, ainda é necessária prova no Max interativo.

### 1. Fechar o contrato geométrico antes de editar consumidores — E14.1

1. Definir uma base destra: U aponta para a direita na vista de criação,
   V aponta para cima e N = cross(U,V) aponta para o observador. Em fachada
   nivelada, V = Z mundial. Validar esses sinais com pontos de referência nas
   quatro vistas; não inferir sinais pelo nome Front/Right apenas.
2. Antes de normalizar, validar componentes finitos e comprimento não nulo.
   Conferir perpendicularidade, comprimento unitário e handedness. Rejeitar
   bases degeneradas; não deixar NaN chegar ao TextPlus ou à mesh.
3. Para origem O e ponto mundial P: u = dot(P-O,U), v = dot(P-O,V),
   w = dot(P-O,N). A projeção retorna O + u*U + v*V. Um round-trip 2D recupera
   a projeção, não P quando w é diferente de zero.
4. Horizontal mede abs(uB-uA), Vertical mede abs(vB-vA), Alinhada mede a
   distância 2D em U/V. Preservar o sinal separado para orientação e lado;
   a medida exibida não pode virar negativa ao inverter A/B.
5. Retornar pontos de layout em coordenadas mundiais, como esperam os gráficos
   atuais. Nomes de variáveis devem diferenciar worldPoint e planeCoordinates.
   Nunca passar coordenadas U/V como se fossem pontos de cena.
6. Manter o default legado O=[0,0,0], U=X, V=Y, N=Z em APIs antigas.
   Não mudar globalmente o significado de Vertical para Z: isso quebraria plantas.
7. Preservar a convenção atual de perpendicular de H e V no modo legado.
   Não derivar N apenas de direction × perpendicular: no modo vertical atual
   isso pode inverter seu sinal. Consumir a normal explícita validada.
8. Separar tolerância angular adimensional, tolerância de medição em unidades
   de cena e tolerância de picking em pixels. Converter valores físicos pelo
   serviço de unidades existente. Nunca usar 10 unidades de cena como 10 mm.

**Provas:** A/B invertidos, offset dos dois lados, origem longe de zero, pontos
em profundidades diferentes, projeção nula com distância 3D não nula, milímetros/
centímetros/metros, coordenadas negativas e base inválida. Usar medidas conhecidas
independentes do próprio código de projeção para calcular os resultados esperados.

### 2. Resolver orientação, origem e câmera — E14.1/E14.4

- A câmera pode girar em torno do Z, mas deve olhar horizontalmente e manter o
  eixo superior alinhado ao Z. Definir e testar tolerância angular explícita.
  Câmera inclinada, Top/Bottom ou com roll recebe instrução para nivelar a vista.
- Capturar orientação e identidade da viewport/câmera antes do primeiro clique.
  Fixar O no primeiro snap aceito, sem alterar os pontos 3D seguintes. Não usar
  posição da câmera como plano de anotação.
- Pontos fora do plano continuam válidos: medimos sua projeção na fachada.
  O movimento de uma âncora somente em N não muda a medida projetada.
- Afastamento da linha é uma coordenada em U/V. Não confundi-lo com profundidade
  ao longo de N. No MVP o plano fica na profundidade do primeiro ponto; não
  adicionar deslocamento escondido para frente para mascarar oclusão.
- O plano fica fixo no mundo depois da criação. Mover/rotacionar a câmera não o
  altera, nem mover um objeto transporta automaticamente o plano inteiro.
- As APIs de câmera/viewport e convenções de matriz devem ser comprovadas em
  um spike mínimo com os tipos realmente disponíveis no Max 2026. Não adivinhar
  propriedades de câmera, nem considerar toda câmera como ortográfica.
- Pan/zoom recalculam o raio a partir da tela corrente sem recapturar O/U/V/N.
  Mudança de viewport, câmera, orientação ou projeção cancela a sessão e restaura
  o painel; conferir antes de cada captura/commit e no preview.

### 3. Preservar snaps 3D até o armazenamento — E14.4/E14.5

O perigo não está somente no layout: `flattenPoint`, `isModeDirectionMismatch`,
checagens de repetição, extração de estação e `positionPointFromScreen` na
contínua ainda contêm hipóteses XY. Inventariar todos esses caminhos por busca
de `flattenPoint`, `projectToWorldXY`, `targetZ`, `.x`, `.y` e vetores com Z zero.
Não fazer substituição global: coordenadas de tela e bounding boxes 3D continuam
usando X/Y/Z legitimamente.

- Conservar worldPoint, node e vertexId da referência escolhida. Projetar uma
  cópia para comparar estações; nunca destruir o Z original de `points`.
- Preservar o mapeamento sourceIndex durante ordenação. Cada segmento deve
  receber as âncoras originais correspondentes, e não apenas os pontos projetados.
- Referência repetida e estação coincidente são casos distintos. Rejeitar
  estações iguais com explicação, mesmo que os objetos tenham profundidades
  diferentes; não criar cotas zero nem escolher silenciosamente outra âncora.
- Generalizar `ameno_continuous_input.ms`: interseção por t = dot(O-rayOrigin,N)
  / dot(rayDirection,N). Denominador quase zero ou ponto não finito deve retornar
  falha explícita, sem fallback para XY. Validar origem e sentido do raio no spike.
- Preservar a prioridade do snap real e os filtros de nós técnicos Ameno.
  Ausência de snap não significa clique vazio: manter referência/geometria/vazio/
  ambíguo como classificações distintas do fluxo E12.
- O terceiro clique usa interseção raio/plano; os cliques de referência usam
  os snaps 3D existentes. Preview e commit consomem o mesmo resolvedor e layout.
- Manter Enter desativado como no fluxo atual. Não reintroduzir DispatcherTimer
  chamando MAXScript para confirmar, capturar ou alterar a cena.

### 4. Persistência e fonte de verdade — E14.2/E14.6

- Preservar attribID e ordem/tipo de todos os parâmetros existentes. Acrescentar
  campos ao fim do bloco CA; atualizar de forma coerente versão da definição,
  schemaVersion do serviço, record, criação do controlador e dataSchemaVersion.
- Exercitar migração com arquivo .max v5 real criado pela versão anterior.
  Testar também o fallback legado de UserProps. A simples existência de defaults
  novos não prova que os dados antigos foram preservados.
- CA é a fonte autoritativa; UserProps servem a compatibilidade/diagnóstico.
  Não permitir duas versões conflitantes do plano. Ler, copiar, editar, reancorar,
  aplicar estilo e reconstruir deve preservar todos os campos novos.
- Dados ausentes em schema legado assumem XY. Plano inválido explicitamente
  gravado em v6 gera diagnóstico e preserva gráficos existentes; nunca tratá-lo
  silenciosamente como planta. Reparar precisa de dados recuperáveis válidos.
- Auditar callbacks de abertura e `applyCA`: a intenção de migração preguiçosa
  não é atendida se o callback regravar todas as cotas durante sync/rebuild.
  Abrir a cena não deve gerar Undo de edição nem reescrever arbitrariamente dados.
- Validar também metadados de orientação do texto no controlador e nos filhos:
  o rebuild não pode perder a preferência `TextFollowsLine`.

### 5. Linha comum que continua comum — E14.2/E14.5/E14.6

O código atual cria controladores independentes e `resolvePoints` recalcula o
offset a partir de A. Repetir isso em cada segmento faz a baseline se separar
quando somente uma referência se move perpendicularmente à linha.

**Contrato escolhido para cadeias novas de fachada:** persistir em cada segmento
o mesmo plano e uma coordenada absoluta de baseline no plano: V constante em H,
U constante em V. Anexar `baselinePolicy` e `baselineCoordinate` ao schema v6;
defaults legados mantêm o comportamento atual. A política `fixedPlaneBaseline`
é usada na nova cadeia de fachada. Não depende de um segmento mestre que pode
ser apagado e não exige reconstruir um grafo de cadeia.

- Resolver âncoras atualiza somente as estações e extensões; a baseline fica fixa
  no plano. Mover todas as âncoras não transporta automaticamente a baseline.
- A cota individual mantém o afastamento relativo existente, agora calculado
  em U/V. A política deve ser explícita para evitar comportamentos misturados.
- Excluir um segmento não afeta os demais. Não inferir associação pela igualdade
  numérica de offsets nem pelo nome dos objetos.
- Preservar os pares de âncoras após o commit. Se estações se cruzarem, não religar
  automaticamente outros vértices; se coincidirem, sinalizar projeção nula.
  Não renderizar um valor antigo como se ainda fosse válido.
- A edição geométrica de direção de um segmento com baseline fixa deve ser
  bloqueada com mensagem até existir conversão definida. Não confundir esse
  comando com os modos medido/manual da aba Editar, que continuam disponíveis.

**Prova essencial:** cadeia com quatro referências; mover uma intermediária na
direção perpendicular à medição; todas as linhas devem continuar na mesma
baseline antes/depois de save/load, estilo, reancoragem, Undo e Redo.

### 6. Gráficos, texto e atualização — E14.3/E14.6

- Criar um único resolvedor de layout a partir do record. Criação, preview,
  auditoria, rebuild, atualização rápida e preRender devem passar o plano e a
  política de baseline por esse mesmo contrato. Localizar todos os
  `layoutForMode` para impedir um caminho que ainda use o default XY.
- Orientar TextPlus por uma base completa comprovada no Max. Testar origem
  distante de zero para capturar novamente o bug de posição girando em torno
  da origem. Aplicar orientação e depois posição conforme o contrato validado.
- `followLine=false` significa horizontal no plano da cota, não horizontal XY
  mundial. `followLine=true` mantém leitura no semiplano correto de U/V.
- Não aplicar escala/reflexão de objetos ancorados ao texto; escala do estilo
  vem de milímetros, e transformações das âncoras só resolvem pontos mundiais.
- Testar cada terminal, inclusive os de spline, além dos terminais mesh.
  Conferir winding, normal, posição e visibilidade na vista de criação.
- Atualização rápida e rebuild completo devem produzir a mesma geometria.
  Se uma atualização parcial falhar, não deixar linha nova com texto antigo:
  fazer rebuild transacional ou manter o conjunto anterior com diagnóstico.
- Topologia alterada que invalida vertexId deve preservar a cota como órfã;
  não reancorar automaticamente no vértice mais próximo. ID ainda existente
  após renumeração topológica não garante identidade semântica: documentar a
  limitação existente e não prometer rastreamento de topologia arbitrária.

### 7. Ciclo de vida e transações — E14.4 a E14.7

- Seguir a máquina de estados já existente; adicionar plano ao estado da sessão,
  sem um segundo MouseTool ou sistema paralelo de captura.
- Um commit individual ou de cadeia cria um único Undo. Registrar alocações
  antes de operações que possam falhar, incluindo terminais e controladores.
- Simular falha no meio da cadeia e em criação de texto/terminal. Nenhum filho
  parcial pode sobreviver, e uma falha recuperável não deve consumir o draft.
- Cancelamento, Esc, botão direito, reset, abertura de arquivo e fechamento do
  painel devem limpar previews, referências temporárias e callbacks da sessão.
  Repetir cleanup deve ser seguro. Restaurar controles e preferências de snap/
  escape para os valores que existiam antes, não para defaults inventados.
- Preservar o lifecycle WPF atual; não recriar abas a cada movimento do mouse,
  nem fazer Hide/startTool/Show reentrante. Executar mutações de cena nos caminhos
  síncronos já comprovados e proteger callbacks contra reconstrução recursiva.
- No preRender, sincronizar medidas antes de isolar/mudar materiais. Se alguma
  cota selecionada tiver plano ou projeção inválidos, bloquear a operação com
  diagnóstico antes da mutação, em vez de renderizar um valor desatualizado.

### 8. Render e múltiplas fachadas na mesma cena — E14.7

- Usar inicialmente o escopo Selecionadas para a fachada desejada. O escopo Todas
  continua significando todas as cotas elegíveis; não inventar filtragem por
  câmera invisível ao usuário. Testar planta + duas fachadas simultaneamente.
- Preservar câmera, frame, resolução, pixel aspect, Crop/Region e restauração
  transacional existentes. Não mudar a câmera para corrigir texto.
- Testar overlay somente-cotas e passe com geometria. No segundo, a oclusão pelo
  modelo é esperada se o plano estiver atrás de elementos; não desligar depth ou
  mover cotas silenciosamente. Overlay isolado deve permitir composição limpa.
- Preservar a guarda de Isolate Selection e despacho por renderer real. Não
  alterar parâmetros nativos Corona/V-Ray sem necessidade da E14.
- V-Ray sem render real fica explicitamente pendente: testes do adapter não
  comprovam saída visual. Não declarar compatibilidade visual validada nesse caso.

### 9. Matriz mínima de execução e evidências

| Subetapa | Evidência obrigatória antes de avançar |
| --- | --- |
| E14.1 | XY equivalente ao legado; XZ/YZ/rotação Z; valores conhecidos; bases inválidas; unidade física; A/B invertidos |
| E14.2 | Fixture .max v5 real; v6 save/load; plano e baseline preservados; CA inválido sem fallback silencioso |
| E14.3 | Rebuild e atualização iguais; 4 vistas; texto followLine on/off; todos os terminais; origem distante |
| E14.4 | 3 cliques; cancelamento em cada estado; pan/zoom; troca de vista; rejeição de perspectiva/inclinação/roll |
| E14.5 | H/V com cliques fora de ordem; referências em profundidades distintas; estação repetida; falha no segmento intermediário |
| E14.6 | Baseline após mover referência; transformações; órfãs; bake; reancoragem; estilo; save/load; Undo/Redo |
| E14.7 | Cena mista; Corona real; V-Ray real ou pendência explícita; restauração após erro/cancelamento; hash e gate manual |

Automação precisa de exit code zero e ausência de FAIL, além dos marcadores PASS.
Um log parcial ou apenas um PASS não fecha a subetapa. Testes devem comparar
medidas e posições, não apenas contar nós. Gates de MouseTool/TextPlus/render
exigem uso real no Max: Batch sozinho não prova a interação.

Em cada handoff registrar: commit/base, mudanças, decisões, testes executados,
resultados, pendências reais, estado de instalação e próximo comando/ação.
Não marcar aceitação manual por inferência. Não executar fixtures que apaguem
cena ou biblioteca de estilos na sessão de produção do usuário.

### 10. Limites desta revisão

Esta revisão antecipa riscos por inspeção do código e define caminhos de
implementação; não garante ausência de bugs. Antes de depender de uma API
específica do Max, o executor deverá confirmar sua documentação oficial ou
demonstrar seu comportamento em um spike local isolado. Diferenças descobertas
devem atualizar este contrato e seus testes antes de espalhar uma solução entre
os consumidores.
