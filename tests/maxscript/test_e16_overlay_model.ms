/* E16.3 — OverlayModel puro: sem nós, sem picking e sem viewport side effects. */
(
    global AmenoApp
    global AmenoDimensionChainMath
    global AmenoDimensionPlaneService
    global AmenoContinuousOverlayService
    global AmenoContinuousOverlayStyleSnapshot
    global AmenoStyleRecord

    resetMaxFile #noPrompt
    local testPath = getFilenamePath (getSourceFileName())
    local repoRoot = pathConfig.normalizePath (pathConfig.appendPath testPath @"..\..")
    local bootstrapPath = pathConfig.normalizePath (pathConfig.appendPath repoRoot @"Contents\scripts\startup\ameno_bootstrap.ms")
    fileIn bootstrapPath quiet:true
    if AmenoApp != undefined do AmenoApp.prepareScene()

    local totalTests = 0
    local passedTests = 0

    fn e16mEq description actual expected =
    (
        totalTests += 1
        if actual == expected then
        (
            passedTests += 1
            format "[PASS] %\n" description
        )
        else format "[FAIL] % expected=<%> actual=<%>\n" description expected actual
    )

    fn e16mOk description value = e16mEq description value true

    local plane = AmenoDimensionPlaneService.worldXY()
    local points = #([0,0,0], [100,10,0], [220,-5,0])
    local layout = AmenoDimensionChainMath.layout points [100,80,0] mode:#horizontal plane:plane
    e16mOk "chain layout válido" (layout != undefined and layout.valid)
    e16mEq "chain possui N-1 segmentos" layout.segments.count 2

    AmenoContinuousOverlayService.beginSession "e16-model" style:undefined outputUnitValue:#meters precisionValue:2
    local model = AmenoContinuousOverlayService.buildModel points layout
    e16mOk "builder devolve modelo" (model != undefined and model.visible)
    e16mEq "modelo preserva sessão" model.sessionId "e16-model"
    e16mEq "modelo preserva referências" model.referencePoints.count 3
    e16mEq "modelo possui N-1 segmentos" model.segments.count 2
    e16mOk "segmento tem linha" (model.segments[1].linePointA != undefined and model.segments[1].linePointB != undefined)
    e16mOk "segmento tem extensões" (model.segments[1].extensionA != undefined and model.segments[1].extensionB != undefined)
    e16mOk "segmento tem rótulo" (model.segments[1].labelText != undefined and model.segments[1].labelText != "")
    e16mEq "tick cria um primitivo por terminal" model.segments[1].terminalA.count 1
    e16mEq "tick cria terminal B" model.segments[1].terminalB.count 1

    local beforeObjects = objects.count
    AmenoContinuousOverlayService.publishLayout points layout
    local publishedModel = AmenoContinuousOverlayService.model
    e16mEq "publicação não cria nós" objects.count beforeObjects
    e16mEq "publicação mantém segmentos" publishedModel.segments.count 2
    e16mOk "revision é positiva" (publishedModel.revision > 0)
    local stableRevision = publishedModel.revision
    AmenoContinuousOverlayService.publishLayout points layout
    e16mEq "publicação idêntica não incrementa revision" AmenoContinuousOverlayService.model.revision stableRevision

    local arrowStyle = AmenoStyleRecord styleId:"e16-arrow" terminalType:#arrowOpen terminalSize:60.0 extensionGap:15.0 extensionOverhang:40.0 textGap:25.0 annotationColor:"10,20,30"
    local arrowSnapshot = AmenoContinuousOverlayService.snapshotStyle arrowStyle outputUnitValue:#centimeters precisionValue:1
    local arrowModel = AmenoContinuousOverlayService.buildModel points layout snapshotValue:arrowSnapshot
    e16mEq "arrow open cria primitivo A" arrowModel.segments[1].terminalA[1].kind #polyline
    e16mEq "arrow open cria primitivo B" arrowModel.segments[1].terminalB[1].kind #polyline
    e16mEq "snapshot preserva unidade" arrowSnapshot.outputUnit #centimeters
    e16mEq "snapshot preserva precisão" arrowSnapshot.precision 1

    local closedSnapshot = AmenoContinuousOverlayService.snapshotStyle (AmenoStyleRecord styleId:"e16-closed" terminalType:#arrowClosed terminalSize:60.0) outputUnitValue:#meters precisionValue:2
    local closedModel = AmenoContinuousOverlayService.buildModel points layout snapshotValue:closedSnapshot
    e16mEq "arrow closed cria polígono A" closedModel.segments[1].terminalA[1].kind #polygon
    e16mEq "arrow closed cria polígono B" closedModel.segments[1].terminalB[1].kind #polygon

    local dotSnapshot = AmenoContinuousOverlayService.snapshotStyle (AmenoStyleRecord styleId:"e16-dot" terminalType:#dot terminalSize:60.0) outputUnitValue:#meters precisionValue:2
    local dotModel = AmenoContinuousOverlayService.buildModel points layout snapshotValue:dotSnapshot
    e16mEq "dot cria marker A" dotModel.segments[1].terminalA[1].kind #marker
    e16mEq "dot cria marker B" dotModel.segments[1].terminalB[1].kind #marker

    local noneSnapshot = AmenoContinuousOverlayService.snapshotStyle (AmenoStyleRecord styleId:"e16-none" terminalType:#none) outputUnitValue:#meters precisionValue:2
    local noneModel = AmenoContinuousOverlayService.buildModel points layout snapshotValue:noneSnapshot
    e16mEq "none não cria terminal A" noneModel.segments[1].terminalA.count 0
    e16mEq "none não cria terminal B" noneModel.segments[1].terminalB.count 0

    local invalidModelBefore = AmenoContinuousOverlayService.model.revision
    AmenoContinuousOverlayService.publishLayout points (AmenoDimensionChainLayout valid:false errorCode:#invalidPoint errorMessage:"fixture")
    e16mEq "layout inválido não mantém segmentos" AmenoContinuousOverlayService.model.segments.count 0
    e16mOk "layout inválido avança revision" (AmenoContinuousOverlayService.model.revision > invalidModelBefore)
    AmenoContinuousOverlayService.clearSession()

    format "=== [AMENO_E16_OVERLAY_MODEL] RESULT %/% PASS ===\n" passedTests totalTests
    if passedTests == totalTests then
        format "[AMENO_TEST][PASS] E16 overlay model passed.\n"
    else
    (
        format "[AMENO_TEST][FAIL] E16 overlay model failures=%\n" (totalTests - passedTests)
        throw ("E16 overlay model failed: " + ((totalTests - passedTests) as string))
    )
    resetMaxFile #noPrompt
)
