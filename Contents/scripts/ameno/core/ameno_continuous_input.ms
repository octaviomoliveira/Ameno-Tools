/*
    E12-R2 — aquisição e resolução de picking da cotação contínua.

    O snap é apenas uma fonte de candidato. Grid, helpers e gráficos Ameno não
    encerram a consulta: a geometria real sob o mesmo pixel continua elegível.
*/

global AmenoContinuousInputSample
global AmenoContinuousSurfaceHit
global AmenoContinuousVertexProbe
global AmenoContinuousPickResult
global AmenoContinuousInputResolver
global AmenoDimensionGraphics
global AmenoDimensionCA

struct AmenoContinuousSurfaceHit
(
    node = undefined,
    worldPoint = undefined,
    depth = 1e30
)

struct AmenoContinuousVertexProbe
(
    node = undefined,
    vertexId = -1,
    worldPoint = undefined,
    screenPoint = undefined,
    depth = 1e30
)

struct AmenoContinuousInputSample
(
    sessionId = "",
    sequence = 0,
    eventType = #mousePoint,
    nativeClickNumber = 0,
    viewportId = undefined,
    screenPoint = undefined,
    rawWorldPoint = undefined,
    rayValue = undefined,
    rayStatus = #pending,
    snapHit = false,
    snapNode = undefined,
    snapWorldPoint = undefined,
    snapStatus = #ok,
    geometryStatus = #pending,
    surfaceHits = #(),
    shortlistStatus = #pending,
    shortlistNodes = #(),
    vertexProbes = #(),
    planePoint = undefined,
    planeStatus = #pending
)

struct AmenoContinuousPickResult
(
    kind = #ambiguous,
    reasonCode = #unresolved,
    node = undefined,
    vertexId = -1,
    worldPoint3D = undefined,
    screenDistancePx = 1e30,
    provenance = #none,
    detail = ""
)

