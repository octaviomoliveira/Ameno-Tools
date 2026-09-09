# E16 — Preview transitório `gw` e commit previsível das cotas

Data: 2026-09-09

Status: implementação automatizada concluída na branch
`feature/e16-gw-preview-performance`; gate visual/manual E16.9 pendente em um
processo novo do 3ds Max 2026.

Escopo certificado nesta rodada: 3ds Max 2026, branch derivada de `develop`

Base funcional inspecionada ao escrever este plano: `b2ce56b`. A branch de
implementação deve partir do `develop` atual que já contenha este plano; não
fazer checkout destacado da base funcional e perder a documentação E16.

Contagem de execução: **10 etapas, 78 subetapas numeradas**

Decisão arquitetural: `docs/decisions/0025-e16-preview-gw-e-commit-preparado.md`

Execução desta rodada: o caminho `gw`, o modelo transitório, o hover leve, o
contexto de commit preparado, o rollback e a suíte automatizada estão verdes.
O soak humano (câmeras, DPI, resize, 20 sessões e a cena problemática) foi
deixado como último passo porque o Max interativo já aberto não podia ser
encerrado com segurança sem risco de perder uma cena não salva. O roteiro e a
coleta estão em `tests/maxscript/manual_e16_viewport_soak.ms`.

## 1. Resultado que esta etapa precisa entregar

Eliminar o trabalho pesado que hoje acontece enquanto o usuário movimenta o
mouse na ferramenta de cotação contínua e reduzir o tempo de materialização da
cadeia no clique final, sem alterar o resultado persistente das cotas.

Ao final da E16:

- `mouseMove` calcula somente o ponto no plano, atualiza um modelo transitório
  composto por valores simples e solicita um redraw;
- o callback de viewport usa apenas `gw` para desenhar pontos, linhas de cota,
  linhas auxiliares, terminais e rótulos temporários;
- nenhum spline, `TextPlus`, mesh, material, layer, Custom Attribute ou helper
  é criado, atualizado, procurado ou removido durante o preview contínuo;
- a resolução cara de geometria e vértice acontece somente em clique real;
- o clique final cria cada cota persistente uma única vez, dentro de um único
  Undo e com contexto de cena/estilo preparado uma vez por cadeia;
- a UI Python/Qt da E15 continua igual e responsiva; esta etapa não redesenha a
  interface nem reintroduz WPF;
- Planta e Fachada preservam a matemática, as âncoras 3D, a baseline, o render,
  a persistência e o comportamento de Undo/Redo atuais.

O objetivo não é esconder uma operação de 18 segundos atrás de uma animação.
O objetivo é remover trabalho redundante do caminho quente e comprovar a
redução com contadores e tempos reproduzíveis.

## 2. Diagnóstico já confirmado

### 2.1 Evidência de tempo

- Duas cotas verticais levaram 5,28 s, aproximadamente 2,64 s por segmento.
- Sete cotas horizontais levaram 18,15 s, aproximadamente 2,59 s por segmento.
- O custo por segmento é praticamente igual. Não há evidência de uma fórmula
  Vertical especialmente pesada.
- O layout matemático isolado é barato diante do custo de materialização.

### 2.2 Caminho quente atual

Na base `b2ce56b`, o fluxo relevante é:

```text
MouseTool.mouseMove
  -> AmenoDimensionContinuousTool.handleMove()
     -> AmenoContinuousInputResolver.acquireSample()
     -> handleHoverSample()
        -> classifyInputSample()
           -> AmenoContinuousInputResolver.resolveSample()
              -> intersectRayScene / shortlist / snapshotAsMesh
        -> refreshChainPreview()                         [linha-base 811]
           -> calculateChainLayout()
           -> AmenoSceneSetup.inspect()
           -> AmenoStyleService.getStyle()
           -> createPreviewDimension() ou updatePreviewDimension()
              -> spline / TextPlus / terminais / material / layer / UserProps
```

O throttle atual de 40 ms reduz a frequência, mas não muda o tipo de trabalho.
Um evento aceito ainda pode consultar a cena, percorrer geometria, gerar mesh e
mutar nós reais. Throttle é contenção, não solução.

### 2.3 Caminho-alvo

```text
MouseTool.mouseMove
  -> acquireSample() com raio/plano e hint nativo de snap
  -> classifyHoverFast() sem consulta de cena
  -> calculateChainLayout() puro
  -> buildOverlayModel() com point3/string/color/float/name
  -> model.revision += 1
  -> uma solicitação de redraw

Viewport redraw callback
  -> lê snapshot do OverlayModel
  -> gw.marker / gw.polyline / gw.text / primitivas equivalentes
  -> nunca chama serviço de cena, picking, estilo, CA ou logger persistente

MouseTool.mousePoint
  -> acquireSample()
  -> resolveSample() completo uma única vez
  -> adiciona referência OU inicia commit
  -> commitChain()
     -> prepara contexto uma vez
     -> cria cada cota persistente uma vez
     -> um Undo; rollback total em erro
```

## 3. Escopo fechado

### 3.1 Dentro da E16

- Preview da **ferramenta contínua** Horizontal/Vertical nos planos Planta e
  Fachada usando `gw` e zero nós temporários.
- Separação entre hover leve de `mouseMove` e picking completo de `mousePoint`.
- Lifecycle determinístico do redraw callback.
- Instrumentação de preview e commit com custo por fase.
- Preparação única de cena, layers, estilo e material no commit de cadeia.
- Reuso do `chainLayout` já calculado; nenhuma segunda projeção por segmento.
- Uma transação de Undo por cadeia e rollback integral.
- Regressões de âncora, fachada, texto, terminais, render e pacote.
- Teste manual e soak somente no Max 2026.

### 3.2 Fora da E16

- Alteração visual da janela Qt, Login, páginas ou navegação.
- Endpoint real de autenticação.
- Compatibilidade com Max 2021/2024/2027.
- Retomada dos gates finais E14.6/E14.7 de produção.
- Mudança do formato de arquivo, schema CA v6 ou migração de cenas.
- Reescrita do render Corona/V-Ray/Arnold.
- Multithreading, `threading`, `QtConcurrent`, worker Python ou acesso a
  `pymxs.runtime` fora da thread principal.
- Remoção imediata das APIs legadas `createPreviewDimension()`,
  `updatePreviewDimension()` e `removePreviewDimension()`: a ferramenta
  individual e testes históricos ainda as utilizam. A E16 apenas remove a
  dependência delas no fluxo contínuo.
- Otimização especulativa da ferramenta individual. Ela só entra em outro
  marco depois de ser medida separadamente.

## 4. Invariantes inegociáveis

Os itens abaixo são contratos, não sugestões. Se um deles for violado, a fase
não pode avançar mesmo que a viewport pareça mais rápida.

### G01 — A cena não é um canvas de preview

Entre o primeiro movimento da cadeia e o clique final, a contagem e os handles
dos objetos da cena devem permanecer iguais. É proibido criar ou alterar:

- spline, shape, `TextPlus`, Point helper ou mesh;
- material ou mapa;
- layer ou membro de layer;
- Custom Attribute, UserProp ou AppData;
- seleção, renderer, câmera, isolamento ou preferências do usuário.

### G02 — Hover não é clique

`mouseMove` não pode chamar direta ou indiretamente:

- `AmenoContinuousInputResolver.resolveSample()`;
- `querySurfaceHits()` / `intersectRayScene`;
- `buildShortlist()` ou laços sobre `geometry`/`objects`;
- `collectVertexProbes()` / `snapshotAsMesh`;
- leitura de todos os vértices de qualquer nó.

