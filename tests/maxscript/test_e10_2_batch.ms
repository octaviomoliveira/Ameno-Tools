-- =============================================================
-- E10.2 Tests: Operacoes em lote e bake de ancoras
-- Executado por 3dsmaxbatch.exe via tools\test-maxscript.ps1
-- =============================================================

global AmenoApp
global AmenoDimensionGraphics
global AmenoDimensionCA
global AmenoDimensionRecord
global AmenoDimensionMath
global AmenoSceneSetup

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

-- ----------------------------------------------------------------
-- BLOCO 1: getSelectedDimensionControllers detecta controladores
-- ----------------------------------------------------------------
format "\n=== B1: getSelectedDimensionControllers ===\n"

if AmenoApp == undefined or AmenoDimensionGraphics == undefined or AmenoDimensionCA == undefined then
(
    format "  [SKIP] AmenoApp/Graphics/CA nao disponivel\n"
)
else
(
    -- Preparar cena limpa
    try (AmenoDimensionGraphics.deleteAllTestDimensions()) catch ()

    local pA = [0, 0, 0]
    local pB = [100, 0, 0]
    local pOff = [50, 30, 0]

    local r1 = AmenoDimensionGraphics.createDimension pA pB pOff role:"test"
    local r2 = AmenoDimensionGraphics.createDimension [0, 50, 0] [100, 50, 0] [50, 80, 0] role:"test"

    if r1 != undefined and r2 != undefined then
    (
        -- Selecionar os nos visuais das duas cotas
        select #(r1.lineNode, r2.textNode)

        local ctrls = AmenoApp.getSelectedDimensionControllers()
        expectTrue "getSelectedDimensionControllers retorna array nao vazio" (ctrls.count > 0)
        expectTrue "encontrou pelo menos 1 controlador" (ctrls.count >= 1)

        -- Nenhum duplicado
        local unique = #()
        for c in ctrls where (findItem unique c) == 0 do append unique c
        expect "sem duplicados" unique.count ctrls.count
    )
    else
        format "  [SKIP] Falha ao criar cotas de teste\n"
)

-- ----------------------------------------------------------------
-- BLOCO 2: applyUnitToSelected
-- ----------------------------------------------------------------
format "\n=== B2: applyUnitToSelected ===\n"

if AmenoApp == undefined or AmenoDimensionCA == undefined then
(
    format "  [SKIP] AmenoApp nao disponivel\n"
)
else
(
    local pA = [0, 0, 0]
    local pB = [200, 0, 0]
    local pOff = [100, 40, 0]

    local r = AmenoDimensionGraphics.createDimension pA pB pOff role:"test"
    if r != undefined and r.controller != undefined then
    (
        select #(r.lineNode)
        local count = AmenoApp.applyUnitToSelected #centimeters
        expectTrue "applyUnitToSelected retornou > 0" (count >= 1)

        -- Verificar que o CA foi atualizado
        local rec = AmenoDimensionCA.readCA r.controller
        expect "unidade gravada no CA" rec.outputUnit "centimeters"
    )
    else
        format "  [SKIP] Falha ao criar cota de teste\n"
)

-- ----------------------------------------------------------------
-- BLOCO 3: applyPrecisionToSelected
-- ----------------------------------------------------------------
format "\n=== B3: applyPrecisionToSelected ===\n"

if AmenoApp == undefined or AmenoDimensionCA == undefined then
(
    format "  [SKIP] AmenoApp nao disponivel\n"
)
else
(
    local r = AmenoDimensionGraphics.createDimension [0,0,0] [150,0,0] [75,30,0] role:"test"
    if r != undefined and r.controller != undefined then
    (
        select #(r.controller)
        local count = AmenoApp.applyPrecisionToSelected 0
        expectTrue "applyPrecisionToSelected retornou > 0" (count >= 1)

        local rec = AmenoDimensionCA.readCA r.controller
        expect "precisao gravada no CA" rec.precision 0
    )
    else
        format "  [SKIP] Falha ao criar cota de teste\n"
)

-- ----------------------------------------------------------------
-- BLOCO 4: applyDimensionModeToSelected
-- ----------------------------------------------------------------
format "\n=== B4: applyDimensionModeToSelected ===\n"

if AmenoApp == undefined or AmenoDimensionCA == undefined then
(
    format "  [SKIP] AmenoApp nao disponivel\n"
)
else
(
    local r = AmenoDimensionGraphics.createDimension [0,0,0] [100,100,0] [50,80,0] role:"test"
    if r != undefined and r.controller != undefined then
    (
        select #(r.lineNode)
        local count = AmenoApp.applyDimensionModeToSelected #horizontal
        expectTrue "applyDimensionModeToSelected retornou > 0" (count >= 1)

        local rec = AmenoDimensionCA.readCA r.controller
        expect "modo gravado no CA" rec.dimensionMode "horizontal"
    )
    else
        format "  [SKIP] Falha ao criar cota de teste\n"
)

-- ----------------------------------------------------------------
-- BLOCO 5: bakeSelected - cota mundial nao e reprocessada
-- ----------------------------------------------------------------
format "\n=== B5: bakeSelected cota mundial ===\n"

if AmenoApp == undefined or AmenoDimensionCA == undefined then
(
    format "  [SKIP] AmenoApp nao disponivel\n"
)
else
(
    local r = AmenoDimensionGraphics.createDimension [0,0,0] [80,0,0] [40,25,0] role:"test"
    if r != undefined and r.controller != undefined then
    (
        -- Ja e mundial (anchorType = "world" por padrao sem nos)
        local recBefore = AmenoDimensionCA.readCA r.controller
        select #(r.controller)
        local countBake = AmenoApp.bakeSelected()
        -- Nao deve contar cotas ja mundiais
        local recAfter = AmenoDimensionCA.readCA r.controller
        expect "anchorType ainda world" recAfter.anchorType "world"
    )
    else
        format "  [SKIP] Falha ao criar cota de teste\n"
)

-- ----------------------------------------------------------------
-- RESULTADO
-- ----------------------------------------------------------------
format "\n=== RESULTADO E10.2 ===\n"
format "PASS: %  FAIL: %\n" passed failed

if failed > 0 do
(
    format "Testes falhos:\n"
    for e in errors do format "  - %\n" e
)

if failed == 0 then
    format "[AMENO_TEST][PASS] E10.2 lote e bake aprovados\n"
else
    format "E10.2 FAIL\n"
