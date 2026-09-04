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

    -- HUD WPF ────────────────────────────────────────────────────────────────
    hudWindow    = undefined,
    hudLabel     = undefined,
    hudBtnUndo   = undefined,
    hudBtnCancel = undefined,

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

    -- ── HUD WPF ───────────────────────────────────────────────────────────────

    fn buildHudXaml =
    (
        "<Window xmlns='http://schemas.microsoft.com/winfx/2006/xaml/presentation' \
                 xmlns:x='http://schemas.microsoft.com/winfx/2006/xaml' \
                 Title='Cotação Contínua' \
                 Width='240' Height='105' \
                 ResizeMode='NoResize' \
                 WindowStyle='ToolWindow' \
                 Topmost='True' \
                 ShowInTaskbar='False'> \
          <Window.Resources> \
            <Style TargetType='Button'> \
              <Setter Property='Margin' Value='4,0,4,0'/> \
              <Setter Property='Padding' Value='6,4'/> \
              <Setter Property='FontSize' Value='12'/> \
            </Style> \
          </Window.Resources> \
          <Grid Margin='8'> \
            <Grid.RowDefinitions> \
              <RowDefinition Height='Auto'/> \
              <RowDefinition Height='Auto'/> \
              <RowDefinition Height='Auto'/> \
            </Grid.RowDefinitions> \
            <Label x:Name='lblStatus' Grid.Row='0' Content='Pontos: 0 · Segs: 0' \
                   FontSize='12' Padding='0,0,0,4'/> \
            <Label x:Name='lblTotal' Grid.Row='1' Content='Total: —' \
                   FontSize='11' Foreground='Gray' Padding='0,0,0,6'/> \
            <StackPanel Grid.Row='2' Orientation='Horizontal' HorizontalAlignment='Center'> \
              <Button x:Name='btnUndo' Content='↩ Desfazer ponto' IsEnabled='False'/> \
              <Button x:Name='btnCancel' Content='✕ Cancelar'/> \
            </StackPanel> \
          </Grid> \
        </Window>"
    ),

    fn openHUD =
    (
        -- Fecha janela anterior se existir
        if hudWindow != undefined do
        (
            try (hudWindow.Close()) catch ()
            hudWindow    = undefined
            hudLabel     = undefined
            hudBtnUndo   = undefined
            hudBtnCancel = undefined
        )

        try
        (
            local xamlStr  = buildHudXaml()
            local xamlReader = dotNetClass "System.Windows.Markup.XamlReader"
            local win = xamlReader.Parse xamlStr

            hudWindow    = win
            hudLabel     = win.FindName "lblStatus"
            local lblTot = win.FindName "lblTotal"
            hudBtnUndo   = win.FindName "btnUndo"
            hudBtnCancel = win.FindName "btnCancel"

            -- Posiciona no canto superior direito da tela
            local screenW = dotNetClass "System.Windows.SystemParameters"
            try
            (
                win.Left = screenW.PrimaryScreenWidth - 260.0
                win.Top  = 60.0
            )
            catch ()

            -- Handlers de botão
            dotNet.addEventHandler hudBtnUndo "Click" AmenoDimensionContinuousHudUndoHandler
            dotNet.addEventHandler hudBtnCancel "Click" AmenoDimensionContinuousHudCancelHandler

            -- Impede que fechar a janela quebre o tool (apenas esconde)
            dotNet.addEventHandler win "Closing" AmenoDimensionContinuousHudClosingHandler

            win.Show()
        )
        catch
        (
            lastError = getCurrentException() as string
            format "[E12] Falha ao abrir HUD: %\n" lastError
            hudWindow = undefined
        )
    ),

    fn updateHUD =
    (
        if hudWindow == undefined then return false

        try
        (
            local n    = points.count
            local segs = if n > 1 then (n - 1) else 0

            if hudLabel != undefined do
                hudLabel.Content = ("Pontos: " + n as string + "  ·  Segmentos: " + segs as string)

            -- Atualiza total
            local lblTot = hudWindow.FindName "lblTotal"
            if lblTot != undefined do
                lblTot.Content = if segs > 0 then ("Total: " + (formatTotal())) else "Total: —"

            -- Habilita/desabilita undo
            if hudBtnUndo != undefined do
                hudBtnUndo.IsEnabled = (n >= 2)

            -- Muda rótulo do undo conforme stage
            if hudBtnUndo != undefined do
                hudBtnUndo.Content = if stage == #collectingPoints then "↩ Desfazer ponto" else "↩ Desfazer ponto"
        )
        catch ()

        true
    ),

    fn closeHUD =
    (
        if hudWindow != undefined do
        (
            try
            (
                -- Remove handlers antes de fechar para evitar callbacks pós-destruição
                dotNet.removeAllEventHandlers hudBtnUndo
                dotNet.removeAllEventHandlers hudBtnCancel
                dotNet.removeAllEventHandlers hudWindow
                hudWindow.Close()
            )
            catch ()
            hudWindow    = undefined
            hudLabel     = undefined
            hudBtnUndo   = undefined
            hudBtnCancel = undefined
        )
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
        local off = defaultOffset pA pB

        try
        (
            while segmentPreviews.count < segIdx do append segmentPreviews undefined

            if segIdx > segmentPreviews.count then
                append segmentPreviews undefined

            if segmentPreviews[segIdx] == undefined then
                segmentPreviews[segIdx] = AmenoDimensionGraphics.createPreviewDimension pA pB off \
                    outputUnit:previewOutputUnit precision:previewPrecision styleId:activeStyleId mode:activeMode
            else
                segmentPreviews[segIdx] = AmenoDimensionGraphics.updatePreviewDimension segmentPreviews[segIdx] \
                    pA pB off outputUnit:previewOutputUnit precision:previewPrecision styleId:activeStyleId mode:activeMode
        )
        catch ()
        true
    ),

    fn refreshActivePreview cursorPoint =
    (
        if points.count == 0 then return false
        local pA = points[points.count]
        if (length (cursorPoint - pA)) <= 0.00001 then return false
        local off = defaultOffset pA cursorPoint

        try
        (
            if activePreview == undefined then
                activePreview = AmenoDimensionGraphics.createPreviewDimension pA cursorPoint off \
                    outputUnit:previewOutputUnit precision:previewPrecision styleId:activeStyleId mode:activeMode
            else
                activePreview = AmenoDimensionGraphics.updatePreviewDimension activePreview pA cursorPoint off \
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
                -- Duplo-clique: confirma pontos sem adicionar o ponto duplicado
                if clickNumber >= 2 then
                (
                    confirmPoints()
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

                if points.count >= 2 do refreshSegmentPreview (points.count - 1)
                setStage #collectingPoints
                updateHUD()
                undefined
            )
            #offset:
            (
                if points.count < 2 then return undefined

                local offsetPoint = candidate
                removeAllPreviews()

                local createdCount = 0
                for i = 1 to (points.count - 1) do
                (
                    local pA = points[i]
                    local pB = points[i + 1]
                    local nA = anchorNodes[i]
                    local nB = anchorNodes[i + 1]
                    local vA = anchorVertexIds[i]
                    local vB = anchorVertexIds[i + 1]

                    try
                    (
                        local created = AmenoDimensionGraphics.createDimension pA pB offsetPoint \
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
        -- Botão direito / Esc: sempre cancela a sessão inteira
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

-- ── Callbacks globais do HUD (fora da struct para compatibilidade dotNet) ─────

fn AmenoDimensionContinuousHudUndoHandler sender args =
(
    if ::AmenoDimensionContinuousTool != undefined do
        ::AmenoDimensionContinuousTool.undoLastPoint()
)

fn AmenoDimensionContinuousHudCancelHandler sender args =
(
    if ::AmenoDimensionContinuousTool != undefined do
    (
        ::AmenoDimensionContinuousTool.cancel()
        -- Força encerramento do tool ativo
        try (stopTool AmenoDimensionContinuousMouseTool) catch ()
    )
)

fn AmenoDimensionContinuousHudClosingHandler sender args =
(
    -- Se o HUD for fechado pelo usuário (X), cancela a sessão
    if ::AmenoDimensionContinuousTool != undefined and ::AmenoDimensionContinuousTool.active do
    (
        ::AmenoDimensionContinuousTool.cancel()
        try (stopTool AmenoDimensionContinuousMouseTool) catch ()
    )
)

-- ── Mouse Tool block ──────────────────────────────────────────────────────────

tool AmenoDimensionContinuousMouseTool prompt:"Ameno Cota Contínua: clique pontos · duplo-clique confirma · Esc cancela"
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
