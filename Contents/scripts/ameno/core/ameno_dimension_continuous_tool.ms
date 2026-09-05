/*
    E12 — Ferramenta de cotação contínua estilo Revit (Híbrida).

    Fluxo de interação:
      1. Painel principal abre o HUD WPF (pequeno, flutuante) e ativa o MouseTool.
      2. Usuário clica N pontos sequenciais (≥ 2).
      3. Duplo-clique → confirma os pontos e vai para #offset.
      4. Clique de offset → cria N-1 cotas paralelas → encerra.

    Gestos:
      - Clique esquerdo (simples)  : adiciona ponto
      - Duplo-clique esquerdo      : confirma pontos (vai para #offset)
      - Esc / botão direito        : cancela toda a sessão

    HUD WPF (240 × 80 px):
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

-- ── HUD Rollout: painel nativo do 3ds Max (funciona durante startTool) ───────

rollout AmenoContinuousHUDRlt "Cotação Contínua" width:270
(
    label   lblStatus "Pontos: 0" align:#left
    label   lblInstr  "Btn-dir ou duplo-clique para confirmar" align:#left
    button  btnConfirm "Finalizar coleta de pontos" width:254 enabled:false
    button  btnUndo   "Desfazer" width:125 across:2 enabled:false
    button  btnCancel "Cancelar" width:125

    on btnConfirm pressed do
    (
        if ::AmenoDimensionContinuousTool != undefined do
            ::AmenoDimensionContinuousTool.confirmPoints()
    )

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

    -- Detecta âncora (cópia fiel do AmenoDimensionToolService)
    fn detectHitNode pointValue screenPoint:undefined snapNode:undefined snapWorldPoint:undefined snapHit:false =
    (
        local anchorPoint = if snapHit and snapWorldPoint != undefined then snapWorldPoint else pointValue

        if snapHit and snapNode != undefined and isValidNode snapNode and anchorPoint != undefined do
        (
            local snapKind = ::AmenoDimensionGraphics.readTextProperty snapNode "Ameno.Kind"
            if (snapKind == undefined or snapKind == "") and (findString snapNode.name "AMENO_" == undefined) do
            (
                local tol = if ::AmenoDimensionGraphics != undefined then (::AmenoDimensionGraphics.toSceneUnits 10.0) else 1.0
                local sv = undefined
                if ::AmenoDimensionCA != undefined do sv = ::AmenoDimensionCA.findNearestVertex snapNode anchorPoint maxDistance:tol
                if sv != undefined then
                    return (AmenoDimensionAnchorHit node:snapNode vertexId:sv.vertexId vertexWorldPoint:sv.worldPoint)
                else
                    return (AmenoDimensionAnchorHit node:snapNode)
            )
        )

        if anchorPoint != undefined and ::AmenoDimensionCA != undefined do
        (
            local tol = if ::AmenoDimensionGraphics != undefined then (::AmenoDimensionGraphics.toSceneUnits 10.0) else 1.0
            local bestNode = undefined
            local bestHit  = undefined
            local bestDist = 1e30

            for obj in geometry where isValidNode obj and not obj.isHidden do
            (
                local k = ::AmenoDimensionGraphics.readTextProperty obj "Ameno.Kind"
                if (k == undefined or k == "") and (findString obj.name "AMENO_" == undefined) do
                (
                    local inside = false
                    try
                    (
                        local bbMin = obj.min
                        local bbMax = obj.max
                        inside = anchorPoint.x >= (bbMin.x - tol) and anchorPoint.x <= (bbMax.x + tol) and \
                                 anchorPoint.y >= (bbMin.y - tol) and anchorPoint.y <= (bbMax.y + tol) and \
                                 anchorPoint.z >= (bbMin.z - tol) and anchorPoint.z <= (bbMax.z + tol)
                    )
                    catch ()

                    if inside do
                    (
                        local vh = ::AmenoDimensionCA.findNearestVertex obj anchorPoint maxDistance:tol
                        if vh != undefined and vh.distance < bestDist do
                        (
                            bestNode = obj
                            bestHit  = vh
                            bestDist = vh.distance
                        )
                    )
                )
            )
            if bestNode != undefined and bestHit != undefined then
                return (AmenoDimensionAnchorHit node:bestNode vertexId:bestHit.vertexId vertexWorldPoint:bestHit.worldPoint)
        )

        local candidateNode = undefined
        try
        (
            local r = if screenPoint != undefined then (mapScreenToWorldRay screenPoint) else (mapScreenToWorldRay mouse.pos)
            if r != undefined then
            (
                local hits = intersectRayScene r
                for h in hits where isValidNode h[1] do
                (
                    local k = ::AmenoDimensionGraphics.readTextProperty h[1] "Ameno.Kind"
                    if (k == undefined or k == "") and (findString h[1].name "AMENO_" == undefined) do
                    (
                        candidateNode = h[1]
                        exit
                    )
                )
            )
        )
        catch ()

        local result = AmenoDimensionAnchorHit node:candidateNode
        if candidateNode != undefined and ::AmenoDimensionCA != undefined do
        (
            local tol = if ::AmenoDimensionGraphics != undefined then (::AmenoDimensionGraphics.toSceneUnits 10.0) else 1.0
            local vh = ::AmenoDimensionCA.findNearestVertex candidateNode anchorPoint maxDistance:tol
            if vh != undefined do
            (
                result.vertexId = vh.vertexId
                result.vertexWorldPoint = vh.worldPoint
            )
        )
        result
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
            #collectingPoints:
                if n == 0 then
                    "Ameno Cota Contínua: clique o 1º ponto  (Esc cancela)"
                else
                    ("Ameno Cota Contínua: " + n as string + " ponto(s) · duplo-clique confirma  (Esc cancela)")
            #offset:
                ("Ameno Cota Contínua: " + n as string + " pontos · clique o afastamento  (Esc cancela)")
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
                #collectingPoints: ("E12: coletando pontos (" + points.count as string + " definido(s)) · duplo-clique confirma.")
                #offset:           ("E12: " + points.count as string + " pontos · clique o afastamento.")
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
            if stage == #offset then
                instrStr = ">> Clique o afastamento das cotas <<"
            else if segs > 0 then
                instrStr = "Duplo-clique ou Finalizar para confirmar"
            else
                instrStr = "Continue clicando os pontos"
            ::AmenoContinuousHUDRlt.lblInstr.text = instrStr

            -- Botão Finalizar
            ::AmenoContinuousHUDRlt.btnConfirm.enabled = (n >= 2 and stage == #collectingPoints)

            -- Botão Undo
            ::AmenoContinuousHUDRlt.btnUndo.enabled = (n >= 1 and stage == #collectingPoints)
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

        setStage #collectingPoints
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
        setStage #collectingPoints
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

    -- ── Confirmar pontos → ir para #offset ────────────────────────────────────

    fn confirmPoints =
    (
        if stage != #collectingPoints then return false
        if points.count < 2 then
        (
            displayTempPrompt "Ameno Cota Contínua: defina ao menos 2 pontos antes de confirmar." 1600
            return false
        )
        removeActivePreview()
        setStage #offset
        updateHUD()
        true
    ),

    -- ── Handlers de mouse ─────────────────────────────────────────────────────

    fn handlePoint clickNumber pointValue screenPoint:undefined snapNode:undefined snapWorldPoint:undefined snapHit:false =
    (
        if not active then return #stop

        local effectivePoint = if snapHit and snapWorldPoint != undefined then snapWorldPoint else pointValue
        local candidate = flattenPoint effectivePoint
        if candidate == undefined then return undefined

        case stage of
        (
            #collectingPoints:
            (
                -- Se não há snap (clique no vazio): confirmar se já tem pontos, senão ignorar
                if not snapHit and snapWorldPoint == undefined then
                (
                    if points.count >= 2 then confirmPoints()
                    return undefined
                )

                -- Verifica duplicata com ponto imediatamente anterior
                if points.count > 0 and (length (candidate - points[points.count])) <= 0.00001 then
                (
                    displayTempPrompt "Ameno Cota Contínua: escolha um ponto diferente do anterior." 1400
                    return undefined
                )

                -- Detecta âncora
                local hit = detectHitNode effectivePoint screenPoint:screenPoint snapNode:snapNode \
                    snapWorldPoint:snapWorldPoint snapHit:snapHit
                local finalPoint = if hit.vertexWorldPoint != undefined then (flattenPoint hit.vertexWorldPoint) else candidate

                append points          finalPoint
                append anchorNodes     hit.node
                append anchorVertexIds hit.vertexId

                -- NÃO mostramos preview de segmento aqui: evita os ângulos confusos durante coleta.
                -- Previews de todos os segmentos aparecem apenas na fase #offset (ao mover o cursor).
                setStage #collectingPoints
                updateHUD()
                undefined
            )
            #offset:
            (
                if points.count < 2 then return undefined

                local rawOffset = candidate
                removeAllPreviews()

                -- Calcula distância perpendicular consistente a partir da direção global P1→Pn
                -- para que TODAS as cotas fiquem no mesmo nível visual.
                local p1    = points[1]
                local pN    = points[points.count]
                local gDirV = [pN.x - p1.x, pN.y - p1.y, 0.0]
                local gLen  = length gDirV
                local gPerp = if gLen > 0.00001 then \
                    (normalize (cross [0,0,1] (normalize gDirV))) else [0,1,0]
                -- Distância escalar: positiva = lado esquerdo da direção global
                local offsetDist = dot (rawOffset - p1) gPerp

                local createdCount = 0
                for i = 1 to (points.count - 1) do
                (
                    local pA = points[i]
                    local pB = points[i + 1]
                    local nA = anchorNodes[i]
                    local nB = anchorNodes[i + 1]
                    local vA = anchorVertexIds[i]
                    local vB = anchorVertexIds[i + 1]

                    -- Offset para este segmento: perpendicular própria × distância escalar global
                    local segDirV = [pB.x - pA.x, pB.y - pA.y, 0.0]
                    local segLen  = length segDirV
                    local segPerp = if segLen > 0.00001 then \
                        (normalize (cross [0,0,1] (normalize segDirV))) else gPerp
                    local segMid        = (pA + pB) / 2.0
                    local segOffsetPt   = segMid + (segPerp * offsetDist)

                    try
                    (
                        local created = AmenoDimensionGraphics.createDimension pA pB segOffsetPt \
                            role:"interactive" outputUnit:previewOutputUnit precision:previewPrecision \
                            styleId:activeStyleId nodeA:nA anchorVertexIdA:vA nodeB:nB anchorVertexIdB:vB \
                            dimensionMode:activeMode

                        if created != undefined do
                        (
                            append lastSessionIds created.dimensionId
                            createdCount += 1
                        )
                    )
                    catch
                    (
                        lastError = getCurrentException() as string
                        format "[E12] Erro ao criar cota %/%: %\n" i (points.count - 1) lastError
                    )
                )

                if ::AmenoAnchorService != undefined do
                    try (::AmenoAnchorService.rebuildIndex()) catch ()

                closeHUD()
                panelStatus ("E12: " + createdCount as string + " cota(s) criada(s).")
                #stop
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
            #collectingPoints:
                if points.count >= 1 do refreshActivePreview candidate
            #offset:
            (
                removeActivePreview()
                if points.count >= 2 do refreshAllPreviewsWithOffset candidate
            )
            default: undefined
        )
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
        -- Clique direito: confirmar se >= 2 pontos (como Revit/AutoCAD)
        -- Se não tem pontos suficientes, cancela
        if stage == #collectingPoints and points.count >= 2 then
        (
            confirmPoints()
        )
        else
        (
            cancel()
            displayTempPrompt "Ameno Cota Contínua: sessão cancelada." 1000
        )
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
                prompt:"Ameno Cota Contínua: clique pontos · duplo-clique confirma · Esc cancela" snap:#3D
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

tool AmenoDimensionContinuousMouseTool prompt:"Ameno Cota Contínua: clique pontos · btn-dir ou duplo-clique confirma · Esc cancela"
(
    -- Detecção de duplo-clique por tempo (clickNumber é sequencial, não indica duplo-clique)
    local lastClickMs = 0

    on start do
    (
        lastClickMs = 0
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
            -- Verifica duplo-clique por intervalo de tempo
            local now = timeStamp()
            local dt  = now - lastClickMs
            lastClickMs = now

            -- Duplo-clique: intervalo < 400ms e já tem pelo menos 1 ponto
            if dt < 400 and AmenoDimensionContinuousTool.stage == #collectingPoints \
                        and AmenoDimensionContinuousTool.points.count >= 1 then
            (
                AmenoDimensionContinuousTool.confirmPoints()
            )
            else
            (
                -- Clique simples: acumula ponto
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
