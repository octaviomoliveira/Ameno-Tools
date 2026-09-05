/*
    E12 — Ferramenta de cotação contínua estilo Revit.

    Fluxo de interação:
      1. Painel principal abre o HUD nativo (pequeno, flutuante) e ativa o MouseTool.
      2. Usuário clica N referências de vértice (≥ 2).
      3. O primeiro clique realmente vazio solicita o commit do conjunto.
      4. Layout e commit da cadeia são implementados nos gates E12-B/C.

    Gestos:
      - Clique em vértice           : adiciona referência
      - Clique vazio                : solicita posicionamento/commit
      - Esc / botão direito         : cancela toda a sessão

    HUD nativo:
      - Label com contagem de pontos e comprimento total acumulado
      - Botão "↩ Desfazer ponto"  : remove o último ponto acumulado
      - Botão "✕ Cancelar"        : fecha o HUD e cancela a sessão

    Compatível com os modos herdados #aligned / #horizontal / #vertical.
*/

global AmenoDimensionContinuousTool
global AmenoDimensionContinuousMouseTool
global AmenoDimensionGraphics
global AmenoDimensionMath
global AmenoUnitService
global AmenoSceneSetup
global AmenoLog
global AmenoApp
global AmenoRefreshMainPanel
global AmenoDimensionAnchorHit
global AmenoAnchorService
global AmenoDimensionCA
global AmenoDimensionChainMath
global AmenoContinuousClickClassification
global AmenoContinuousDiagnostics

struct AmenoContinuousClickClassification
(
    kind       = #ambiguous,
    node       = undefined,
    vertexId   = -1,
    worldPoint = undefined,
    detail     = ""
)

-- ── HUD Rollout: painel nativo do 3ds Max (funciona durante startTool) ───────

rollout AmenoContinuousHUDRlt "Cotação Contínua" width:270
(
    label   lblStatus "Pontos: 0" align:#left
    label   lblInstr  "Clique em vértices; clique vazio posiciona" align:#left
    button  btnConfirm "Posicione clicando no vazio" width:254 enabled:false
    button  btnUndo   "Desfazer" width:125 across:2 enabled:false
    button  btnCancel "Cancelar" width:125

    on btnConfirm pressed do ()

    on btnUndo pressed do
    (
        if ::AmenoDimensionContinuousTool != undefined do
            ::AmenoDimensionContinuousTool.undoLastPoint()
    )

    on btnCancel pressed do
    (
        if ::AmenoDimensionContinuousTool != undefined do
        (
            ::AmenoDimensionContinuousTool.cancel()
            try (stopTool ::AmenoDimensionContinuousMouseTool) catch ()
        )
    )

    -- Fechar o X cancela a sessão
    on AmenoContinuousHUDRlt close do
    (
        if ::AmenoDimensionContinuousTool != undefined and ::AmenoDimensionContinuousTool.active do
        (
            ::AmenoDimensionContinuousTool.cancel()
            try (stopTool ::AmenoDimensionContinuousMouseTool) catch ()
        )
    )
)

-- ── Helpers ──────────────────────────────────────────────────────────────────