O hover pode exibir um **hint provisório** obtido de `snapMode.hit`,
`snapMode.node`, `snapMode.worldHitpoint` e da interseção raio/plano já entregue
por `acquireSample()`. O `vertexId` verdadeiro só é aceito após o resolver
completo no evento de clique.

### G03 — Picking R2 não pode regredir

O clique deve continuar ignorando gráficos Ameno e encontrar a geometria real
sob o mesmo pixel, inclusive vértices compartilhados entre cadeias H/V. Não
substituir o resolver de clique por `pickObject`, bbox aproximada ou pelo hint
do hover.

### G04 — Modelo do overlay é primitivo e descartável

O modelo pode conter somente cópias de `point2`, `point3`, `color`, `float`,
`integer`, `boolean`, `name`, `string` e arrays desses valores. Ele não guarda
nós, materiais, meshes, layers, controllers, CA, widgets Qt ou objetos .NET.

### G05 — O callback só desenha

O redraw callback não calcula layout, não formata unidade, não resolve estilo,
não consulta cena, não executa picking, não cria dados persistentes e não grava
um log por frame. Ele apenas lê um snapshot já pronto e chama `gw`.

### G06 — Uma identidade de callback por processo

O valor antigo da função global deve ser desregistrado **antes** de redefini-la.
Registrar uma função de mesmo nome depois de redefinir não remove o valor
anterior. O callback sobrevive a `resetMaxFile` e abertura de outra cena; por
isso o teardown explícito é obrigatório.

### G07 — Nenhuma recarga no mesmo processo

Depois de instalar ou alterar scripts, fechar o 3ds Max normalmente e abrir um
novo processo. Não executar `fileIn`, `AmenoBootstrap.start()` ou reload da UI
na sessão que já carregou uma geração anterior.

### G08 — Commit continua single-threaded e atômico

Toda mutação de cena ocorre na thread principal. A cadeia gera uma única entrada
de Undo. Qualquer falha remove somente as alocações da tentativa atual e preserva
as referências e o overlay para nova tentativa.

### G09 — Não otimizar removendo dados

Não omitir CA, UserProps, identificação gráfica, terminais, audit, anchor local,
`vertexId`, plano U/V/N, baseline ou material para ganhar tempo. Primeiro
eliminar repetição e medir; sem paridade de dados não há otimização válida.

### G10 — Redraw desligado precisa ser exception-safe

Usar `with redraw off (...)` ao materializar a cadeia. Não espalhar pares
manuais `disableSceneRedraw()`/`enableSceneRedraw()` que podem deixar o host
travado após uma exceção.

### G11 — Testes do Max são sequenciais

Nunca executar duas instâncias de `tools/test-maxscript.ps1` em paralelo. Elas
compartilham `.test-output` e Listener log; execução paralela já produziu colisão
de `FileStream` e resultados inválidos. Paralelizar leitura/análise é aceitável;
Max Batch, instalação e testes que escrevem na pasta comum são sequenciais.

### G12 — Cena real não é fixture

Não salvar por cima da cena de produção. Usar fixture gerada ou cópia
descartável. Antes de instalar, o Max deve estar fechado e o pacote atual deve
ter backup recuperável.

### G13 — O backend de preview é exclusivo

Durante desenvolvimento pode existir a chave `#sceneNodes | #gw`, mas apenas um
backend pode estar ativo por sessão. Nunca desenhar `gw` enquanto também cria
`segmentPreviews`. Após o gate, o padrão passa a `#gw`; a chave serve somente
para rollback técnico temporário e não é persistida na cena.

### G14 — Sem mudança silenciosa de UX

O rótulo temporário pode ser tipograficamente aproximado porque `gw` não é
`TextPlus`, mas valor, unidade, posição, cor de estado e tipo de terminal devem
continuar reconhecíveis. O objeto final deve permanecer visual e numericamente
idêntico à baseline.

### G15 — Erro não pode desaparecer em `catch ()`

O callback precisa proteger o host, porém deve incrementar contador de erro e
guardar a última mensagem em memória. A sessão emite um único resumo no stop.
Não imprimir exceção a cada redraw e não deixar callback permanentemente
desabilitado sem diagnóstico.

## 5. Arquivos e responsabilidades

### Arquivos principais a criar

- `Contents/scripts/ameno/core/ameno_continuous_overlay.ms`
  - structs primitivas do overlay;
  - builder puro de segmentos/terminais/rótulos;
  - serviço de estado, revision/dirty e desenho `gw`;
  - registro, auditoria e limpeza do callback.
- `tests/maxscript/test_e16_overlay_model.ms`
  - layout → primitivas, sem host gráfico e sem nós.
- `tests/maxscript/test_e16_mousemove_no_scene.ms`
  - contadores de chamadas proibidas e delta zero de cena.
- `tests/maxscript/test_e16_callback_lifecycle.ms`
  - cardinalidade do callback e teardown.
- `tests/maxscript/test_e16_commit_performance.ms`
  - tempos por fase, atomicidade e metas.
- `tests/maxscript/manual_e16_viewport_soak.ms`
  - assistente de gate manual, sem salvar a cena.

### Arquivos principais a alterar

- `Contents/scripts/startup/ameno_bootstrap.ms`
  - carregar `ameno_continuous_overlay.ms` depois de
    `ameno_continuous_diagnostics.ms` e antes de
    `ameno_dimension_continuous_tool.ms`;
  - não alterar a ordem restante.
- `Contents/scripts/ameno/core/ameno_dimension_continuous_tool.ms`
  - remover o preview contínuo baseado em nós;
  - separar hover fast de classificação de clique;
  - alimentar/limpar o overlay;
  - usar o contexto preparado no commit.
- `Contents/scripts/ameno/core/ameno_dimension_graphics.ms`
  - adicionar API interna de build preparado, sem quebrar `createDimension()`;
  - aceitar layer/estilo/material/layout já resolvidos no caminho de cadeia;
  - expor métricas por estágio somente quando diagnóstico estiver ativo.
- `tests/maxscript/test_e12_r3_preview.ms`
  - substituir expectativas de nós temporários pelo contrato do overlay.
- `tests/maxscript/test_e12_chain_commit.ms`
  - substituir `segmentPreviews` por modelo/revision, mantendo rollback e Undo.
- `tests/maxscript/test_e14_tools.ms`
  - provar preview de fachada no plano correto e zero nós temporários.
- `tests/maxscript/test_e13_stage5_terminals.ms`
  - manter os testes diretos das APIs legadas da ferramenta individual;
  - migrar apenas a seção que testa a cadeia contínua.
- `tests/maxscript/test_vertical_performance.ms`
  - manter a comparação H/V e acrescentar o backend `gw`, counters e validação
    de métricas finitas; não usar este teste sozinho como gate de cena real.

### Arquivos que não devem ser alterados sem evidência nova

- `Contents/python/ameno_ui/*`;
- módulos WPF congelados/fora do pacote;
- schema em `ameno_dimension_ca.ms`;
- matemática U/V/N em `ameno_dimension_plane.ms`;
- `ameno_dimension_chain_math.ms`, salvo correção comprovada por teste puro;
- adapters de render;
- `PackageContents.xml` e faixa de versões.

## 6. Contratos de dados propostos

Os nomes podem ser ajustados à convenção existente, mas as fronteiras abaixo
não podem ser misturadas.

### 6.1 `AmenoContinuousOverlayStyleSnapshot`

Campos mínimos:

