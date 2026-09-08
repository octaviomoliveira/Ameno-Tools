/*
    E14.1 — contrato geométrico de planos U/V/N.
    Executado por 3dsmaxbatch.exe via tools\test-maxscript.ps1.
*/

global AmenoDimensionPlaneService
global AmenoDimensionMath
global AmenoContinuousInputResolver
global AmenoDimensionCA
global AmenoDimensionRecord

(
    local testFile = getSourceFileName()
    local testPath = getFilenamePath testFile
    local repositoryRoot = pathConfig.normalizePath (pathConfig.appendPath testPath @"..\..")
    local bootstrapPath = pathConfig.normalizePath (pathConfig.appendPath repositoryRoot @"Contents\scripts\startup\ameno_bootstrap.ms")
    fileIn bootstrapPath quiet:true

    if AmenoDimensionPlaneService == undefined then throw "E14.1: serviço de planos não foi carregado pelo bootstrap."
    if AmenoDimensionMath == undefined then throw "E14.1: matemática de cotas não foi carregada pelo bootstrap."

    local passed = 0
    local failed = 0
    local errors = #()

    fn expect label actual expected =
    (
        if actual == expected then passed += 1
        else
        (
            failed += 1
            append errors label
            format "[FAIL] % | esperado=% obtido=%\n" label expected actual
        )
    )

    fn expectTrue label actual =
    (
        expect label actual true
    )

    fn expectNear label actual expected tolerance:0.0001 =
    (
        if actual != undefined and (abs (actual - expected)) <= tolerance then passed += 1
        else
        (
            failed += 1
            append errors label
            format "[FAIL] % | esperado=% obtido=%\n" label expected actual
        )
    )

    fn expectPoint label actual expected tolerance:0.0001 =
    (
        if actual != undefined and (length (actual - expected)) <= tolerance then passed += 1
        else
        (
            failed += 1
            append errors label
            format "[FAIL] % | esperado=% obtido=%\n" label expected actual
        )
    )

    local xy = AmenoDimensionPlaneService.worldXY()
    expectTrue "worldXY valido" xy.valid
    expect "worldXY tipo" xy.planeType #worldXY
    expectPoint "worldXY projecta Z fora do plano" (AmenoDimensionPlaneService.project xy [3,4,7]) [3,4,0]
    local xyCoords = AmenoDimensionPlaneService.coordinatesOf xy [3,4,7]
    expectPoint "worldXY coordenadas preservam profundidade" xyCoords [3,4,7]

    local front = AmenoDimensionPlaneService.standardForViewType #view_front
    expectTrue "front valido" front.valid
    expectPoint "front U direita" front.axisU [1,0,0]
    expectPoint "front V altura" front.axisV [0,0,1]
    expectPoint "front normal" front.normal [0,-1,0]
    expect "topo não é fachada" (AmenoDimensionPlaneService.standardForViewType #view_top).errorCode #unsupportedViewport
    expect "inferior não é fachada" (AmenoDimensionPlaneService.standardForViewType #view_bottom).errorCode #unsupportedViewport

    local frontRay = ray [0, 5, 20] [0, -1, 0]
    expectPoint "raio intersecta plano da fachada" (AmenoContinuousInputResolver.intersectRayWithPlane frontRay plane:front) [0,0,20]

    local pointA = [0,2,10]
    local pointB = [100,9,40]
    local offset = [50,0,20]
    local horizontal = AmenoDimensionMath.layoutForMode pointA pointB offset mode:#horizontal millimetersPerSceneUnit:1.0 plane:front
    expectTrue "fachada horizontal valida" horizontal.valid
    expectNear "fachada horizontal mede largura" horizontal.measuredSceneUnits 100.0
    expectPoint "fachada horizontal linha A" horizontal.linePointA [0,0,20]
    expectPoint "fachada horizontal linha B" horizontal.linePointB [100,0,20]
    expectPoint "fachada horizontal eixo" horizontal.direction [1,0,0]
    expectPoint "fachada horizontal perpendicular" horizontal.perpendicular [0,0,1]

    local vertical = AmenoDimensionMath.layoutForMode pointA pointB offset mode:#vertical millimetersPerSceneUnit:1.0 plane:front
    expectTrue "fachada vertical valida" vertical.valid
    expectNear "fachada vertical mede altura" vertical.measuredSceneUnits 30.0
    expectPoint "fachada vertical linha A" vertical.linePointA [50,0,10]
    expectPoint "fachada vertical linha B" vertical.linePointB [50,0,40]
    expectPoint "fachada vertical eixo" vertical.direction [0,0,1]

    local aligned = AmenoDimensionMath.layoutForMode pointA pointB offset mode:#aligned millimetersPerSceneUnit:1.0 plane:front
    expectTrue "fachada alinhada valida" aligned.valid
    expectNear "fachada alinhada mede no plano" aligned.measuredSceneUnits (sqrt (10000.0 + 900.0))
    expect "fachada layout guarda tipo" aligned.planeType #viewPlane
    expectPoint "fachada layout guarda normal" aligned.planeNormal [0,-1,0]

    local angle = 30.0
    local rotatedU = [cos angle, sin angle, 0]
    local rotatedV = [-sin angle, cos angle, 0]
    local rotated = AmenoDimensionPlaneService.make [10,20,5] rotatedU rotatedV [0,0,1] planeTypeValue:#viewPlane orientationLabelValue:"Fachada girada"
    expectTrue "plano rotacionado valido" rotated.valid
    local rotatedA = rotated.origin + (rotated.axisU * 100.0) + (rotated.axisV * 20.0) + (rotated.normal * 7.0)
    local rotatedB = rotated.origin + (rotated.axisU * 100.0) + (rotated.axisV * 70.0) + (rotated.normal * -4.0)
    local rotatedOffset = rotated.origin + (rotated.axisU * 130.0) + (rotated.axisV * 40.0) + (rotated.normal * 99.0)
    local rotatedVertical = AmenoDimensionMath.layoutForMode rotatedA rotatedB rotatedOffset mode:#vertical millimetersPerSceneUnit:1.0 plane:rotated
    expectTrue "plano rotacionado vertical valido" rotatedVertical.valid
    expectNear "plano rotacionado mede no eixo V" rotatedVertical.measuredSceneUnits 50.0
    expectPoint "plano rotacionado projeta linha A" rotatedVertical.linePointA (rotated.origin + (rotated.axisU * 130.0) + (rotated.axisV * 20.0))

    local invalid = AmenoDimensionPlaneService.make [0,0,0] [1,0,0] [1,0,0] [0,0,1]
    expect "base não ortogonal invalida" invalid.errorCode #nonOrthonormalBasis
    local wrongNormal = AmenoDimensionPlaneService.make [0,0,0] [1,0,0] [0,1,0] [0,0,-1]
    expect "normal com sinal errado invalida" wrongNormal.errorCode #invalidHandedness
    local zeroAxis = AmenoDimensionPlaneService.make [0,0,0] [0,0,0] [0,1,0] [0,0,1]
    expect "eixo zero invalida" zeroAxis.errorCode #invalidBasis
    local unknownType = AmenoDimensionPlaneService.make [0,0,0] [1,0,0] [0,1,0] [0,0,1] planeTypeValue:#unsupported
    expect "tipo de plano desconhecido invalida" unknownType.errorCode #unsupportedPlaneType
    local invalidRecord = AmenoDimensionRecord schemaVersion:6 planeAxisU:[1,0,0] planeAxisV:[1,0,0] planeNormal:[0,0,1]
    expect "CA v6 inválido não cai em XY" (AmenoDimensionCA.recordPlane invalidRecord).errorCode #nonOrthonormalBasis

    format "=== [AMENO_E14_1] RESULT %/% PASS ===\n" passed (passed + failed)
    if failed == 0 then
        format "[AMENO_TEST][PASS] E14.1 plane math passed.\n"
    else
    (
        format "[AMENO_TEST][FAIL] E14.1 failures=%\n" failed
        for label in errors do format "  - %\n" label
        throw ("E14.1 failed: " + (failed as string))
    )
)
