/* E12-R1 — lifecycle, modo de sessão e cleanup da cotação contínua. */
(
    global AmenoDimensionContinuousTool
    global AmenoDimensionGraphics
    global AmenoContinuousClickClassification
    global AmenoSceneSetup

    format "\n=== [AMENO_E12_R1] START source=% ===\n" (getSourceFileName())
    resetMaxFile #noPrompt

    local testPath = getFilenamePath (getSourceFileName())
    local repoRoot = pathConfig.normalizePath (pathConfig.appendPath testPath @"..\..")
    local bootstrapPath = pathConfig.normalizePath (pathConfig.appendPath repoRoot @"Contents\scripts\startup\ameno_bootstrap.ms")
    fileIn bootstrapPath quiet:true

    local totalTests = 0
    local passedTests = 0

    fn r1Eq description actual expected =
    (
        totalTests += 1
        if actual == expected then
        (
            passedTests += 1
            format "[PASS] %\n" description
        )
        else format "[FAIL] % expected=<%> actual=<%>\n" description expected actual
    )

    fn r1Ok description condition = r1Eq description condition true

    fn resetTool =
    (
        try (AmenoDimensionContinuousTool.removeAllPreviews()) catch ()
        try (AmenoDimensionContinuousTool.closeHUD()) catch ()
        AmenoDimensionContinuousTool.active = false
        AmenoDimensionContinuousTool.stage = #idle
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
        AmenoDimensionContinuousTool.lastResult = #idle
        AmenoDimensionContinuousTool.cleanupInProgress = false
        AmenoDimensionContinuousTool.clearSessionConfiguration()
    )

    fn makeAnchor nameValue positionValue =
    (
        local nodeValue = box name:nameValue length:10 width:10 height:10 pos:positionValue
        convertToPoly nodeValue
        #(nodeValue, polyOp.getVert nodeValue 1)
    )

    fn addReference anchorValue =
    (
        local clickValue = AmenoContinuousClickClassification kind:#reference node:anchorValue[1] \
            vertexId:1 worldPoint:anchorValue[2]
        AmenoDimensionContinuousTool.handleClassifiedClick clickValue
    )

    AmenoSceneSetup.prepare()
    local anchorA = makeAnchor "E12_R1_A" [0,0,0]
    local anchorB = makeAnchor "E12_R1_B" [100,20,0]
    local anchorC = makeAnchor "E12_R1_C" [200,-10,0]
    local baselineControllers = (AmenoDimensionGraphics.findControllers role:"interactive").count

    -- Alinhado é recusado antes de capturar mouse ou abrir HUD.
    resetTool()
    AmenoDimensionContinuousTool.activeMode = #aligned
    r1Eq "aligned begin rejected" (AmenoDimensionContinuousTool.begin()) false
    r1Eq "aligned leaves tool inactive" AmenoDimensionContinuousTool.active false
    r1Eq "aligned leaves idle stage" AmenoDimensionContinuousTool.stage #idle
    r1Eq "aligned records rejected result" AmenoDimensionContinuousTool.lastResult #rejected
    r1Eq "aligned does not open HUD" AmenoDimensionContinuousTool.hudOpen false
    r1Eq "aligned creates no dimensions" (AmenoDimensionGraphics.findControllers role:"interactive").count baselineControllers

    -- Configuração é congelada para a sessão e o HUD não abre automaticamente.
    resetTool()
    AmenoDimensionContinuousTool.activeMode = #horizontal
    AmenoDimensionContinuousTool.activeStyleId = "default"
    AmenoDimensionContinuousTool.previewOutputUnit = #meters
    AmenoDimensionContinuousTool.previewPrecision = 2
    r1Ok "horizontal begin succeeds" (AmenoDimensionContinuousTool.begin())
    r1Eq "horizontal begins collecting" AmenoDimensionContinuousTool.stage #collecting
    r1Eq "HUD remains closed" AmenoDimensionContinuousTool.hudOpen false
    r1Ok "onStart keeps HUD closed without keyboard monitor" (AmenoDimensionContinuousTool.onStart() and AmenoDimensionContinuousTool.hudOpen == false)
    AmenoDimensionContinuousTool.activeMode = #vertical
    AmenoDimensionContinuousTool.previewOutputUnit = #millimeters
    AmenoDimensionContinuousTool.previewPrecision = 0
    r1Eq "session mode remains horizontal" (AmenoDimensionContinuousTool.effectiveMode()) #horizontal
    r1Eq "session unit remains meters" (AmenoDimensionContinuousTool.effectiveOutputUnit()) #meters
    r1Eq "session precision remains two" (AmenoDimensionContinuousTool.effectivePrecision()) 2
    AmenoDimensionContinuousTool.cancel()
    r1Eq "cancel clears session mode" AmenoDimensionContinuousTool.sessionMode undefined

    -- Abort com 0, 1 e 3 referências nunca cria cotas.
    for referenceCount in #(0,1,3) do
    (
        resetTool()
        AmenoDimensionContinuousTool.activeMode = #horizontal
        r1Ok ("abort begin count=" + (referenceCount as string)) (AmenoDimensionContinuousTool.begin())
        if referenceCount >= 1 do addReference anchorA
        if referenceCount >= 2 do addReference anchorB
        if referenceCount >= 3 do addReference anchorC
        AmenoDimensionContinuousTool.onAbort 1
        r1Eq ("abort inactive count=" + (referenceCount as string)) AmenoDimensionContinuousTool.active false
        r1Eq ("abort idle count=" + (referenceCount as string)) AmenoDimensionContinuousTool.stage #idle
        r1Eq ("abort result count=" + (referenceCount as string)) AmenoDimensionContinuousTool.lastResult #cancelled
        r1Eq ("abort creates nothing count=" + (referenceCount as string)) (AmenoDimensionGraphics.findControllers role:"interactive").count baselineControllers
    )

    -- Falha de commit preserva draft e permite retry.
    resetTool()
    AmenoDimensionContinuousTool.activeMode = #horizontal
    r1Ok "failure begin succeeds" (AmenoDimensionContinuousTool.begin())
    r1Eq "failure add A" (addReference anchorA) #referenceAdded
    r1Eq "failure add B" (addReference anchorB) #referenceAdded
    r1Ok "failure request accepted" (AmenoDimensionContinuousTool.requestCommit())
    r1Eq "injected commit fails" (AmenoDimensionContinuousTool.commitChain [50,80,0] failAtSegment:1) false
    r1Eq "failure keeps tool active" AmenoDimensionContinuousTool.active true
    r1Eq "failure returns collecting" AmenoDimensionContinuousTool.stage #collecting
    r1Eq "failure keeps draft" AmenoDimensionContinuousTool.points.count 2
    r1Eq "failure records result" AmenoDimensionContinuousTool.lastResult #failed
    AmenoDimensionContinuousTool.cancel()

    -- Sucesso retorna #stop na borda, preserva cotas e tolera cleanup repetido.
    resetTool()
    AmenoDimensionContinuousTool.activeMode = #horizontal
    r1Ok "success begin succeeds" (AmenoDimensionContinuousTool.begin())
    r1Eq "success add A" (addReference anchorA) #referenceAdded
    r1Eq "success add B" (addReference anchorB) #referenceAdded
    AmenoDimensionContinuousTool.lastCursorPoint = [50,80,0]
    r1Ok "programmatic confirmation commits at cursor" (AmenoDimensionContinuousTool.confirmPoints())
    r1Eq "confirmation reaches finished" AmenoDimensionContinuousTool.stage #finished
    local serviceOutcome = #chainCommitted
    r1Eq "success reaches finished" AmenoDimensionContinuousTool.stage #finished
    r1Eq "success records committed result" AmenoDimensionContinuousTool.lastResult #committed
    r1Eq "mouse border translates success to stop" (AmenoDimensionContinuousTool.mouseReturnForOutcome serviceOutcome) #stop
    r1Eq "success stores one id" AmenoDimensionContinuousTool.lastSessionIds.count 1
    local committedId = AmenoDimensionContinuousTool.lastSessionIds[1]
    r1Eq "success created one dimension" (AmenoDimensionGraphics.findControllers role:"interactive").count (baselineControllers + 1)

    AmenoDimensionContinuousTool.onStop()
    r1Eq "stop leaves inactive" AmenoDimensionContinuousTool.active false
    r1Eq "stop leaves idle" AmenoDimensionContinuousTool.stage #idle
    r1Eq "stop preserves committed result" AmenoDimensionContinuousTool.lastResult #committed
    r1Eq "stop preserves created id" AmenoDimensionContinuousTool.lastSessionIds[1] committedId
    r1Eq "stop preserves permanent dimension" (AmenoDimensionGraphics.findControllers role:"interactive").count (baselineControllers + 1)

    AmenoDimensionContinuousTool.onStop()
    r1Eq "second stop stays idle" AmenoDimensionContinuousTool.stage #idle
    r1Eq "second stop preserves permanent dimension" (AmenoDimensionGraphics.findControllers role:"interactive").count (baselineControllers + 1)

    -- Um clique de viewport que não resolve vértice posiciona diretamente no plano XY.
    resetTool()
    AmenoDimensionContinuousTool.activeMode = #horizontal
    r1Ok "viewport begin succeeds" (AmenoDimensionContinuousTool.begin())
    r1Eq "viewport add A" (addReference anchorA) #referenceAdded
    r1Eq "viewport add B" (addReference anchorB) #referenceAdded
    local viewportOutcome = AmenoDimensionContinuousTool.handlePoint 1 [50,80,0]
    r1Eq "viewport click returns stop after commit" viewportOutcome #stop
    r1Eq "viewport click reaches finished" AmenoDimensionContinuousTool.stage #finished
    r1Eq "viewport click creates one dimension" (AmenoDimensionGraphics.findControllers role:"interactive").count (baselineControllers + 2)
    local viewportId = AmenoDimensionContinuousTool.lastSessionIds[1]
    AmenoDimensionContinuousTool.onStop()

    with undo off
    (
        AmenoDimensionGraphics.deleteNodes (AmenoDimensionGraphics.findNodesForDimension committedId)
        AmenoDimensionGraphics.deleteNodes (AmenoDimensionGraphics.findNodesForDimension viewportId)
    )
    r1Eq "test cleanup restores controller count" (AmenoDimensionGraphics.findControllers role:"interactive").count baselineControllers

    format "=== [AMENO_E12_R1] RESULT %/% PASS ===\n" passedTests totalTests
    if passedTests == totalTests then
        format "[AMENO_TEST][PASS] E12-R1 lifecycle and mode gate passed.\n"
    else
    (
        format "[AMENO_TEST][FAIL] E12-R1 failures=%\n" (totalTests - passedTests)
        throw ("E12-R1 failed: " + ((totalTests - passedTests) as string))
    )
)