```text
styleId
lineColor
textColor
hoverReferenceColor
hoverEmptyColor
errorColor
lineWidthPx
extensionGapScene
extensionOverhangScene
terminalType
terminalSizeScene
terminalPlacement
terminalAngleDegrees
textGapScene
outputUnit
precision
```

Regras:

- criado no início da sessão ou quando um comando explícito mudar estilo;
- não contém o objeto de estilo original;
- não chama `AmenoStyleService.getStyle()` durante o mouseMove;
- valores físicos continuam em scene units após conversão única e documentada;
- fonte, bold, italic e tracking podem ser ignorados pelo overlay se `gw` não
  suportar paridade; eles continuam obrigatórios no `TextPlus` final.

### 6.2 `AmenoContinuousOverlaySegment`

Campos mínimos:

```text
sourceIndexA / sourceIndexB
linePointA / linePointB
extensionAStart / extensionAEnd
extensionBStart / extensionBEnd
labelWorldPoint
labelText
terminalA[] / terminalB[]
measuredMillimeters
valid / errorCode
```

`terminalA/B` devem ser primitivas simples, por exemplo arrays de pares de
pontos para tick/open arrow, triângulo para closed arrow e marker/pequeno
polígono para dot. Não chamar `AmenoDimensionTerminalMesh` no overlay.

### 6.3 `AmenoContinuousOverlayModel`

Campos mínimos:

```text
sessionId
revision
visible
dirty
mode
planeType
referencePoints[]
hoverVisible / hoverKind / hoverPoint / hoverColor
offsetPoint
segments[]
status / errorCode / errorDetail
lastDrawnRevision
drawErrorCount / lastDrawError
```

Regras:

- uma instância nova por sessão;
- `sessionId` impede callback antigo de desenhar estado de outra sessão;
- `revision` só cresce quando o snapshot muda de fato;
- publicar o snapshot pronto de uma vez; o callback nunca deve observar arrays
  parcialmente reconstruídos;
- `clear()` torna `visible=false`, esvazia arrays e incrementa revision uma vez;
- o modelo não conhece `segmentPreviews`.

### 6.4 `AmenoDimensionBuildContext`

Campos mínimos:

```text
sceneState
systemLayer
dimensionsLayer
styleId
resolvedStyle
dimensionMaterial
plane
mode
outputUnit
precision
role
baselinePolicy
baselineCoordinate
```

Regras:

- preparado uma vez antes de abrir o laço dos segmentos;
- inválido se scene/layer/style/plane não puderem ser resolvidos;
- não guarda referências transitórias do mouse;
- não substitui dados específicos A/B de cada segmento;
- `createDimension()` público permanece wrapper compatível;
- o caminho novo interno recebe `segmentLayout` já pronto para não executar
  `layoutForMode()` novamente;
- material compartilhado deve ser comprovado em Corona/V-Ray/Arnold e no
  render separado antes de virar padrão; se houver incompatibilidade, reutilizar
  todo o restante e criar material por segmento, registrando a medição.

## 7. Contrato do redraw callback

### 7.1 Ordem segura de definição

```maxscript
global AmenoContinuousViewportDraw
try (unRegisterRedrawViewsCallback AmenoContinuousViewportDraw) catch ()
fn AmenoContinuousViewportDraw =
(
    if ::AmenoContinuousOverlayService == undefined then return false
    ::AmenoContinuousOverlayService.drawCurrent()
)
```

O exemplo é estrutural. Não copiar sem a prova E16.2. O ponto obrigatório é:
desregistrar o **valor antigo** antes de redefinir a função global.

### 7.2 O que `drawCurrent()` pode fazer

- verificar `visible`, `sessionId` e arrays válidos;
- `gw.setTransform (matrix3 1)` para coordenadas mundiais;
- desenhar primitivas já calculadas;
- projetar apenas o ponto de texto com `gw.wTransPoint()` se o spike escolher
  texto em screen space;
- ampliar a região de update segundo o caminho validado no spike;
- registrar em memória duração e falha do draw, sem I/O por frame.

### 7.3 O que `drawCurrent()` não pode fazer

- chamar `redrawViews()` recursivamente;
- iniciar outro callback ou timer;
- chamar `gw` fora do contexto de redraw;
- acessar `objects`, `geometry`, layers, seleção ou renderer;
- chamar `layout()`, formatador de unidade ou StyleService;
- criar bitmap, mesh, material, shape, texto 3D ou QWidget;
- escrever Listener/arquivo a cada quadro;
- engolir uma falha sem atualizar `drawErrorCount`/`lastDrawError`.

### 7.4 Texto e clipping

A API `gw` oferece coordenadas mundiais e de dispositivo. Rotinas `h*`/`w*`
não fazem clipping de forma geral e desenhar fora da região válida pode ser
perigoso. Portanto:

- o spike deve testar `gw.text` mundial primeiro;
- se for necessário centralizar em screen space, limitar o ponto projetado à
  viewport antes de chamar `gw.wText`/equivalente;
- não tentar rotacionar glifos manualmente nesta etapa;
- rótulo fora do frustum deve ser omitido, não extrapolado;
- DPI 100%, 125% e 150% devem manter posição/tamanho aceitáveis;
- perspectiva, ortográfica e fachadas devem ser testadas antes da integração.

## 8. Instrumentação obrigatória

### 8.1 Eventos agregados de preview

Não persistir um log por movimento. Guardar contadores na sessão e emitir um
resumo ao encerrar/cancelar:

```text
[E16_PERF] session=<id> movesReceived=<n> movesAccepted=<n>
  layoutP50Ms=<x> layoutP95Ms=<x> layoutMaxMs=<x>
  modelP50Ms=<x> modelP95Ms=<x> modelMaxMs=<x>
  drawP50Ms=<x> drawP95Ms=<x> drawMaxMs=<x>
  fullResolveDuringMove=<0> sceneMutationsDuringMove=<0>
  nodeDelta=<0> callbackCountAfter=<0> drawErrors=<0>
```

Se percentis forem complexos em MAXScript, manter amostra limitada/circular e
calcular no fim. Não deixar arrays crescerem sem limite durante horas de uso.

### 8.2 Tempos do commit

Medir ao menos:

```text
layout
prepareScene
resolveStyle
createOrResolveMaterial
perSegment.total
perSegment.controller
perSegment.anchorCoordinates
perSegment.CAInitial
perSegment.audit
perSegment.CAFinal
perSegment.line
perSegment.text
perSegment.terminals
perSegment.decorate
anchorIndexRebuild
redraw
commit.total
rollback.total
```

Usar nomes de etapa estáveis. Não misturar tempo de teste/fixture com o tempo do
produto. Sempre registrar quantidade de referências, segmentos, modo, plano,
renderer, quantidade total de objetos e versão do Max.

### 8.3 Contadores sentinela para testes

Nos testes, permitir wrappers/injeções que contem chamadas a:

- `resolveSample`;
- `querySurfaceHits`;
- `buildShortlist`;
- `collectVertexProbes`;
- `createPreviewDimension`/`updatePreviewDimension`;
- `ensureSceneReady`;
- `getStyle`;
- `createDimensionMaterial`;
- `layoutForMode`;
- `createDimension` e API preparada.

Produção não deve monkey-patch global permanentemente. Cada teste restaura as
funções em bloco de cleanup mesmo se uma asserção falhar.

## 9. Plano de execução — 10 etapas, 78 subetapas

As subetapas que contam para o total são apenas os itens numerados `E16.x.y`.
Não pular gates. Cada etapa deve terminar em commit pequeno, evidência e árvore
limpa antes de avançar.

### E16.0 — Congelar baseline e tornar a medição confiável (7 subetapas)

