/* E12-R3 — draft válido, overlay transitório e preview não-alvo. */
(
    global AmenoDimensionContinuousTool
    global AmenoContinuousClickClassification
    global AmenoContinuousInputSample
    global AmenoContinuousSurfaceHit
    global AmenoContinuousVertexProbe
    global AmenoDimensionGraphics
    global AmenoContinuousInputResolver
    global AmenoContinuousOverlayService

    format "\n=== [AMENO_E12_R3] START source=% ===\n" (getSourceFileName())
    resetMaxFile #noPrompt

    local testPath = getFilenamePath (getSourceFileName())
    local repoRoot = pathConfig.normalizePath (pathConfig.appendPath testPath @"..\..")
    local bootstrapPath = pathConfig.normalizePath (pathConfig.appendPath repoRoot @"Contents\scripts\startup\ameno_bootstrap.ms")
    fileIn bootstrapPath quiet:true
    AmenoApp.prepareScene()

    local totalTests = 0
    local passedTests = 0

    fn r3Eq description actual expected =
    (
        totalTests += 1
        if actual == expected then
        (
            passedTests += 1
            format "[PASS] %\n" description
        )
        else format "[FAIL] % expected=<%> actual=<%>\n" description expected actual
    )

    fn r3Ok description conditionValue = r3Eq description conditionValue true

    fn resetTool modeValue =
    (
        try (AmenoDimensionContinuousTool.cleanupSession clearDraft:true) catch ()
        AmenoDimensionContinuousTool.active = true
        AmenoDimensionContinuousTool.stage = #collecting
        AmenoDimensionContinuousTool.activeMode = modeValue
        AmenoDimensionContinuousTool.sessionMode = modeValue
        AmenoDimensionContinuousTool.points = #()
        AmenoDimensionContinuousTool.anchorNodes = #()
        AmenoDimensionContinuousTool.anchorVertexIds = #()
        AmenoDimensionContinuousTool.segmentPreviews = #()
        AmenoDimensionContinuousTool.lastCursorPoint = undefined
        AmenoContinuousOverlayService.clearSession()
        AmenoDimensionContinuousTool.registerViewportOverlay()
    )

    fn referenceClick nodeValue vertexValue pointValue =
    (
        AmenoContinuousClickClassification kind:#reference node:nodeValue vertexId:vertexValue \
            worldPoint:pointValue reasonCode:#testReference provenance:#test
    )

    fn injectedHover nodeValue vertexValue pointValue screenValue =
    (
        local sample = AmenoContinuousInputSample eventType:#mouseMove nativeClickNumber:1 screenPoint:screenValue \
            rawWorldPoint:[999,999,999] rayValue:(ray [0,0,100] [0,0,-1]) rayStatus:#ok \
            snapHit:true snapNode:nodeValue snapWorldPoint:pointValue snapStatus:#ok \
            geometryStatus:#pending shortlistStatus:#pending planePoint:[30,40,0] planeStatus:#ok
        sample.surfaceHits = #((AmenoContinuousSurfaceHit node:nodeValue worldPoint:pointValue depth:20.0))
        sample.vertexProbes = #((AmenoContinuousVertexProbe node:nodeValue vertexId:vertexValue worldPoint:pointValue screenPoint:screenValue depth:20.0))
        sample
    )

    local nodeA = box name:"R3_GEOMETRY_A" length:20 width:20 height:20 pos:[0,0,10]
    local nodeB = box name:"R3_GEOMETRY_B" length:20 width:20 height:20 pos:[40,80,10]
    local nodeC = box name:"R3_GEOMETRY_C" length:20 width:20 height:20 pos:[80,120,10]

    resetTool #horizontal
    r3Eq "first horizontal reference is accepted" \
        (AmenoDimensionContinuousTool.handleClassifiedClick (referenceClick nodeA 1 [0,0,12])) #referenceAdded
    r3Eq "no fictitious overlay segment exists after first reference" AmenoContinuousOverlayService.model.segments.count 0
    r3Eq "no fictitious node preview exists after first reference" AmenoDimensionContinuousTool.segmentPreviews.count 0
    r3Eq "modo incompatível é rejeitado antes do picking" \
        (AmenoDimensionContinuousTool.handleClassifiedClick (referenceClick nodeB 1 [0,8,22])) #modeMismatch
    r3Eq "sessão incompatível é cancelada" AmenoDimensionContinuousTool.points.count 0
    resetTool #horizontal
    r3Eq "recomeço aceita a primeira referência" \
        (AmenoDimensionContinuousTool.handleClassifiedClick (referenceClick nodeA 1 [0,0,12])) #referenceAdded
    r3Eq "different horizontal station is accepted" \
        (AmenoDimensionContinuousTool.handleClassifiedClick (referenceClick nodeB 2 [40,8,22])) #referenceAdded
    r3Eq "original 3D Z is preserved in draft" AmenoDimensionContinuousTool.points[2].z 22.0
    r3Eq "draft arrays remain aligned" AmenoDimensionContinuousTool.anchorNodes.count AmenoDimensionContinuousTool.points.count

    r3Ok "preview is created only after two valid clicked references" (AmenoDimensionContinuousTool.refreshChainPreview [0,60,0])
    r3Eq "one valid interval creates one overlay segment" AmenoContinuousOverlayService.model.segments.count 1
    r3Eq "contínuo permanece sem nodes temporários" AmenoDimensionContinuousTool.segmentPreviews.count 0
    local previewRevision = AmenoContinuousOverlayService.model.revision
    r3Ok "overlay contém linha e rótulo" (AmenoContinuousOverlayService.model.segments[1].linePointA != undefined and AmenoContinuousOverlayService.model.segments[1].labelText != "")
    r3Ok "overlay update succeeds without scene node" (AmenoDimensionContinuousTool.refreshChainPreview [0,70,0])
    r3Ok "overlay revision avança" (AmenoContinuousOverlayService.model.revision > previewRevision)

    local hoverSample = injectedHover nodeC 3 [80,120,35] [250,180]
    local hoverResult = AmenoDimensionContinuousTool.handleHoverSample hoverSample
    r3Eq "hover usa apenas hint nativo" hoverResult.kind #reference
    r3Eq "hover não inventa vertexId" hoverResult.vertexId -1
    r3Eq "hover marker matches resolved 3D candidate" AmenoDimensionContinuousTool.hoverPoint [80,120,35]
    r3Eq "hover does not flatten elevated geometry" AmenoDimensionContinuousTool.hoverPoint.z 35.0
    r3Eq "hover updates independent XY offset point" AmenoDimensionContinuousTool.lastCursorPoint [30,40,0]

    local emptyHover = AmenoContinuousInputSample eventType:#mouseMove screenPoint:[9000,9000] \
        rawWorldPoint:[1,2,3] rayValue:(ray [0,0,100] [0,0,-1]) rayStatus:#ok snapStatus:#ok \
        geometryStatus:#ok shortlistStatus:#ok planePoint:[1,2,0] planeStatus:#ok
    r3Eq "empty hover permanece leve" (AmenoDimensionContinuousTool.handleHoverSample emptyHover).kind #empty
    r3Eq "marker disappears without valid target" AmenoDimensionContinuousTool.hoverVisible false

    r3Ok "central removal removes the last draft reference" (AmenoDimensionContinuousTool.removeLastDraftReference())
    r3Eq "central removal keeps arrays aligned" AmenoDimensionContinuousTool.anchorVertexIds.count AmenoDimensionContinuousTool.points.count

    AmenoDimensionContinuousTool.cleanupSession clearDraft:true
    r3Eq "cleanup unregisters viewport callback state" AmenoDimensionContinuousTool.viewportCallbackRegistered false
    r3Eq "cleanup clears hover point" AmenoDimensionContinuousTool.hoverPoint undefined
    r3Eq "cleanup remove overlay" AmenoContinuousOverlayService.model.segments.count 0
    r3Eq "cleanup removes preview nodes" AmenoDimensionContinuousTool.segmentPreviews.count 0

    format "=== [AMENO_E12_R3] RESULT %/% PASS ===\n" passedTests totalTests
    if passedTests == totalTests then
        format "[AMENO_TEST][PASS] E12-R3 preview contract passed.\n"
    else
    (
        format "[AMENO_TEST][FAIL] E12-R3 failures=%\n" (totalTests - passedTests)
        throw ("E12-R3 failed: " + ((totalTests - passedTests) as string))
    )
)