struct AmenoContinuousInputResolverService
(
    pixelTolerance = 10.0,
    planeZ = 0.0,
    planeEpsilon = 0.000001,
    sampleSequence = 0,

    fn isFiniteNumber value =
    (
        if value == undefined then return false
        try ((value == value) and ((abs value) < 1e30)) catch false
    ),

    fn isAmenoTechnicalNode nodeValue =
    (
        if nodeValue == undefined or not isValidNode nodeValue then return false
        local kindValue = undefined
        local previewValue = undefined
        try (kindValue = ::AmenoDimensionGraphics.readTextProperty nodeValue "Ameno.Kind") catch ()
        try (previewValue = ::AmenoDimensionGraphics.readTextProperty nodeValue "Ameno.Preview") catch ()
        if kindValue != undefined and kindValue != "" then return true
        if previewValue != undefined and previewValue != "" then return true
        local hasDimensionCA = false
        try (hasDimensionCA = (::AmenoDimensionCA != undefined and ::AmenoDimensionCA.hasCA nodeValue)) catch ()
        if hasDimensionCA then return true
        false
    ),

    fn isEligibleGeometryNode nodeValue =
    (
        if nodeValue == undefined or not isValidNode nodeValue then return false
        local hiddenState = false
        local frozenState = false
        try (hiddenState = nodeValue.isHidden) catch ()
        try (frozenState = nodeValue.isFrozen) catch ()
        if hiddenState or frozenState or (isAmenoTechnicalNode nodeValue) then return false
        try ((superClassOf nodeValue) == GeometryClass) catch false
    ),

    fn intersectRayWithPlane rayValue targetZ:0.0 =
    (
        if rayValue == undefined then return undefined
        local originPoint = undefined
        local directionValue = undefined
        try
        (
            originPoint = rayValue.pos
            directionValue = rayValue.dir
        )
        catch (return undefined)
        if originPoint == undefined or directionValue == undefined then return undefined
        if not (isFiniteNumber directionValue.z) or (abs directionValue.z) <= planeEpsilon then return undefined
        local parameter = (targetZ - originPoint.z) / directionValue.z
        if not (isFiniteNumber parameter) then return undefined
        local result = originPoint + (directionValue * parameter)
        if not (isFiniteNumber result.x) or not (isFiniteNumber result.y) or not (isFiniteNumber result.z) then return undefined
        result
    ),

    fn acquireSample eventTypeValue nativeClickNumberValue screenPointValue rawWorldPointValue \
        snapHit:false snapNode:undefined snapWorldPoint:undefined snapStatus:#ok sessionId:"" =
    (
        sampleSequence += 1
        local sample = AmenoContinuousInputSample sessionId:sessionId sequence:sampleSequence \
            eventType:eventTypeValue nativeClickNumber:nativeClickNumberValue \
            screenPoint:screenPointValue rawWorldPoint:rawWorldPointValue snapHit:snapHit snapNode:snapNode \
            snapWorldPoint:snapWorldPoint snapStatus:snapStatus
        try (sample.viewportId = viewport.activeViewport) catch ()
        try
        (
            if screenPointValue == undefined then throw "screen point unavailable"
            sample.rayValue = mapScreenToWorldRay screenPointValue
            if sample.rayValue == undefined then throw "ray unavailable"
            sample.rayStatus = #ok
        )
        catch
        (
            sample.rayValue = undefined
            sample.rayStatus = #error
        )
        if sample.rayStatus == #ok do
        (
            sample.planePoint = intersectRayWithPlane sample.rayValue targetZ:planeZ
            sample.planeStatus = if sample.planePoint == undefined then #invalidPlane else #ok
        )
        sample
    ),

    fn projectWorldPoint worldPoint =
    (
        if worldPoint == undefined then return undefined
        try
        (
            gw.setTransform (matrix3 1)
            gw.wTransPoint worldPoint
        )
        catch undefined
    ),

    fn screenDistance pointA pointB =
    (
        if pointA == undefined or pointB == undefined then return 1e30
        local dx = (pointA.x as float) - (pointB.x as float)
        local dy = (pointA.y as float) - (pointB.y as float)
        sqrt ((dx * dx) + (dy * dy))
    ),

    fn appendUniqueNode nodes nodeValue =
    (
        if nodeValue != undefined and isValidNode nodeValue and (findItem nodes nodeValue) == 0 do append nodes nodeValue
        nodes
    ),

    fn querySurfaceHits sample =
    (
        if sample == undefined then return false
        if sample.geometryStatus != #pending then return (sample.geometryStatus == #ok)
        if sample.rayStatus != #ok or sample.rayValue == undefined then
        (
            sample.geometryStatus = #error
            return false
        )
        try
        (
            sample.surfaceHits = #()
            local nativeHits = intersectRayScene sample.rayValue
            for nativeHit in nativeHits where nativeHit.count >= 1 do
            (
                local hitNode = nativeHit[1]
                local hitPoint = undefined
                try (hitPoint = nativeHit[2].pos) catch ()
                local hitDepth = 1e30
                if hitPoint != undefined do
                    try (hitDepth = dot (hitPoint - sample.rayValue.pos) (normalize sample.rayValue.dir)) catch ()
                append sample.surfaceHits (AmenoContinuousSurfaceHit node:hitNode worldPoint:hitPoint depth:hitDepth)
            )
            sample.geometryStatus = #ok
            true
        )
        catch
        (
            sample.surfaceHits = #()
            sample.geometryStatus = #error
            false
        )
    ),

    fn nodeScreenBoundsContains nodeValue screenPointValue paddingPx:10.0 =
    (
        if not (isEligibleGeometryNode nodeValue) or screenPointValue == undefined then return false
        try
        (
            local minPoint = nodeValue.min
            local maxPoint = nodeValue.max
            local corners = #(
                [minPoint.x,minPoint.y,minPoint.z], [maxPoint.x,minPoint.y,minPoint.z],
                [minPoint.x,maxPoint.y,minPoint.z], [maxPoint.x,maxPoint.y,minPoint.z],
                [minPoint.x,minPoint.y,maxPoint.z], [maxPoint.x,minPoint.y,maxPoint.z],
                [minPoint.x,maxPoint.y,maxPoint.z], [maxPoint.x,maxPoint.y,maxPoint.z]
            )
            local minX = 1e30
            local minY = 1e30
            local maxX = -1e30
            local maxY = -1e30
            for corner in corners do
            (
                local projected = projectWorldPoint corner
                if projected != undefined do
                (
                    if projected.x < minX do minX = projected.x
                    if projected.y < minY do minY = projected.y
                    if projected.x > maxX do maxX = projected.x
                    if projected.y > maxY do maxY = projected.y
                )
            )
            screenPointValue.x >= (minX - paddingPx) and screenPointValue.x <= (maxX + paddingPx) and \
                screenPointValue.y >= (minY - paddingPx) and screenPointValue.y <= (maxY + paddingPx)
        )
        catch false
    ),

    fn buildShortlist sample =
    (
        local nodes = #()
        if sample == undefined then return nodes

        -- O primeiro hit geométrico elegível define a superfície frontal. Hits
        -- Ameno anteriores são ignorados, mas geometria elegível posterior não.
        local frontNode = undefined
        local frontDepth = 1e30
        for surfaceHit in sample.surfaceHits do
        (
            if isEligibleGeometryNode surfaceHit.node and surfaceHit.depth >= 0.0 and surfaceHit.depth < frontDepth do
            (
                frontNode = surfaceHit.node
                frontDepth = surfaceHit.depth
            )
        )
        if frontNode != undefined then
            appendUniqueNode nodes frontNode
        else if sample.shortlistStatus == #pending then
        (
            -- Contorno/wireframe: o raio pode não atravessar uma face. A bbox em
            -- pixels forma apenas uma shortlist; só um vértice dentro da tolerância vence.
            try
            (
                for nodeValue in geometry where (nodeScreenBoundsContains nodeValue sample.screenPoint paddingPx:pixelTolerance) do
                    appendUniqueNode nodes nodeValue
                sample.shortlistStatus = #ok
            )
            catch (sample.shortlistStatus = #error)
        )

        -- Testes podem injetar o retorno da consulta de região nessa fronteira.
        for nodeValue in sample.shortlistNodes where isEligibleGeometryNode nodeValue do appendUniqueNode nodes nodeValue
        nodes
    ),

    fn collectVertexProbes nodeValue sample =
    (
        local probes = #()
        if nodeValue == undefined or sample == undefined then return probes
        if sample.vertexProbes.count > 0 then
        (
            for probe in sample.vertexProbes where probe.node == nodeValue do append probes probe
            return probes
        )

        local evaluatedMesh = undefined
        try (evaluatedMesh = snapshotAsMesh nodeValue) catch ()
        if evaluatedMesh == undefined then return probes
        try
        (
            local vertexCount = getNumVerts evaluatedMesh
            for vertexId = 1 to vertexCount do
            (
                local worldPoint = undefined
                in coordsys world (worldPoint = getVert evaluatedMesh vertexId)
                local projected = projectWorldPoint worldPoint
                if projected != undefined do
                (
                    local depthValue = 1e30
                    if sample.rayValue != undefined do
                        try (depthValue = dot (worldPoint - sample.rayValue.pos) (normalize sample.rayValue.dir)) catch ()
                    append probes (AmenoContinuousVertexProbe node:nodeValue vertexId:vertexId worldPoint:worldPoint \
                        screenPoint:[projected.x,projected.y] depth:depthValue)
                )
            )
        )
        catch ()
        try (delete evaluatedMesh) catch ()
        probes
    ),

    fn bestVertexCandidate sample nodes =
    (
        local bestProbe = undefined
        local bestDistance = 1e30
        local bestDepth = 1e30
        for nodeValue in nodes do
        (
            for probe in (collectVertexProbes nodeValue sample) where probe.vertexId >= 1 and probe.worldPoint != undefined do
            (
                local distancePx = screenDistance sample.screenPoint probe.screenPoint
                local depthValue = probe.depth
                if depthValue < 0.0 do depthValue = 1e30
                if distancePx <= pixelTolerance and \
                    (distancePx < bestDistance or ((abs (distancePx - bestDistance)) <= 0.0001 and depthValue < bestDepth)) do
                (
                    bestProbe = probe
                    bestDistance = distancePx
                    bestDepth = depthValue
                )
            )
        )
        if bestProbe == undefined then return undefined
        AmenoContinuousPickResult kind:#reference reasonCode:#vertexWithinPixelTolerance node:bestProbe.node \
            vertexId:bestProbe.vertexId worldPoint3D:bestProbe.worldPoint screenDistancePx:bestDistance \
            provenance:#geometryQuery detail:"eligible vertex inside pixel tolerance"
    ),

    fn resolveSample sample =
    (
        if sample == undefined then
            return (AmenoContinuousPickResult kind:#ambiguous reasonCode:#missingSample detail:"input sample unavailable")
        if sample.rayStatus != #ok then
            return (AmenoContinuousPickResult kind:#ambiguous reasonCode:#rayQueryFailed detail:"viewport ray unavailable")
        if sample.planeStatus != #ok then
            return (AmenoContinuousPickResult kind:#ambiguous reasonCode:#invalidPlane detail:"viewport ray does not intersect the XY plane")

        local queryOk = querySurfaceHits sample
        if not queryOk then
            return (AmenoContinuousPickResult kind:#ambiguous reasonCode:#geometryQueryFailed detail:"geometry query failed")

        local nodes = buildShortlist sample
        if sample.snapHit and isEligibleGeometryNode sample.snapNode do
        (
            local reordered = #(sample.snapNode)
            for nodeValue in nodes where nodeValue != sample.snapNode do append reordered nodeValue
            nodes = reordered
        )

        local candidate = bestVertexCandidate sample nodes
        if candidate != undefined do
        (
            if sample.snapHit and candidate.node == sample.snapNode do candidate.provenance = #snapCandidate
            return candidate
        )

        if nodes.count > 0 then
            return (AmenoContinuousPickResult kind:#geometryWithoutReference reasonCode:#noVertexWithinPixelTolerance \
                node:nodes[1] detail:"eligible geometry without a vertex inside pixel tolerance")

        if sample.shortlistStatus == #error then
            return (AmenoContinuousPickResult kind:#ambiguous reasonCode:#shortlistQueryFailed detail:"screen-region query failed")

        if sample.snapStatus == #error then
            return (AmenoContinuousPickResult kind:#ambiguous reasonCode:#snapQueryFailed detail:"snap query failed")

        AmenoContinuousPickResult kind:#empty reasonCode:#noEligibleTarget worldPoint3D:sample.planePoint \
            provenance:#planeIntersection detail:"successful query found no eligible target"
    )
)

AmenoContinuousInputResolver = AmenoContinuousInputResolverService()