struct AmenoDimensionContinuousToolService
(
    -- Estado ─────────────────────────────────────────────────────────────────
    stage              = #idle,
    active             = false,
    activeStyleId      = "default",
    activeMode         = #aligned,
    previewOutputUnit  = #meters,
    previewPrecision   = 2,
    lastError          = "",
    lastCursorPoint    = undefined,
    lastChainLayout    = undefined,
    lastCommittedLayout = undefined,

    -- Pontos acumulados ───────────────────────────────────────────────────────
    points          = #(),
    anchorNodes     = #(),
    anchorVertexIds = #(),

    -- Previews de segmentos já confirmados (um por par)
    segmentPreviews = #(),
    -- Preview do segmento ativo (último ponto → cursor)
    activePreview   = undefined,

    -- IDs das cotas criadas nesta sessão
    lastSessionIds  = #(),

    -- HUD (rollout nativo MaxScript — funciona durante startTool)
    hudOpen = false,

    -- ── Geométrica ───────────────────────────────────────────────────────────

    fn flattenPoint pointValue =
    (
        if pointValue == undefined then return undefined
        [pointValue.x, pointValue.y, 0.0]
    ),

    fn diagnosticTrace eventName fields:#() throttleKey:undefined =
    (
        if ::AmenoContinuousDiagnostics == undefined then return false
        try (::AmenoContinuousDiagnostics.trace eventName fields:fields throttleKey:throttleKey) catch false
    ),

    fn diagnosticNodeText nodeValue =
    (
        if ::AmenoContinuousDiagnostics == undefined then return "<diagnostics-unavailable>"
        try (::AmenoContinuousDiagnostics.nodeText nodeValue) catch "<diagnostics-error>"
    ),

    fn diagnosticPointText pointValue =
    (
        if ::AmenoContinuousDiagnostics == undefined then return "<diagnostics-unavailable>"
        try (::AmenoContinuousDiagnostics.pointText pointValue) catch "<diagnostics-error>"
    ),

    fn isEligibleReferenceNode nodeValue =
    (
        if nodeValue == undefined or not isValidNode nodeValue then return false

        local hiddenState = false
        local frozenState = false
        try (hiddenState = nodeValue.isHidden) catch ()
        try (frozenState = nodeValue.isFrozen) catch ()
        if hiddenState or frozenState then return false

        local kindValue = undefined
        try (kindValue = ::AmenoDimensionGraphics.readTextProperty nodeValue "Ameno.Kind") catch ()
        (kindValue == undefined or kindValue == "") and (findString nodeValue.name "AMENO_" == undefined)
    ),

    -- Detecta âncora (cópia fiel do AmenoDimensionToolService)
    fn detectHitNode pointValue screenPoint:undefined snapNode:undefined snapWorldPoint:undefined snapHit:false =
    (
        local anchorPoint = if snapHit and snapWorldPoint != undefined then snapWorldPoint else pointValue

        -- Grid/helper/Ameno snap nunca deve cair no raycast e virar referência por acidente.
        if snapHit and not (isEligibleReferenceNode snapNode) then
            return (AmenoDimensionAnchorHit node:undefined)

        if snapHit and isEligibleReferenceNode snapNode and anchorPoint != undefined do
        (
            local tol = if ::AmenoDimensionGraphics != undefined then (::AmenoDimensionGraphics.toSceneUnits 10.0) else 1.0
            local sv = undefined
            if ::AmenoDimensionCA != undefined do sv = ::AmenoDimensionCA.findNearestVertex snapNode anchorPoint maxDistance:tol
            if sv != undefined then
                return (AmenoDimensionAnchorHit node:snapNode vertexId:sv.vertexId vertexWorldPoint:sv.worldPoint)
            else
                return (AmenoDimensionAnchorHit node:snapNode)
        )

        local candidateNode = undefined
        local candidatePoint = anchorPoint
        try
        (
            local r = if screenPoint != undefined then (mapScreenToWorldRay screenPoint) else (mapScreenToWorldRay mouse.pos)
            if r != undefined then
            (
                local hits = intersectRayScene r
                for h in hits where isEligibleReferenceNode h[1] do
                (
                    candidateNode = h[1]
                    try (candidatePoint = h[2].pos) catch ()
                    exit
                )
            )
        )
        catch ()

        local result = AmenoDimensionAnchorHit node:candidateNode
        if candidateNode != undefined and ::AmenoDimensionCA != undefined do
        (
            local tol = if ::AmenoDimensionGraphics != undefined then (::AmenoDimensionGraphics.toSceneUnits 10.0) else 1.0
            local vh = ::AmenoDimensionCA.findNearestVertex candidateNode candidatePoint maxDistance:tol
            if vh != undefined do
            (
                result.vertexId = vh.vertexId
                result.vertexWorldPoint = vh.worldPoint
            )
        )
        result
    ),

    fn classifyDetectedHit detectedHit snapHit:false snapNode:undefined snapWorldPoint:undefined fallbackWorldPoint:undefined =
    (
        if detectedHit != undefined and isEligibleReferenceNode detectedHit.node then
        (
            if detectedHit.vertexId >= 0 and detectedHit.vertexWorldPoint != undefined then
                AmenoContinuousClickClassification kind:#reference node:detectedHit.node \
                    vertexId:detectedHit.vertexId worldPoint:detectedHit.vertexWorldPoint detail:"vertex"
            else
                AmenoContinuousClickClassification kind:#geometryWithoutReference node:detectedHit.node \
                    detail:"geometry without a vertex inside tolerance"
        )
        else if snapHit then
            AmenoContinuousClickClassification kind:#ambiguous node:snapNode worldPoint:snapWorldPoint \
                detail:"snap without an eligible vertex reference"
        else
            AmenoContinuousClickClassification kind:#empty worldPoint:fallbackWorldPoint \
                detail:"no eligible geometry under cursor"
    ),

    fn classifyClick pointValue screenPoint:undefined snapNode:undefined snapWorldPoint:undefined snapHit:false =
    (
        local detectedHit = detectHitNode pointValue screenPoint:screenPoint snapNode:snapNode \
            snapWorldPoint:snapWorldPoint snapHit:snapHit
        local classification = classifyDetectedHit detectedHit snapHit:snapHit snapNode:snapNode snapWorldPoint:snapWorldPoint \
            fallbackWorldPoint:pointValue
        local detectedNodeText = "<undefined>"
        local detectedVertexText = "-1"
        try (detectedNodeText = diagnosticNodeText detectedHit.node) catch ()
        try (detectedVertexText = detectedHit.vertexId as string) catch ()
        diagnosticTrace #classification #(
            "stage=" + (stage as string),
            "mode=" + (activeMode as string),
            "snapHit=" + (snapHit as string),
            "snapNode=" + (diagnosticNodeText snapNode),
            "detectedNode=" + detectedNodeText,
            "detectedVertex=" + detectedVertexText,
            "kind=" + (classification.kind as string),
            "reason=" + classification.detail,
            "worldPoint=" + (diagnosticPointText classification.worldPoint)
        )
        classification
    ),

    -- ── Status / Prompt ───────────────────────────────────────────────────────

    fn panelStatus statusText =
    (
        try (if AmenoApp != undefined do AmenoApp.dimensionStatus = statusText) catch ()
        statusText
    ),

    fn buildPrompt =
    (
        local n = points.count
        case stage of
        (
            #collecting:
                if n == 0 then
                    "Ameno Cota Contínua: clique o 1º ponto  (Esc cancela)"
                else
                    ("Ameno Cota Contínua: " + n as string + " referência(s) · clique vazio posiciona")
            #committing:
                "Ameno Cota Contínua: preparando a cadeia"
            default:
                "Ameno Cota Contínua: pronto"
        )
    ),

    fn updatePrompt =
    (
        try (replacePrompt (buildPrompt())) catch ()
    ),

    fn setStage stageValue =
    (
        stage = stageValue
        updatePrompt()
        local statusText =
            case stage of
            (
                #collecting:       ("E12: coletando referências (" + points.count as string + " definida(s)).")
                #committing:       "E12: cadeia pronta para o layout/commit do próximo gate."
                default:           "E12: ferramenta pronta."
            )
        panelStatus statusText
    ),

    -- ── Cálculo do total acumulado ─────────────────────────────────────────────

    fn calcTotalMillimeters =
    (
        local total = 0.0
        if points.count < 2 then return total

        for i = 1 to (points.count - 1) do
        (
            try
            (
                local layout = AmenoDimensionMath.layoutForMode points[i] points[i + 1] (points[i] + [0, 100, 0]) mode:activeMode
                if layout.valid do total += layout.measuredMillimeters
            )
            catch ()
        )
        total
    ),

    fn formatTotal =
    (
        local totalMm = calcTotalMillimeters()
        try
        (
            local fmt = AmenoUnitService.formatMillimeters totalMm outputUnit:previewOutputUnit precision:previewPrecision decimalSeparator:#comma
            fmt.text
        )
        catch
        (
            (formattedPrint (totalMm / 1000.0) format:"0.2f") + " m"
        )
    ),

    -- ── HUD Rollout nativo (funciona em modo de ferramenta) ──────────────────

    fn openHUD =
    (
        -- Fecha dialog anterior se existir
        try (destroyDialog ::AmenoContinuousHUDRlt) catch ()
        hudOpen = false

        try
        (
            local sw = sysinfo.desktopSize
            local px = sw.x - 275
            local py = 50
            createDialog ::AmenoContinuousHUDRlt pos:[px, py] style:#(#style_border, #style_sysmenu, #style_titlebar)
            hudOpen = true
        )
        catch
        (
            lastError = getCurrentException() as string
            format "[E12] Falha ao abrir HUD: %\n" lastError
        )
    ),

    fn updateHUD =
    (
        if not hudOpen then return false
        try
        (
            local n    = points.count
            local segs = if n > 1 then (n - 1) else 0

            -- Status
            local statusStr = "Pontos: " + (n as string)
            if segs > 0 do statusStr += "  +  total: " + (formatTotal())
            ::AmenoContinuousHUDRlt.lblStatus.text = statusStr

            -- Instrução
            local instrStr = ""
            if stage == #committing then
                instrStr = "Preparando posicionamento da cadeia"
            else if segs > 0 then
                instrStr = "Clique em outro vértice ou no vazio para posicionar"
            else
                instrStr = "Continue clicando os pontos"
            ::AmenoContinuousHUDRlt.lblInstr.text = instrStr

            -- Botão Finalizar
            ::AmenoContinuousHUDRlt.btnConfirm.enabled = false

            -- Botão Undo
            ::AmenoContinuousHUDRlt.btnUndo.enabled = (n >= 1 and stage == #collecting)
        )
        catch ()
        true
    ),

    fn closeHUD =
    (
        try (destroyDialog ::AmenoContinuousHUDRlt) catch ()
        hudOpen = false
    ),


    -- ── Gestão de previews ────────────────────────────────────────────────────

    fn removeActivePreview =
    (
        if activePreview != undefined do
        (
            try (AmenoDimensionGraphics.removePreviewDimension activePreview) catch ()
            activePreview = undefined
        )
    ),

    fn removeSegmentPreview idx =
    (
        if idx >= 1 and idx <= segmentPreviews.count and segmentPreviews[idx] != undefined do
        (
            try (AmenoDimensionGraphics.removePreviewDimension segmentPreviews[idx]) catch ()
            segmentPreviews[idx] = undefined
        )
    ),

    fn removeAllPreviews =
    (
        removeActivePreview()
        for i = 1 to segmentPreviews.count do removeSegmentPreview i
        segmentPreviews = #()
    ),

    fn calculateChainLayout offsetPoint =
    (
        if activeMode != #horizontal and activeMode != #vertical then return undefined
        AmenoDimensionChainMath.layout points offsetPoint mode:activeMode
    ),

    fn refreshChainPreview offsetPoint =
    (
        if points.count < 2 then
        (
            removeAllPreviews()
            lastChainLayout = undefined
            return false
        )

        local chainLayout = calculateChainLayout offsetPoint
        if chainLayout == undefined or not chainLayout.valid then
        (
            removeAllPreviews()
            lastChainLayout = chainLayout
            return false
        )

        while segmentPreviews.count > chainLayout.segments.count do
        (
            removeSegmentPreview segmentPreviews.count
            deleteItem segmentPreviews segmentPreviews.count
        )

        try
        (
            for segmentIndex = 1 to chainLayout.segments.count do
            (
                local segmentLayout = chainLayout.segments[segmentIndex]
                local pointAValue = points[segmentLayout.sourceIndexA]
                local pointBValue = points[segmentLayout.sourceIndexB]
                while segmentPreviews.count < segmentIndex do append segmentPreviews undefined

                if segmentPreviews[segmentIndex] == undefined then
                    segmentPreviews[segmentIndex] = AmenoDimensionGraphics.createPreviewDimension pointAValue pointBValue chainLayout.offsetPoint \
                        outputUnit:previewOutputUnit precision:previewPrecision styleId:activeStyleId mode:activeMode
                else
                    segmentPreviews[segmentIndex] = AmenoDimensionGraphics.updatePreviewDimension segmentPreviews[segmentIndex] \
                        pointAValue pointBValue chainLayout.offsetPoint outputUnit:previewOutputUnit precision:previewPrecision styleId:activeStyleId mode:activeMode
            )
            lastChainLayout = chainLayout
            true
        )
        catch
        (
            lastError = getCurrentException() as string
            format "[E12-C] Falha no preview: %\n" lastError
            false
        )
    ),

    -- ── Undo de ponto (chamado pelo HUD) ──────────────────────────────────────

    fn undoLastPoint =
    (
        if points.count == 0 then return false

        removeAllPreviews()

        -- Remove último ponto e âncoras
        local n = points.count - 1
        local newPoints  = #()
        local newNodes   = #()
        local newVertIds = #()
        for i = 1 to n do
        (
            append newPoints  points[i]
            append newNodes   anchorNodes[i]
            append newVertIds anchorVertexIds[i]
        )
        points          = newPoints
        anchorNodes     = newNodes
        anchorVertexIds = newVertIds

        setStage #collecting
        if points.count >= 2 and lastCursorPoint != undefined do refreshChainPreview lastCursorPoint
        updateHUD()
        true
    ),

    -- ── Ciclo de vida ─────────────────────────────────────────────────────────

    fn begin =
    (
        diagnosticTrace #beginRequested #("active=" + (active as string), "mode=" + (activeMode as string))
        if active then
        (
            diagnosticTrace #beginRejected #("reason=already-active")
            return false
        )

        local sceneState = AmenoSceneSetup.inspect()
        if sceneState.status != #ready do sceneState = AmenoSceneSetup.prepare()

        if sceneState.status != #ready then
        (
            diagnosticTrace #beginRejected #("reason=scene-not-ready", "detail=" + sceneState.detail)
            displayTempPrompt ("Ameno Cota Contínua: prepare a cena antes de cotar. " + sceneState.detail) 2200
            return false
        )

        removeAllPreviews()
        points          = #()
        anchorNodes     = #()
        anchorVertexIds = #()
        segmentPreviews = #()
        activePreview   = undefined
        lastSessionIds  = #()
        lastError       = ""
        lastCursorPoint = undefined
        lastChainLayout = undefined
        lastCommittedLayout = undefined
        active          = true
        setStage #collecting
        openHUD()
        updateHUD()
        diagnosticTrace #beginReady #("stage=" + (stage as string), "mode=" + (activeMode as string))
        true
    ),

    fn cancel =
    (
        diagnosticTrace #cancelBegin #("stage=" + (stage as string), "references=" + (points.count as string))
        removeAllPreviews()
        points          = #()
        anchorNodes     = #()
        anchorVertexIds = #()
        segmentPreviews = #()
        lastCursorPoint = undefined
        lastChainLayout = undefined
        active          = false
        stage           = #idle
        closeHUD()
        panelStatus "E12: sessão cancelada."
        diagnosticTrace #cancelEnd #("stage=" + (stage as string), "active=" + (active as string))
        true
    ),

    -- ── Solicitação de commit; layout/criação pertencem aos gates E12-B/C ────

    fn requestCommit =
    (
        diagnosticTrace #commitRequested #("stage=" + (stage as string), "references=" + (points.count as string), "mode=" + (activeMode as string))
        if stage != #collecting then
        (
            diagnosticTrace #commitRequestRejected #("reason=invalid-stage", "stage=" + (stage as string))
            return false
        )
        if points.count < 2 then
        (
            diagnosticTrace #commitRequestRejected #("reason=insufficient-references", "references=" + (points.count as string))
            displayTempPrompt "Ameno Cota Contínua: defina ao menos 2 pontos antes de confirmar." 1600
            return false
        )
        setStage #committing
        updateHUD()
        diagnosticTrace #commitRequestAccepted #("stage=" + (stage as string), "references=" + (points.count as string))
        true
    ),

    fn rollbackCreatedDimensions dimensionIds =
    (
        with undo off
        (
            for dimensionId in dimensionIds do
            (
                local createdNodes = AmenoDimensionGraphics.findNodesForDimension dimensionId
                AmenoDimensionGraphics.deleteNodes createdNodes
            )
        )
        true
    ),

    fn commitChain offsetPoint failAtSegment:0 =
    (
        diagnosticTrace #commitBegin #(
            "stage=" + (stage as string),
            "mode=" + (activeMode as string),
            "references=" + (points.count as string),
            "offset=" + (diagnosticPointText offsetPoint)
        )
        if stage != #committing and stage != #collecting then
        (
            diagnosticTrace #commitRejected #("reason=invalid-stage", "stage=" + (stage as string))
            return false
        )
        if activeMode != #horizontal and activeMode != #vertical then
        (
            lastError = "E12-C suporta somente Horizontal e Vertical."
            diagnosticTrace #commitRejected #("reason=unsupported-mode", "mode=" + (activeMode as string), "error=" + lastError)
            setStage #collecting
            return false
        )

        local chainLayout = calculateChainLayout offsetPoint
        if chainLayout == undefined or not chainLayout.valid then
        (
            lastError = if chainLayout == undefined then "Layout de cadeia indisponível." else chainLayout.errorMessage
            local layoutCodeText = "<undefined>"
            try (layoutCodeText = chainLayout.errorCode as string) catch ()
            diagnosticTrace #commitRejected #("reason=invalid-layout", "layoutCode=" + layoutCodeText, "error=" + lastError)
            setStage #collecting
            return false
        )

        diagnosticTrace #layoutAccepted #(
            "segments=" + (chainLayout.segments.count as string),
            "offset=" + (diagnosticPointText chainLayout.offsetPoint)
        )

        setStage #committing
        local createdIds = #()
        local completed = false
        try
        (
            undo "Ameno: criar cadeia de cotas" on
            (
                for segmentIndex = 1 to chainLayout.segments.count do
                (
                    diagnosticTrace #segmentCreateBegin #("segment=" + (segmentIndex as string))
                    if failAtSegment == segmentIndex do throw ("Falha injetada no segmento " + (segmentIndex as string))
                    local segmentLayout = chainLayout.segments[segmentIndex]
                    local sourceA = segmentLayout.sourceIndexA
                    local sourceB = segmentLayout.sourceIndexB
                    local created = AmenoDimensionGraphics.createDimension points[sourceA] points[sourceB] chainLayout.offsetPoint \
                        role:"interactive" outputUnit:previewOutputUnit precision:previewPrecision styleId:activeStyleId \
                        nodeA:anchorNodes[sourceA] anchorVertexIdA:anchorVertexIds[sourceA] \
                        nodeB:anchorNodes[sourceB] anchorVertexIdB:anchorVertexIds[sourceB] \
                        dimensionMode:activeMode useUndo:false
                    if created == undefined do throw ("Segmento " + (segmentIndex as string) + " não foi criado.")
                    append createdIds created.dimensionId
                    diagnosticTrace #segmentCreateEnd #("segment=" + (segmentIndex as string), "dimensionId=" + created.dimensionId)
                )
            )
            completed = (createdIds.count == chainLayout.segments.count)
        )
        catch
        (
            lastError = getCurrentException() as string
            diagnosticTrace #commitException #("error=" + lastError, "createdIds=" + (createdIds.count as string))
            rollbackCreatedDimensions createdIds
            setStage #collecting
            panelStatus ("E12-C: falha; nenhuma cota mantida. " + lastError)
            diagnosticTrace #commitRollbackEnd #("stage=" + (stage as string), "references=" + (points.count as string))
            return false
        )

        if not completed then
        (
            diagnosticTrace #commitIncomplete #("createdIds=" + (createdIds.count as string), "segments=" + (chainLayout.segments.count as string))
            rollbackCreatedDimensions createdIds
            setStage #collecting
            return false
        )

        removeAllPreviews()
        lastSessionIds = createdIds
        lastCommittedLayout = chainLayout
        points = #()
        anchorNodes = #()
        anchorVertexIds = #()
        lastCursorPoint = undefined
        lastChainLayout = undefined
        setStage #collecting
        updateHUD()
        if ::AmenoAnchorService != undefined do try (::AmenoAnchorService.rebuildIndex()) catch ()
        panelStatus ("E12-C: " + (createdIds.count as string) + " cota(s) criada(s).")
        diagnosticTrace #commitSuccess #("createdIds=" + (createdIds.count as string), "stage=" + (stage as string), "active=" + (active as string))
        true
    ),

    fn confirmPoints =
    (
        displayTempPrompt "Ameno Cota Contínua: posicione com o primeiro clique vazio." 1400
        false
    ),

    fn isDuplicateReference clickInfo tolerance:0.00001 =
    (
        if clickInfo == undefined or clickInfo.kind != #reference then return false
        for i = 1 to points.count do
        (
            local sameIdentity = false
            if clickInfo.node != undefined and i <= anchorNodes.count and anchorNodes[i] == clickInfo.node and \
                i <= anchorVertexIds.count and anchorVertexIds[i] == clickInfo.vertexId do sameIdentity = true
            if sameIdentity or (length ((flattenPoint clickInfo.worldPoint) - points[i])) <= tolerance do return true
        )
        false
    ),

    fn handleClassifiedClick clickInfo commitNow:false =
    (
        if not active then return #inactive
        if stage != #collecting then return #ignored
        if clickInfo == undefined then return #ambiguous

        case clickInfo.kind of
        (
            #reference:
            (
                if clickInfo.worldPoint == undefined or clickInfo.vertexId < 0 or \
                    clickInfo.node == undefined or not isValidNode clickInfo.node then return #ambiguous
                if isDuplicateReference clickInfo then
                (
                    displayTempPrompt "Ameno Cota Contínua: esta referência já foi escolhida." 1400
                    return #duplicateReference
                )
                append points (flattenPoint clickInfo.worldPoint)
                append anchorNodes clickInfo.node
                append anchorVertexIds clickInfo.vertexId
                setStage #collecting
                updateHUD()
                #referenceAdded
            )
            #geometryWithoutReference:
            (
                displayTempPrompt "Ameno Cota Contínua: clique em um vértice válido." 1400
                #geometryWithoutReference
            )
            #empty:
            (
                if points.count < 2 then
                (
                    displayTempPrompt "Ameno Cota Contínua: escolha ao menos 2 vértices." 1400
                    #needsMoreReferences
                )
                else if clickInfo.worldPoint == undefined then #ambiguous
                else if requestCommit() then
                (
                    if commitNow then
                    (
                        if commitChain clickInfo.worldPoint then #chainCommitted else #commitFailed
                    )
                    else #commitRequested
                )
                else #ignored
            )
            default:
            (
                displayTempPrompt "Ameno Cota Contínua: clique ambíguo; nenhuma ação executada." 1400
                #ambiguous
            )
        )
    ),

    -- ── Handlers de mouse ─────────────────────────────────────────────────────

    fn handlePoint clickNumber pointValue screenPoint:undefined snapNode:undefined snapWorldPoint:undefined snapHit:false =
    (
        diagnosticTrace #handlePointBegin #(
            "clickNumber=" + (clickNumber as string),
            "stage=" + (stage as string),
            "active=" + (active as string),
            "references=" + (points.count as string),
            "point=" + (diagnosticPointText pointValue),
            "screen=" + (diagnosticPointText screenPoint),
            "snapHit=" + (snapHit as string),
            "snapNode=" + (diagnosticNodeText snapNode),
            "snapPoint=" + (diagnosticPointText snapWorldPoint)
        )
        if not active then
        (
            diagnosticTrace #handlePointEnd #("outcome=stop", "reason=inactive")
            return #stop
        )

        local effectivePoint = if snapHit and snapWorldPoint != undefined then snapWorldPoint else pointValue
        if flattenPoint effectivePoint == undefined then
        (
            diagnosticTrace #handlePointEnd #("outcome=ambiguous", "reason=missing-effective-point")
            return #ambiguous
        )
        local clickInfo = classifyClick effectivePoint screenPoint:screenPoint snapNode:snapNode \
            snapWorldPoint:snapWorldPoint snapHit:snapHit
        local outcome = handleClassifiedClick clickInfo commitNow:true
        diagnosticTrace #handlePointEnd #(
            "outcome=" + (outcome as string),
            "stage=" + (stage as string),
            "active=" + (active as string),
            "references=" + (points.count as string),
            "lastError=" + lastError
        )
        outcome
    ),

    fn handleMove clickNumber pointValue =
    (
        if not active then return undefined

        local candidate = flattenPoint pointValue
        if candidate == undefined then return undefined

        lastCursorPoint = candidate
        diagnosticTrace #handleMove #(
            "clickNumber=" + (clickNumber as string),
            "stage=" + (stage as string),
            "references=" + (points.count as string),
            "point=" + (diagnosticPointText candidate)
        ) throttleKey:("move:" + (stage as string) + ":" + (points.count as string))
        if stage == #collecting and points.count >= 2 then refreshChainPreview candidate else undefined
    ),

    -- ── onStart / onAbort / onStop ────────────────────────────────────────────

    fn onStart =
    (
        diagnosticTrace #toolStart #("activeBefore=" + (active as string), "stageBefore=" + (stage as string))
        if not active do active = true
        updatePrompt()
        diagnosticTrace #toolStartReady #("active=" + (active as string), "stage=" + (stage as string))
        true
    ),

    fn onAbort clickNumber =
    (
        diagnosticTrace #toolAbort #("clickNumber=" + (clickNumber as string), "stage=" + (stage as string), "references=" + (points.count as string))
        cancel()
        displayTempPrompt "Ameno Cota Contínua: sessão cancelada." 1000
        undefined
    ),

    fn onStop =
    (
        diagnosticTrace #toolStopBegin #("stage=" + (stage as string), "active=" + (active as string), "references=" + (points.count as string), "lastIds=" + (lastSessionIds.count as string))
        removeAllPreviews()
        closeHUD()
        try (popPrompt()) catch ()
        active = false
        stage  = #idle
        panelStatus "E12: ferramenta pronta."
        diagnosticTrace #toolStopEnd #("stage=" + (stage as string), "active=" + (active as string), "lastIds=" + (lastSessionIds.count as string))
        true
    ),

    -- ── Entry point ───────────────────────────────────────────────────────────

    fn start =
    (
        diagnosticTrace #startRequested #("mode=" + (activeMode as string))
        if not begin() then
        (
            diagnosticTrace #startRejected #("lastError=" + lastError)
            return undefined
        )

        local toolResult = #abort
        try
        (
            toolResult = startTool AmenoDimensionContinuousMouseTool \
                prompt:"Ameno Cota Contínua: clique vértices · clique vazio posiciona · Esc cancela" snap:#3D
            diagnosticTrace #startToolReturned #("toolResult=" + (toolResult as string), "lastIds=" + (lastSessionIds.count as string))
        )
        catch
        (
            lastError = getCurrentException() as string
            diagnosticTrace #startException #("error=" + lastError)
            displayTempPrompt ("Ameno Cota Contínua: ferramenta interrompida — " + lastError) 2200
            cancel()
        )

        if toolResult == #abort do removeAllPreviews()
        lastSessionIds
    )
)

