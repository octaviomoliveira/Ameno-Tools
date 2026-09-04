-- =============================================================
-- E10.4 Tests: Diagnostico de Cena e Cenas-Fixture
-- Executado por 3dsmaxbatch.exe via tools\test-maxscript.ps1
-- =============================================================

global AmenoApp
global AmenoDiagnosticService
global AmenoDiagnosticReport

(
local testFile = getSourceFileName()
local testPath = getFilenamePath testFile
local repositoryRoot = pathConfig.normalizePath (pathConfig.appendPath testPath @"..\..")
local bootstrapPath = pathConfig.normalizePath (pathConfig.appendPath repositoryRoot @"Contents\scripts\startup\ameno_bootstrap.ms")
local fixturePath = pathConfig.normalizePath (pathConfig.appendPath repositoryRoot @"tests\fixtures\create_fixture_architecture_plan.ms")

if AmenoApp == undefined or AmenoDiagnosticService == undefined do
(
    fileIn bootstrapPath quiet:true
)

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

format "\n=== B1: Existencia do AmenoDiagnosticService ===\n"

expectTrue "AmenoDiagnosticService definido" (AmenoDiagnosticService != undefined)
expectTrue "possui generateReport" (isProperty AmenoDiagnosticService #generateReport)
expectTrue "possui printReport" (isProperty AmenoDiagnosticService #printReport)
expectTrue "possui exportReportToFile" (isProperty AmenoDiagnosticService #exportReportToFile)

format "\n=== B2: Execucao da Fixture Arquitetonica ===\n"

local fixtureOk = false
try
(
    fileIn fixturePath quiet:true
    fixtureOk = true
)
catch
(
    format "Erro ao carregar fixture: %\n" (getCurrentException() as string)
)
expectTrue "fixture arquitetonica executada com sucesso" fixtureOk

format "\n=== B3: Geracao e Auditoria do Relatorio de Diagnostico ===\n"

if AmenoDiagnosticService != undefined do
(
    local rep = AmenoDiagnosticService.generateReport()
    expectTrue "generateReport retornou objeto valido" (rep != undefined)
    expect "total de 6 cotas na fixture" rep.totalDimensions 6
    expectTrue "possui cotas saudaveis" (rep.healthyCount >= 5)
    expectTrue "possui cotas alinhadas" (rep.alignedCount >= 3)
    expectTrue "possui cotas horizontais" (rep.horizontalCount >= 1)
    expectTrue "possui cotas verticais" (rep.verticalCount >= 2)
    expectTrue "possui cotas com ancoras em objetos" (rep.nodeAAnchorCount >= 2)
    expectTrue "possui cotas com ambas as ancoras" (rep.bothAnchorCount >= 1)
    expectTrue "possui cotas com override manual" (rep.manualCount >= 1)

    -- Testa texto do relatorio
    local reportText = rep.summaryText()
    expectTrue "relatorio contem cabecalho esperado" (matchPattern reportText pattern:"*AMENO TOOLS - RELAT*")
    expectTrue "relatorio contem secao de modos" (matchPattern reportText pattern:"*MODOS:*")
    expectTrue "relatorio contem secao de ancoras" (matchPattern reportText pattern:"*NCORAS:*")
)

format "\n=== B4: Exportacao para Arquivo de Texto ===\n"

if AmenoDiagnosticService != undefined do
(
    local tempReportPath = pathConfig.appendPath (getDir #temp) "ameno_test_report.txt"
    deleteFile tempReportPath
    local exported = AmenoDiagnosticService.exportReportToFile tempReportPath
    expectTrue "exportReportToFile retornou true" exported
    expectTrue "arquivo de relatorio foi criado" (doesFileExist tempReportPath)
    deleteFile tempReportPath
)

format "\n=== RESULTADO E10.4 ===\n"
format "PASS: %  FAIL: %\n" passed failed

if failed > 0 do
(
    format "Testes falhos:\n"
    for e in errors do format "  - %\n" e
)

if failed == 0 then
(
    format "[AMENO_TEST][PASS] E10.4 diagnostics and fixture tests passed\n"
)
else
(
    format "E10.4 FAIL\n"
)
)
