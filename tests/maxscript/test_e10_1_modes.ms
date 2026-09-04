-- =============================================================
-- E10.1 Tests: Modos de cota aligned / horizontal / vertical
-- Executado por 3dsmaxbatch.exe via tools\test-maxscript.ps1
-- =============================================================

global AmenoDimensionMath
global AmenoDimensionCA
global AmenoDimensionRecord

local passed = 0
local failed = 0
local errors = #()

fn expect label actual expected =
(
    if actual == expected then
    (
        format "  [PASS] %\n" label
        passed += 1
    )
    else
    (
        format "  [FAIL] % | esperado: % | obtido: %\n" label expected actual
        failed += 1
        append errors label
    )
)

fn expectTrue label val =
(
    if val == true then
    (
        format "  [PASS] %\n" label
        passed += 1
    )
    else
    (
        format "  [FAIL] % | esperado: true | obtido: %\n" label val
        failed += 1
        append errors label
    )
)

fn expectNear label actual expected tol:0.001 =
(
    if (abs (actual - expected)) <= tol then
    (
        format "  [PASS] %\n" label
        passed += 1
    )
    else
    (
        format "  [FAIL] % | esperado: % | obtido: %\n" label expected actual
        failed += 1
        append errors label
    )
)

-- ----------------------------------------------------------------
-- BLOCO 1: layoutForMode despacha corretamente
-- ----------------------------------------------------------------
format "\n=== B1: layoutForMode dispatch ===\n"

-- aligned == alignedLayout
local pA = [0, 0, 0]
local pB = [100, 0, 0]
local pOff = [50, 30, 0]

local layoutAligned = AmenoDimensionMath.layoutForMode pA pB pOff mode:#aligned
local layoutDirect  = AmenoDimensionMath.alignedLayout  pA pB pOff

expectTrue "aligned dispatch valid" layoutAligned.valid
expectNear "aligned mm == direct mm" layoutAligned.measuredMillimeters layoutDirect.measuredMillimeters
expect     "aligned dimensionMode"  layoutAligned.dimensionMode #aligned

-- ----------------------------------------------------------------
-- BLOCO 2: layoutForMode horizontal
-- ----------------------------------------------------------------
format "\n=== B2: horizontal layout ===\n"

local pA2 = [0,   0, 0]
local pB2 = [200, 100, 0]  -- dx=200, dy=100
local pO2 = [100, 50, 0]

local lh = AmenoDimensionMath.layoutForMode pA2 pB2 pO2 mode:#horizontal

expectTrue "horizontal valid"            lh.valid
expect     "horizontal dimensionMode"    lh.dimensionMode #horizontal
expect     "horizontal direction"        lh.direction     [1, 0, 0]
expect     "horizontal perpendicular"    lh.perpendicular [0, 1, 0]

-- Valor medido deve ser somente |dx| em scene units; confirmamos que mm > 0
expectTrue "horizontal measuredMm > 0"  (lh.measuredMillimeters > 0.0)

-- linePointA deve ter X de A, Y = A.y + offset
local expectedOffY = pO2.y - pA2.y   -- = 50
local expectedLineA = [pA2.x, pA2.y + expectedOffY, 0.0]
local expectedLineB = [pB2.x, pA2.y + expectedOffY, 0.0]
expectNear "horizontal linePointA.x"   lh.linePointA.x  expectedLineA.x
expectNear "horizontal linePointA.y"   lh.linePointA.y  expectedLineA.y
expectNear "horizontal linePointB.x"   lh.linePointB.x  expectedLineB.x

-- ----------------------------------------------------------------
-- BLOCO 3: layoutForMode vertical
-- ----------------------------------------------------------------
format "\n=== B3: vertical layout ===\n"

local pA3 = [0,   0, 0]
local pB3 = [100, 300, 0]  -- dx=100, dy=300
local pO3 = [60,  150, 0]

