/*
    E12 — Ferramenta de cotação contínua estilo Revit.

    Fluxo de interação:
      1. Painel principal valida o modo e ativa o MouseTool.
      2. Usuário clica N referências de vértice (≥ 2).
      3. Um clique na viewport posiciona a cadeia e conclui o commit.
      4. Layout e commit da cadeia são implementados nos gates E12-B/C.

    Gestos:
      - Clique em vértice           : adiciona referência
      - Clique na viewport          : posiciona e cria a cadeia
      - Esc / botão direito         : cancela toda a sessão

    HUD nativo legado (não aberto neste fluxo):
      - Label com contagem de pontos e comprimento total acumulado
      - Botão "↩ Desfazer ponto"  : remove o último ponto acumulado
      - Botão "✕ Cancelar"        : fecha o HUD e cancela a sessão

    Nesta etapa, a ferramenta contínua aceita somente #horizontal / #vertical.
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
global AmenoContinuousInputResolver
global AmenoContinuousViewportDraw

try (unRegisterRedrawViewsCallback AmenoContinuousViewportDraw) catch ()
fn AmenoContinuousViewportDraw =
(
    if ::AmenoDimensionContinuousTool == undefined or not ::AmenoDimensionContinuousTool.active then return false
    try
    (
        gw.setTransform (matrix3 1)
        for pointValue in ::AmenoDimensionContinuousTool.points where pointValue != undefined do
            gw.marker pointValue #smallDiamond color:(color 245 245 245)
        if ::AmenoDimensionContinuousTool.hoverVisible and ::AmenoDimensionContinuousTool.hoverPoint != undefined do
        (
            local candidateColor = ::AmenoDimensionContinuousTool.hoverColor
            gw.marker ::AmenoDimensionContinuousTool.hoverPoint #diamond color:candidateColor
        )
        gw.enlargeUpdateRect #whole
    )
    catch ()
    true
)

struct AmenoContinuousClickClassification
(
    kind       = #ambiguous,
    node       = undefined,
    vertexId   = -1,
    worldPoint = undefined,
    reasonCode = #unresolved,
    provenance = #none,
    screenDistancePx = 1e30,
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
    sessionStyleId     = undefined,
    sessionMode        = undefined,
    sessionOutputUnit  = undefined,
    sessionPrecision   = undefined,
    lastResult         = #idle,
    cleanupInProgress  = false,
    escapeEnableBeforeTool = undefined,
    inputSessionId     = "",
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

    -- Overlay transitório de referências/candidato; não cria nó e não participa do Snap.
    hoverVisible = false,
    hoverPoint = undefined,
    hoverColor = (color 80 220 120),
    hoverClassification = undefined,
    viewportCallbackRegistered = false,

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

    fn diagnosticTrace eventName fields throttleKey:undefined =
    (
        if ::AmenoContinuousDiagnostics == undefined then return false
        try (::AmenoContinuousDiagnostics.trace eventName fields:fields throttleKey:throttleKey) catch false
    ),

    -- O log persistente é best-effort e nunca participa do resultado da
    -- ferramenta. Eventos de alta frequência (mouseMove) continuam somente
    -- no diagnóstico opt-in para não pesar a interação.
    fn persistentLog level message =
    (
        try
        (
            if ::AmenoLog != undefined do ::AmenoLog.write level message
        )
        catch ()
        true
    ),

    fn persistentInfo message =
    (
        persistentLog #info message
    ),

    fn persistentWarn message =
    (
        persistentLog #warn message
    ),

    fn persistentError message =
    (
        persistentLog #error message
    ),

    -- O startTool deve receber o Esc mesmo quando o Max estiver com o
    -- escapeEnable global desligado por outra rotina. O valor anterior é
    -- restaurado assim que a ferramenta termina, sem alterar a preferência
    -- global do usuário.
    fn armEscapeAbort =
    (
        escapeEnableBeforeTool = try (escapeEnable) catch (undefined)
        try (escapeEnable = true) catch ()
        true
    ),

    fn restoreEscapeAbort =
    (
        if escapeEnableBeforeTool != undefined do
            try (escapeEnable = escapeEnableBeforeTool) catch ()
        escapeEnableBeforeTool = undefined
        true
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

    fn effectiveMode =
    (
        if sessionMode == undefined then activeMode else sessionMode
    ),

    fn effectiveStyleId =
    (
        if sessionStyleId == undefined then activeStyleId else sessionStyleId
    ),

    fn effectiveOutputUnit =
    (
        if sessionOutputUnit == undefined then previewOutputUnit else sessionOutputUnit
    ),

    fn effectivePrecision =
    (
        if sessionPrecision == undefined then previewPrecision else sessionPrecision
    ),

    fn clearSessionConfiguration =
    (
        sessionStyleId = undefined
        sessionMode = undefined
        sessionOutputUnit = undefined
        sessionPrecision = undefined
        true
    ),

    fn snapshotSessionConfiguration =
    (
        sessionStyleId = activeStyleId
        sessionMode = activeMode
        sessionOutputUnit = previewOutputUnit
        sessionPrecision = previewPrecision
        true
    ),

    fn registerViewportOverlay =
    (
        if viewportCallbackRegistered then return true
        try
        (
            unRegisterRedrawViewsCallback ::AmenoContinuousViewportDraw
            registerRedrawViewsCallback ::AmenoContinuousViewportDraw
            viewportCallbackRegistered = true
        )
        catch (viewportCallbackRegistered = false)
        viewportCallbackRegistered
    ),

    fn unregisterViewportOverlay =
    (
        try (unRegisterRedrawViewsCallback ::AmenoContinuousViewportDraw) catch ()
        viewportCallbackRegistered = false
        hoverVisible = false
        hoverPoint = undefined
        hoverClassification = undefined
        try (redrawViews()) catch ()
        true
    ),

    fn setHoverClassification classification =
    (
        hoverClassification = classification
        hoverVisible = classification != undefined and classification.kind == #reference and classification.worldPoint != undefined
        hoverPoint = if hoverVisible then classification.worldPoint else undefined
        hoverColor = if hoverVisible then (color 80 220 120) else (color 230 170 60)
        try (redrawViews()) catch ()
        hoverVisible
    ),

    fn isEligibleReferenceNode nodeValue =
    (
        if ::AmenoContinuousInputResolver == undefined then return false
        ::AmenoContinuousInputResolver.isEligibleGeometryNode nodeValue
    ),

    -- Detecta âncora (cópia fiel do AmenoDimensionToolService)
    fn detectHitNode pointValue screenPoint:undefined snapNode:undefined snapWorldPoint:undefined snapHit:false =
    (
        local anchorPoint = if snapHit and snapWorldPoint != undefined then snapWorldPoint else pointValue

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
            if detectedHit.vertexId >= 1 and detectedHit.vertexWorldPoint != undefined then
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

    fn classificationFromPickResult pickResult =
    (
        if pickResult == undefined then
            return (AmenoContinuousClickClassification kind:#ambiguous reasonCode:#missingPickResult detail:"pick result unavailable")
        AmenoContinuousClickClassification kind:pickResult.kind node:pickResult.node \
            vertexId:pickResult.vertexId worldPoint:pickResult.worldPoint3D reasonCode:pickResult.reasonCode \
            provenance:pickResult.provenance screenDistancePx:pickResult.screenDistancePx detail:pickResult.detail
    ),

    fn classifyInputSample sample =
    (
        if ::AmenoContinuousInputResolver == undefined then
            return (AmenoContinuousClickClassification kind:#ambiguous reasonCode:#resolverUnavailable detail:"input resolver unavailable")
        local pickResult = ::AmenoContinuousInputResolver.resolveSample sample
        local classification = classificationFromPickResult pickResult
        local detectedNodeText = "<undefined>"
        local detectedVertexText = "-1"
        try (detectedNodeText = diagnosticNodeText pickResult.node) catch ()
        try (detectedVertexText = pickResult.vertexId as string) catch ()
        diagnosticTrace #classification #(
            "stage=" + (stage as string),
            "mode=" + ((effectiveMode()) as string),
            "snapHit=" + (sample.snapHit as string),
            "snapNode=" + (diagnosticNodeText sample.snapNode),
            "detectedNode=" + detectedNodeText,
            "detectedVertex=" + detectedVertexText,
            "kind=" + (classification.kind as string),
            "reasonCode=" + (classification.reasonCode as string),
            "provenance=" + (classification.provenance as string),
            "reason=" + classification.detail,
            "worldPoint=" + (diagnosticPointText classification.worldPoint)
        )
        classification
    ),

    fn classifyClick pointValue screenPoint:undefined snapNode:undefined snapWorldPoint:undefined snapHit:false snapStatus:#ok clickNumber:0 =
    (
        if ::AmenoContinuousInputResolver == undefined then
            return (AmenoContinuousClickClassification kind:#ambiguous reasonCode:#resolverUnavailable detail:"input resolver unavailable")
        local sample = ::AmenoContinuousInputResolver.acquireSample #mousePoint clickNumber screenPoint pointValue \
            snapHit:snapHit snapNode:snapNode snapWorldPoint:snapWorldPoint snapStatus:snapStatus sessionId:inputSessionId
        classifyInputSample sample
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
                    ("Ameno Cota Contínua: " + n as string + " referência(s) · clique na viewport para confirmar")
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
                #committing:       "E12: preparando posicionamento da cadeia."
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
                local layout = AmenoDimensionMath.layoutForMode points[i] points[i + 1] (points[i] + [0, 100, 0]) mode:(effectiveMode())
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
            local fmt = AmenoUnitService.formatMillimeters totalMm outputUnit:(effectiveOutputUnit()) precision:(effectivePrecision()) decimalSeparator:#comma
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
                instrStr = "Clique na viewport para confirmar"
            else
                instrStr = "Continue clicando os pontos"
            ::AmenoContinuousHUDRlt.lblInstr.text = instrStr

            -- O HUD não é aberto durante a ferramenta; mantém o estado legado se
            -- outra rotina o utilizar explicitamente.
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

    fn positionPointFromScreen screenPoint fallbackPoint:undefined =
    (
        local positionPoint = undefined
        if screenPoint != undefined and ::AmenoContinuousInputResolver != undefined do
        (
            try
            (
                local rayValue = mapScreenToWorldRay screenPoint
                positionPoint = ::AmenoContinuousInputResolver.intersectRayWithPlane rayValue targetZ:0.0
            )
            catch ()
        )
        if positionPoint == undefined do positionPoint = fallbackPoint
        flattenPoint positionPoint
    ),

    fn currentPositionPoint =
    (
        local screenPoint = undefined
        try (screenPoint = mouse.pos) catch ()
        local positionPoint = positionPointFromScreen screenPoint fallbackPoint:lastCursorPoint
        if positionPoint == undefined and lastCursorPoint != undefined do
            positionPoint = flattenPoint lastCursorPoint
        positionPoint
    ),

    fn handlePositionClick clickNumber pointValue screenPoint:undefined =
    (
        if not active or stage != #committing then return #ignored

        local offsetPoint = positionPointFromScreen screenPoint fallbackPoint:pointValue
        persistentInfo ("E12 posicionamento confirmado por clique · click=" + (clickNumber as string) + " · offset=" + (diagnosticPointText offsetPoint))
        diagnosticTrace #positionClick #(
            "clickNumber=" + (clickNumber as string),
            "offset=" + (diagnosticPointText offsetPoint)
        )
        if offsetPoint == undefined then
        (
            displayTempPrompt "Ameno Cota Contínua: não foi possível obter o ponto de posicionamento." 1800
            return #ambiguous
        )

        if commitChain offsetPoint then #chainCommitted else #commitFailed
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
        local modeValue = effectiveMode()
        if modeValue != #horizontal and modeValue != #vertical then return undefined
        AmenoDimensionChainMath.layout points offsetPoint mode:modeValue
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
                (
                    local createdPreview = AmenoDimensionGraphics.createPreviewDimension pointAValue pointBValue chainLayout.offsetPoint \
                        outputUnit:(effectiveOutputUnit()) precision:(effectivePrecision()) styleId:(effectiveStyleId()) mode:(effectiveMode())
                    if createdPreview == undefined then throw "preview creation returned undefined"
                    segmentPreviews[segmentIndex] = createdPreview
                )
                else
                (
                    local previousPreview = segmentPreviews[segmentIndex]
                    local updatedPreview = AmenoDimensionGraphics.updatePreviewDimension previousPreview \
                        pointAValue pointBValue chainLayout.offsetPoint outputUnit:(effectiveOutputUnit()) precision:(effectivePrecision()) styleId:(effectiveStyleId()) mode:(effectiveMode())
                    if updatedPreview == undefined then throw "preview update returned undefined"
                    segmentPreviews[segmentIndex] = updatedPreview
                )
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

    fn removeLastDraftReference =
    (
        if points.count == 0 then return false
        deleteItem points points.count
        if anchorNodes.count > 0 do deleteItem anchorNodes anchorNodes.count
        if anchorVertexIds.count > 0 do deleteItem anchorVertexIds anchorVertexIds.count
        true
    ),

    -- ── Undo de ponto (chamado pelo HUD) ──────────────────────────────────────

    fn undoLastPoint =
    (
        if points.count == 0 then return false

        removeAllPreviews()

        removeLastDraftReference()

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

        if activeMode != #horizontal and activeMode != #vertical then
        (
            lastError = "A cotação contínua aceita somente os modos Horizontal e Vertical nesta versão."
            lastResult = #rejected
            diagnosticTrace #beginRejected #("reason=unsupported-mode", "mode=" + (activeMode as string), "error=" + lastError)
            panelStatus ("E12: " + lastError)
            displayTempPrompt ("Ameno Cota Contínua: " + lastError) 2200
            return false
        )

        try
        (
            local sceneState = AmenoSceneSetup.inspect()
            if sceneState.status != #ready do sceneState = AmenoSceneSetup.prepare()

            if sceneState.status != #ready then
            (
                lastError = "Prepare a cena antes de cotar. " + sceneState.detail
                lastResult = #rejected
                diagnosticTrace #beginRejected #("reason=scene-not-ready", "detail=" + sceneState.detail)
                displayTempPrompt ("Ameno Cota Contínua: " + lastError) 2200
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
            lastResult      = #collecting
            cleanupInProgress = false
            inputSessionId = (timeStamp()) as string
            snapshotSessionConfiguration()
            active          = true
            registerViewportOverlay()
            setStage #collecting
            diagnosticTrace #beginReady #("stage=" + (stage as string), "mode=" + ((effectiveMode()) as string))
            true
        )
        catch
        (
            lastError = getCurrentException() as string
            lastResult = #failed
            active = false
            stage = #idle
            removeAllPreviews()
            closeHUD()
            clearSessionConfiguration()
            diagnosticTrace #beginRejected #("reason=exception", "error=" + lastError)
            false
        )
    ),

    fn cleanupSession clearDraft:true =
    (
        if cleanupInProgress then return true
        cleanupInProgress = true

        -- Desativar antes de fechar o HUD impede que o callback close reentre em cancel().
        active = false
        unregisterViewportOverlay()
        removeAllPreviews()
        if clearDraft do
        (
            points = #()
            anchorNodes = #()
            anchorVertexIds = #()
            segmentPreviews = #()
            lastCursorPoint = undefined
            lastChainLayout = undefined
        )
        closeHUD()
        try (popPrompt()) catch ()
        stage = #idle
        clearSessionConfiguration()
        cleanupInProgress = false
        true
    ),

    -- Detecta o erro mais comum da cotação contínua: o usuário pretende uma
    -- cadeia vertical, mas inicia a sessão com Horizontal (ou vice-versa).
    -- A checagem ocorre antes de rejeitar a segunda referência como estação
    -- duplicada, encerra a sessão e devolve o painel para a correção do modo.
    fn modeMismatchForCandidate pointValue =
    (
        if points.count != 1 or pointValue == undefined then return false
        local firstPoint = flattenPoint points[1]
        local candidatePoint = flattenPoint pointValue
        if firstPoint == undefined or candidatePoint == undefined then return false

        local deltaX = abs (candidatePoint.x - firstPoint.x)
        local deltaY = abs (candidatePoint.y - firstPoint.y)
        local epsilon = 0.00001

        if deltaX <= epsilon and deltaY > epsilon then
            return (effectiveMode() == #horizontal)
        if deltaY <= epsilon and deltaX > epsilon then
            return (effectiveMode() == #vertical)

        local dominantAxisRatio = 1.5
        if effectiveMode() == #horizontal then
            deltaY > (deltaX * dominantAxisRatio)
        else if effectiveMode() == #vertical then
            deltaX > (deltaY * dominantAxisRatio)
        else
            false
    ),

    fn modeMismatchMessage =
    (
        local activeModeText = if effectiveMode() == #horizontal then "Horizontal" else "Vertical"
        local expectedModeText = if effectiveMode() == #horizontal then "Vertical" else "Horizontal"
        "O modo " + activeModeText + " está ativo, mas os dois primeiros pontos parecem " + expectedModeText + "."
    ),

    fn cancel =
    (
        diagnosticTrace #cancelBegin #("stage=" + (stage as string), "references=" + (points.count as string))
        lastResult = #cancelled
        cleanupSession clearDraft:true
        panelStatus "E12: sessão cancelada."
        diagnosticTrace #cancelEnd #("stage=" + (stage as string), "active=" + (active as string))
        true
    ),

    -- ── Solicitação de commit; layout/criação pertencem aos gates E12-B/C ────

    fn requestCommit =
    (
        diagnosticTrace #commitRequested #("stage=" + (stage as string), "references=" + (points.count as string), "mode=" + ((effectiveMode()) as string))
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
        persistentInfo ("E12 commit begin · stage=" + (stage as string) + " · mode=" + ((effectiveMode()) as string) + " · refs=" + (points.count as string) + " · offset=" + (diagnosticPointText offsetPoint))
        diagnosticTrace #commitBegin #(
            "stage=" + (stage as string),
            "mode=" + ((effectiveMode()) as string),
            "references=" + (points.count as string),
            "offset=" + (diagnosticPointText offsetPoint)
        )
        if stage != #committing and stage != #collecting then
        (
            diagnosticTrace #commitRejected #("reason=invalid-stage", "stage=" + (stage as string))
            return false
        )
        local modeValue = effectiveMode()
        if modeValue != #horizontal and modeValue != #vertical then
        (
            lastError = "E12-C suporta somente Horizontal e Vertical."
            lastResult = #failed
            diagnosticTrace #commitRejected #("reason=unsupported-mode", "mode=" + (modeValue as string), "error=" + lastError)
            setStage #collecting
            return false
        )

        local chainLayout = calculateChainLayout offsetPoint
        if chainLayout == undefined or not chainLayout.valid then
        (
            lastError = if chainLayout == undefined then "Layout de cadeia indisponível." else chainLayout.errorMessage
            lastResult = #failed
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
                    persistentInfo ("E12 segmento begin · segmento=" + (segmentIndex as string) + "/" + (chainLayout.segments.count as string))
                    diagnosticTrace #segmentCreateBegin #("segment=" + (segmentIndex as string))
                    if failAtSegment == segmentIndex do throw ("Falha injetada no segmento " + (segmentIndex as string))
                    local segmentLayout = chainLayout.segments[segmentIndex]
                    local sourceA = segmentLayout.sourceIndexA
                    local sourceB = segmentLayout.sourceIndexB
                    local created = AmenoDimensionGraphics.createDimension points[sourceA] points[sourceB] chainLayout.offsetPoint \
                        role:"interactive" outputUnit:(effectiveOutputUnit()) precision:(effectivePrecision()) styleId:(effectiveStyleId()) \
                        nodeA:anchorNodes[sourceA] anchorVertexIdA:anchorVertexIds[sourceA] \
                        nodeB:anchorNodes[sourceB] anchorVertexIdB:anchorVertexIds[sourceB] \
                        dimensionMode:modeValue useUndo:false
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
            lastResult = #failed
            persistentError ("E12 commit exception · segmentosCriados=" + (createdIds.count as string) + " · " + lastError)
            diagnosticTrace #commitException #("error=" + lastError, "createdIds=" + (createdIds.count as string))
            rollbackCreatedDimensions createdIds
            setStage #collecting
            panelStatus ("E12-C: falha; nenhuma cota mantida. " + lastError)
            diagnosticTrace #commitRollbackEnd #("stage=" + (stage as string), "references=" + (points.count as string))
            return false
        )

        if not completed then
        (
            lastResult = #failed
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
        lastResult = #committed
        setStage #finished
        if ::AmenoAnchorService != undefined do try (::AmenoAnchorService.rebuildIndex()) catch ()
        panelStatus ("E12-C: " + (createdIds.count as string) + " cota(s) criada(s).")
        persistentInfo ("E12 commit success · cotas=" + (createdIds.count as string))
        diagnosticTrace #commitSuccess #("createdIds=" + (createdIds.count as string), "stage=" + (stage as string), "active=" + (active as string))
        true
    ),

    fn mouseReturnForOutcome outcome =
    (
        if outcome == #chainCommitted or outcome == #modeMismatch then #stop else outcome
    ),

    fn confirmPoints =
    (
        if not active then return false
        if stage != #collecting and stage != #committing then return false

        persistentInfo ("E12 confirmação solicitada · stage=" + (stage as string) + " · refs=" + (points.count as string))
        local offsetPoint = currentPositionPoint()
        if offsetPoint == undefined then
        (
            persistentWarn "E12 confirmação sem posição reconhecida"
            displayTempPrompt "Ameno Cota Contínua: a posição atual não foi reconhecida; mova o cursor e clique na viewport." 2200
            return false
        )

        if stage == #collecting and not requestCommit() then return false
        if stage != #committing then return false

        if commitChain offsetPoint then
        (
            displayTempPrompt "Ameno Cota Contínua: cota confirmada." 1000
            true
        )
        else false
    ),

    fn isDuplicateReference clickInfo tolerance:0.00001 =
    (
        if clickInfo == undefined or clickInfo.kind != #reference then return false
        for i = 1 to points.count do
        (
            local sameIdentity = false
            if clickInfo.node != undefined and i <= anchorNodes.count and anchorNodes[i] == clickInfo.node and \
                i <= anchorVertexIds.count and anchorVertexIds[i] == clickInfo.vertexId do sameIdentity = true
            if sameIdentity or (length ((flattenPoint clickInfo.worldPoint) - (flattenPoint points[i]))) <= tolerance do return true
        )
        false
    ),

    fn stationForPoint pointValue =
    (
        if pointValue == undefined then return undefined
        case (effectiveMode()) of
        (
            #horizontal: pointValue.x
            #vertical: pointValue.y
            default: undefined
        )
    ),

    fn hasConflictingStation pointValue tolerance:0.00001 =
    (
        local candidateStation = stationForPoint pointValue
        if candidateStation == undefined then return true
        for existingPoint in points do
        (
            local existingStation = stationForPoint existingPoint
            if existingStation != undefined and (abs (candidateStation - existingStation)) <= tolerance do return true
        )
        false
    ),

    fn appendDraftReference clickInfo =
    (
        if clickInfo == undefined or clickInfo.worldPoint == undefined or clickInfo.vertexId < 1 or \
            clickInfo.node == undefined or not isValidNode clickInfo.node then return #ambiguous
        if isDuplicateReference clickInfo then return #duplicateReference
        if hasConflictingStation clickInfo.worldPoint then return #duplicateStation

        append points clickInfo.worldPoint
        append anchorNodes clickInfo.node
        append anchorVertexIds clickInfo.vertexId
        if points.count != anchorNodes.count or points.count != anchorVertexIds.count then
        (
            if points.count > 0 do deleteItem points points.count
            if anchorNodes.count > 0 do deleteItem anchorNodes anchorNodes.count
            if anchorVertexIds.count > 0 do deleteItem anchorVertexIds anchorVertexIds.count
            return #ambiguous
        )
        #referenceAdded
    ),

    fn handleClassifiedClick clickInfo commitNow:false =
    (
        if not active then return #inactive
        if stage != #collecting then return #ignored
        if clickInfo == undefined then return #ambiguous
        setHoverClassification undefined

        case clickInfo.kind of
        (
            #reference:
            (
                if modeMismatchForCandidate clickInfo.worldPoint do
                (
                    lastError = modeMismatchMessage()
                    persistentWarn ("E12 modo incompatível · " + lastError)
                    cancel()
                    displayTempPrompt ("Ameno Cota Contínua: " + lastError + " Sessão cancelada; selecione o modo correto e tente novamente.") 3000
                    return #modeMismatch
                )
                local appendOutcome = appendDraftReference clickInfo
                if appendOutcome == #duplicateReference then
                (
                    persistentWarn "E12 referência duplicada rejeitada"
                    displayTempPrompt "Ameno Cota Contínua: esta referência já foi escolhida." 1400
                    return #duplicateReference
                )
                if appendOutcome == #duplicateStation then
                (
                    persistentWarn "E12 referência com estação duplicada rejeitada"
                    displayTempPrompt "Ameno Cota Contínua: escolha um vértice em outra estação da cadeia." 1700
                    panelStatus "E12: referência rejeitada — estação repetida."
                    return #duplicateStation
                )
                if appendOutcome != #referenceAdded then return appendOutcome
                setStage #collecting
                updateHUD()
                persistentInfo ("E12 referência adicionada · refs=" + (points.count as string) + " · ponto=" + (diagnosticPointText clickInfo.worldPoint))
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

    fn handleInputSample sample commitNow:true =
    (
        local clickInfo = classifyInputSample sample
        handleClassifiedClick clickInfo commitNow:commitNow
    ),

    -- ── Handlers de mouse ─────────────────────────────────────────────────────

    fn handlePoint clickNumber pointValue screenPoint:undefined snapNode:undefined snapWorldPoint:undefined snapHit:false snapStatus:#ok =
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

        local outcome = #ignored
        if stage == #committing then
            outcome = handlePositionClick clickNumber pointValue screenPoint:screenPoint
        else
        (
            local clickInfo = classifyClick pointValue screenPoint:screenPoint snapNode:snapNode \
                snapWorldPoint:snapWorldPoint snapHit:snapHit snapStatus:snapStatus clickNumber:clickNumber
            local isReference = (clickInfo != undefined and clickInfo.kind == #reference)
            if isReference or points.count < 2 then
                outcome = handleClassifiedClick clickInfo commitNow:true
            else
            (
                -- Depois de duas referências, qualquer clique que não seja um
                -- vértice é uma tentativa de posicionamento. Isso permite
                -- clicar sobre uma face, bloco ou objeto que não tenha um
                -- vértice dentro da tolerância de picking.
                local offsetPoint = positionPointFromScreen screenPoint fallbackPoint:pointValue
                if offsetPoint == undefined then
                (
                    displayTempPrompt "Ameno Cota Contínua: clique não reconhecido; mova o cursor e clique novamente na viewport." 1800
                    outcome = #needsPosition
                )
                else if requestCommit() then
                (
                    if commitChain offsetPoint then
                        outcome = #chainCommitted
                    else
                        outcome = #commitFailed
                )
                else
                    outcome = #ignored
            )
        )
        diagnosticTrace #handlePointEnd #(
            "outcome=" + (outcome as string),
            "stage=" + (stage as string),
            "active=" + (active as string),
            "references=" + (points.count as string),
            "lastError=" + lastError
        )
        mouseReturnForOutcome outcome
    ),

    fn handleHoverSample sample =
    (
        if not active then return undefined
        if sample == undefined then
        (
            setHoverClassification undefined
            return undefined
        )

        local classification = classifyInputSample sample
        setHoverClassification classification
        if sample.planeStatus != #ok or sample.planePoint == undefined then return classification

        lastCursorPoint = sample.planePoint
        if stage == #collecting and points.count >= 2 do refreshChainPreview sample.planePoint
        if stage == #committing and points.count >= 2 do refreshChainPreview sample.planePoint
        classification
    ),

    fn handleMove clickNumber pointValue screenPoint:undefined snapNode:undefined snapWorldPoint:undefined snapHit:false snapStatus:#ok =
    (
        if not active then return undefined

        if screenPoint != undefined and ::AmenoContinuousInputResolver != undefined then
        (
            local sample = ::AmenoContinuousInputResolver.acquireSample #mouseMove clickNumber screenPoint pointValue \
                snapHit:snapHit snapNode:snapNode snapWorldPoint:snapWorldPoint snapStatus:snapStatus sessionId:inputSessionId
            return handleHoverSample sample
        )

        local candidate = flattenPoint pointValue
        if candidate == undefined then return undefined

        setHoverClassification undefined
        lastCursorPoint = candidate
        diagnosticTrace #handleMove #(
            "clickNumber=" + (clickNumber as string),
            "stage=" + (stage as string),
            "references=" + (points.count as string),
            "point=" + (diagnosticPointText candidate)
        ) throttleKey:("move:" + (stage as string) + ":" + (points.count as string))
        if (stage == #collecting or stage == #committing) and points.count >= 2 then refreshChainPreview candidate else undefined
    ),

    -- ── onStart / onAbort / onStop ────────────────────────────────────────────

    fn onStart =
    (
        diagnosticTrace #toolStart #("activeBefore=" + (active as string), "stageBefore=" + (stage as string))
        if not active do active = true
        updatePrompt()
        persistentInfo ("E12 MouseTool iniciado · modo=" + ((effectiveMode()) as string))
        diagnosticTrace #toolStartReady #("active=" + (active as string), "stage=" + (stage as string))
        true
    ),

    fn onAbort clickNumber =
    (
        persistentWarn ("E12 MouseTool abortado · click=" + (clickNumber as string) + " · refs=" + (points.count as string))
        diagnosticTrace #toolAbort #("clickNumber=" + (clickNumber as string), "stage=" + (stage as string), "references=" + (points.count as string))
        cancel()
        displayTempPrompt "Ameno Cota Contínua: sessão cancelada." 1000
        undefined
    ),

    fn onStop =
    (
        persistentInfo ("E12 MouseTool parado · resultado=" + (lastResult as string) + " · refs=" + (points.count as string) + " · cotas=" + (lastSessionIds.count as string))
        diagnosticTrace #toolStopBegin #("stage=" + (stage as string), "active=" + (active as string), "references=" + (points.count as string), "lastIds=" + (lastSessionIds.count as string))
        local committed = (lastResult == #committed)
        cleanupSession clearDraft:true
        if committed then
            panelStatus ("E12-C: " + (lastSessionIds.count as string) + " cota(s) criada(s).")
        else if lastResult != #cancelled then
            panelStatus "E12: ferramenta pronta."
        diagnosticTrace #toolStopEnd #("stage=" + (stage as string), "active=" + (active as string), "lastIds=" + (lastSessionIds.count as string))
        true
    ),

    -- ── Entry point ───────────────────────────────────────────────────────────

    fn start =
    (
        persistentInfo ("E12 start solicitado · modo=" + (activeMode as string))
        diagnosticTrace #startRequested #("mode=" + (activeMode as string))
        local began = false
        try (began = begin()) catch
        (
            lastError = getCurrentException() as string
            lastResult = #failed
            cleanupSession clearDraft:true
        )
        if not began then
        (
            diagnosticTrace #startRejected #("lastError=" + lastError)
            return undefined
        )

        local toolResult = #abort
        armEscapeAbort()
        try
        (
            toolResult = startTool AmenoDimensionContinuousMouseTool \
                prompt:"Ameno Cota Contínua: clique vértices · clique viewport confirma · Esc cancela" snap:#3D
            diagnosticTrace #startToolReturned #("toolResult=" + (toolResult as string), "lastIds=" + (lastSessionIds.count as string))
        )
        catch
        (
            lastError = getCurrentException() as string
            lastResult = #failed
            persistentError ("E12 falha ao iniciar ferramenta · " + lastError)
            diagnosticTrace #startException #("error=" + lastError)
            displayTempPrompt ("Ameno Cota Contínua: ferramenta interrompida — " + lastError) 2200
            cleanupSession clearDraft:true
            panelStatus ("E12: ferramenta interrompida — " + lastError)
        )
        restoreEscapeAbort()

        if toolResult == #abort do removeAllPreviews()
        lastSessionIds
    )
)

AmenoDimensionContinuousTool = AmenoDimensionContinuousToolService()

-- ── Mouse Tool block ──────────────────────────────────────────────────────────

tool AmenoDimensionContinuousMouseTool prompt:"Ameno Cota Contínua: clique vértices · clique viewport confirma · Esc cancela"
(
    on start do
    (
        if AmenoDimensionContinuousTool != undefined do
            AmenoDimensionContinuousTool.diagnosticTrace #mouseToolEvent #("type=start")
        if AmenoDimensionContinuousTool != undefined do AmenoDimensionContinuousTool.onStart()
    )

    on freeMove do
    (
        local moveSnapHit = false
        local moveSnapNode = undefined
        local moveSnapPoint = undefined
        local moveSnapStatus = #ok
        try
        (
            moveSnapHit = (snapMode.hit == true)
            if moveSnapHit do
            (
                moveSnapNode = snapMode.node
                moveSnapPoint = snapMode.worldHitpoint
            )
        )
        catch (moveSnapStatus = #error)
        if AmenoDimensionContinuousTool != undefined do
            AmenoDimensionContinuousTool.diagnosticTrace #mouseToolEvent #(
                "type=freeMove",
                "stage=" + (AmenoDimensionContinuousTool.stage as string),
                "references=" + (AmenoDimensionContinuousTool.points.count as string),
                "worldPoint=" + (worldPoint as string)
            ) throttleKey:("native-freeMove:" + (AmenoDimensionContinuousTool.stage as string) + ":" + (AmenoDimensionContinuousTool.points.count as string))
        if AmenoDimensionContinuousTool != undefined do
            AmenoDimensionContinuousTool.handleMove 1 worldPoint screenPoint:viewPoint snapNode:moveSnapNode \
                snapWorldPoint:moveSnapPoint snapHit:moveSnapHit snapStatus:moveSnapStatus
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
            local snapReadStatus    = #ok
            try
            (
                snapped = (snapMode.hit == true)
                if snapped do
                (
                    snappedNode       = snapMode.node
                    snappedWorldPoint = snapMode.worldHitpoint
                )
            )
            catch (snapReadStatus = #error)

            AmenoDimensionContinuousTool.diagnosticTrace #mouseToolEvent #(
                "type=mousePoint",
                "clickNumber=" + (clickNumber as string),
                "stage=" + (AmenoDimensionContinuousTool.stage as string),
                "references=" + (AmenoDimensionContinuousTool.points.count as string),
                "worldPoint=" + (worldPoint as string),
                "viewPoint=" + (viewPoint as string),
                "snapHit=" + (snapped as string),
                "snapStatus=" + (snapReadStatus as string),
                "snapNode=" + (AmenoDimensionContinuousTool.diagnosticNodeText snappedNode),
                "snapWorldPoint=" + (AmenoDimensionContinuousTool.diagnosticPointText snappedWorldPoint)
            )

            local eventOutcome = AmenoDimensionContinuousTool.handlePoint clickNumber worldPoint \
                screenPoint:viewPoint snapNode:snappedNode \
                snapWorldPoint:snappedWorldPoint snapHit:snapped snapStatus:snapReadStatus
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
        local moveSnapHit = false
        local moveSnapNode = undefined
        local moveSnapPoint = undefined
        local moveSnapStatus = #ok
        try
        (
            moveSnapHit = (snapMode.hit == true)
            if moveSnapHit do
            (
                moveSnapNode = snapMode.node
                moveSnapPoint = snapMode.worldHitpoint
            )
        )
        catch (moveSnapStatus = #error)
        if AmenoDimensionContinuousTool != undefined do
            AmenoDimensionContinuousTool.diagnosticTrace #mouseToolEvent #(
                "type=mouseMove",
                "clickNumber=" + (clickNumber as string),
                "stage=" + (AmenoDimensionContinuousTool.stage as string),
                "references=" + (AmenoDimensionContinuousTool.points.count as string),
                "worldPoint=" + (worldPoint as string)
            ) throttleKey:("native-mouseMove:" + (clickNumber as string) + ":" + (AmenoDimensionContinuousTool.stage as string) + ":" + (AmenoDimensionContinuousTool.points.count as string))
        if AmenoDimensionContinuousTool != undefined do
            AmenoDimensionContinuousTool.handleMove clickNumber worldPoint screenPoint:viewPoint snapNode:moveSnapNode \
                snapWorldPoint:moveSnapPoint snapHit:moveSnapHit snapStatus:moveSnapStatus
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
        try
        (
            if AmenoDimensionContinuousTool != undefined do AmenoDimensionContinuousTool.onAbort clickNumber
        )
        catch ()
        -- Retorno explícito evita que um erro secundário no cleanup mantenha o
        -- MouseTool ativo sem devolver o controle ao Max/painel.
        #stop
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
