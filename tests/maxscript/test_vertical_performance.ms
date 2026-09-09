/*
    Diagnóstico de desempenho H/V para a E12/E14.

    Executado em 3dsmaxbatch.exe para separar o custo da matemática pura do
    custo real de preview (spline, TextPlus e terminais). Não altera a cena do
    usuário: o runner usa o perfil isolado e o teste termina com resetMaxFile.
*/

global AmenoApp
global AmenoDimensionPlaneService
global AmenoDimensionChainMath
global AmenoDimensionMath
global AmenoDimensionContinuousTool
global AmenoDimensionGraphics
global AmenoContinuousOverlayService

(
    local testFile = getSourceFileName()
    local testPath = getFilenamePath testFile
    local repositoryRoot = pathConfig.normalizePath (pathConfig.appendPath testPath @"..\..")
    local bootstrapPath = pathConfig.normalizePath (pathConfig.appendPath repositoryRoot @"Contents\scripts\startup\ameno_bootstrap.ms")

    if AmenoApp == undefined do fileIn bootstrapPath quiet:true
    resetMaxFile #noPrompt
    if AmenoApp != undefined do AmenoApp.prepareScene()

    local planeValue = if AmenoDimensionPlaneService != undefined then AmenoDimensionPlaneService.worldXY() else undefined
    if planeValue == undefined or not planeValue.valid then throw "Benchmark vertical: plano XY indisponível."

    fn msElapsed startTick = ((timeStamp() - startTick) as float)

    fn makePoints modeValue countValue =
    (
        local result = #()
        for pointIndex = 1 to countValue do
        (
            if modeValue == #vertical then
                append result [((pointIndex * 13) as float), ((pointIndex * 100) as float), 0.0]
            else
                append result [((pointIndex * 100) as float), ((pointIndex * 13) as float), 0.0]
        )
        result
    )

    fn resetToolForBenchmark modeValue pointsValue =
    (
        try (AmenoDimensionContinuousTool.removeAllPreviews()) catch ()
        AmenoDimensionContinuousTool.previewBackend = #gw
        AmenoDimensionContinuousTool.active = true
        AmenoDimensionContinuousTool.stage = #collecting
        AmenoDimensionContinuousTool.activeMode = modeValue
        AmenoDimensionContinuousTool.sessionMode = modeValue
        AmenoDimensionContinuousTool.activePlaneMode = #worldXY
        AmenoDimensionContinuousTool.activePlane = planeValue
        AmenoDimensionContinuousTool.sessionPlaneMode = #worldXY
        AmenoDimensionContinuousTool.sessionPlane = planeValue
        AmenoDimensionContinuousTool.points = pointsValue
        AmenoDimensionContinuousTool.anchorNodes = #()
        AmenoDimensionContinuousTool.anchorVertexIds = #()
        AmenoDimensionContinuousTool.segmentPreviews = #()
        AmenoDimensionContinuousTool.lastChainLayout = undefined
        AmenoDimensionContinuousTool.lastResult = #collecting
        AmenoDimensionContinuousTool.cleanupInProgress = false
        AmenoDimensionContinuousTool.inputSessionId = ("e16-vertical-" + (modeValue as string))
        if AmenoContinuousOverlayService != undefined do
            AmenoContinuousOverlayService.beginSession AmenoDimensionContinuousTool.inputSessionId style:undefined outputUnitValue:#meters precisionValue:2
        true
    )

    fn finishToolForBenchmark =
    (
        try (AmenoDimensionContinuousTool.removeAllPreviews()) catch ()
        AmenoDimensionContinuousTool.active = false
        AmenoDimensionContinuousTool.stage = #idle
        AmenoDimensionContinuousTool.sessionMode = undefined
        AmenoDimensionContinuousTool.sessionPlane = undefined
        AmenoDimensionContinuousTool.points = #()
        AmenoDimensionContinuousTool.segmentPreviews = #()
        true
    )

    fn benchmarkMode modeValue =
    (
        local pointsValue = makePoints modeValue 4
        local offsetValue = if modeValue == #vertical then [600.0, 0.0, 0.0] else [0.0, 600.0, 0.0]
        local mathIterations = 5000
        local previewIterations = 4
        local segmentCount = pointsValue.count - 1

        local mathStart = timeStamp()
        local mathResult = undefined
        for iteration = 1 to mathIterations do
            mathResult = AmenoDimensionChainMath.layout pointsValue offsetValue mode:modeValue plane:planeValue
        local mathMs = msElapsed mathStart
        if mathResult == undefined or not mathResult.valid then throw ("Benchmark vertical: layout inválido em " + (modeValue as string))

        resetToolForBenchmark modeValue pointsValue
        local createStart = timeStamp()
        local createOk = AmenoDimensionContinuousTool.refreshChainPreview offsetValue
        local createMs = msElapsed createStart
        if not createOk then throw ("Benchmark vertical: criação de preview falhou em " + (modeValue as string))
        if AmenoDimensionContinuousTool.segmentPreviews.count != 0 then
            throw ("Benchmark vertical: preview criou nós no backend gw " + (modeValue as string))
        if AmenoContinuousOverlayService == undefined or AmenoContinuousOverlayService.model.segments.count != segmentCount then
            throw ("Benchmark vertical: overlay incompleto em " + (modeValue as string))

        local updateStart = timeStamp()
        for iteration = 1 to previewIterations do
        (
            local step = (iteration as float) * 3.0
            local updateOffset = if modeValue == #vertical then [600.0 + step, 0.0, 0.0] else [0.0, 600.0 + step, 0.0]
            if not (AmenoDimensionContinuousTool.refreshChainPreview updateOffset) then
                throw ("Benchmark vertical: atualização de preview falhou em " + (modeValue as string))
            if AmenoDimensionContinuousTool.segmentPreviews.count != 0 then
                throw ("Benchmark vertical: atualização criou nós no backend gw " + (modeValue as string))
        )
        local updateMs = msElapsed updateStart
        local nodePreviewCount = AmenoDimensionContinuousTool.segmentPreviews.count
        local overlaySegmentCount = if AmenoContinuousOverlayService == undefined then -1 else AmenoContinuousOverlayService.model.segments.count
        finishToolForBenchmark()

        local mathPerCall = mathMs / (mathIterations as float)
        local createPerSegment = createMs / (segmentCount as float)
        local updatePerCall = updateMs / (previewIterations as float)
        local updatePerSegment = updatePerCall / (segmentCount as float)

        format "[AMENO_BENCH] backend=gw mode=% math_calls=% math_total_ms=% math_ms_call=% preview_build_ms=% preview_build_ms_segment=% update_calls=% update_total_ms=% update_ms_call=% update_ms_segment=% segments=% node_previews=% overlay_segments=%\n" \
            modeValue mathIterations mathMs mathPerCall createMs createPerSegment previewIterations updateMs updatePerCall updatePerSegment segmentCount \
            nodePreviewCount overlaySegmentCount
        #(mathPerCall, createPerSegment, updatePerSegment)
    )

    local horizontalMetrics = benchmarkMode #horizontal
    local verticalMetrics = benchmarkMode #vertical

    format "[AMENO_BENCH] ratio_math_vertical_horizontal=% ratio_create_vertical_horizontal=% ratio_update_vertical_horizontal=%\n" \
        (verticalMetrics[1] / horizontalMetrics[1]) (verticalMetrics[2] / horizontalMetrics[2]) (verticalMetrics[3] / horizontalMetrics[3])
    format "[AMENO_TEST][PASS] benchmark vertical/horizontal concluído.\n"
    resetMaxFile #noPrompt
)