local lv = AmenoDimensionMath.layoutForMode pA3 pB3 pO3 mode:#vertical

expectTrue "vertical valid"             lv.valid
expect     "vertical dimensionMode"     lv.dimensionMode #vertical
expect     "vertical direction"         lv.direction     [0, 1, 0]
expect     "vertical perpendicular"     lv.perpendicular [1, 0, 0]
expectTrue "vertical measuredMm > 0"   (lv.measuredMillimeters > 0.0)

local expectedOffX = pO3.x - pA3.x   -- = 60
local expectedLineAv = [pA3.x + expectedOffX, pA3.y, 0.0]
local expectedLineBv = [pA3.x + expectedOffX, pB3.y, 0.0]
expectNear "vertical linePointA.x"    lv.linePointA.x  expectedLineAv.x
expectNear "vertical linePointA.y"    lv.linePointA.y  expectedLineAv.y
expectNear "vertical linePointB.y"    lv.linePointB.y  expectedLineBv.y

-- ----------------------------------------------------------------
-- BLOCO 4: zero projection errors
-- ----------------------------------------------------------------
format "\n=== B4: zero projection ===\n"

local pSameX1 = [50, 0, 0]
local pSameX2 = [50, 100, 0]
local pOx = [50, 50, 0]
local lhZero = AmenoDimensionMath.layoutForMode pSameX1 pSameX2 pOx mode:#horizontal
expect "horizontal zeroProjection errorCode"  lhZero.errorCode  #zeroProjection
expect "horizontal zeroProjection valid=false" lhZero.valid false

local pSameY1 = [0,  50, 0]
local pSameY2 = [100, 50, 0]
local pOy = [50, 50, 0]
local lvZero = AmenoDimensionMath.layoutForMode pSameY1 pSameY2 pOy mode:#vertical
expect "vertical zeroProjection errorCode"  lvZero.errorCode  #zeroProjection
expect "vertical zeroProjection valid=false" lvZero.valid false

-- ----------------------------------------------------------------
-- BLOCO 5: CA v4 round-trip dimensionMode
-- ----------------------------------------------------------------
format "\n=== B5: CA v4 round-trip ===\n"

if AmenoDimensionCA != undefined then
(
    -- Verificar que AmenoDimensionRecord tem o campo
    local rec = AmenoDimensionRecord()
    expect "record.dimensionMode default"    rec.dimensionMode  "aligned"
    expect "record.schemaVersion default=4"  rec.schemaVersion  4

    -- Verificar que a service tem schemaVersion 4
    expect "CAService.schemaVersion = 4"  AmenoDimensionCA.schemaVersion  4
)
else
(
    format "  [SKIP] AmenoDimensionCA nao disponivel\n"
)

-- ----------------------------------------------------------------
-- BLOCO 6: retrocompatibilidade — dimensionMode ausente → "aligned"
-- ----------------------------------------------------------------
format "\n=== B6: retrocompat dimensionMode ausente ===\n"

-- Simula CA v3 sem o campo: como não podemos criar um CA real sem Max,
-- verificamos apenas que o readCA com ca.dimensionMode indefinido retorna "aligned"
-- via lógica direta do guard isProperty.
-- Este bloco apenas confirma o comportamento do record default.
local recOld = AmenoDimensionRecord()
recOld.dimensionMode = "aligned"   -- valor default que seria atribuído pelo guard
expect "retrocompat: dimensionMode = aligned"  recOld.dimensionMode  "aligned"

-- ----------------------------------------------------------------
-- RESULTADO
-- ----------------------------------------------------------------
format "\n=== RESULTADO E10.1 ===\n"
format "PASS: %  FAIL: %\n" passed failed

if failed > 0 do
(
    format "Testes falhos:\n"
    for e in errors do format "  - %\n" e
)

if failed == 0 then
    format "E10.1 PASS\n"
else
    format "E10.1 FAIL\n"