AmenoDimensionContinuousTool = AmenoDimensionContinuousToolService()

-- ── Mouse Tool block ──────────────────────────────────────────────────────────

tool AmenoDimensionContinuousMouseTool prompt:"Ameno Cota Contínua: clique vértices · clique vazio posiciona · Esc cancela"
(
    on start do
    (
        if AmenoDimensionContinuousTool != undefined do
            AmenoDimensionContinuousTool.diagnosticTrace #mouseToolEvent #("type=start")
        if AmenoDimensionContinuousTool != undefined do AmenoDimensionContinuousTool.onStart()
    )

    on freeMove do
    (
        if AmenoDimensionContinuousTool != undefined do
            AmenoDimensionContinuousTool.diagnosticTrace #mouseToolEvent #(
                "type=freeMove",
                "stage=" + (AmenoDimensionContinuousTool.stage as string),
                "references=" + (AmenoDimensionContinuousTool.points.count as string),
                "worldPoint=" + (worldPoint as string)
            ) throttleKey:("native-freeMove:" + (AmenoDimensionContinuousTool.stage as string) + ":" + (AmenoDimensionContinuousTool.points.count as string))
        if AmenoDimensionContinuousTool != undefined do AmenoDimensionContinuousTool.handleMove 1 worldPoint
    )

    on mousePoint clickNumber do
    (
        if AmenoDimensionContinuousTool == undefined then
        (
            #abort
        )
        else
        (
            -- Não há heurística de duplo-clique: cada evento é classificado pelo alvo.
            local snapped           = false
            local snappedNode       = undefined
            local snappedWorldPoint = undefined
            try
            (
                snapped = (snapMode.hit == true)
                if snapped do
                (
                    snappedNode       = snapMode.node
                    snappedWorldPoint = snapMode.worldHitpoint
                )
            )
            catch ()

            AmenoDimensionContinuousTool.diagnosticTrace #mouseToolEvent #(
                "type=mousePoint",
                "clickNumber=" + (clickNumber as string),
                "stage=" + (AmenoDimensionContinuousTool.stage as string),
                "references=" + (AmenoDimensionContinuousTool.points.count as string),
                "worldPoint=" + (worldPoint as string),
                "viewPoint=" + (viewPoint as string),
                "snapHit=" + (snapped as string),
                "snapNode=" + (AmenoDimensionContinuousTool.diagnosticNodeText snappedNode),
                "snapWorldPoint=" + (AmenoDimensionContinuousTool.diagnosticPointText snappedWorldPoint)
            )

            local eventOutcome = AmenoDimensionContinuousTool.handlePoint clickNumber worldPoint \
                screenPoint:viewPoint snapNode:snappedNode \
                snapWorldPoint:snappedWorldPoint snapHit:snapped
            AmenoDimensionContinuousTool.diagnosticTrace #mouseToolEventResult #(
                "type=mousePoint",
                "clickNumber=" + (clickNumber as string),
                "outcome=" + (eventOutcome as string),
                "stage=" + (AmenoDimensionContinuousTool.stage as string),
                "references=" + (AmenoDimensionContinuousTool.points.count as string)
            )
            eventOutcome
        )
    )

    on mouseMove clickNumber do
    (
        if AmenoDimensionContinuousTool != undefined do
            AmenoDimensionContinuousTool.diagnosticTrace #mouseToolEvent #(
                "type=mouseMove",
                "clickNumber=" + (clickNumber as string),
                "stage=" + (AmenoDimensionContinuousTool.stage as string),
                "references=" + (AmenoDimensionContinuousTool.points.count as string),
                "worldPoint=" + (worldPoint as string)
            ) throttleKey:("native-mouseMove:" + (clickNumber as string) + ":" + (AmenoDimensionContinuousTool.stage as string) + ":" + (AmenoDimensionContinuousTool.points.count as string))
        if AmenoDimensionContinuousTool != undefined do AmenoDimensionContinuousTool.handleMove clickNumber worldPoint
    )

    on mouseAbort clickNumber do
    (
        if AmenoDimensionContinuousTool != undefined do
            AmenoDimensionContinuousTool.diagnosticTrace #mouseToolEvent #(
                "type=mouseAbort",
                "clickNumber=" + (clickNumber as string),
                "stage=" + (AmenoDimensionContinuousTool.stage as string),
                "references=" + (AmenoDimensionContinuousTool.points.count as string)
            )
        if AmenoDimensionContinuousTool != undefined do AmenoDimensionContinuousTool.onAbort clickNumber
    )

    on stop do
    (
        if AmenoDimensionContinuousTool != undefined do
            AmenoDimensionContinuousTool.diagnosticTrace #mouseToolEvent #(
                "type=stop",
                "stage=" + (AmenoDimensionContinuousTool.stage as string),
                "references=" + (AmenoDimensionContinuousTool.points.count as string)
            )
        if AmenoDimensionContinuousTool != undefined do AmenoDimensionContinuousTool.onStop()
    )
)
