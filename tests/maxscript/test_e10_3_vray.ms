-- =============================================================
-- E10.3 Tests: V-Ray CPU Renderer Adapter
-- Executado por 3dsmaxbatch.exe via tools\test-maxscript.ps1
-- =============================================================

global AmenoApp
global AmenoVRayRendererAdapter
global AmenoCoronaRendererAdapter
global AmenoRenderCotasService
global AmenoRenderCotasRequest
global AmenoRendererProbe

if AmenoVRayRendererAdapter == undefined do
(
    local testFile = getSourceFileName()
    local testPath = getFilenamePath testFile
    local repositoryRoot = pathConfig.normalizePath (pathConfig.appendPath testPath @"..\..")
    local bootstrapPath = pathConfig.normalizePath (pathConfig.appendPath repositoryRoot @"Contents\scripts\startup\ameno_bootstrap.ms")
    fileIn bootstrapPath quiet:true
)

(
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

format "\n=== B1: Existencia e contrato do AmenoVRayRendererAdapter ===\n"

expectTrue "AmenoVRayRendererAdapter definido" (AmenoVRayRendererAdapter != undefined)
if AmenoVRayRendererAdapter != undefined do
(
    expect "adapterId correto" AmenoVRayRendererAdapter.adapterId "vray-overlay-v1"
    expectTrue "possui metodo validate" (isProperty AmenoVRayRendererAdapter #validate)
    expectTrue "possui metodo captureState" (isProperty AmenoVRayRendererAdapter #captureState)
    expectTrue "possui metodo configureOutput" (isProperty AmenoVRayRendererAdapter #configureOutput)
    expectTrue "possui metodo restore" (isProperty AmenoVRayRendererAdapter #restore)
    expectTrue "possui metodo createAnnotationMaterial" (isProperty AmenoVRayRendererAdapter #createAnnotationMaterial)
    expectTrue "possui metodo renderOverlay" (isProperty AmenoVRayRendererAdapter #renderOverlay)
    expectTrue "possui metodo verifyOutput" (isProperty AmenoVRayRendererAdapter #verifyOutput)
)

format "\n=== B2: Validacao de request no adapter V-Ray ===\n"

if AmenoVRayRendererAdapter != undefined do
(
    -- Validacao com request undefined deve disparar excecao
    local threwUndefined = false
    try (AmenoVRayRendererAdapter.validate undefined) catch (threwUndefined = true)
    expectTrue "request undefined dispara excecao" threwUndefined

    -- Validacao com extensao diferente de PNG deve disparar excecao
    if AmenoRenderCotasRequest != undefined do
    (
        local reqJpg = AmenoRenderCotasRequest outputPath:"c:\\teste\\overlay.jpg"
        local threwJpg = false
        try (AmenoVRayRendererAdapter.validate reqJpg) catch (threwJpg = true)
        expectTrue "arquivo nao-PNG dispara excecao" threwJpg
    )
)

format "\n=== B3: Captura e restauracao de estado ===\n"

if AmenoVRayRendererAdapter != undefined do
(
    local st = AmenoVRayRendererAdapter.captureState()
    expectTrue "captureState retorna struct valida" (st != undefined)
    expectTrue "state possui campo pngAlpha" (isProperty st #pngAlpha)
    expectTrue "state possui campo savedOutputPath" (isProperty st #savedOutputPath)

    local restoredOk = false
    try (restoredOk = AmenoVRayRendererAdapter.restore st) catch ()
    expectTrue "restore executa com sucesso" restoredOk
)

format "\n=== B4: Despacho dinamico no AmenoRenderCotasService ===\n"

if AmenoRenderCotasService != undefined do
(
    expectTrue "possui resolveDefaultAdapter" (isProperty AmenoRenderCotasService #resolveDefaultAdapter)
    local resolved = AmenoRenderCotasService.resolveDefaultAdapter()
    expectTrue "resolveDefaultAdapter retorna adapter valido" (resolved != undefined)
)

format "\n=== RESULTADO E10.3 ===\n"
format "PASS: %  FAIL: %\n" passed failed

if failed > 0 do
(
    format "Testes falhos:\n"
    for e in errors do format "  - %\n" e
)

if failed == 0 then
(
    format "[AMENO_TEST][PASS] E10.3 V-Ray adapter tests passed\n"
)
else
(
    format "E10.3 FAIL\n"
)
)
