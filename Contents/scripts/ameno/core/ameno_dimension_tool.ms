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
    nodeA = undefined,
    nodeB = undefined,
    anchorVertexIdA = -1,
    anchorVertexIdB = -1,
    lastAnchorSummary = "",

    fn detectHitNode pointValue screenPoint:undefined snapNode:undefined snapWorldPoint:undefined snapHit:false =
    (
        local candidateNode = undefined
        local anchorPoint = if snapHit and snapWorldPoint != undefined then snapWorldPoint else pointValue

        -- Preferencia absoluta para o resultado real do sistema de Snap. O Max
        -- informa diretamente o no e o ponto mundial sob o marcador; isso evita
        -- inferir a ancora por raycast quando o clique ja foi resolvido pelo Snap.
        if snapHit and snapNode != undefined and isValidNode snapNode and anchorPoint != undefined do
        (
            local snapKind = ::AmenoDimensionGraphics.readTextProperty snapNode "Ameno.Kind"
            if (snapKind == undefined or snapKind == "") and (findString snapNode.name "AMENO_" == undefined) do
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
                local k = ::AmenoDimensionGraphics.readTextProperty obj "Ameno.Kind"
                if (k == undefined or k == "") and (findString obj.name "AMENO_" == undefined) do
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
                    local k = ::AmenoDimensionGraphics.readTextProperty nodeHit "Ameno.Kind"
                    if (k == undefined or k == "") and (findString nodeHit.name "AMENO_" == undefined) do
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
                    local k = ::AmenoDimensionGraphics.readTextProperty obj "Ameno.Kind"
                    if (k == undefined or k == "") and (findString obj.name "AMENO_" == undefined) do
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
        local measurementVector = [pointBValue.x - pointAValue.x, pointBValue.y - pointAValue.y, 0.0]
        local measuredLength = length measurementVector

        if measuredLength <= 0.00001 then
        (
            pointAValue + [0, 100.0, 0]
        )
        else
        (
            local direction = normalize measurementVector
            local perpendicular = normalize (cross [0, 0, 1] direction)
            local offsetDistance = measuredLength * 0.2
            if offsetDistance < 10.0 do offsetDistance = 10.0
            pointAValue + (perpendicular * offsetDistance)
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
        try (layout = AmenoDimensionMath.layoutForMode pointAValue pointBValue offsetPointValue mode:activeMode) catch ()

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
                preview = AmenoDimensionGraphics.createPreviewDimension pointAValue pointBValue offsetPointValue outputUnit:previewOutputUnit precision:previewPrecision styleId:activeStyleId mode:activeMode
            )
            else
            (
                preview = AmenoDimensionGraphics.updatePreviewDimension preview pointAValue pointBValue offsetPointValue outputUnit:previewOutputUnit precision:previewPrecision styleId:activeStyleId mode:activeMode
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
        active = true
        setStage #pointA
        true
    ),

    fn handlePoint clickNumber pointValue screenPoint:undefined snapNode:undefined snapWorldPoint:undefined snapHit:false =
    (
        if not active then return #stop

        local effectivePoint = if snapHit and snapWorldPoint != undefined then snapWorldPoint else pointValue
        local candidate = flattenPoint effectivePoint
        if candidate == undefined then return undefined

        case stage of
        (
            #pointA:
            (
                pointA = candidate
                local hitA = detectHitNode effectivePoint screenPoint:screenPoint snapNode:snapNode snapWorldPoint:snapWorldPoint snapHit:snapHit
                nodeA = hitA.node
                anchorVertexIdA = hitA.vertexId
                if hitA.vertexWorldPoint != undefined do pointA = flattenPoint hitA.vertexWorldPoint
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
                if hitB.vertexWorldPoint != undefined do pointB = flattenPoint hitB.vertexWorldPoint
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
                        nodeA:nodeA anchorVertexIdA:anchorVertexIdA nodeB:nodeB anchorVertexIdB:anchorVertexIdB dimensionMode:activeMode
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

        local candidate = flattenPoint pointValue
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
