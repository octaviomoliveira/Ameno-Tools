/* E12-C — preview H/V, commit atômico, rollback e Undo/Redo. */
(
    global AmenoDimensionContinuousTool
    global AmenoDimensionGraphics
    global AmenoDimensionCA
    global AmenoContinuousClickClassification

    format "\n=== [AMENO_E12_C] START source=% ===\n" (getSourceFileName())
    resetMaxFile #noPrompt

    local testPath = getFilenamePath (getSourceFileName())
    local repoRoot = pathConfig.normalizePath (pathConfig.appendPath testPath @"..\..")
    local bootstrapPath = pathConfig.normalizePath (pathConfig.appendPath repoRoot @"Contents\scripts\startup\ameno_bootstrap.ms")
    format "[AMENO_E12_C] bootstrap=%\n" bootstrapPath
    fileIn bootstrapPath quiet:true

    local totalTests = 0
    local passedTests = 0

    fn e12cEq description actual expected =
    (
        totalTests += 1
        if actual == expected then
        (
            passedTests += 1
            format "[PASS] %\n" description
        )
        else format "[FAIL] % expected=<%> actual=<%>\n" description expected actual
    )

    fn e12cNear description actual expected toleranceValue:0.0001 =
    (
        totalTests += 1
        if abs (actual - expected) <= toleranceValue then
        (
            passedTests += 1
            format "[PASS] %\n" description
        )
        else format "[FAIL] % expected=<%> actual=<%>\n" description expected actual
    )

    fn resetTool modeValue =
    (
        AmenoDimensionContinuousTool.removeAllPreviews()
        AmenoDimensionContinuousTool.active = true
        AmenoDimensionContinuousTool.stage = #collecting
        AmenoDimensionContinuousTool.activeMode = modeValue
        AmenoDimensionContinuousTool.points = #()
        AmenoDimensionContinuousTool.anchorNodes = #()
        AmenoDimensionContinuousTool.anchorVertexIds = #()
        AmenoDimensionContinuousTool.segmentPreviews = #()
        AmenoDimensionContinuousTool.activePreview = undefined
        AmenoDimensionContinuousTool.lastSessionIds = #()
        AmenoDimensionContinuousTool.lastCursorPoint = undefined
        AmenoDimensionContinuousTool.lastChainLayout = undefined
        AmenoDimensionContinuousTool.lastCommittedLayout = undefined
        AmenoDimensionContinuousTool.lastError = ""
        AmenoDimensionContinuousTool.hudOpen = false
    )

    fn addReference nodeValue vertexIdValue worldPointValue =
    (
        local clickValue = AmenoContinuousClickClassification kind:#reference node:nodeValue \
            vertexId:vertexIdValue worldPoint:worldPointValue
        AmenoDimensionContinuousTool.handleClassifiedClick clickValue
    )

    fn makeAnchor nameValue xValue yValue =
    (
        local nodeValue = box name:nameValue length:10 width:10 height:10 pos:[xValue,yValue,0]
        convertToPoly nodeValue
        -- polyOp.getVert em um nó retorna a posição no espaço mundial.
        local worldVertex = polyOp.getVert nodeValue 1
        #(nodeValue, worldVertex)
    )

    local anchorA = makeAnchor "E12C_A" 0 0
    local anchorB = makeAnchor "E12C_B" 100 20
    local anchorC = makeAnchor "E12C_C" 200 -10
    local baselineY = 80.0

    resetTool #horizontal
    e12cEq "add A" (addReference anchorA[1] 1 anchorA[2]) #referenceAdded
    e12cEq "add B" (addReference anchorB[1] 1 anchorB[2]) #referenceAdded
    e12cEq "add C" (addReference anchorC[1] 1 anchorC[2]) #referenceAdded
    e12cEq "preview succeeds" (AmenoDimensionContinuousTool.refreshChainPreview [100,baselineY,0]) true
    e12cEq "preview count N-1" AmenoDimensionContinuousTool.segmentPreviews.count 2
    for previewIndex = 1 to AmenoDimensionContinuousTool.segmentPreviews.count do
    (
        e12cNear ("preview line A shared Y " + (previewIndex as string)) AmenoDimensionContinuousTool.segmentPreviews[previewIndex].layout.linePointA.y baselineY
        e12cNear ("preview line B shared Y " + (previewIndex as string)) AmenoDimensionContinuousTool.segmentPreviews[previewIndex].layout.linePointB.y baselineY
    )

    local controllerCountBefore = (AmenoDimensionGraphics.findControllers role:"interactive").count
    e12cEq "injected failure rolls back" (AmenoDimensionContinuousTool.commitChain [100,baselineY,0] failAtSegment:2) false
    e12cEq "rollback leaves no controller" (AmenoDimensionGraphics.findControllers role:"interactive").count controllerCountBefore
    e12cEq "rollback keeps draft" AmenoDimensionContinuousTool.points.count 3
    e12cEq "rollback returns collecting" AmenoDimensionContinuousTool.stage #collecting
    e12cEq "rollback preserves preview records" AmenoDimensionContinuousTool.segmentPreviews.count 2

    clearUndoBuffer()
    local emptyClick = AmenoContinuousClickClassification kind:#empty worldPoint:[100,baselineY,0]
    e12cEq "first empty commits chain" (AmenoDimensionContinuousTool.handleClassifiedClick emptyClick commitNow:true) #chainCommitted
    e12cEq "two permanent dimensions" (AmenoDimensionGraphics.findControllers role:"interactive").count (controllerCountBefore + 2)
    e12cEq "draft reset after success" AmenoDimensionContinuousTool.points.count 0
    e12cEq "tool remains collecting" AmenoDimensionContinuousTool.stage #collecting
    e12cEq "session stores two ids" AmenoDimensionContinuousTool.lastSessionIds.count 2
    e12cEq "preview removed after success" AmenoDimensionContinuousTool.segmentPreviews.count 0

    local controllers = AmenoDimensionGraphics.findControllers role:"interactive"
    for controllerValue in controllers do
    (
        local recordValue = AmenoDimensionCA.readCA controllerValue
        e12cNear ("persistent baseline Y " + controllerValue.name) recordValue.offsetPoint.y baselineY
        e12cEq ("persistent mode horizontal " + controllerValue.name) recordValue.dimensionMode "horizontal"
    )

    max undo
    e12cEq "one Undo removes whole chain" (AmenoDimensionGraphics.findControllers role:"interactive").count controllerCountBefore
    max redo
    e12cEq "one Redo restores whole chain" (AmenoDimensionGraphics.findControllers role:"interactive").count (controllerCountBefore + 2)

    -- Repete o fluxo persistente no modo vertical, compartilhando uma única baseline X.
    with undo off
    (
        for controllerValue in (AmenoDimensionGraphics.findControllers role:"interactive") do
        (
            local dimensionIdValue = AmenoDimensionGraphics.getDimensionId controllerValue
            AmenoDimensionGraphics.deleteNodes (AmenoDimensionGraphics.findNodesForDimension dimensionIdValue)
        )
    )
    clearUndoBuffer()

    local baselineX = 260.0
    resetTool #vertical
    e12cEq "vertical add A" (addReference anchorA[1] 1 anchorA[2]) #referenceAdded
    e12cEq "vertical add B" (addReference anchorB[1] 1 anchorB[2]) #referenceAdded
    e12cEq "vertical add C" (addReference anchorC[1] 1 anchorC[2]) #referenceAdded
    e12cEq "vertical preview succeeds" (AmenoDimensionContinuousTool.refreshChainPreview [baselineX,0,0]) true
    e12cEq "vertical preview count N-1" AmenoDimensionContinuousTool.segmentPreviews.count 2
    for previewIndex = 1 to AmenoDimensionContinuousTool.segmentPreviews.count do
    (
        e12cNear ("vertical preview line A shared X " + (previewIndex as string)) AmenoDimensionContinuousTool.segmentPreviews[previewIndex].layout.linePointA.x baselineX
        e12cNear ("vertical preview line B shared X " + (previewIndex as string)) AmenoDimensionContinuousTool.segmentPreviews[previewIndex].layout.linePointB.x baselineX
    )

    local verticalEmptyClick = AmenoContinuousClickClassification kind:#empty worldPoint:[baselineX,0,0]
    e12cEq "vertical empty commits chain" (AmenoDimensionContinuousTool.handleClassifiedClick verticalEmptyClick commitNow:true) #chainCommitted
    e12cEq "vertical creates two dimensions" (AmenoDimensionGraphics.findControllers role:"interactive").count 2
    local verticalControllers = AmenoDimensionGraphics.findControllers role:"interactive"
    for controllerValue in verticalControllers do
    (
        local recordValue = AmenoDimensionCA.readCA controllerValue
        e12cNear ("persistent baseline X " + controllerValue.name) recordValue.offsetPoint.x baselineX
        e12cEq ("persistent mode vertical " + controllerValue.name) recordValue.dimensionMode "vertical"
    )
    max undo
    e12cEq "vertical one Undo removes whole chain" (AmenoDimensionGraphics.findControllers role:"interactive").count 0
    max redo
    e12cEq "vertical one Redo restores whole chain" (AmenoDimensionGraphics.findControllers role:"interactive").count 2

    format "=== [AMENO_E12_C] RESULT %/% PASS ===\n" passedTests totalTests
    if passedTests == totalTests then
        format "[AMENO_TEST][PASS] E12-C preview/commit passed.\n"
    else
    (
        format "[AMENO_TEST][FAIL] E12-C failures=%\n" (totalTests - passedTests)
        throw ("E12-C failed: " + ((totalTests - passedTests) as string))
    )
)