Objetivo: impedir que o agente compare resultados de máquinas, cenas ou runners
diferentes e chame ruído de ganho.

1. **E16.0.1 — Abrir branch isolada.** Confirmar `git status --short --branch`,
   registrar `b2ce56b` como base funcional analisada e criar
   `feature/e16-gw-preview-performance` a partir do `develop` atual contendo
   este plano. Não tocar `main`.
2. **E16.0.2 — Registrar ambiente.** Salvar Max 2026.x, Python/PySide, driver
   gráfico, renderer ativo, unidade da cena, DPI e resolução da viewport no
   relatório de baseline.
3. **E16.0.3 — Congelar duas fixtures.** Uma cena mínima determinística e uma
   cópia descartável da cena problemática. Registrar quantidade de objetos,
   vértices aproximados, modifiers e tamanho do arquivo; nunca versionar a cena
   de produção por engano.
4. **E16.0.4 — Validar o benchmark existente.** Confirmar que
   `horizontalMetrics` e `verticalMetrics` recebem retorno, denominadores são
   maiores que zero e resultados são numéricos/finitos. Falha de script é FAIL,
   nunca ausência de gargalo.
5. **E16.0.5 — Medir cinco rodadas sequenciais.** Descartar warm-up, coletar
   mediana e pior caso para 2 e 7 segmentos H/V. Não executar Max Batch em
   paralelo.
6. **E16.0.6 — Capturar invariantes da cena.** Antes/depois: handles dos nós,
   quantidade por classe, layers, materiais relevantes, callbacks registrados,
   Undo disponível e controllers Ameno.
7. **E16.0.7 — Publicar baseline E16.** Criar `work/e16-baseline/README.md` com
   comandos, logs e tabela; nenhum código funcional nesta etapa.

Gate E16.0:

- benchmark executa com exit code 0 e marcadores PASS explícitos;
- cinco rodadas comparáveis estão registradas;
- o custo comum por segmento é reproduzido ou a divergência é explicada antes
  de seguir;
- `git diff` contém apenas harness/evidência, sem mudança do produto.

Rollback: reverter somente o commit do harness. Não instalar pacote.

### E16.1 — Criar sentinelas e testes que falham antes da correção (8 subetapas)

Objetivo: provar que os testes detectam exatamente os dois problemas: mutação
de cena no preview e resolução pesada no mouseMove.

1. **E16.1.1 — Inventário do fluxo.** Documentar todos os chamadores de
   `refreshChainPreview`, `classifyInputSample`, `resolveSample` e APIs de
   preview por nós; salvar linhas atuais no relatório.
2. **E16.1.2 — Helper de snapshot de cena.** Implementar comparação por handles,
   classes, quantidade de materiais/layers e seleção, sem depender apenas de
   `objects.count`.
3. **E16.1.3 — Sentinela de mutação.** Exercitar 1.000 moves com três
   referências e falhar se qualquer handle/material/layer/CA mudar.
4. **E16.1.4 — Sentinela de picking.** Contar chamadas caras; na baseline o
   teste deve demonstrar que `resolveSample` pode ser alcançado pelo move. Após
   a correção, todas as contagens proibidas devem ser zero.
5. **E16.1.5 — Sentinela do backend.** Contar
   `createPreviewDimension`/`updatePreviewDimension`; o gate final exige zero
   chamadas pelo contínuo, sem proibir a ferramenta individual.
6. **E16.1.6 — Contrato do clique.** Acrescentar controle positivo: um clique
   verdadeiro precisa chamar o resolver completo uma vez e persistir o
   `vertexId` correto.
7. **E16.1.7 — Contrato de rollback.** Injetar falha no segundo segmento e
   provar: zero dimensões parciais, referências preservadas, sessão coletando e
   preview ainda disponível.
8. **E16.1.8 — Classificar falhas esperadas.** Marcar os testes red/green para
   que a falha da baseline seja intencional e não confundida com runner quebrado.

Gate E16.1:

- o teste novo falha na baseline pelo motivo esperado;
- o controle de clique R2 continua verde;
- cleanup dos wrappers ocorre mesmo em exceção;
- nenhuma alteração funcional foi feita para “fazer o teste passar”.

Rollback: remover apenas os testes novos; preservar relatório de diagnóstico.

### E16.2 — Spike isolado da API `gw` no Max 2026 (9 subetapas)

Objetivo: validar a API gráfica real antes de integrar o MouseTool. Esta fase não
usa a ferramenta de cotas e não cria objetos na cena.

1. **E16.2.1 — Callback mínimo.** Registrar uma função global única que desenha
   uma linha em world space; auditar com
   `showregisteredRedrawViewsCallbacks asArray:true`.
2. **E16.2.2 — Nitrous e update.** Comparar o padrão oficial de
   `gw.enlargeUpdateRect` com a necessidade de `gw.updateScreen`; escolher o
   menor caminho que não gere recursão/flicker e documentar o resultado.
3. **E16.2.3 — Linha e extensão.** Desenhar baseline e duas extensões em world
   space com identidade de transform.
4. **E16.2.4 — Rótulo.** Testar `gw.text` mundial e, se necessário,
   `gw.wTransPoint` + texto em screen space com clipping explícito.
5. **E16.2.5 — Terminais.** Provar tick, arrow open, arrow closed, dot e none
   apenas com polyline/polygon/marker; zero meshes.
6. **E16.2.6 — Estados.** Provar cores normal, referência provisória, vazio e
   erro sem material de cena.
7. **E16.2.7 — Câmeras.** Testar Planta ortográfica, perspectiva, Front/Back/
   Left/Right e câmera ortográfica rotacionada; observar clipping e z-order.
8. **E16.2.8 — DPI e resize.** Testar 100%, 125%, 150%, viewport maximizada e
   quatro viewports; nenhum acesso fora dos limites de dispositivo.
9. **E16.2.9 — Teardown repetido.** Registrar/desregistrar em 100 ciclos; após
   reset/new/open, cancelar e erro injetado, cardinalidade final deve ser zero.

Gate E16.2:

- vídeo/capturas e log do spike em `work/e16-gw-spike/`;
- zero objetos, materiais e layers criados;
- callback não duplica e não fica desabilitado após erro tratado;
- desenho legível nos planos exigidos;
- spike removível em um commit, sem tocar no fluxo de produção.

Rollback: desregistrar callback, fechar o Max e reverter o commit do spike. Se o
callback não puder ser comprovadamente removido, reiniciar o Max antes de
qualquer novo teste.

### E16.3 — Implementar modelo e builder puros do overlay (10 subetapas)

Objetivo: transformar chain layout + style snapshot em primitivas, sem `gw` e
sem cena. Só depois o renderer consumirá esse modelo.

1. **E16.3.1 — Criar módulo.** Adicionar
   `ameno_continuous_overlay.ms` e a ordem de bootstrap, inicialmente sem
   registro automático de callback.
2. **E16.3.2 — Criar style snapshot.** Copiar/converter uma vez os campos
   necessários e validar defaults para estilo ausente/cor inválida.
3. **E16.3.3 — Criar segment DTO.** Derivar linha, extensões, midpoint/rótulo e
   medida de cada `AmenoDimensionChainSegmentLayout`.
4. **E16.3.4 — Builder de tick.** Calcular duas pequenas linhas no plano U/V/N,
   respeitando tamanho, ângulo e placement.
5. **E16.3.5 — Builders de arrows.** Criar open/closed como pontos/polylines,
   incluindo inversão A/B e segmentos muito curtos.
6. **E16.3.6 — Builder de dot/none.** Dot vira marker/polígono simples; none
   produz array vazio e jamais nó dummy.
