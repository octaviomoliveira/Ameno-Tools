/* E12-R2 — aquisição, picking em pixels e offset no plano XY. */
(
    global AmenoContinuousInputResolver
    global AmenoContinuousInputSample
    global AmenoContinuousSurfaceHit
    global AmenoContinuousVertexProbe
    global AmenoDimensionContinuousTool
    global AmenoDimensionGraphics

    format "\n=== [AMENO_E12_R2] START source=% ===\n" (getSourceFileName())
    resetMaxFile #noPrompt

    local testPath = getFilenamePath (getSourceFileName())
    local repoRoot = pathConfig.normalizePath (pathConfig.appendPath testPath @"..\..")
    local bootstrapPath = pathConfig.normalizePath (pathConfig.appendPath repoRoot @"Contents\scripts\startup\ameno_bootstrap.ms")
    fileIn bootstrapPath quiet:true

    local totalTests = 0
    local passedTests = 0

    fn r2Eq description actual expected =
    (
        totalTests += 1
        if actual == expected then
        (
            passedTests += 1
            format "[PASS] %\n" description
        )
        else format "[FAIL] % expected=<%> actual=<%>\n" description expected actual
    )

    fn r2Ok description conditionValue = r2Eq description conditionValue true

    fn r2Near description actual expected tolerance:0.0001 =
    (
        r2Ok description ((abs (actual - expected)) <= tolerance)
    )

    fn resetTool =
    (
        try (AmenoDimensionContinuousTool.removeAllPreviews()) catch ()
        AmenoDimensionContinuousTool.active = true
        AmenoDimensionContinuousTool.stage = #collecting
        AmenoDimensionContinuousTool.activeMode = #vertical
        AmenoDimensionContinuousTool.sessionMode = #vertical
        AmenoDimensionContinuousTool.points = #()
        AmenoDimensionContinuousTool.anchorNodes = #()
        AmenoDimensionContinuousTool.anchorVertexIds = #()
        AmenoDimensionContinuousTool.lastResult = #collecting
    )

    fn injectedSample screenValue =
    (
        AmenoContinuousInputSample eventType:#mousePoint nativeClickNumber:1 screenPoint:screenValue \
            rawWorldPoint:[999,999,999] rayValue:(ray [0,0,100] [0,0,-1]) rayStatus:#ok \
            snapStatus:#ok geometryStatus:#ok shortlistStatus:#ok planePoint:[0,0,0] planeStatus:#ok
    )

    local sourceNode = box name:"AMENO_REAL_GEOMETRY" length:200 width:200 height:50 pos:[0,0,25]
    convertToPoly sourceNode
    local sourceBehind = box name:"R2_BEHIND" length:200 width:200 height:50 pos:[0,0,-100]
    convertToPoly sourceBehind
    local amenoGraphic = splineShape name:"R2_EXISTING_DIMENSION"
    AmenoDimensionGraphics.setTextProperty amenoGraphic "Ameno.Kind" "dimensionGraphic"
    local arbitraryHelper = point name:"R2_HELPER" pos:[0,0,0]

    r2Ok "legitimate AMENO_ geometry name remains eligible" (AmenoContinuousInputResolver.isEligibleGeometryNode sourceNode)
    r2Eq "arbitrary helper is not eligible" (AmenoContinuousInputResolver.isEligibleGeometryNode arbitraryHelper) false
    r2Eq "Ameno graphic is not eligible" (AmenoContinuousInputResolver.isEligibleGeometryNode amenoGraphic) false
    sourceNode.isHidden = true
    r2Eq "hidden geometry is not eligible" (AmenoContinuousInputResolver.isEligibleGeometryNode sourceNode) false
    sourceNode.isHidden = false
    sourceNode.isFrozen = true
    r2Eq "frozen geometry is not eligible" (AmenoContinuousInputResolver.isEligibleGeometryNode sourceNode) false
    sourceNode.isFrozen = false

    -- Caso real reportado: a cota existente recebe o snap, mas a geometria atrás vence.
    local overlap = injectedSample [100,100]
    overlap.snapHit = true
    overlap.snapNode = amenoGraphic
    overlap.snapWorldPoint = [100,100,0]
    overlap.surfaceHits = #(
        (AmenoContinuousSurfaceHit node:amenoGraphic worldPoint:[100,100,0] depth:10.0),
        (AmenoContinuousSurfaceHit node:sourceNode worldPoint:[100,100,50] depth:50.0)
    )
    overlap.vertexProbes = #(
        (AmenoContinuousVertexProbe node:sourceNode vertexId:8 worldPoint:[100,100,50] screenPoint:[102,99] depth:50.0)
    )
    local overlapPick = AmenoContinuousInputResolver.resolveSample overlap
    r2Eq "Ameno snap does not block geometry behind" overlapPick.kind #reference
    r2Eq "overlap resolves original geometry" overlapPick.node sourceNode
    r2Eq "overlap resolves valid vertex id" overlapPick.vertexId 8
    r2Near "overlap uses pixel distance" overlapPick.screenDistancePx (sqrt 5.0)
    r2Near "overlap preserves original Z" overlapPick.worldPoint3D.z 50.0

    resetTool()
    r2Eq "sample reaches real handler" (AmenoDimensionContinuousTool.handleInputSample overlap commitNow:false) #referenceAdded
    r2Eq "handler stores source node" AmenoDimensionContinuousTool.anchorNodes[1] sourceNode
    r2Eq "handler stores source vertex" AmenoDimensionContinuousTool.anchorVertexIds[1] 8
    r2Near "handler preserves anchor Z" AmenoDimensionContinuousTool.points[1].z 50.0

    -- Tolerância é visual, não milímetros.
    local pixelEdge = injectedSample [100,100]
    pixelEdge.surfaceHits = #((AmenoContinuousSurfaceHit node:sourceNode worldPoint:[0,0,50] depth:50.0))
    pixelEdge.vertexProbes = #((AmenoContinuousVertexProbe node:sourceNode vertexId:1 worldPoint:[0,0,50] screenPoint:[110,100] depth:50.0))
    r2Eq "vertex at ten pixels is accepted" (AmenoContinuousInputResolver.resolveSample pixelEdge).kind #reference
    pixelEdge.vertexProbes[1].screenPoint = [110.01,100]
    r2Eq "vertex outside ten pixels is not accepted" (AmenoContinuousInputResolver.resolveSample pixelEdge).kind #geometryWithoutReference
    pixelEdge.vertexProbes[1].screenPoint = [100,100]
    pixelEdge.vertexProbes[1].vertexId = 0
    r2Eq "vertex id zero is never accepted" (AmenoContinuousInputResolver.resolveSample pixelEdge).kind #geometryWithoutReference

    local contourSample = injectedSample [75,75]
    contourSample.shortlistNodes = #(sourceNode)
    contourSample.vertexProbes = #((AmenoContinuousVertexProbe node:sourceNode vertexId:4 worldPoint:[-100,100,50] screenPoint:[75,75] depth:50.0))
    local contourPick = AmenoContinuousInputResolver.resolveSample contourSample
    r2Eq "region shortlist resolves a contour without a face hit" contourPick.kind #reference
    r2Eq "contour keeps the real source" contourPick.node sourceNode

    -- A primeira superfície geométrica elegível impede seleção posterior acidental.
    local depthSample = injectedSample [50,50]
    depthSample.surfaceHits = #(
        (AmenoContinuousSurfaceHit node:sourceNode worldPoint:[0,0,50] depth:20.0),
        (AmenoContinuousSurfaceHit node:sourceBehind worldPoint:[0,0,-75] depth:145.0)
    )
    depthSample.vertexProbes = #(
        (AmenoContinuousVertexProbe node:sourceNode vertexId:1 worldPoint:[-100,-100,0] screenPoint:[90,90] depth:20.0),
        (AmenoContinuousVertexProbe node:sourceBehind vertexId:1 worldPoint:[0,0,-75] screenPoint:[50,50] depth:145.0)
    )
    local depthPick = AmenoContinuousInputResolver.resolveSample depthSample
    r2Eq "rear object is not selected through front geometry" depthPick.kind #geometryWithoutReference
    r2Eq "front geometry explains missing vertex" depthPick.node sourceNode

    -- Grid/helper ou preview sem geometria real não bloqueia um vazio válido.
    local gridEmpty = injectedSample [9000,9000]
    gridEmpty.snapHit = true
    gridEmpty.snapNode = arbitraryHelper
    gridEmpty.snapWorldPoint = [25,25,0]
    gridEmpty.planePoint = [40,60,0]
    local gridPick = AmenoContinuousInputResolver.resolveSample gridEmpty
    r2Eq "ineligible snap with successful empty query is empty" gridPick.kind #empty
    r2Eq "empty offset comes from independent plane ray" gridPick.worldPoint3D [40,60,0]

    local secondReference = injectedSample [150,150]
    secondReference.surfaceHits = #((AmenoContinuousSurfaceHit node:sourceNode worldPoint:[100,-100,50] depth:50.0))
    secondReference.vertexProbes = #((AmenoContinuousVertexProbe node:sourceNode vertexId:7 worldPoint:[100,-100,50] screenPoint:[150,150] depth:50.0))
    r2Eq "second resolved sample reaches handler" (AmenoDimensionContinuousTool.handleInputSample secondReference commitNow:false) #referenceAdded
    r2Eq "grid empty with valid draft requests commit" (AmenoDimensionContinuousTool.handleInputSample gridEmpty commitNow:false) #commitRequested

    local queryError = injectedSample [100,100]
    queryError.geometryStatus = #error
    r2Eq "geometry query error is ambiguous" (AmenoContinuousInputResolver.resolveSample queryError).reasonCode #geometryQueryFailed

    local shortlistError = injectedSample [100,100]
    shortlistError.shortlistStatus = #error
    r2Eq "shortlist query error is ambiguous" (AmenoContinuousInputResolver.resolveSample shortlistError).reasonCode #shortlistQueryFailed

    local snapError = injectedSample [100,100]
    snapError.snapStatus = #error
    r2Eq "snap error cannot silently confirm" (AmenoContinuousInputResolver.resolveSample snapError).reasonCode #snapQueryFailed

    local invalidPlane = injectedSample [100,100]
    invalidPlane.planeStatus = #invalidPlane
    r2Eq "invalid XY plane intersection is ambiguous" (AmenoContinuousInputResolver.resolveSample invalidPlane).reasonCode #invalidPlane

    local planeHit = AmenoContinuousInputResolver.intersectRayWithPlane (ray [10,20,100] [0,0,-1]) targetZ:0.0
    r2Eq "ray-plane X" planeHit.x 10.0
    r2Eq "ray-plane Y" planeHit.y 20.0
    r2Eq "ray-plane Z" planeHit.z 0.0
    r2Eq "parallel ray has no XY intersection" (AmenoContinuousInputResolver.intersectRayWithPlane (ray [0,0,10] [1,0,0])) undefined

    AmenoDimensionContinuousTool.cancel()
    format "=== [AMENO_E12_R2] RESULT %/% PASS ===\n" passedTests totalTests
    if passedTests == totalTests then
        format "[AMENO_TEST][PASS] E12-R2 picking and plane contract passed.\n"
    else
    (
        format "[AMENO_TEST][FAIL] E12-R2 failures=%\n" (totalTests - passedTests)
        throw ("E12-R2 failed: " + ((totalTests - passedTests) as string))
    )
)
