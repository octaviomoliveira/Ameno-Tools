/*
    E11.3 — Renderer do Preview Vetorial 2D (Canvas WPF).
    Renderiza de forma isolada, rápida e determinística a cota de visualização em 2D:
    - Planta neutra/contexto arquitetônico sutil;
    - Extensões, recuo (gap) e prolongamento (overhang);
    - Linha principal de dimensão;
    - 5 tipos de terminais geométricos (#tick, #arrowClosed, #arrowOpen, #dot, #none);
    - Inversão automática para posicionamento externo (#outside ou #auto quando espaço apertado);
    - Rótulo de texto com família de fonte, tamanho, B/I, tracking e máscara de corte;
    - Alerta visual no preview se a fonte configurada não estiver instalada;
    - Alternância de fundo escuro (#121212) e claro (#F5F5F5);
    - Zoom (50%, 100%, 200%) com escala vetorial nítida sem pixelização;
    - 100% isolado da cena (0 nós e 0 materiais criados no 3ds Max).
*/

global AmenoPreviewRenderer
global AmenoPreviewModel
global AmenoStyleService

struct AmenoPreviewRendererDefinition
(
    fn createBrush colorStr defaultHex:"#F0F0F0" =
    (
        local colorClass = dotNetClass "System.Windows.Media.Color"
        local colorConv = dotNetClass "System.Windows.Media.ColorConverter"
        local targetStr = if colorStr != undefined and colorStr != "" then colorStr else defaultHex

        -- Se for string RGB "R,G,B"
        local parts = filterString targetStr ","
        if parts.count == 3 then
        (
            try
            (
                local r = parts[1] as integer
                local g = parts[2] as integer
                local b = parts[3] as integer
                local c = colorClass.FromRgb r g b
                return (dotNetObject "System.Windows.Media.SolidColorBrush" c)
            )
            catch ()
        )

        -- Tentar converter via ColorConverter e instanciar SolidColorBrush unfrozen
        try
        (
            local c = colorConv.ConvertFromString targetStr
            return (dotNetObject "System.Windows.Media.SolidColorBrush" c)
        )
        catch
        (
            try
            (
                local cDef = colorConv.ConvertFromString defaultHex
                return (dotNetObject "System.Windows.Media.SolidColorBrush" cDef)
            )
            catch ()
        )

        -- Fallback seguro
        dotNetObject "System.Windows.Media.SolidColorBrush" (colorClass.FromRgb 240 240 240)
    ),

    fn clear canvasHost =
    (
        if canvasHost != undefined and (isProperty canvasHost #Children) do
        (
            canvasHost.Children.Clear()
        )
    ),

    fn render previewModel canvasHost width:undefined height:undefined =
    (
        if previewModel == undefined or canvasHost == undefined do return false
        clear canvasHost

        -- Determinar dimensões reais ou aproximadas do canvas
        local w = if width != undefined and width > 0 then width else (canvasHost.ActualWidth as float)
        local h = if height != undefined and height > 0 then height else (canvasHost.ActualHeight as float)
        if w <= 10.0 do w = 360.0
        if h <= 10.0 do h = 300.0

        local isDark = previewModel.darkBackground
        local bgHex = if isDark then "#121212" else "#F5F5F5"
        local wallFillHex = if isDark then "#252528" else "#E2E2E6"
        local wallStrokeHex = if isDark then "#38383E" else "#C4C4CA"
        local defaultDimHex = if isDark then "#F0F0F0" else "#222222"

        local dimBrush = createBrush previewModel.annotationColor defaultHex:defaultDimHex
        local textBrush = if previewModel.textColor != "" then (createBrush previewModel.textColor defaultHex:defaultDimHex) else dimBrush
        local wallFill = createBrush wallFillHex
        local wallStroke = createBrush wallStrokeHex
        local bgBrush = createBrush bgHex

        local zoomFactor = if previewModel.zoom != undefined and previewModel.zoom > 0 then previewModel.zoom else 1.0
        if zoomFactor < 0.25 do zoomFactor = 0.25
        if zoomFactor > 4.0 do zoomFactor = 4.0

        local cx = w / 2.0
        local cy = h / 2.0

        -- Geometria de base da cota de amostra
        local baseSpan = 200.0 * zoomFactor
        local xA = cx - (baseSpan / 2.0)
        local xB = cx + (baseSpan / 2.0)

        local yDim = cy - (10.0 * zoomFactor)
        local yWall = cy + (45.0 * zoomFactor)
        local wallThickness = 24.0 * zoomFactor

        local lineThick = previewModel.lineThickness * zoomFactor
        if lineThick < 0.8 do lineThick = 0.8

        local overhang = previewModel.extensionOverhang * 0.6 * zoomFactor
        local gap = previewModel.extensionGap * 0.6 * zoomFactor
        local termSize = previewModel.terminalSize * 0.8 * zoomFactor
        if termSize < 4.0 do termSize = 4.0

        local canvasClass = dotNetClass "System.Windows.Controls.Canvas"

        -------------------------------------------------------------
        -- 1. PLANTA NEUTRA (CONTEXTO ARQUITETÔNICO SUTIL)
        -------------------------------------------------------------
        local wallRect = dotNetObject "System.Windows.Shapes.Rectangle"
        wallRect.Width = baseSpan + (70.0 * zoomFactor)
        wallRect.Height = wallThickness
        wallRect.Fill = wallFill
        wallRect.Stroke = wallStroke
        wallRect.StrokeThickness = 1.0
        canvasClass.SetLeft wallRect (xA - (35.0 * zoomFactor))
        canvasClass.SetTop wallRect yWall
        canvasHost.Children.Add wallRect

        -- Retorno de parede à esquerda
        local retL = dotNetObject "System.Windows.Shapes.Rectangle"
        retL.Width = 20.0 * zoomFactor
        retL.Height = 35.0 * zoomFactor
        retL.Fill = wallFill
        retL.Stroke = wallStroke
        retL.StrokeThickness = 1.0
        canvasClass.SetLeft retL (xA - (35.0 * zoomFactor))
        canvasClass.SetTop retL (yWall + wallThickness)
        canvasHost.Children.Add retL

        -- Retorno de parede à direita
        local retR = dotNetObject "System.Windows.Shapes.Rectangle"
        retR.Width = 20.0 * zoomFactor
        retR.Height = 35.0 * zoomFactor
        retR.Fill = wallFill
        retR.Stroke = wallStroke
        retR.StrokeThickness = 1.0
        canvasClass.SetLeft retR (xB + (15.0 * zoomFactor))
        canvasClass.SetTop retR (yWall + wallThickness)
        canvasHost.Children.Add retR

        -------------------------------------------------------------
        -- 2. LINHAS DE EXTENSÃO
        -------------------------------------------------------------
        local extStart = yWall - gap
        local extEnd = yDim - overhang

        local extLineA = dotNetObject "System.Windows.Shapes.Line"
        extLineA.X1 = xA; extLineA.Y1 = extStart; extLineA.X2 = xA; extLineA.Y2 = extEnd
        extLineA.Stroke = dimBrush
        extLineA.StrokeThickness = lineThick * 0.8
        canvasHost.Children.Add extLineA

        local extLineB = dotNetObject "System.Windows.Shapes.Line"
        extLineB.X1 = xB; extLineB.Y1 = extStart; extLineB.X2 = xB; extLineB.Y2 = extEnd
        extLineB.Stroke = dimBrush
        extLineB.StrokeThickness = lineThick * 0.8
        canvasHost.Children.Add extLineB

        -------------------------------------------------------------
        -- 3. LINHA PRINCIPAL DE COTA
        -------------------------------------------------------------
        -- Decisão de posicionamento dos terminais (fit interno/externo)
        local isTight = (baseSpan < (termSize * 3.5))
        local isOutside = (previewModel.terminalPlacement == #outside) or (previewModel.terminalPlacement == #auto and isTight)

        local mainLineStart = if isOutside then (xA - termSize - (8.0 * zoomFactor)) else xA
        local mainLineEnd = if isOutside then (xB + termSize + (8.0 * zoomFactor)) else xB

        local mainLine = dotNetObject "System.Windows.Shapes.Line"
        mainLine.X1 = mainLineStart; mainLine.Y1 = yDim
        mainLine.X2 = mainLineEnd; mainLine.Y2 = yDim
        mainLine.Stroke = dimBrush
        mainLine.StrokeThickness = lineThick
        canvasHost.Children.Add mainLine

        -------------------------------------------------------------
        -- 4. TERMINAIS GEOMÉTRICOS (5 TIPOS)
        -------------------------------------------------------------
        case previewModel.terminalType of
        (
            #tick:
            (
                local angleDeg = if previewModel.terminalAngle != undefined then previewModel.terminalAngle else 45.0
                local rad = angleDeg * (pi / 180.0)
                local dx = (termSize * 0.5) * (cos angleDeg)
                local dy = (termSize * 0.5) * (sin angleDeg)

                local tickA = dotNetObject "System.Windows.Shapes.Line"
                tickA.X1 = (xA - dx); tickA.Y1 = (yDim + dy); tickA.X2 = (xA + dx); tickA.Y2 = (yDim - dy)
                tickA.Stroke = dimBrush
                tickA.StrokeThickness = lineThick * 1.3
                canvasHost.Children.Add tickA

                local tickB = dotNetObject "System.Windows.Shapes.Line"
                tickB.X1 = (xB - dx); tickB.Y1 = (yDim + dy); tickB.X2 = (xB + dx); tickB.Y2 = (yDim - dy)
                tickB.Stroke = dimBrush
                tickB.StrokeThickness = lineThick * 1.3
                canvasHost.Children.Add tickB
            )
            #arrowClosed:
            (
                local halfW = termSize * 0.3
                local polyA = dotNetObject "System.Windows.Shapes.Polygon"
                local polyB = dotNetObject "System.Windows.Shapes.Polygon"
                polyA.Fill = dimBrush
                polyB.Fill = dimBrush

                local ptClass = dotNetClass "System.Windows.Point"
                local ptsA = dotNetObject "System.Windows.Media.PointCollection"
                local ptsB = dotNetObject "System.Windows.Media.PointCollection"

                if not isOutside then
                (
                    ptsA.Add (dotNetObject ptClass xA yDim)
                    ptsA.Add (dotNetObject ptClass (xA + termSize) (yDim - halfW))
                    ptsA.Add (dotNetObject ptClass (xA + termSize) (yDim + halfW))

                    ptsB.Add (dotNetObject ptClass xB yDim)
                    ptsB.Add (dotNetObject ptClass (xB - termSize) (yDim - halfW))
                    ptsB.Add (dotNetObject ptClass (xB - termSize) (yDim + halfW))
                )
                else
                (
                    ptsA.Add (dotNetObject ptClass xA yDim)
                    ptsA.Add (dotNetObject ptClass (xA - termSize) (yDim - halfW))
                    ptsA.Add (dotNetObject ptClass (xA - termSize) (yDim + halfW))

                    ptsB.Add (dotNetObject ptClass xB yDim)
                    ptsB.Add (dotNetObject ptClass (xB + termSize) (yDim - halfW))
                    ptsB.Add (dotNetObject ptClass (xB + termSize) (yDim + halfW))
                )

                polyA.Points = ptsA
                polyB.Points = ptsB
                canvasHost.Children.Add polyA
                canvasHost.Children.Add polyB
            )
            #arrowOpen:
            (
                local halfW = termSize * 0.3
                local lA1 = dotNetObject "System.Windows.Shapes.Line"
                local lA2 = dotNetObject "System.Windows.Shapes.Line"
                local lB1 = dotNetObject "System.Windows.Shapes.Line"
                local lB2 = dotNetObject "System.Windows.Shapes.Line"
                lA1.Stroke = dimBrush; lA1.StrokeThickness = lineThick
                lA2.Stroke = dimBrush; lA2.StrokeThickness = lineThick
                lB1.Stroke = dimBrush; lB1.StrokeThickness = lineThick
                lB2.Stroke = dimBrush; lB2.StrokeThickness = lineThick

                local dir = if not isOutside then 1.0 else -1.0

                lA1.X1 = xA; lA1.Y1 = yDim; lA1.X2 = xA + (termSize * dir); lA1.Y2 = yDim - halfW
                lA2.X1 = xA; lA2.Y1 = yDim; lA2.X2 = xA + (termSize * dir); lA2.Y2 = yDim + halfW

                lB1.X1 = xB; lB1.Y1 = yDim; lB1.X2 = xB - (termSize * dir); lB1.Y2 = yDim - halfW
                lB2.X1 = xB; lB2.Y1 = yDim; lB2.X2 = xB - (termSize * dir); lB2.Y2 = yDim + halfW

                canvasHost.Children.Add lA1
                canvasHost.Children.Add lA2
                canvasHost.Children.Add lB1
                canvasHost.Children.Add lB2
            )
            #dot:
            (
                local r = termSize * 0.35
                local dotA = dotNetObject "System.Windows.Shapes.Polygon"
                local dotB = dotNetObject "System.Windows.Shapes.Polygon"
                dotA.Fill = dimBrush
                dotB.Fill = dimBrush

                local ptClass = dotNetClass "System.Windows.Point"
                local ptsA = dotNetObject "System.Windows.Media.PointCollection"
                local ptsB = dotNetObject "System.Windows.Media.PointCollection"

                ptsA.Add (dotNetObject ptClass xA (yDim - r))
                ptsA.Add (dotNetObject ptClass (xA + r) yDim)
                ptsA.Add (dotNetObject ptClass xA (yDim + r))
                ptsA.Add (dotNetObject ptClass (xA - r) yDim)

                ptsB.Add (dotNetObject ptClass xB (yDim - r))
                ptsB.Add (dotNetObject ptClass (xB + r) yDim)
                ptsB.Add (dotNetObject ptClass xB (yDim + r))
                ptsB.Add (dotNetObject ptClass (xB - r) yDim)

                dotA.Points = ptsA
                dotB.Points = ptsB
                canvasHost.Children.Add dotA
                canvasHost.Children.Add dotB
            )
            #none:
            (
                -- Sem terminais
            )
        )

        -------------------------------------------------------------
        -- 5. RÓTULO DE TEXTO COM MÁSCARA DE FUNDO
        -------------------------------------------------------------
        local textStr = if previewModel.sampleValue != undefined and previewModel.sampleValue != "" then previewModel.sampleValue else "3,50 m"
        local fontSz = previewModel.fontSize * 0.7 * zoomFactor
        if fontSz < 8.0 do fontSz = 8.0

        local txtBlock = dotNetObject "System.Windows.Controls.TextBlock"
        txtBlock.Text = textStr
        txtBlock.FontSize = fontSz
        txtBlock.Foreground = textBrush

        -- Verificar se a fonte está instalada
        local validFont = previewModel.fontName
        local isFontMissing = false
        if ::AmenoStyleService != undefined do
        (
            local vf = ::AmenoStyleService.validateFont previewModel.fontName
            if vf != previewModel.fontName do
            (
                validFont = "Arial"
                isFontMissing = true
            )
        )
        txtBlock.FontFamily = dotNetObject "System.Windows.Media.FontFamily" validFont

        if previewModel.bold do txtBlock.FontWeight = (dotNetClass "System.Windows.FontWeights").Bold
        if previewModel.italic do txtBlock.FontStyle = (dotNetClass "System.Windows.FontStyles").Italic

        -- Container com máscara de fundo
        local textBorder = dotNetObject "System.Windows.Controls.Border"
        textBorder.Child = txtBlock
        textBorder.CornerRadius = dotNetObject "System.Windows.CornerRadius" 2.0

        if previewModel.textMaskEnabled then
        (
            textBorder.Background = bgBrush
            textBorder.Padding = dotNetObject "System.Windows.Thickness" 4.0 1.0 4.0 1.0
        )
        else
        (
            textBorder.Background = createBrush "Transparent"
            textBorder.Padding = dotNetObject "System.Windows.Thickness" 2.0 0.0 2.0 0.0
        )

        -- Medição e centralização do rótulo
        local sizeClass = dotNetClass "System.Windows.Size"
        local infiniteSize = dotNetObject sizeClass (dotNetClass "System.Double").PositiveInfinity (dotNetClass "System.Double").PositiveInfinity
        textBorder.Measure infiniteSize
        local textWidth = textBorder.DesiredSize.Width
        local textHeight = textBorder.DesiredSize.Height

        local tGap = previewModel.textGap * 0.6 * zoomFactor
        local textX = cx - (textWidth / 2.0)
        local textY = yDim - tGap - (textHeight / 2.0)

        canvasClass.SetLeft textBorder textX
        canvasClass.SetTop textBorder textY
        canvasHost.Children.Add textBorder

        -------------------------------------------------------------
        -- 6. ALERTA VISUAL DE FONTE AUSENTE (SE APLICÁVEL)
        -------------------------------------------------------------
        if isFontMissing do
        (
            local warnBorder = dotNetObject "System.Windows.Controls.Border"
            warnBorder.Background = createBrush "#3A2B14"
            warnBorder.BorderBrush = createBrush "#D19A66"
            warnBorder.BorderThickness = dotNetObject "System.Windows.Thickness" 1.0
            warnBorder.CornerRadius = dotNetObject "System.Windows.CornerRadius" 3.0
            warnBorder.Padding = dotNetObject "System.Windows.Thickness" 6.0 2.0 6.0 2.0

            local warnText = dotNetObject "System.Windows.Controls.TextBlock"
            warnText.Text = "⚠️ Fonte '" + previewModel.fontName + "' não instalada (exibindo Arial)"
            warnText.Foreground = createBrush "#E5C07B"
            warnText.FontSize = 10.0

            warnBorder.Child = warnText
            canvasClass.SetLeft warnBorder 10.0
            canvasClass.SetTop warnBorder 8.0
            canvasHost.Children.Add warnBorder
        )

        true
    )
)

AmenoPreviewRenderer = AmenoPreviewRendererDefinition()
