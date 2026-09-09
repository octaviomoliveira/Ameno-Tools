/* E16.6/E16.7 — commit preparado: 7 segmentos, uma transação e rollback. */
(
    global AmenoApp
    global AmenoDimensionContinuousTool
    global AmenoDimensionGraphics
    global AmenoContinuousOverlayService
    global AmenoDimensionPlaneService

    resetMaxFile #noPrompt
    local testPath = getFilenamePath (getSourceFileName())
    local repoRoot = pathConfig.normalizePath (pathConfig.appendPath testPath @"..\..")
    local bootstrapPath = pathConfig.normalizePath (pathConfig.appendPath repoRoot @"Contents\scripts\startup\ameno_bootstrap.ms")
    fileIn bootstrapPath quiet:true
    AmenoApp.prepareScene()

    local totalTests = 0
    local passedTests = 0
    fn e16pEq description actual expected =
    (
        totalTests += 1
        if actual == expected then
        (
            passedTests += 1
            format "[PASS] %\n" description
        )
        else format "[FAIL] % expected=<%> actual=<%>\n" description expected actual
    )
    fn e16pOk description value = (e16pEq description value true)

    fn resetToolForChain =
    (
        try (AmenoDimensionContinuousTool.cleanupSession clearDraft:true) catch ()
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
        AmenoDimensionContinuousTool.inputSessionId = "e16-perf"
        AmenoDimensionContinuousTool.points = #([0,0,0], [100,10,0], [220,-5,0], [340,20,0], [470,0,0], [590,30,0], [730,5,0], [860,35,0])
        AmenoDimensionContinuousTool.anchorNodes = #(undefined,undefined,undefined,undefined,undefined,undefined,undefined,undefined)
        AmenoDimensionContinuousTool.anchorVertexIds = #(-1,-1,-1,-1,-1,-1,-1,-1)
        AmenoDimensionContinuousTool.segmentPreviews = #()
        AmenoDimensionContinuousTool.activePreview = undefined
        AmenoDimensionContinuousTool.lastError = ""
        AmenoDimensionContinuousTool.lastResult = #collecting
        AmenoDimensionContinuousTool.moveFullResolveCount = 0
        AmenoDimensionContinuousTool.moveSceneMutationCount = 0
        AmenoDimensionContinuousTool.moveAcceptedCount = 0
        AmenoContinuousOverlayService.beginSession "e16-perf" style:undefined outputUnitValue:#meters precisionValue:2
        true
    )

    fn interactiveControllerCount = (AmenoDimensionGraphics.findControllers role:"interactive").count

    clearUndoBuffer()
    resetToolForChain()
    e16pOk "preview gw para 7 segmentos" (AmenoDimensionContinuousTool.refreshChainPreview [100,100,0])
    e16pEq "overlay possui 7 segmentos" AmenoContinuousOverlayService.model.segments.count 7
    e16pEq "preview contínuo não possui nós" AmenoDimensionContinuousTool.segmentPreviews.count 0
    local beforeControllers = interactiveControllerCount()
    local startedAt = timeStamp()
    e16pOk "commit preparado conclui" (AmenoDimensionContinuousTool.commitChain [100,100,0])
    local totalMs = (timeStamp() - startedAt) as float
    local afterControllers = interactiveControllerCount()
    e16pEq "commit cria sete controllers" (afterControllers - beforeControllers) 7
    e16pEq "commit registra sete ids" AmenoDimensionContinuousTool.lastSessionIds.count 7
    e16pOk "tempo total é finito" (totalMs == totalMs and totalMs >= 0.0)
    e16pOk "meta de 7 segmentos <= 5s" (totalMs <= 5000.0)
    e16pOk "nenhum segmento excede 1s (proxy total/7)" ((totalMs / 7.0) <= 1000.0)
    format "[E16_PERF] segments=7 totalMs=% averageMs=% prepareContext=shared\n" totalMs (totalMs / 7.0)

    max undo
    e16pEq "um Undo remove a cadeia inteira" (interactiveControllerCount()) beforeControllers
    max redo
    e16pEq "um Redo restaura a cadeia inteira" (interactiveControllerCount()) (beforeControllers + 7)

    with undo off
    (
        for controllerValue in (AmenoDimensionGraphics.findControllers role:"interactive") do
        (
            local dimensionIdValue = AmenoDimensionGraphics.getDimensionId controllerValue
            AmenoDimensionGraphics.deleteNodes (AmenoDimensionGraphics.findNodesForDimension dimensionIdValue)
        )
    )
    clearUndoBuffer()

    resetToolForChain()
    e16pOk "preview gw permanece antes do rollback" (AmenoDimensionContinuousTool.refreshChainPreview [100,100,0])
    local failureBefore = interactiveControllerCount()
    e16pEq "falha injetada no quarto segmento" (AmenoDimensionContinuousTool.commitChain [100,100,0] failAtSegment:4) false
    e16pEq "rollback de cadeia preparada deixa zero parcial" (interactiveControllerCount()) failureBefore
    e16pEq "rollback mantém referências" AmenoDimensionContinuousTool.points.count 8
    e16pEq "rollback retorna collecting" AmenoDimensionContinuousTool.stage #collecting
    e16pEq "rollback mantém overlay" AmenoContinuousOverlayService.model.segments.count 7
    AmenoDimensionContinuousTool.cleanupSession clearDraft:true

    format "=== [AMENO_E16_COMMIT] RESULT %/% PASS totalMs=% ===\n" passedTests totalTests totalMs
    if passedTests == totalTests then
        format "[AMENO_TEST][PASS] E16 commit performance passed.\n"
    else
    (
        format "[AMENO_TEST][FAIL] E16 commit performance failures=%\n" (totalTests - passedTests)
        throw ("E16 commit performance failed: " + ((totalTests - passedTests) as string))
    )
    resetMaxFile #noPrompt
)
