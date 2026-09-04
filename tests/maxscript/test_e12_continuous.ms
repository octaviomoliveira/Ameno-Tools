/*
    E12 — Testes headless para AmenoDimensionContinuousTool.

    Valida:
      1. Instância e estado inicial
      2. Acumulação de pontos
      3. Undo de ponto (undoLastPoint)
      4. confirmPoints (transição para #offset)
      5. Criação de cotas ao fornecer offset
      6. Cancel a qualquer momento
      7. Limpeza de previews no cancel
*/

global AmenoDimensionContinuousTool
global AmenoDimensionGraphics
global AmenoDimensionMath
global AmenoUnitService

-- Suprime o HUD WPF em ambiente headless
-- (openHUD / closeHUD falharão silenciosamente sem janelas — por design)

local PASS = 0
local FAIL = 0

fn assert_eq label got expected =
(
    if got == expected then
    (
        format "[AMENO_TEST][PASS] %\n" label
        PASS += 1
    )
    else
    (
        format "[AMENO_TEST][FAIL] % — esperado: % · obtido: %\n" label expected got
        FAIL += 1
    )
)

fn assert_true label cond =
(
    if cond then
    (
        format "[AMENO_TEST][PASS] %\n" label
        PASS += 1
    )
    else
    (
        format "[AMENO_TEST][FAIL] % — condição falsa\n" label
        FAIL += 1
    )
)

fn assert_false label cond = assert_true label (not cond)

-- ── Helpers ───────────────────────────────────────────────────────────────────

fn resetTool =
(
    AmenoDimensionContinuousTool.active          = false
    AmenoDimensionContinuousTool.stage           = #idle
    AmenoDimensionContinuousTool.points          = #()
    AmenoDimensionContinuousTool.anchorNodes     = #()
    AmenoDimensionContinuousTool.anchorVertexIds = #()
    AmenoDimensionContinuousTool.segmentPreviews = #()
    AmenoDimensionContinuousTool.activePreview   = undefined
    AmenoDimensionContinuousTool.lastSessionIds  = #()
    AmenoDimensionContinuousTool.lastError       = ""
    AmenoDimensionContinuousTool.hudWindow       = undefined
    AmenoDimensionContinuousTool.hudLabel        = undefined
    AmenoDimensionContinuousTool.hudBtnUndo      = undefined
    AmenoDimensionContinuousTool.hudBtnCancel    = undefined
)

-- Versão de begin() sem cena (pula AmenoSceneSetup para headless)
fn beginHeadless =
(
    resetTool()
    AmenoDimensionContinuousTool.active = true
    AmenoDimensionContinuousTool.stage  = #collectingPoints
)

-- Simula adição de ponto diretamente (sem mouse)
fn addPoint x y =
(
    local pt = [x, y, 0.0]
    append AmenoDimensionContinuousTool.points pt
    append AmenoDimensionContinuousTool.anchorNodes undefined
    append AmenoDimensionContinuousTool.anchorVertexIds -1
)

-- ── Teste 1: Estado inicial ───────────────────────────────────────────────────

format "=== E12.1 Estado inicial ===\n"
(
    assert_true  "T1.1 tool instanciado" (AmenoDimensionContinuousTool != undefined)
    assert_false "T1.2 active=false inicial" AmenoDimensionContinuousTool.active
    assert_eq    "T1.3 stage=#idle inicial" AmenoDimensionContinuousTool.stage #idle
    assert_eq    "T1.4 points vazio"  AmenoDimensionContinuousTool.points.count 0
    assert_eq    "T1.5 mode=#aligned" AmenoDimensionContinuousTool.activeMode #aligned
)

-- ── Teste 2: Acumulação de pontos ─────────────────────────────────────────────

format "=== E12.2 Acumulação de pontos ===\n"
(
    beginHeadless()
    addPoint 0 0
    addPoint 1000 0
    addPoint 2000 0
    addPoint 2000 1500

    assert_eq "T2.1 4 pontos acumulados" AmenoDimensionContinuousTool.points.count 4
    assert_eq "T2.2 anchorNodes count"   AmenoDimensionContinuousTool.anchorNodes.count 4
    assert_eq "T2.3 anchorVertexIds count" AmenoDimensionContinuousTool.anchorVertexIds.count 4
    assert_eq "T2.4 ponto[1] x" AmenoDimensionContinuousTool.points[1].x 0.0
    assert_eq "T2.5 ponto[2] x" AmenoDimensionContinuousTool.points[2].x 1000.0
    assert_eq "T2.6 ponto[4] y" AmenoDimensionContinuousTool.points[4].y 1500.0
    assert_eq "T2.7 stage=#collectingPoints" AmenoDimensionContinuousTool.stage #collectingPoints
)

-- ── Teste 3: Undo de ponto ────────────────────────────────────────────────────

format "=== E12.3 Undo de ponto ===\n"
(
    beginHeadless()
    addPoint 0 0
    addPoint 500 0
    addPoint 1000 0

    assert_eq "T3.1 antes do undo: 3 pontos" AmenoDimensionContinuousTool.points.count 3

    local ok1 = AmenoDimensionContinuousTool.undoLastPoint()
    assert_true "T3.2 undoLastPoint retorna true" ok1
    assert_eq   "T3.3 após 1 undo: 2 pontos" AmenoDimensionContinuousTool.points.count 2
    assert_eq   "T3.4 último ponto é [500,0,0]" AmenoDimensionContinuousTool.points[2].x 500.0

    local ok2 = AmenoDimensionContinuousTool.undoLastPoint()
    assert_true "T3.5 segundo undo retorna true" ok2
    assert_eq   "T3.6 após 2 undos: 1 ponto" AmenoDimensionContinuousTool.points.count 1
    assert_eq   "T3.7 último ponto é [0,0,0]" AmenoDimensionContinuousTool.points[1].x 0.0

    -- Undo com apenas 1 ponto: ainda funciona (remove o único)
    local ok3 = AmenoDimensionContinuousTool.undoLastPoint()
    assert_true "T3.8 undo do último ponto retorna true" ok3
    assert_eq   "T3.9 após undo do único: 0 pontos" AmenoDimensionContinuousTool.points.count 0

    -- Undo sem pontos: retorna false
    local ok4 = AmenoDimensionContinuousTool.undoLastPoint()
    assert_false "T3.10 undo com 0 pontos retorna false" ok4
)

