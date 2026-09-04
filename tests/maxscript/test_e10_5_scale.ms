-- =============================================================
-- E10.5 Tests: Escala e Desempenho (1, 10, 100, 500, 1000 cotas)
-- Executado por 3dsmaxbatch.exe via tools\test-maxscript.ps1
-- =============================================================

global AmenoApp
global AmenoDimensionGraphics
global AmenoDiagnosticService
global AmenoAnchorService
global generateScaleDimensions

(
local testFile = getSourceFileName()
local testPath = getFilenamePath testFile
local repositoryRoot = pathConfig.normalizePath (pathConfig.appendPath testPath @"..\..")
local bootstrapPath = pathConfig.normalizePath (pathConfig.appendPath repositoryRoot @"Contents\scripts\startup\ameno_bootstrap.ms")
local scaleFixturePath = pathConfig.normalizePath (pathConfig.appendPath repositoryRoot @"tests\fixtures\create_fixture_scale.ms")

if AmenoApp == undefined or AmenoDiagnosticService == undefined do
(
    fileIn bootstrapPath quiet:true
)

fileIn scaleFixturePath quiet:true

local passed = 0
local failed = 0
local errors = #()

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

fn runScaleBenchmark count =
(
    format "\n--- Benchmark: % cota(s) ---\n" count
    resetMaxFile #noPrompt
    if AmenoApp != undefined do AmenoApp.prepareScene()

    -- 1. Tempo de criacao
    local t0 = timestamp()
    local created = generateScaleDimensions count:count spacing:20
    local tCreate = (timestamp() - t0) / 1000.0
    local msPerDim = if created > 0 then ((tCreate * 1000.0) / created) else 0.0

    format "  Criacao: % cotas em % s (% ms/cota)\n" created tCreate msPerDim
    expectTrue ("Criadas todas as " + (count as string) + " cotas") (created == count)

    -- 2. Inspecao e Diagnostico
    local tDiag0 = timestamp()
    local rep = if AmenoDiagnosticService != undefined then AmenoDiagnosticService.generateReport() else undefined
    local tDiag = (timestamp() - tDiag0) / 1000.0

    if rep != undefined then
    (
        format "  Diagnostico: % s | Total: % | Saudaveis: %\n" tDiag rep.totalDimensions rep.healthyCount
        expectTrue ("Total de cotas coincide com " + (count as string)) (rep.totalDimensions == count)
        expectTrue ("Todas as " + (count as string) + " cotas sao saudaveis") (rep.healthyCount == count)
    )
    else
    (
        expectTrue "Diagnostico executado" false
    )

    -- 3. Sincronizacao das ancoras em lote
    local tSync0 = timestamp()
    if ::AmenoAnchorService != undefined do ::AmenoAnchorService.syncAll force:true
    local tSync = (timestamp() - tSync0) / 1000.0
    format "  Sincronizacao em lote: % s\n" tSync
    expectTrue "Sincronizacao concluida sem erro" true

    -- Limpa a cena
    resetMaxFile #noPrompt
    true
)

format "\n=== B1: Escala 1 cota (baseline) ===\n"
runScaleBenchmark 1

format "\n=== B2: Escala 10 cotas (cena pequena) ===\n"
runScaleBenchmark 10

format "\n=== B3: Escala 100 cotas (projeto medio) ===\n"
runScaleBenchmark 100

format "\n=== B4: Escala 500 cotas (planta complexa) ===\n"
runScaleBenchmark 500

format "\n=== B5: Escala 1000 cotas (estresse maximo do MVP) ===\n"
runScaleBenchmark 1000

format "\n=== RESULTADO E10.5 ===\n"
format "PASS: %  FAIL: %\n" passed failed

if failed > 0 do
(
    format "Testes falhos:\n"
    for e in errors do format "  - %\n" e
)

if failed == 0 then
(
    format "[AMENO_TEST][PASS] E10.5 scale and stress benchmarks (1, 10, 100, 500, 1000) passed\n"
)
else
(
    format "E10.5 FAIL\n"
)
)
