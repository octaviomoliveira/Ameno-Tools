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
global AmenoContinuousClickClassification

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

    fn classifyDetectedHit detectedHit snapHit:false snapNode:undefined snapWorldPoint:undefined =
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
            AmenoContinuousClickClassification kind:#empty detail:"no eligible geometry under cursor"
    ),

    fn classifyClick pointValue screenPoint:undefined snapNode:undefined snapWorldPoint:undefined snapHit:false =
    (
        local detectedHit = detectHitNode pointValue screenPoint:screenPoint snapNode:snapNode \
            snapWorldPoint:snapWorldPoint snapHit:snapHit
        classifyDetectedHit detectedHit snapHit:snapHit snapNode:snapNode snapWorldPoint:snapWorldPoint
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

    fn defaultOffset pA pB =
    (
        local mv  = [pB.x - pA.x, pB.y - pA.y, 0.0]
        local len = length mv
        if len > 0.00001 then
        (
            local dir  = normalize mv
            local perp = normalize (cross [0, 0, 1] dir)
            local dist = amax (len * 0.2) 10.0
            pA + (perp * dist)
        )
        else
            pA + [0, 100.0, 0]
    ),

    fn refreshSegmentPreview segIdx =
    (
        if segIdx < 1 or segIdx >= points.count then return false
        local pA = points[segIdx]
        local pB = points[segIdx + 1]
        local calcOff = defaultOffset pA pB

        try
        (
            while segmentPreviews.count < segIdx do append segmentPreviews undefined

            if segIdx > segmentPreviews.count then
                append segmentPreviews undefined

            if segmentPreviews[segIdx] == undefined then
                segmentPreviews[segIdx] = AmenoDimensionGraphics.createPreviewDimension pA pB calcOff \
                    outputUnit:previewOutputUnit precision:previewPrecision styleId:activeStyleId mode:activeMode
            else
                segmentPreviews[segIdx] = AmenoDimensionGraphics.updatePreviewDimension segmentPreviews[segIdx] \
                    pA pB calcOff outputUnit:previewOutputUnit precision:previewPrecision styleId:activeStyleId mode:activeMode
        )
        catch ()
        true
    ),

    fn refreshActivePreview cursorPoint =
    (
        if points.count == 0 then return false
        local pA = points[points.count]
        if (length (cursorPoint - pA)) <= 0.00001 then return false
        local calcOff = defaultOffset pA cursorPoint

        try
        (
            if activePreview == undefined then
                activePreview = AmenoDimensionGraphics.createPreviewDimension pA cursorPoint calcOff \
                    outputUnit:previewOutputUnit precision:previewPrecision styleId:activeStyleId mode:activeMode
            else
                activePreview = AmenoDimensionGraphics.updatePreviewDimension activePreview pA cursorPoint calcOff \
                    outputUnit:previewOutputUnit precision:previewPrecision styleId:activeStyleId mode:activeMode
        )
        catch ()
        true
    ),

    fn refreshAllPreviewsWithOffset offsetPoint =
    (
        for i = 1 to (points.count - 1) do
        (
            local pA = points[i]
            local pB = points[i + 1]
            try
            (
                while segmentPreviews.count < i do append segmentPreviews undefined

                if segmentPreviews[i] == undefined then
                    segmentPreviews[i] = AmenoDimensionGraphics.createPreviewDimension pA pB offsetPoint \
                        outputUnit:previewOutputUnit precision:previewPrecision styleId:activeStyleId mode:activeMode
                else
                    segmentPreviews[i] = AmenoDimensionGraphics.updatePreviewDimension segmentPreviews[i] \
                        pA pB offsetPoint outputUnit:previewOutputUnit precision:previewPrecision styleId:activeStyleId mode:activeMode
            )
            catch ()
        )
    ),

    -- ── Undo de ponto (chamado pelo HUD) ──────────────────────────────────────

    fn undoLastPoint =
    (
        if points.count == 0 then return false

        -- Remove preview do último segmento
        local lastSeg = points.count - 1
        if lastSeg >= 1 do removeSegmentPreview lastSeg

        -- Compacta array de previews
        if segmentPreviews.count > 0 do
        (
            local newPreviews = #()
            for i = 1 to (segmentPreviews.count - 1) do append newPreviews segmentPreviews[i]
            segmentPreviews = newPreviews
        )

        -- Remove preview ativo
        removeActivePreview()

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
        updateHUD()
        true
    ),

    -- ── Ciclo de vida ─────────────────────────────────────────────────────────

    fn begin =
    (
        if active then return false

        local sceneState = AmenoSceneSetup.inspect()
        if sceneState.status != #ready do sceneState = AmenoSceneSetup.prepare()

        if sceneState.status != #ready then
        (
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
        active          = true
        setStage #collecting
        openHUD()
        updateHUD()
        true
    ),

    fn cancel =
    (
        removeAllPreviews()
        points          = #()
        anchorNodes     = #()
        anchorVertexIds = #()
        segmentPreviews = #()
        active          = false
        stage           = #idle
        closeHUD()
        panelStatus "E12: sessão cancelada."
        true
    ),

    -- ── Solicitação de commit; layout/criação pertencem aos gates E12-B/C ────

    fn requestCommit =
    (
        if stage != #collecting then return false
        if points.count < 2 then
        (
            displayTempPrompt "Ameno Cota Contínua: defina ao menos 2 pontos antes de confirmar." 1600
            return false
        )
        setStage #committing
        updateHUD()
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

    fn handleClassifiedClick clickInfo =
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
                else if requestCommit() then #commitRequested else #ignored
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
        if not active then return #stop

        local effectivePoint = if snapHit and snapWorldPoint != undefined then snapWorldPoint else pointValue
        if flattenPoint effectivePoint == undefined then return #ambiguous
        local clickInfo = classifyClick effectivePoint screenPoint:screenPoint snapNode:snapNode \
            snapWorldPoint:snapWorldPoint snapHit:snapHit
        handleClassifiedClick clickInfo
    ),

    fn handleMove clickNumber pointValue =
    (
        if not active then return undefined

        local candidate = flattenPoint pointValue
        if candidate == undefined then return undefined

        -- O preview compartilhado será conectado ao calculador único na E12-C.
        undefined
    ),

    -- ── onStart / onAbort / onStop ────────────────────────────────────────────

    fn onStart =
    (
        if not active do active = true
        updatePrompt()
        true
    ),

    fn onAbort clickNumber =
    (
        cancel()
        displayTempPrompt "Ameno Cota Contínua: sessão cancelada." 1000
        undefined
    ),

    fn onStop =
    (
        removeAllPreviews()
        closeHUD()
        try (popPrompt()) catch ()
        active = false
        stage  = #idle
        panelStatus "E12: ferramenta pronta."
        true
    ),

    -- ── Entry point ───────────────────────────────────────────────────────────

    fn start =
    (
        if not begin() then return undefined

        local toolResult = #abort
        try
        (
            toolResult = startTool AmenoDimensionContinuousMouseTool \
                prompt:"Ameno Cota Contínua: clique vértices · clique vazio posiciona · Esc cancela" snap:#3D
        )
        catch
        (
            lastError = getCurrentException() as string
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
        if AmenoDimensionContinuousTool != undefined do AmenoDimensionContinuousTool.onStart()
    )

    on freeMove do
    (
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

            AmenoDimensionContinuousTool.handlePoint clickNumber worldPoint \
                screenPoint:viewPoint snapNode:snappedNode \
                snapWorldPoint:snappedWorldPoint snapHit:snapped
        )
    )

    on mouseMove clickNumber do
    (
        if AmenoDimensionContinuousTool != undefined do AmenoDimensionContinuousTool.handleMove clickNumber worldPoint
    )

    on mouseAbort clickNumber do
    (
        if AmenoDimensionContinuousTool != undefined do AmenoDimensionContinuousTool.onAbort clickNumber
    )

    on stop do
    (
        if AmenoDimensionContinuousTool != undefined do AmenoDimensionContinuousTool.onStop()
    )
)