7. **E16.3.7 — Label determinístico.** Reutilizar o formatador existente fora
   do callback; mesma unidade, precisão, vírgula e valor do commit.
8. **E16.3.8 — Publicação atômica.** Construir arrays locais completos e somente
   então substituir `model.segments`; falha mantém o último snapshot válido ou
   limpa explicitamente, nunca estado parcial.
9. **E16.3.9 — Revision/dirty.** Não incrementar revision se offset, referências,
   estilo e resultado forem iguais dentro da tolerância definida.
10. **E16.3.10 — Testes puros.** Cobrir H/V em XY, fachadas U/V/N, ordem de
    estações, baseline fixa, unidades, cinco terminais, erro e arrays vazios.

Gate E16.3:

- o módulo carrega no bootstrap e todos os testes puros passam;
- nenhum teste precisa criar Max node;
- `OverlayModel` não contém referência de host proibida;
- geometria do preview coincide numericamente com `chainLayout` dentro de
  tolerância de `1e-4` scene unit;
- o código de produção ainda usa o backend antigo nesta fase.

Rollback: remover módulo/loader/teste; nenhum schema ou cena foi alterado.

### E16.4 — Trocar somente o mouseMove contínuo pelo overlay (8 subetapas)

Objetivo: obter o maior ganho sem alterar o clique e o commit no mesmo passo.

1. **E16.4.1 — Chave exclusiva.** Introduzir `previewBackend`, inicialmente
   `#sceneNodes` em desenvolvimento; proibir ativação simultânea.
2. **E16.4.2 — `classifyHoverFast`.** Criar classificação provisória baseada
   apenas em sample/plane/native snap. Não chamar `classifyInputSample`.
3. **E16.4.3 — Alterar `handleHoverSample`.** Usar o caminho fast, atualizar
   cursor/model e conservar o resolver completo somente em `mousePoint`.
4. **E16.4.4 — Refatorar `refreshChainPreview`.** Com backend `#gw`, calcular
   chain layout, construir/publicar overlay e retornar; não inspecionar cena nem
   resolver estilo a cada move.
5. **E16.4.5 — Alimentar estilo de sessão.** Capturar snapshot no `begin()` e
   invalidá-lo apenas por comando explícito; campos da UI continuam congelados
   durante a ferramenta.
6. **E16.4.6 — Coalescer redraw.** Manter no máximo um redraw solicitado para a
   última revision; descartar eventos intermediários. Não adicionar timer Qt.
7. **E16.4.7 — Ativar callback do produto.** Reaproveitar uma única função
   global e delegar ao serviço; não manter o callback do spike.
8. **E16.4.8 — Tornar `#gw` padrão.** Somente após sentinelas verdes; manter
   `#sceneNodes` temporariamente como rollback não persistente.

Gate E16.4:

- 1.000 moves aceitos: zero criação/atualização de preview por nós;
- zero `resolveSample`, `intersectRayScene`, scan de geometria e
  `snapshotAsMesh` durante move;
- delta zero de handles/materials/layers/CA/seleção;
- clique verdadeiro continua resolvendo e persistindo vértice;
- preview mostra N-1 segmentos, valor e terminais corretos;
- p95 de layout + build do modelo <= 16 ms e nenhum evento síncrono > 50 ms na
  fixture mínima. Se a máquina não sustentar o limiar, registrar distribuição e
  parar para análise; não maquiar a métrica aumentando throttle.

Rollback: mudar a chave para `#sceneNodes`, reiniciar Max e reverter somente o
commit de integração; modelo/testes podem permanecer.

### E16.5 — Fechar lifecycle, cancelamento e recuperação (9 subetapas)

Objetivo: garantir que o ganho não introduza o mesmo tipo de vazamento que
causava os travamentos anteriores.

1. **E16.5.1 — Início idempotente.** `begin()` limpa estado antigo, cria novo
   sessionId/model e registra exatamente um callback.
2. **E16.5.2 — Sucesso.** Após commit bem-sucedido, esconder/limpar overlay,
   desregistrar callback e só então finalizar a sessão/painel.
3. **E16.5.3 — Esc/botão direito.** Cancelar sem commit, limpar overlay e
   callback mesmo se o HUD/Qt já estiver fechando.
4. **E16.5.4 — Exceção de preview.** Preservar referências, limpar snapshot
   inválido, mostrar erro único e permitir cancelar; não criar fallback de nós
   automaticamente no mesmo frame.
5. **E16.5.5 — Exceção de commit.** Rollback de alocações, retorno a collecting e
   reconstrução do overlay a partir do draft preservado.
6. **E16.5.6 — Undo de ponto.** Recalcular o modelo para N-1; com menos de duas
   referências, `segments=[]` e nenhum resíduo.
7. **E16.5.7 — New/reset/open.** Callbacks de lifecycle existentes chamam uma
   única limpeza; o redraw callback não sobrevive ativo.
8. **E16.5.8 — Fechamento Qt/Max.** O bridge continua cancelando MouseTool antes
   do teardown da janela; nenhuma chamada Qt entra no overlay.
9. **E16.5.9 — Auditoria.** Em 100 ciclos begin/cancel e 20 ciclos
   begin/commit, medir callbacks, nodes, handles, erro e crescimento monotônico.

Gate E16.5:

- callback Ameno: 0 ocioso, 1 durante sessão, 0 ao terminar;
- zero crescimento de callbacks ou nós em todos os ciclos;
- nenhuma exceção não tratada no Listener/Max.log;
- reset/new/open e fechar janela não deixam MouseTool ativo;
- draw error é diagnosticável e não derruba o host.

Rollback: desativar backend `#gw`, fechar/reabrir Max e voltar ao commit E16.3.

### E16.6 — Instrumentar e preparar o commit de cadeia (7 subetapas)

Objetivo: eliminar resolução repetida por segmento sem mudar o objeto final.

1. **E16.6.1 — Medir antes de refatorar.** Inserir timers opt-in nos estágios
   listados na seção 8.2 e obter três perfis de 7 segmentos.
2. **E16.6.2 — Criar BuildContext.** Preparar cena/layers, estilo e material uma
   vez; validar tudo antes de criar o primeiro controller.
3. **E16.6.3 — Criar API interna preparada.** Implementar
   `createDimensionFromLayout(context, segmentLayout, ...)`; o método público
   atual vira wrapper e mantém assinatura/comportamento.
4. **E16.6.4 — Reusar layout.** Converter o segment layout da cadeia para o
   layout esperado pela representação sem nova chamada `layoutForMode`.
5. **E16.6.5 — Envolver redraw.** Executar o laço persistente em um único
   `with redraw off` dentro do único `undo ... on`; redraw final uma vez.
6. **E16.6.6 — Preservar alocação/rollback.** Registrar controller, line, text,
   marker e terminais por segmento; falha em qualquer estágio remove todos os
   IDs da tentativa e não toca em cotas anteriores.
7. **E16.6.7 — Reconstruir índice uma vez.** `AmenoAnchorService.rebuildIndex()`
   somente depois do commit completo; nunca por segmento.

Gate E16.6:

- `ensureSceneReady`, resolução de estilo e criação/resolução de material:
  uma vez por cadeia, salvo exceção documentada de renderer;
- `layoutForMode`: zero por segmento no caminho preparado;
- objeto final tem a mesma CA v6, UserProps, nós, terminais, texto e anchors da
  baseline;
