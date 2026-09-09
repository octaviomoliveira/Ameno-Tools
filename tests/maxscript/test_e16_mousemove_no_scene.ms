/* E16.4 — 1.000 movimentos no caminho gw, sem picking pesado ou mutação. */
(
    global AmenoApp
    global AmenoDimensionContinuousTool
    global AmenoDimensionPlaneService
    global AmenoContinuousInputSample
    global AmenoContinuousOverlayService

    resetMaxFile #noPrompt
    local testPath = getFilenamePath (getSourceFileName())
    local repoRoot = pathConfig.normalizePath (pathConfig.appendPath testPath @"..\..")
    local bootstrapPath = pathConfig.normalizePath (pathConfig.appendPath repoRoot @"Contents\scripts\startup\ameno_bootstrap.ms")
    fileIn bootstrapPath quiet:true
    if AmenoApp == undefined then throw "AmenoApp não foi criado."

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
    fn e16mOk description value = (e16mEq description value true)

    fn sceneSnapshot =
    (
        local handles = for n in objects where isValidNode n collect n.handle
        local classes = for n in objects where isValidNode n collect ((classOf n) as string)
        local materialNames = for n in objects where isValidNode n collect
            (try (if n.material == undefined then "" else n.material.name) catch ("<error>"))
        local layerNames = #()
        try
        (
            for layerIndex = 0 to (LayerManager.count - 1) do
                append layerNames (LayerManager.getLayer layerIndex).name
        )
        catch ()
        local selectionHandles = for n in selection where isValidNode n collect n.handle
        #(handles, classes, materialNames, layerNames, selectionHandles)
    )

    fn callbackCount =
    (
        local callbacks = #()
        try (callbacks = showregisteredRedrawViewsCallbacks asArray:true) catch (callbacks = #())
        if callbacks == undefined then 0 else callbacks.count
    )

    fn snapshotEqual leftValue rightValue =
    (
        if leftValue == undefined or rightValue == undefined or leftValue.count != rightValue.count then return false
        for fieldIndex = 1 to leftValue.count do
        (
            local leftField = leftValue[fieldIndex]
            local rightField = rightValue[fieldIndex]
            if leftField == undefined or rightField == undefined then
            (
                if leftField != rightField do return false
            )
            else if leftField.count != rightField.count then
                return false
            else
                for itemIndex = 1 to leftField.count do
                    if leftField[itemIndex] != rightField[itemIndex] do return false
        )
        true
    )

    AmenoDimensionContinuousTool.removeAllPreviews()
    AmenoDimensionContinuousTool.previewBackend = #gw
    AmenoDimensionContinuousTool.active = true
    AmenoDimensionContinuousTool.stage = #collecting
    AmenoDimensionContinuousTool.activeMode = #horizontal
    AmenoDimensionContinuousTool.activePlaneMode = #worldXY
    AmenoDimensionContinuousTool.activePlane = AmenoDimensionPlaneService.worldXY()
    AmenoDimensionContinuousTool.sessionPlaneMode = #worldXY
    AmenoDimensionContinuousTool.sessionPlane = AmenoDimensionContinuousTool.activePlane
    AmenoDimensionContinuousTool.sessionMode = #horizontal
    AmenoDimensionContinuousTool.sessionStyleId = "default"
    AmenoDimensionContinuousTool.sessionOutputUnit = #meters
    AmenoDimensionContinuousTool.sessionPrecision = 2
    AmenoDimensionContinuousTool.inputSessionId = "e16-move"
    AmenoDimensionContinuousTool.points = #([0,0,0], [100,10,0], [220,-5,0])
    AmenoDimensionContinuousTool.anchorNodes = #(undefined, undefined, undefined)
    AmenoDimensionContinuousTool.anchorVertexIds = #(-1, -1, -1)
    AmenoDimensionContinuousTool.segmentPreviews = #()
    AmenoDimensionContinuousTool.activePreview = undefined
    AmenoDimensionContinuousTool.moveFullResolveCount = 0
    AmenoDimensionContinuousTool.moveSceneMutationCount = 0
    AmenoDimensionContinuousTool.moveAcceptedCount = 0
    AmenoContinuousOverlayService.beginSession "e16-move" style:undefined outputUnitValue:#meters precisionValue:2

    local before = sceneSnapshot()
    local callbacksBefore = callbackCount()
    local startedAt = timeStamp()
    for moveIndex = 1 to 1000 do
    (
        local sample = AmenoContinuousInputSample eventType:#mouseMove nativeClickNumber:1 \
            sessionId:"e16-move" sequence:moveIndex screenPoint:[moveIndex, 20] \
            rayStatus:#ok planeStatus:#ok planePoint:[(moveIndex as float) * 0.25, 80, 0] \
            snapHit:false snapStatus:#ok
        AmenoDimensionContinuousTool.handleHoverSample sample
    )
    local elapsedMs = (timeStamp() - startedAt) as float
    local after = sceneSnapshot()
    local callbacksAfter = callbackCount()
    local model = AmenoContinuousOverlayService.model

    e16mEq "backend exclusivo gw" AmenoDimensionContinuousTool.previewBackend #gw
    e16mEq "zero previews de nós" AmenoDimensionContinuousTool.segmentPreviews.count 0
    e16mEq "zero full resolve durante move" AmenoDimensionContinuousTool.moveFullResolveCount 0
    e16mEq "zero mutação contabilizada durante move" AmenoDimensionContinuousTool.moveSceneMutationCount 0
    e16mEq "modelo mantém N-1 segmentos" model.segments.count 2
    e16mEq "modelo mantém três referências" model.referencePoints.count 3
    e16mOk "no máximo um redraw por movimento" (AmenoContinuousOverlayService.redrawRequests <= 1000)
    e16mOk "revision não duplica hover/layout desnecessariamente" (model.revision <= 1001)
    e16mOk "snapshot de cena inalterado" (snapshotEqual after before)
    e16mOk "tempo dos 1.000 movimentos é finito" (elapsedMs == elapsedMs and elapsedMs >= 0.0 and elapsedMs < 60000.0)
    e16mEq "callback não foi duplicado pelo move" callbacksAfter callbacksBefore
    AmenoDimensionContinuousTool.cleanupSession clearDraft:true
    e16mOk "callback removido no cleanup" (callbackCount() <= callbacksBefore)
    e16mEq "overlay desabilitado no cleanup" AmenoContinuousOverlayService.enabled false

    format "=== [AMENO_E16_MOUSEMOVE] RESULT %/% PASS elapsedMs=% ===\n" passedTests totalTests elapsedMs
    if passedTests == totalTests then
        format "[AMENO_TEST][PASS] E16 mouseMove no-scene passed.\n"
    else
    (
        format "[AMENO_TEST][FAIL] E16 mouseMove no-scene failures=%\n" (totalTests - passedTests)
        throw ("E16 mouseMove no-scene failed: " + ((totalTests - passedTests) as string))
    )
    resetMaxFile #noPrompt
)
