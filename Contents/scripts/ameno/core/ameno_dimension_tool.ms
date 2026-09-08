/*
    E4 — ferramenta interativa de três cliques.

    A prévia usa nós temporários identificados em Ameno_COTAS. Eles nunca
    recebem controlador e são removidos em cancelamento, erro, reset ou após
    o commit. A cota permanente continua sendo criada pelo construtor da E3.
*/

global AmenoDimensionTool
global AmenoDimensionMouseTool
global AmenoApp
global AmenoDimensionGraphics
global AmenoDimensionMath
global AmenoSceneSetup
global AmenoLog
global AmenoRefreshMainPanel
global AmenoDimensionAnchorHit
global AmenoContinuousInputResolver
global AmenoDimensionCA
global AmenoDimensionPlane
global AmenoDimensionPlaneService

struct AmenoDimensionAnchorHit
(
    node = undefined,
    vertexId = -1,
    vertexWorldPoint = undefined
)

struct AmenoDimensionToolService
(
    stage = #idle,
    pointA = undefined,
    pointB = undefined,
    offsetPoint = undefined,
    preview = undefined,
    active = false,
    lastCommittedRecord = undefined,
    lastError = "",
    previewOutputUnit = #meters,
    previewPrecision = 2,
    activeStyleId = "default",
    activeMode = #aligned, -- E10.1: #aligned | #horizontal | #vertical
    activePlaneMode = #worldXY, -- E14: #worldXY | #viewPlane
    activePlane = undefined,
    nodeA = undefined,
    nodeB = undefined,
    anchorVertexIdA = -1,
    anchorVertexIdB = -1,
    lastAnchorSummary = "",

    fn isTechnicalAmenoNode nodeValue =
    (
        if nodeValue == undefined or not isValidNode nodeValue then return false
        local kindValue = undefined
        local previewValue = undefined
        local dimensionIdValue = undefined
        local dimensionRoleValue = undefined
        local terminalValue = false
        try (terminalValue = (getUserProp nodeValue "AMENO_TERMINAL") == true) catch ()
        if ::AmenoDimensionGraphics != undefined do
        (
            try (kindValue = ::AmenoDimensionGraphics.readTextProperty nodeValue "Ameno.Kind") catch ()
            try (previewValue = ::AmenoDimensionGraphics.readTextProperty nodeValue "Ameno.Preview") catch ()
            try (dimensionIdValue = ::AmenoDimensionGraphics.readTextProperty nodeValue "Ameno.DimensionId") catch ()
            try (dimensionRoleValue = ::AmenoDimensionGraphics.readTextProperty nodeValue "Ameno.DimensionRole") catch ()
        )
        if terminalValue then return true
        if kindValue != undefined and kindValue != "" then return true
        if previewValue != undefined and previewValue != "" then return true
        if dimensionIdValue != undefined and dimensionIdValue != "" then return true
        if dimensionRoleValue != undefined and dimensionRoleValue != "" then return true
        false
    ),

    fn isEligibleReferenceNode nodeValue =
    (
        if nodeValue == undefined or not isValidNode nodeValue then return false
        if isTechnicalAmenoNode nodeValue then return false
        if ::AmenoContinuousInputResolver != undefined then
            return ::AmenoContinuousInputResolver.isEligibleGeometryNode nodeValue
        not nodeValue.isHidden and not nodeValue.isFrozen
    ),

    fn detectHitNode pointValue screenPoint:undefined snapNode:undefined snapWorldPoint:undefined snapHit:false =
    (
        local candidateNode = undefined
        local anchorPoint = if snapHit and snapWorldPoint != undefined then snapWorldPoint else pointValue

        -- Preferencia absoluta para o resultado real do sistema de Snap. O Max
        -- informa diretamente o no e o ponto mundial sob o marcador; isso evita
        -- inferir a ancora por raycast quando o clique ja foi resolvido pelo Snap.
        if snapHit and isEligibleReferenceNode snapNode and anchorPoint != undefined do
        (
            local snapTolerance = if ::AmenoDimensionGraphics != undefined then (::AmenoDimensionGraphics.toSceneUnits 10.0) else 1.0
            local snappedVertex = undefined
            if ::AmenoDimensionCA != undefined do
                snappedVertex = ::AmenoDimensionCA.findNearestVertex snapNode anchorPoint maxDistance:snapTolerance

            if snappedVertex != undefined then
                return (AmenoDimensionAnchorHit node:snapNode vertexId:snappedVertex.vertexId vertexWorldPoint:snappedVertex.worldPoint)
            else
                return (AmenoDimensionAnchorHit node:snapNode)
        )

        -- O ponto retornado pelo Vertex Snap e mais confiavel que o primeiro
        -- ray hit: em planta, o raio pode atravessar outra face antes do vertice.
        -- Procuramos primeiro o vertice avaliado mais proximo em todas as
        -- geometrias elegiveis cujo bounding box contem o ponto clicado.
        if anchorPoint != undefined and ::AmenoDimensionCA != undefined do
        (
            local vertexTolerance = if ::AmenoDimensionGraphics != undefined then (::AmenoDimensionGraphics.toSceneUnits 10.0) else 1.0
            local closestVertexNode = undefined
            local closestVertexHit = undefined
            local closestVertexDistance = 1e30

            for obj in geometry where isValidNode obj and not obj.isHidden do
            (
                if isEligibleReferenceNode obj do
                (
                    local insideCandidateBounds = false
                    try
                    (
                        local bbMin = obj.min
                        local bbMax = obj.max
                        insideCandidateBounds = anchorPoint.x >= (bbMin.x - vertexTolerance) and anchorPoint.x <= (bbMax.x + vertexTolerance) and \
                                                anchorPoint.y >= (bbMin.y - vertexTolerance) and anchorPoint.y <= (bbMax.y + vertexTolerance) and \
                                                anchorPoint.z >= (bbMin.z - vertexTolerance) and anchorPoint.z <= (bbMax.z + vertexTolerance)
                    )
                    catch ()

                    if insideCandidateBounds do
                    (
                        local vertexHit = ::AmenoDimensionCA.findNearestVertex obj anchorPoint maxDistance:vertexTolerance
                        if vertexHit != undefined and vertexHit.distance < closestVertexDistance do
                        (
                            closestVertexNode = obj
                            closestVertexHit = vertexHit
                            closestVertexDistance = vertexHit.distance
                        )
                    )
                )
            )

            if closestVertexNode != undefined and closestVertexHit != undefined then
                return (AmenoDimensionAnchorHit node:closestVertexNode vertexId:closestVertexHit.vertexId vertexWorldPoint:closestVertexHit.worldPoint)
        )

        -- 1. Tentativa via raycasting na cena (usando viewport-relative screenPoint)
        try
        (
            local r = undefined
            if screenPoint != undefined then
            (
                r = mapScreenToWorldRay screenPoint
            )
            else if mouse.pos != undefined then
            (
                r = mapScreenToWorldRay mouse.pos
            )

            if r != undefined then
            (
                local hits = intersectRayScene r
                for h in hits where isValidNode h[1] do
                (
                    local nodeHit = h[1]
                    if isEligibleReferenceNode nodeHit do
                    (
                        candidateNode = nodeHit
                        exit
                    )
                )
            )
        )
        catch ()

        -- 2. Fallback via proximidade de Bounding Box em unidades de cena
        if candidateNode == undefined and anchorPoint != undefined do
        (
            try
            (
                local tol = if ::AmenoDimensionGraphics != undefined then (::AmenoDimensionGraphics.toSceneUnits 50.0) else 5.0
                local closestDist = 1e9

                for obj in geometry where isValidNode obj and not obj.isHidden do
                (
                    if isEligibleReferenceNode obj do
                    (
                        local bbMin = obj.min
                        local bbMax = obj.max

                        if anchorPoint.x >= (bbMin.x - tol) and anchorPoint.x <= (bbMax.x + tol) and \
                           anchorPoint.y >= (bbMin.y - tol) and anchorPoint.y <= (bbMax.y + tol) and \
                           anchorPoint.z >= (bbMin.z - tol) and anchorPoint.z <= (bbMax.z + tol) do
                        (
                            local objCenter = (bbMin + bbMax) * 0.5
                            local d = length (objCenter - anchorPoint)
                            if d < closestDist do
                            (
                                closestDist = d
                                candidateNode = obj
                            )
                        )
                    )
                )
            )
            catch ()
        )

        local result = AmenoDimensionAnchorHit node:candidateNode
        if candidateNode != undefined and ::AmenoDimensionCA != undefined do
        (
            -- O snap do Max entrega o ponto exato; a tolerância cobre pequenas
            -- diferenças numéricas sem capturar um vértice distante por acidente.
            local vertexTolerance = if ::AmenoDimensionGraphics != undefined then (::AmenoDimensionGraphics.toSceneUnits 10.0) else 1.0
            local vertexHit = ::AmenoDimensionCA.findNearestVertex candidateNode anchorPoint maxDistance:vertexTolerance
            if vertexHit != undefined do
            (
                result.vertexId = vertexHit.vertexId
                result.vertexWorldPoint = vertexHit.worldPoint
            )
        )

        result
    ),

    fn flattenPoint pointValue =
    (
        if pointValue == undefined then return undefined
        [pointValue.x, pointValue.y, 0.0]
    ),

    fn setActivePlaneMode planeModeValue =
    (
        if active then return false
        local resolvedMode = planeModeValue
        if resolvedMode != #viewPlane then resolvedMode = #worldXY
        activePlaneMode = resolvedMode
        true
    ),

    fn capturePlane =
    (
        if activePlaneMode != #viewPlane then
        (
            activePlane = if ::AmenoDimensionPlaneService != undefined then ::AmenoDimensionPlaneService.worldXY() else AmenoDimensionPlane()
            return activePlane
        )

        if ::AmenoDimensionPlaneService == undefined then
        (
            lastError = "O serviço de planos da fachada não está disponível."
            return undefined
        )

        local captured = ::AmenoDimensionPlaneService.captureActive()
        if captured == undefined or not captured.valid then
        (
            lastError = if captured != undefined then captured.errorMessage else "A vista ativa não pode ser usada para cotar a fachada."
            displayTempPrompt ("Ameno Dimensions: " + lastError) 2600
            return undefined
        )
        activePlane = captured
        captured
    ),

    fn anchorPlaneAtFirstPoint pointValue =
    (
        -- Planta mantém o contrato legado (origem mundial). Em fachada, a
        -- orientação é capturada antes do clique e a origem passa a ser a
        -- projeção do primeiro snap aceito; assim a anotação não fica presa à
        -- posição da câmera nem a um plano paralelo deslocado.
        if activePlaneMode != #viewPlane or activePlane == undefined or pointValue == undefined then return true
        if ::AmenoDimensionPlaneService == undefined then return false
        local projectedPoint = undefined
        try (projectedPoint = ::AmenoDimensionPlaneService.project activePlane pointValue) catch ()
        if projectedPoint == undefined then return false
        local anchored = undefined
        try
        (
            anchored = ::AmenoDimensionPlaneService.make projectedPoint activePlane.axisU activePlane.axisV activePlane.normal \
                planeTypeValue:activePlane.planeType orientationLabelValue:activePlane.orientationLabel \
                sourceViewportValue:activePlane.sourceViewport sourceCameraValue:activePlane.sourceCamera
        )
        catch ()
        if anchored == undefined or not anchored.valid then return false
        activePlane = anchored
        true
    ),

    fn planeContextStable =
    (
        if activePlaneMode != #viewPlane or activePlane == undefined then return true
        if ::AmenoDimensionPlaneService == undefined then return false
        if activePlane.sourceViewport == undefined and activePlane.sourceCamera == undefined then return true

        local currentViewport = undefined
        try (currentViewport = viewport.activeViewport) catch ()
        if activePlane.sourceViewport != undefined and currentViewport != undefined and currentViewport != activePlane.sourceViewport then return false

        local currentCamera = undefined
        try (currentCamera = viewport.getCamera()) catch ()
        if activePlane.sourceCamera != undefined then
        (
            if currentCamera == undefined or currentCamera != activePlane.sourceCamera then return false
        )
        else if currentCamera != undefined then
            return false

        local currentPlane = undefined
        try (currentPlane = ::AmenoDimensionPlaneService.captureActive()) catch ()
        if currentPlane == undefined or not currentPlane.valid then return false
        ::AmenoDimensionPlaneService.isSameBasis activePlane currentPlane tolerance:0.001
    ),

    fn abortIfPlaneContextChanged =
    (
        if activePlaneMode != #viewPlane or not active then return false
        if planeContextStable() then return false
        lastError = "A vista da fachada mudou durante a captura; a cota foi cancelada para preservar o plano congelado."
        cancel()
        displayTempPrompt ("Ameno Dimensions: " + lastError) 2600
        true
    ),

    fn canonicalPoint pointValue =
    (
        if pointValue == undefined then return undefined
        if activePlaneMode == #viewPlane then pointValue else flattenPoint pointValue
    ),

    fn anchorSummaryPart label nodeValue vertexId =
    (
        if vertexId > 0 then
            (label + "=v" + (vertexId as string))
        else if nodeValue != undefined and isValidNode nodeValue then
            (label + "=obj")
        else
            (label + "=mundo")
    ),

    fn panelStatus statusText =
    (
        try
        (
            if AmenoApp != undefined do AmenoApp.dimensionStatus = statusText
        )
        catch ()

        statusText
    ),

    fn replaceStagePrompt =
    (
        local promptText =
            case stage of
            (
                #pointA: "Ameno Dimensions: clique o ponto A (Esc/botão direito cancela)"
                #pointB: "Ameno Dimensions: clique o ponto B"
                #offset: "Ameno Dimensions: clique para posicionar a linha de cota"
                default: "Ameno Dimensions: pronto"
            )

        try (replacePrompt promptText) catch ()
        promptText
    ),

    fn setStage stageValue =
    (
        stage = stageValue

        local statusText =
            case stage of
            (
                #pointA: "E4: aguardando ponto A."
                #pointB: "E4: ponto A definido · aguardando ponto B."
                #offset: "E4: pontos A/B definidos · aguardando afastamento."
                default: "E4: ferramenta pronta."
            )

        panelStatus statusText
        replaceStagePrompt()
    ),

    fn defaultOffsetPoint pointAValue pointBValue =
    (
        local planeValue = activePlane
        if planeValue == undefined do planeValue = if ::AmenoDimensionPlaneService != undefined then ::AmenoDimensionPlaneService.worldXY() else AmenoDimensionPlane()
        local projectedA = if ::AmenoDimensionPlaneService != undefined then ::AmenoDimensionPlaneService.project planeValue pointAValue else flattenPoint pointAValue
        local projectedB = if ::AmenoDimensionPlaneService != undefined then ::AmenoDimensionPlaneService.project planeValue pointBValue else flattenPoint pointBValue
        local measurementVector = projectedB - projectedA
        local measuredLength = length measurementVector

        if measuredLength <= 0.00001 then
        (
            projectedA + (planeValue.axisV * 100.0)
        )
        else
        (
            local direction = undefined
            local perpendicular = undefined
            if activeMode == #horizontal then
            (
                local coordsA = ::AmenoDimensionPlaneService.coordinatesOf planeValue pointAValue
                local coordsB = ::AmenoDimensionPlaneService.coordinatesOf planeValue pointBValue
                direction = if coordsB.x >= coordsA.x then planeValue.axisU else -planeValue.axisU
                perpendicular = planeValue.axisV
                measuredLength = abs (coordsB.x - coordsA.x)
            )
            else if activeMode == #vertical then
            (
                local coordsA = ::AmenoDimensionPlaneService.coordinatesOf planeValue pointAValue
                local coordsB = ::AmenoDimensionPlaneService.coordinatesOf planeValue pointBValue
                direction = if coordsB.y >= coordsA.y then planeValue.axisV else -planeValue.axisV
                perpendicular = planeValue.axisU
                measuredLength = abs (coordsB.y - coordsA.y)
            )
            else
            (
                direction = normalize measurementVector
                perpendicular = normalize (cross planeValue.normal direction)
            )
            local offsetDistance = measuredLength * 0.2
            if offsetDistance < 10.0 do offsetDistance = 10.0
            projectedA + (perpendicular * offsetDistance)
        )
    ),

    fn removePreview =
    (
        if preview != undefined do
        (
            try (AmenoDimensionGraphics.removePreviewDimension preview) catch ()
            preview = undefined
        )

        true
    ),

    fn updatePreview pointAValue pointBValue offsetPointValue =
    (
        local layout = undefined
        try (layout = AmenoDimensionMath.layoutForMode pointAValue pointBValue offsetPointValue mode:activeMode plane:activePlane) catch ()

        if layout == undefined or not layout.valid then
        (
            local errMsg = if layout != undefined then layout.errorMessage else "os pontos A e B não podem coincidir."
            displayTempPrompt ("Ameno Dimensions: " + errMsg) 1200
            return false
        )

        try
        (
            if preview == undefined then
            (
                preview = AmenoDimensionGraphics.createPreviewDimension pointAValue pointBValue offsetPointValue outputUnit:previewOutputUnit precision:previewPrecision styleId:activeStyleId mode:activeMode plane:activePlane
            )
            else
            (
                preview = AmenoDimensionGraphics.updatePreviewDimension preview pointAValue pointBValue offsetPointValue outputUnit:previewOutputUnit precision:previewPrecision styleId:activeStyleId mode:activeMode plane:activePlane
            )

            preview != undefined
        )
        catch
        (
            lastError = getCurrentException() as string
            displayTempPrompt ("Ameno Dimensions: falha na prévia — " + lastError) 1800
            false
        )
    ),

    fn begin =
    (
        if active then return false

        local sceneState = AmenoSceneSetup.inspect()
        if sceneState.status != #ready do sceneState = AmenoSceneSetup.prepare()

        if sceneState.status != #ready then
        (
            displayTempPrompt ("Ameno Dimensions: prepare a cena antes de cotar. " + sceneState.detail) 2200
            return false
        )

        pointA = undefined
        pointB = undefined
        offsetPoint = undefined
        nodeA = undefined
        nodeB = undefined
        anchorVertexIdA = -1
        anchorVertexIdB = -1
        preview = undefined
        lastCommittedRecord = undefined
        lastError = ""
        lastAnchorSummary = ""
        activePlane = capturePlane()
        if activePlane == undefined then return false
        active = true
        setStage #pointA
        true
    ),

    fn handlePoint clickNumber pointValue screenPoint:undefined snapNode:undefined snapWorldPoint:undefined snapHit:false =
    (
        if not active then return #stop
        if abortIfPlaneContextChanged() then return #stop

        local effectivePoint = if snapHit and snapWorldPoint != undefined then snapWorldPoint else pointValue
        local candidate = canonicalPoint effectivePoint
        if candidate == undefined then return undefined

        case stage of
        (
            #pointA:
            (
                pointA = candidate
                local hitA = detectHitNode effectivePoint screenPoint:screenPoint snapNode:snapNode snapWorldPoint:snapWorldPoint snapHit:snapHit
                nodeA = hitA.node
                anchorVertexIdA = hitA.vertexId
                if hitA.vertexWorldPoint != undefined do pointA = canonicalPoint hitA.vertexWorldPoint
                if not (anchorPlaneAtFirstPoint pointA) then
                (
                    lastError = "Não foi possível fixar a origem do plano da fachada no primeiro ponto."
                    cancel()
                    displayTempPrompt ("Ameno Dimensions: " + lastError) 2200
                    return #stop
                )
                setStage #pointB
                undefined
            )
            #pointB:
            (
                if pointA == undefined then return undefined

                if (length (candidate - pointA)) <= 0.00001 then
                (
                    displayTempPrompt "Ameno Dimensions: escolha um ponto B diferente do ponto A." 1400
                    return undefined
                )

                pointB = candidate
                local hitB = detectHitNode effectivePoint screenPoint:screenPoint snapNode:snapNode snapWorldPoint:snapWorldPoint snapHit:snapHit
                nodeB = hitB.node
                anchorVertexIdB = hitB.vertexId
                if hitB.vertexWorldPoint != undefined do pointB = canonicalPoint hitB.vertexWorldPoint
                offsetPoint = defaultOffsetPoint pointA pointB
                updatePreview pointA pointB offsetPoint
                setStage #offset
                undefined
            )
            #offset:
            (
                if pointA == undefined or pointB == undefined then return undefined

                offsetPoint = candidate
                if not updatePreview pointA pointB offsetPoint then return undefined

                local created = undefined
                try
                (
                    created = AmenoDimensionGraphics.createDimension pointA pointB offsetPoint role:"interactive" outputUnit:previewOutputUnit precision:previewPrecision styleId:activeStyleId \
                        nodeA:nodeA anchorVertexIdA:anchorVertexIdA nodeB:nodeB anchorVertexIdB:anchorVertexIdB dimensionMode:activeMode plane:activePlane
                    lastCommittedRecord = created
                    lastAnchorSummary = (anchorSummaryPart "A" nodeA anchorVertexIdA) + " · " + (anchorSummaryPart "B" nodeB anchorVertexIdB)
                    removePreview()
                    nodeA = undefined
                    nodeB = undefined
                    anchorVertexIdA = -1
                    anchorVertexIdB = -1
                    -- Notifica o serviço de âncoras para que a nova cota entre no índice
                    -- reativo imediatamente. Sem isso, o indexTable ficaria desatualizado
                    -- até o próximo reinício, e o NodeEventCallback ignoraria movimentos
                    -- nos objetos ancorados.
                    if ::AmenoAnchorService != undefined do
                    (
                        try (::AmenoAnchorService.rebuildIndex()) catch ()
                    )
                    true
                )
                catch
                (
                    lastError = getCurrentException() as string
                    displayTempPrompt ("Ameno Dimensions: não foi possível criar a cota — " + lastError) 2200
                    false
                )

                if created != undefined then #stop else undefined
            )
            default: undefined
        )
    ),

    fn handleMove clickNumber pointValue =
    (
        if not active then return undefined
        if abortIfPlaneContextChanged() then return undefined

        local candidate = canonicalPoint pointValue
        if candidate == undefined then return undefined

        case stage of
        (
            #pointA: undefined
            #pointB:
            (
                if pointA != undefined and (length (candidate - pointA)) > 0.00001 do
                (
                    local temporaryOffset = defaultOffsetPoint pointA candidate
                    updatePreview pointA candidate temporaryOffset
                )
            )
            #offset:
            (
                if pointA != undefined and pointB != undefined do updatePreview pointA pointB candidate
            )
            default: undefined
        )
    ),

    fn cancel =
    (
        removePreview()
        pointA = undefined
        pointB = undefined
        offsetPoint = undefined
        nodeA = undefined
        nodeB = undefined
        anchorVertexIdA = -1
        anchorVertexIdB = -1
        active = false
        stage = #idle
        activePlane = undefined
        panelStatus "E4: cota cancelada."
        true
    ),

    fn onStart =
    (
        if not active do active = true
        replaceStagePrompt()
        true
    ),

    fn onAbort clickNumber =
    (
        cancel()
        displayTempPrompt "Ameno Dimensions: cota cancelada." 1000
        undefined
    ),

    fn onStop =
    (
        removePreview()
        try (popPrompt()) catch ()
        active = false
        stage = #idle
        if lastCommittedRecord != undefined and lastAnchorSummary != "" then
            panelStatus ("Cota criada · " + lastAnchorSummary)
        else
            panelStatus "E4: ferramenta pronta."
        true
    ),

    fn start =
    (
        if not begin() then return undefined

        local toolResult = #abort
        try
        (
            toolResult = startTool AmenoDimensionMouseTool prompt:"Ameno Dimensions: clique A, B e o afastamento" snap:#3D
        )
        catch
        (
            lastError = getCurrentException() as string
            displayTempPrompt ("Ameno Dimensions: ferramenta interrompida — " + lastError) 2200
            cancel()
        )

        if toolResult == #abort then removePreview()
        lastCommittedRecord
    )
)