- uma entrada de Undo remove a cadeia inteira; Redo restaura inteira;
- falhas `afterController`, `afterLine`, `afterText`, `afterTerminalA`,
  `afterTerminalB`, `afterTerminalUpdate`, `afterMarker` e `failAtSegment`
  deixam zero parciais;
- sete segmentos <= 5 s na cena de reprodução e nenhum segmento > 1 s. Se não
  atingir, avançar para E16.7 com o perfil; não introduzir thread/fatiamento.

Rollback: o wrapper público continua disponível; fazer `commitChain` voltar a
`createDimension(... useUndo:false)` em um único commit reversível.

### E16.7 — Remover gargalos restantes com evidência (7 subetapas)

Objetivo: usar o perfil, não suposição, para alcançar a meta sem degradar dados.

1. **E16.7.1 — Ordenar custos.** Produzir tabela por mediana/p95 e escolher
   somente o maior estágio remanescente.
2. **E16.7.2 — Scene setup.** Se `inspect/ensureSceneReady` ainda dominar,
   eliminar scans duplicados usando context validado; nunca cachear layer após
   new/open sem invalidar por sessão.
3. **E16.7.3 — Material.** Se criação dominar, compartilhar material por
   cor/adapter dentro da cadeia após teste de render; não usar cache global sem
   política de invalidação de cena.
4. **E16.7.4 — TextPlus.** Se texto dominar, reduzir chamadas redundantes de
   `ResetString/AppendString`, transform e rebuild na criação inicial; não trocar
   TextPlus por texto incompleto.
5. **E16.7.5 — Terminais.** Se mesh dominar, preparar geometria imutável por
   tipo/tamanho/ângulo ou instanciar de modo compatível com render; manter dois
   nós finais e metadados esperados quando o contrato exigir.
6. **E16.7.6 — CA/UserProps.** Se persistência dominar, agrupar somente escritas
   comprovadamente duplicadas. Não remover a segunda aplicação de CA até um
   teste provar equivalência completa do record final.
7. **E16.7.7 — Repetir perfil após cada mudança.** Uma hipótese por commit;
   descartar mudança que não melhora pelo menos 10% no estágio alvo ou que
   aumenta o pior caso/regressão.

Gate E16.7:

- meta de 7 segmentos <= 5 s e nenhum segmento > 1 s;
- nenhuma otimização não medida permanece no diff;
- sem thread, async commit ou timer que muta cena;
- paridade de render/persistência/Undo/anchors continua verde.

Critério de parada: se a meta falhar após remover repetição comprovada, entregar
o perfil com o estágio dominante e parar. Não criar uma transação assíncrona
atravessando eventos do Max sem novo ADR e autorização; isso ameaça Undo,
rollback e lifecycle.

### E16.8 — Regressão automatizada e matriz funcional (7 subetapas)

Objetivo: provar que desempenho não apagou recursos acumulados E10–E15.

1. **E16.8.1 — Preview contínuo.** Migrar R3/chain tests para `OverlayModel`,
   N-1 segmentos, baseline, rótulo, terminais, revision e zero nós.
2. **E16.8.2 — Picking.** Rodar R2 sem enfraquecer assertions de vértice real,
   reutilização H→V e rejeição de gráficos Ameno.
3. **E16.8.3 — Plano/fachada.** Rodar matemática E14 e tools em World XY,
   Front/Back/Left/Right e ortográfica rotacionada.
4. **E16.8.4 — Persistência/anchors.** Criar, salvar, abrir cópia, mover objeto e
   vértice, conferir atualização, bake, órfã e reparo.
5. **E16.8.5 — Visual/render.** Conferir texto vertical, cinco terminais, estilo,
   cor, máscara, render separado e bloqueios de renderer existentes.
6. **E16.8.6 — Transação.** Repetir todas as falhas injetadas, Undo/Redo e
   cancelamento em cada quantidade 2/7/50 segmentos.
7. **E16.8.7 — Pacote.** Rodar validação estrutural, bootstrap, smoke E15 Qt e
   teste do pacote instalado somente depois dos testes de código.

Ordem mínima e sequencial de suítes:

```text
test_e16_overlay_model.ms
test_e16_mousemove_no_scene.ms
test_e16_callback_lifecycle.ms
test_vertical_performance.ms
test_e12_r2_picking.ms
test_e12_r3_preview.ms
test_e12_chain_commit.ms
test_e12_r1_lifecycle.ms
test_e12_r4_transaction.ms
test_e13_stage5_terminals.ms
test_e13_text_commit_position.ms
test_e14_plane_math.ms
test_e14_tools.ms
test_e14_graphics.ms
test_e16_commit_performance.ms
test_e15_* aplicáveis
test_installed_package.ms
```

Antes de executar, confirmar os nomes reais com `rg --files tests/maxscript`;
não inventar um arquivo ausente nem tratar “não encontrado” como PASS.

Gate E16.8:

- `tools/validate-package.ps1` aprovado;
- todas as suítes exigidas exit code 0, PASS explícito e zero FAIL;
- nenhum teste foi relaxado apenas para acomodar a implementação;
- APIs legadas da ferramenta individual ainda passam onde continuam em uso;
- evidência em `work/e16-regression/`, uma pasta por execução sequencial.

Rollback: identificar o primeiro commit causador com suíte focal. Não reverter
arquivos do usuário nem usar `git reset --hard`/`checkout --` destrutivo.

### E16.9 — Soak gráfico, instalação canário e handoff (6 subetapas)

Objetivo: validar comportamento humano/viewport e tornar a entrega recuperável.

1. **E16.9.1 — Fechar Max e criar backup.** Confirmar processos encerrados,
   copiar o pacote ativo para diretório datado e verificar hash antes de instalar.
2. **E16.9.2 — Instalar canário 2026.** Executar `tools/install-dev.ps1`, validar
   conteúdo instalado por SHA-256 e abrir um processo novo do Max.
3. **E16.9.3 — Gate curto.** Login → Criar; duas cadeias H, duas V e quatro
   fachadas; navegar/orbitar/zoom durante preview; min/max/close da janela.
4. **E16.9.4 — Soak.** Vinte sessões alternando sucesso/cancelamento/erro,
   cadeias de 2, 10 e 50 referências, troca de viewport e reset/open em fixture.
5. **E16.9.5 — Cena problemática.** Em cópia descartável, repetir o caso de 7
   segmentos e registrar vídeo, resumo E16_PERF, Max.log, object/callback delta,
   tempo de commit e fluidez de navegação.
6. **E16.9.6 — Fechar entrega.** Gerar ZIP/SHA-256, atualizar PLAN/ADR, listar
   commits/evidências/rollback e publicar em `develop` somente com autorização
   explícita; `main` permanece intacta.

Gate E16.9 / Definition of Done:

- preview contínuo permanece navegável enquanto o cursor se move;
- nenhum nó temporário em 1.000 moves e durante o soak;
- callback 0/1/0, sem acúmulo;
- clique preserva picking por vértice;
- cotas finais H/V/Fachada visualmente corretas;
- 7 segmentos <= 5 s, nenhum segmento > 1 s na cena de referência;
- um Undo/Redo por cadeia;
- zero nó parcial após falha/cancelamento;
- zero nova exceção WPF/Qt/CLR ou minidump atribuível ao pacote;
- pacote instalado corresponde à fonte e backup foi testado/é recuperável;
- somente então marcar E16 concluída.

## 10. Matriz de testes detalhada