-- ── Teste 4: confirmPoints ────────────────────────────────────────────────────

format "=== E12.4 confirmPoints ===\n"
(
    beginHeadless()

    -- Sem pontos: não confirma
    local r1 = AmenoDimensionContinuousTool.confirmPoints()
    assert_false "T4.1 confirmPoints sem pontos retorna false" r1
    assert_eq    "T4.2 stage permanece #collectingPoints" AmenoDimensionContinuousTool.stage #collectingPoints

    -- Com 1 ponto: não confirma
    addPoint 0 0
    local r2 = AmenoDimensionContinuousTool.confirmPoints()
    assert_false "T4.3 confirmPoints com 1 ponto retorna false" r2

    -- Com 2 pontos: confirma
    addPoint 1000 0
    local r3 = AmenoDimensionContinuousTool.confirmPoints()
    assert_true "T4.4 confirmPoints com 2 pontos retorna true" r3
    assert_eq   "T4.5 stage muda para #offset" AmenoDimensionContinuousTool.stage #offset

    -- Segunda chamada (já em #offset): não confirma
    local r4 = AmenoDimensionContinuousTool.confirmPoints()
    assert_false "T4.6 confirmPoints em #offset retorna false" r4
)

-- ── Teste 5: Cancel ───────────────────────────────────────────────────────────

format "=== E12.5 Cancel ===\n"
(
    beginHeadless()
    addPoint 0 0
    addPoint 1000 0
    addPoint 2000 0

    assert_true "T5.1 active=true antes do cancel" AmenoDimensionContinuousTool.active
    assert_eq   "T5.2 3 pontos antes do cancel" AmenoDimensionContinuousTool.points.count 3

    AmenoDimensionContinuousTool.cancel()

    assert_false "T5.3 active=false após cancel" AmenoDimensionContinuousTool.active
    assert_eq    "T5.4 stage=#idle após cancel" AmenoDimensionContinuousTool.stage #idle
    assert_eq    "T5.5 points zerado após cancel" AmenoDimensionContinuousTool.points.count 0
    assert_eq    "T5.6 anchorNodes zerado" AmenoDimensionContinuousTool.anchorNodes.count 0
    assert_eq    "T5.7 segmentPreviews zerado" AmenoDimensionContinuousTool.segmentPreviews.count 0
)

-- ── Teste 6: Cálculo de total (calcTotalMillimeters) ─────────────────────────

format "=== E12.6 Cálculo de total ===\n"
(
    beginHeadless()

    -- Sem pontos: total = 0
    local t0 = AmenoDimensionContinuousTool.calcTotalMillimeters()
    assert_eq "T6.1 total sem pontos = 0.0" t0 0.0

    -- 1 ponto: total = 0
    addPoint 0 0
    local t1 = AmenoDimensionContinuousTool.calcTotalMillimeters()
    assert_eq "T6.2 total com 1 ponto = 0.0" t1 0.0

    -- 2 pontos a 1000 scene units de distância: total em mm depende da unidade da cena.
    -- Valida apenas que o valor é > 0.
    addPoint 1000 0
    local t2 = AmenoDimensionContinuousTool.calcTotalMillimeters()
    assert_true "T6.3 total com 2 pontos > 0" (t2 > 0.0)

    -- Adiciona mais 1 ponto: total deve ser maior
    addPoint 2000 0
    local t3 = AmenoDimensionContinuousTool.calcTotalMillimeters()
    assert_true "T6.4 total com 3 pontos > total com 2 pontos" (t3 > t2)

    -- Ponto de volta (a 1000 units do segundo): total = 2x o primeiro segmento
    addPoint 1000 0
    local t4 = AmenoDimensionContinuousTool.calcTotalMillimeters()
    assert_true "T6.5 total com 4 pontos > total com 3 pontos" (t4 > t3)
)

-- ── Teste 7: Modo propagado ───────────────────────────────────────────────────

format "=== E12.7 Modo ===\n"
(
    resetTool()
    AmenoDimensionContinuousTool.activeMode = #aligned
    assert_eq "T7.1 modo inicial #aligned" AmenoDimensionContinuousTool.activeMode #aligned

    AmenoDimensionContinuousTool.activeMode = #horizontal
    assert_eq "T7.2 modo #horizontal" AmenoDimensionContinuousTool.activeMode #horizontal

    AmenoDimensionContinuousTool.activeMode = #vertical
    assert_eq "T7.3 modo #vertical" AmenoDimensionContinuousTool.activeMode #vertical
)

-- ── Resumo ────────────────────────────────────────────────────────────────────

format "\n=== E12 RESUMO: %/% PASS ===\n" PASS (PASS + FAIL)
if FAIL == 0 then
    format "[AMENO_TEST][PASS] Todos os testes E12 passaram.\n"
else
    format "[AMENO_TEST][FAIL] % teste(s) falharam.\n" FAIL