AmenoDimensionTool = AmenoDimensionToolService()

tool AmenoDimensionMouseTool prompt:"Ameno Dimensions: clique A, B e o afastamento"
(
    on start do
    (
        if AmenoDimensionTool != undefined do AmenoDimensionTool.onStart()
    )

    on freeMove do
    (
        if AmenoDimensionTool != undefined do AmenoDimensionTool.handleMove 1 worldPoint
    )

    on mousePoint clickNumber do
    (
        local snapped = false
        local snappedNode = undefined
        local snappedWorldPoint = undefined
        try
        (
            -- snapMode.hit ja retorna undefined quando Snaps nao esta ativo.
            -- Nao depender de snapMode.active permite ler o Snap imposto pelo
            -- proprio MouseTool mesmo se o toggle global da toolbar estiver off.
            snapped = (snapMode.hit == true)
            if snapped do
            (
                snappedNode = snapMode.node
                snappedWorldPoint = snapMode.worldHitpoint
            )
        )
        catch ()

        if AmenoDimensionTool != undefined then
            AmenoDimensionTool.handlePoint clickNumber worldPoint screenPoint:viewPoint snapNode:snappedNode snapWorldPoint:snappedWorldPoint snapHit:snapped
        else
            #abort
    )

    on mouseMove clickNumber do
    (
        if AmenoDimensionTool != undefined do AmenoDimensionTool.handleMove clickNumber worldPoint
    )

    on mouseAbort clickNumber do
    (
        if AmenoDimensionTool != undefined do AmenoDimensionTool.onAbort clickNumber
    )

    on stop do
    (
        if AmenoDimensionTool != undefined do AmenoDimensionTool.onStop()
    )
)