| Área | Caso | Evidência exigida | Falha se |
| --- | --- | --- | --- |
| Modelo | 0/1/2/N referências | segments 0/0/1/N-1 | segmento fictício ou array parcial |
| Layout H | XY e fachada | baseline V constante | divergência > 1e-4 |
| Layout V | XY e fachada | baseline U constante | divergência > 1e-4 |
| Texto | mm/cm/m, 0–3 casas | string igual ao commit | valor/unidade diferentes |
| Terminal | tick/open/closed/dot/none | primitive count/posição | mesh/nó criado |
| Move | 1.000 eventos | chamadas caras = 0 | qualquer full resolve/scene scan |
| Cena | 1.000 eventos | handles/material/layer delta = 0 | qualquer mutação |
| Click | vértice compartilhado | full resolve = 1 e vertexId correto | usa hint provisório |
| Lifecycle | begin/cancel/commit/error/reset/open | callback 0/1/0 | duplicado/órfão |
| Commit | 2/7/50 segmentos | uma transação, N-1 cotas | parcial/Undo múltiplo |
| Falha | cada injection stage | zero novos IDs | resíduo ou draft perdido |
| Persistência | save/open cópia | CA v6/plano/anchors iguais | schema/data drift |
| Reatividade | move/rotate/vertex | cota acompanha | vínculo perdido |
| Render | separado + estilos | pixels/nós esperados | material/terminal ausente |
| Qt | navegação/min/max/close | sem refresh implícito | UI chama cena ao navegar |
| Performance | cena mínima/problemática | p95/total nas metas | throttle mascara bloqueio |

## 11. Guia de revisão de código

O revisor deve responder explicitamente “sim/não” a cada pergunta:

### MouseMove

- Existe algum caminho de move que chama `resolveSample`?
- Existe qualquer loop sobre `objects` ou `geometry`?
- Existe `snapshotAsMesh`, `intersectRayScene` ou criação de node?
- StyleService/SceneSetup são chamados por movimento?
- Mais de um redraw pode ser enfileirado para a mesma revision?
- Um erro de draw pode inundar Listener/arquivo?

Qualquer “sim” nas cinco primeiras é bloqueador. A última também bloqueia se não
houver agregação/limite.

### Overlay

- O modelo contém somente valores primitivos?
- As extensões respeitam gap/overhang e plano U/V/N?
- Terminais A/B têm orientação correta em segmentos curtos/invertidos?
- Texto usa o mesmo formatador do commit?
- O callback apenas consome snapshot pronto?
- O callback antigo é desregistrado antes da redefinição?
- Todos os finais de sessão limpam estado e registro?

### Commit

- Scene/layer/style são preparados uma vez?
- O layout da cadeia é reutilizado?
- A API pública individual continua compatível?
- `with redraw off` e `undo on` abrangem o laço correto?
- Todas as alocações entram no rollback?
- Anchor index é reconstruído uma vez?
- Cada redução de escrita foi respaldada por comparação do record final?

### Testes

- Há controle negativo e positivo?
- A suíte falha se a otimização for removida?
- O teste mede handles/classes, não só count?
- O teste restaura wrappers/callbacks no cleanup?
- Max Batch foi executado sequencialmente?
- Logs registram host, fixture, modo, plano e quantidade de segmentos?
- Alguma assertion antiga foi apenas apagada em vez de substituída?

## 12. Caminhos errados e respectivas correções

| Caminho errado | Por que falha | Caminho correto |
| --- | --- | --- |
| Aumentar throttle para 100–300 ms | reduz eventos, mantém travadas longas e deixa preview atrasado | remover scene work; coalescer só revisions |
| Usar Qt timer para processar mouse | muda fila, não custo; cria reentrância UI/Max | modelo síncrono leve + redraw nativo |
| Worker/thread para criar TextPlus | API do Max não é thread-safe | commit curto na main thread |
| Resolver vértice no hover | `snapshotAsMesh` escala com cena/malha | hint no hover; full resolve no clique |
| Confiar no hint como âncora | pode apontar gráfico/objeto/vértice errado | revalidar sempre no mousePoint |
| Ocultar nodes de preview | nodes ainda custam criação/update | não criar nodes |
| Reutilizar meshes de terminal no `gw` | ainda acessa objetos de host | primitivas point3 puras |
| Chamar StyleService no callback | callback vira dependente de cena | snapshot de estilo por sessão |
| Redefinir callback antes de unregister | perde referência do valor antigo e duplica | unregister antigo, depois `fn`, depois register |
| `catch ()` absoluto | falha desabilita callback sem causa visível | proteger + contador + resumo único |
| `disableSceneRedraw` manual | exceção pode deixar redraw desligado | `with redraw off` |
| Uma entrada Undo por segmento | UX ruim e rollback fragmentado | um `undo on` externo, internals sem Undo |
| Apagar APIs legadas agora | quebra ferramenta individual/testes | desacoplar contínuo primeiro |
| Remover CA/UserProps para ganhar tempo | corrompe persistência/reparo/render | reduzir chamadas duplicadas comprovadas |
| Rodar Batch em paralelo | colisão na saída compartilhada | uma suíte por vez |
| Hot reload | callback/UI antigos permanecem no processo | fechar e reabrir Max |
| Testar na cena original | risco de perda/contaminação | cópia descartável + backup |
| Declarar Max 2021–2027 | não há matriz instalada/certificada | E16 apenas Max 2026 |

## 13. Procedimento operacional do agente executor

### Antes de editar

```powershell
Set-Location -LiteralPath 'D:\Ameno\_tools'
git status --short --branch
git rev-parse --short HEAD
rg --files | rg 'AGENTS\.md$|SKILL\.md$'
```

Se houver mudança do usuário, não sobrescrever. Identificar ownership e trabalhar
ao redor. Se um `AGENTS.md` aplicável existir, lê-lo integralmente antes da ação.

### Para localizar código

```powershell
rg -n "refreshChainPreview|handleHoverSample|handleMove|classifyInputSample|commitChain" Contents tests
rg -n "createPreviewDimension|updatePreviewDimension|resolveSample|snapshotAsMesh|intersectRayScene" Contents tests
rg -n "registerRedrawViewsCallback|unRegisterRedrawViewsCallback" Contents tests
```

Linhas citadas neste plano pertencem à base `b2ce56b`; usar os símbolos, não
assumir que a numeração continuará igual.

### Para editar

- usar `apply_patch` para alterações manuais;
- commits pequenos por fase;
- não misturar formatação massiva;
- não alterar arquivos Qt/WPF no mesmo commit;
- após cada commit: `git diff --check`, status e suíte focal.

### Para validar

```powershell
& '.\tools\validate-package.ps1'
& '.\tools\test-maxscript.ps1' -TestScript '.\tests\maxscript\test_e16_overlay_model.ms'
```

Executar o segundo comando **uma vez por suíte e sequencialmente**. Ajustar o
parâmetro ao contrato real do script se a assinatura divergir; consultar
`Get-Help .\tools\test-maxscript.ps1 -Full`, não adivinhar.

### Para instalar

- conferir que `3dsmax.exe` e `3dsmaxbatch.exe` estão encerrados;
- criar backup datado do alvo exato;
- executar o instalador existente, não copiar arquivos parcialmente;
- comparar hashes fonte/instalação;
- abrir novo processo do Max;
- em falha, fechar Max, restaurar backup inteiro e verificar hashes.

Não usar reload na sessão e não deixar diretórios de backup dentro do diretório
que o Autodesk Package Manager varre como plugins ativos.

## 14. Relatório obrigatório ao final de cada etapa

Usar este formato, sem declarar sucesso apenas por percepção visual:

