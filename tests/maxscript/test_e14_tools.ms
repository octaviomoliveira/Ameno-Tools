/* E14.4/E14.5 — fluxos individual e contínuo em uma fachada congelada. */
(
    global AmenoApp
    global AmenoDimensionPlaneService
    global AmenoDimensionTool
    global AmenoDimensionContinuousTool
    global AmenoContinuousClickClassification
    global AmenoDimensionGraphics
    global AmenoDimensionCA
    global AmenoAnchorService
    global AmenoUnitService

    local testFile = getSourceFileName()
    local testPath = getFilenamePath testFile
    local repositoryRoot = pathConfig.normalizePath (pathConfig.appendPath testPath @"..\..")
    local bootstrapPath = pathConfig.normalizePath (pathConfig.appendPath repositoryRoot @"Contents\scripts\startup\ameno_bootstrap.ms")
    fileIn bootstrapPath quiet:true

    resetMaxFile #noPrompt
    local sceneState = AmenoApp.prepareScene()
    if sceneState.status != #ready then throw "E14 tools: cena não preparada."

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

    fn expectTrue label value = expect label value true

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

    local front = AmenoDimensionPlaneService.standardForViewType #view_front
    expectTrue "plano frontal disponível" front.valid

    /* Individual: three clicks keep the real world Z, while the layout uses X/Z. */
    AmenoDimensionTool.cancel()
    AmenoDimensionTool.setActivePlaneMode #viewPlane
    AmenoDimensionTool.activeMode = #horizontal
    AmenoDimensionTool.activePlane = front
    AmenoDimensionTool.active = true
    AmenoDimensionTool.stage = #pointA
    local individualA = [0, 8, 10]
    local individualB = [100, 3, 40]
    local individualOffset = [50, 0, 20]
    AmenoDimensionTool.handlePoint 1 individualA
    AmenoDimensionTool.handlePoint 2 individualB
    local individualOutcome = AmenoDimensionTool.handlePoint 3 individualOffset
    expect "cota individual encerra no terceiro clique" individualOutcome #stop
    local individualResult = AmenoDimensionTool.lastCommittedRecord
    expectTrue "resultado individual existe" (individualResult != undefined and individualResult.controller != undefined)
    local individualRecord = AmenoDimensionCA.readCA individualResult.controller
    expect "individual persiste fachada" individualRecord.planeType "viewPlane"
    expectPoint "individual preserva snap A 3D" individualRecord.pointA individualA
    expectNear "individual mede largura projetada" (AmenoDimensionGraphics.getDimensionAudit individualResult.controller).measuredMillimeters (100.0 * AmenoUnitService.currentMillimetersPerSceneUnit())
    local individualRebuild = AmenoDimensionGraphics.rebuildDimension individualResult.controller
    expectPoint "individual rebuild mantém linha no XZ" individualRebuild.layout.linePointA [0, 0, 20]
    AmenoDimensionTool.onStop()

    local individualId = individualResult.dimensionId
    AmenoDimensionGraphics.deleteNodes (AmenoDimensionGraphics.findNodesForDimension individualId)

    /* Continuous: all segments share an absolute V baseline in the facade. */
    fn makeAnchor nameValue positionValue =
    (
        local nodeValue = box name:nameValue length:10 width:10 height:10 pos:positionValue
        convertToPoly nodeValue
        #(nodeValue, AmenoDimensionCA.resolveVertexWorld nodeValue 1)
    )

    local anchorA = makeAnchor "E14_TOOLS_A" [0, 0, 0]
    local anchorB = makeAnchor "E14_TOOLS_B" [100, 0, 25]
    local anchorC = makeAnchor "E14_TOOLS_C" [200, 0, 10]

    AmenoDimensionContinuousTool.cancel()
    AmenoDimensionContinuousTool.setActivePlaneMode #viewPlane
    AmenoDimensionContinuousTool.activePlane = front
    AmenoDimensionContinuousTool.sessionPlane = front
    AmenoDimensionContinuousTool.sessionPlaneMode = #viewPlane
    AmenoDimensionContinuousTool.activeMode = #horizontal
    AmenoDimensionContinuousTool.sessionMode = #horizontal
    AmenoDimensionContinuousTool.active = true
    AmenoDimensionContinuousTool.stage = #collecting
    AmenoDimensionContinuousTool.points = #()
    AmenoDimensionContinuousTool.anchorNodes = #()
    AmenoDimensionContinuousTool.anchorVertexIds = #()
    AmenoDimensionContinuousTool.segmentPreviews = #()
    AmenoDimensionContinuousTool.lastSessionIds = #()
    AmenoDimensionContinuousTool.lastResult = #collecting

    fn addFacadeReference anchorValue =
    (
        local clickValue = AmenoContinuousClickClassification kind:#reference node:anchorValue[1] vertexId:1 worldPoint:anchorValue[2]
        AmenoDimensionContinuousTool.handleClassifiedClick clickValue
    )

    expect "contínua adiciona A" (addFacadeReference anchorA) #referenceAdded
    expect "contínua adiciona B" (addFacadeReference anchorB) #referenceAdded
    expect "contínua adiciona C" (addFacadeReference anchorC) #referenceAdded

    local facadeOffset = [100, 0, 60]
    expectTrue "preview contínuo fachada" (AmenoDimensionContinuousTool.refreshChainPreview facadeOffset)
    local facadeLayout = AmenoDimensionContinuousTool.lastChainLayout
    expect "cadeia usa baseline absoluto" facadeLayout.baselinePolicy "fixedPlaneBaseline"
    local facadeCoords = AmenoDimensionPlaneService.coordinatesOf (AmenoDimensionContinuousTool.effectivePlane()) facadeOffset
    expectNear "cadeia guarda V absoluto" facadeLayout.baselineCoordinate facadeCoords.y
    for previewValue in AmenoDimensionContinuousTool.segmentPreviews do
        expectNear "preview compartilha baseline Z" previewValue.layout.linePointA.z facadeOffset.z

    local emptyFacade = AmenoContinuousClickClassification kind:#empty worldPoint:facadeOffset
    expect "contínua fachada faz commit" (AmenoDimensionContinuousTool.handleClassifiedClick emptyFacade commitNow:true) #chainCommitted
    local controllers = AmenoDimensionGraphics.findControllers role:"interactive"
    expect "contínua cria dois segmentos" controllers.count 2
    local baselineValue = facadeCoords.y
    for controllerValue in controllers do
    (
        local recordValue = AmenoDimensionCA.readCA controllerValue
        expect "segmento persiste plano frontal" recordValue.planeType "viewPlane"
        expect "segmento persiste política fixa" recordValue.baselinePolicy "fixedPlaneBaseline"
        expectNear "segmento persiste baseline comum" recordValue.baselineCoordinate baselineValue
        expectPoint "segmento persiste afastamento no plano" recordValue.offsetPoint facadeOffset
        local rebuiltValue = AmenoDimensionGraphics.rebuildDimension controllerValue
        expectNear "rebuild preserva baseline" rebuiltValue.layout.linePointA.z facadeOffset.z
    )

    /* Move the middle vertex perpendicular to the measured axis: baseline stays fixed. */
    local anchorBase = anchorB[1].baseObject
    local oldLocal = polyOp.getVert anchorBase 1
    local changedSet = #{1}
    polyOp.setVert anchorBase changedSet (oldLocal + [0, 0, 30])
    update anchorB[1]
    AmenoAnchorService.rebuildIndex()
    for controllerValue in controllers do AmenoAnchorService.syncDimension controllerValue
    for controllerValue in controllers do
    (
        local movedRecord = AmenoDimensionCA.readCA controllerValue
        expectNear "movimento não transporta baseline" movedRecord.baselineCoordinate baselineValue
        local movedLayout = AmenoDimensionGraphics.rebuildDimension controllerValue
        expectNear "movimento mantém linha comum" movedLayout.layout.linePointA.z facadeOffset.z
    )

    format "=== [AMENO_E14_TOOLS] RESULT %/% PASS ===\n" passed (passed + failed)
    if failed == 0 then
        format "[AMENO_TEST][PASS] E14 individual and continuous facade flows passed.\n"
    else
    (
        format "[AMENO_TEST][FAIL] E14 tools failures=%\n" failed
        for label in errors do format "  - %\n" label
        throw ("E14 tools failed: " + (failed as string))
    )
)