```text
Etapa: E16.x
Commit:
Arquivos alterados:
Hipótese tratada:
Antes:
Depois:
Testes executados (com exit/PASS/FAIL):
Métricas p50/p95/max:
Node/material/layer delta:
Callback antes/durante/depois:
Regressões relevantes:
Riscos restantes:
Rollback exato:
Próxima etapa autorizada:
```

Se houver crash, anexar horário exato, ação, PID, Max.log, log Ameno, WER e dump
disponível. Não atribuir causa ao pacote sem correlação temporal/call stack.

## 15. Critérios GO / STOP

### GO

Avançar somente quando:

- a suíte focal e os controles adjacentes estão verdes;
- árvore Git está compreendida e sem mudanças não relacionadas do agente;
- cleanup deixa callbacks/nodes zerados;
- métrica melhora sem perda de paridade;
- rollback da fase está descrito e possível.

### STOP imediato

Parar, preservar evidência e não improvisar se ocorrer:

- minidump, access violation, erro CLR/Qt nativo ou Max sem responder de forma
  não recuperável;
- callback duplicado que não pode ser desregistrado no processo;
- redraw permanece desligado após exceção;
- clique perde `vertexId` ou ancora em gráfico Ameno;
- Undo remove cotas anteriores ou deixa parte da cadeia;
- save/open perde CA/plano/âncora;
- render diverge por material compartilhado;
- a única forma aparente de atingir meta exige background scene access;
- fixture ou runner deixa de ser confiável.

Nesses casos: fechar o Max normalmente se possível, preservar logs, restaurar o
último pacote aprovado e retomar do último gate verde.

## 16. Registro de execução E16 (2026-09-09)

| Etapa | Estado | Evidência / observação |
| --- | --- | --- |
| E16.0 | parcial documentada | ambiente e diagnóstico registrados em `work/e16-baseline/`; a medição histórica de 5,28 s/18,15 s foi preservada, mas não foi repetida cinco vezes para não recarregar o Max interativo aberto |
| E16.1 | automatizada | sentinelas de 1.000 moves, snapshot de cena e controle positivo R2 executados; o caminho E16 removeu o resolve completo do hover |
| E16.2 | integrada | primitivas `gw`, callback único, terminais e contadores implementados; inspeção visual de câmeras/DPI fica no gate manual |
| E16.3 | concluída | `test_e16_overlay_model.ms` — 27/27 PASS |
| E16.4 | concluída | `test_e16_mousemove_no_scene.ms` — 13/13 PASS, zero nós/full resolve/mutação |
| E16.5 | automatizada | `test_e16_callback_lifecycle.ms` — 6/6 PASS; rollback e teardown cobertos pelos testes de cadeia |
| E16.6 | concluída | contexto compartilhado, layout reutilizado, `with redraw off`, Undo único e rollback integral |
| E16.7 | concluída | commit de 7 segmentos em 181 ms (média 25,86 ms), prepare 1 ms, material 1 ms; nenhum segmento acima de 1 s |
| E16.8 | concluída | matriz E12–E15/E14, pacote instalado e smoke Qt executados em série, todos com exit 0/PASS/zero FAIL |
| E16.9 | canário preparado | backup/hash, instalação única, ZIP/SHA e assistente manual prontos; soak gráfico humano ainda pendente |

A implementação não deve ser promovida para `develop` ou `main` sem autorização
explícita e sem fechar o gate manual pendente.

## 16. Referências oficiais que governam a implementação

- Autodesk — Viewport Redraw Callback Mechanism:
  https://help.autodesk.com/cloudhelp/2023/ENU/MAXScript-Help/files/MAXScript-Tools-and-Interaction/Change-Handlers-and-Callbacks/GUID-1961F536-7F01-4D72-930C-4B9432952B79.html
- Autodesk — Viewport Drawing Methods:
  https://help.autodesk.com/cloudhelp/2023/ENU/MAXScript-Help/files/MAXScript-Tools-and-Interaction/Interacting-with-the-3ds-Max/Viewports/GUID-1B088FF0-6A36-420E-9F37-F0DBE9FB2676.html
- Autodesk — Disable Viewport Redraws when making scene changes:
  https://help.autodesk.com/cloudhelp/2025/ENU/MAXScript-Help/files/Frequently-Asked-Questions/Writing-Better-and-Faster/How-To-Make-It-Faster-/GUID-75BB21C9-2283-49BD-853C-78006717FBE2.html
- Autodesk — `undo` context:
  https://help.autodesk.com/cloudhelp/2025/ENU/MAXScript-Help/files/MAXScript-Language-Reference/Names-Literal-Constants-and/Context-Expressions/GUID-C8517C4A-A75F-4D4E-A058-BE3EE61A2A11.html

Pontos normativos extraídos dessas referências:

- no Nitrous, chamadas `gw` precisam ocorrer no redraw callback;
- callbacks registram valores de função, não apenas nomes;
- callback antigo deve ser desregistrado antes da redefinição;
- callbacks sobrevivem a reset/open até teardown explícito;
- `showregisteredRedrawViewsCallbacks asArray:true` permite auditoria no Max
  2021.1+ e está disponível no alvo 2026;
- com transform identidade, primitivas sem prefixo `h/w` recebem world space;
- APIs em screen/device space exigem cuidado de clipping;
- mudanças em lote na cena devem suspender redraw de forma exception-safe;
- uma cláusula externa de Undo deve representar a operação lógica inteira.

## 17. Prompt de handoff para o próximo agente

Copiar o bloco abaixo ao iniciar a execução:

```text
Implemente a E16 seguindo integralmente
plans/2026-09-09-e16-otimizacao-preview-commit-viewport.md.

Comece pela E16.0 e não pule gates. O alvo é somente 3ds Max 2026 e a branch
deve partir do develop atual que contém este plano; b2ce56b é apenas a base
funcional inspecionada. Main fica intacta. Não altere a UI Qt, não
reintroduza WPF, não use threads e não faça hot reload no Max.

Contrato central: mouseMove da ferramenta contínua não pode resolver a cena nem
criar/atualizar qualquer nó. Ele publica um OverlayModel primitivo; um único
redraw callback desenha com gw. O resolver completo continua no clique para
preservar vertexId/picking R2. O commit só será otimizado depois desse gate e
deve continuar single-threaded, em um Undo, com rollback total.

Execute Max Batch sempre sequencialmente. Registre em cada etapa commit, testes,
métricas, deltas de cena/callback e rollback. Se um gate falhar, corrija dentro
da fase; se houver crash, perda de picking, Undo parcial, persistência divergente
ou necessidade de background scene access, pare e preserve a evidência.
```

## 18. Checklist final de aceite do usuário

- [ ] Arrastar o cursor durante a cadeia não trava zoom/orbit/pan.
- [ ] Preview aparece com linhas, extensões, terminais e valor legíveis.
- [ ] Horizontal e Vertical têm resposta equivalente.
- [ ] Fachadas Front/Back/Left/Right funcionam no plano capturado.
- [ ] Clique no mesmo vértice continua reutilizável entre cadeias.
- [ ] Nenhum objeto temporário aparece no Scene Explorer.
- [ ] Cancelar não deixa resíduos.
- [ ] Falha de commit permite tentar novamente sem perder pontos.
- [ ] Uma ação de Undo remove a cadeia completa; Redo restaura.
- [ ] Texto/terminais finais continuam renderizando como antes.
- [ ] Sete segmentos concluem em até 5 s na cena de referência.
- [ ] Vinte sessões não degradam progressivamente a viewport.
- [ ] Fechar/reabrir a janela Qt não duplica callback ou MouseTool.
- [ ] Reiniciar o Max carrega o pacote sem erro.
- [ ] Backup anterior restaura o estado conhecido.
