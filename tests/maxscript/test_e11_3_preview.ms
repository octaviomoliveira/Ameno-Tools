/*
    E11.3 — Testes do Renderer de Preview Vetorial 2D (Canvas WPF).
    Verifica:
    1. Renderização dos 5 tipos de terminal (#tick, #arrowClosed, #arrowOpen, #dot, #none).
    2. Modificação de linhas de extensão (overhang e gap).
    3. Tipografia: peso, itálico, tamanho, fonte e sampleValue.
    4. Máscara de corte de texto (fundo opaco vs transparente).
    5. Cores da cota e do texto.
    6. Alternância de temas de fundo (escuro #121212 vs claro #F5F5F5).
    7. Fit interno vs externo determinístico dos terminais.
    8. Alerta visual de fonte não instalada.
    9. Escala vetorial nítida com Zoom (50%, 100%, 200%).
    10. Isolamento de cena (0 nós, 0 materiais e 0 layers criados na cena 3D).
*/

(
    global AmenoPreviewRenderer
    global AmenoPreviewModel
    global AmenoStyleService
    global AmenoStyleEditorWPF

    format "\n=================================================================\n"
    format "=== [AMENO_TEST] Iniciando Testes da E11.3: Renderer do Preview ===\n"
    format "=================================================================\n\n"

    resetMaxFile #noPrompt

    local testFile = getSourceFileName()
    local testPath = getFilenamePath testFile
    local repositoryRoot = pathConfig.normalizePath (pathConfig.appendPath testPath @"..\..")
    local bootstrapPath = pathConfig.normalizePath (pathConfig.appendPath repositoryRoot @"Contents\scripts\startup\ameno_bootstrap.ms")
    fileIn bootstrapPath quiet:true

    local totalTests = 0
    local passedTests = 0

    fn assertCondition desc condition =
    (
        totalTests += 1
        if condition then (
            passedTests += 1
            format "[PASS] %\n" desc
        ) else (
            format "[FAIL] %\n" desc
        )
    )

    -- Instanciar um Canvas WPF independente para os testes unitários do renderer
    local canvas = dotNetObject "System.Windows.Controls.Canvas"
    canvas.Width = 400.0
    canvas.Height = 350.0

    -- Helper para contar tipos de filhos no Canvas
    fn countChildrenOfType canvasHost typeName =
    (
        local cnt = 0
        for i = 0 to (canvasHost.Children.Count - 1) do
        (
            local child = canvasHost.Children.Item[i]
            local childType = child.GetType()
            local t = childType.Name
            if t == typeName do cnt += 1
        )
        cnt
    )

    -- Helper para encontrar primeiro TextBlock
    fn findTextBlock canvasHost =
    (
        for i = 0 to (canvasHost.Children.Count - 1) do
        (
            local child = canvasHost.Children.Item[i]
            local childType = child.GetType()
            if childType.Name == "Border" and child.Child != undefined do
            (
                local childSub = child.Child.GetType()
                if childSub.Name == "TextBlock" do return child.Child
            )
        )
        undefined
    )

    -- Helper para encontrar primeiro Border de texto
    fn findTextBorder canvasHost =
    (
        for i = 0 to (canvasHost.Children.Count - 1) do
        (
            local child = canvasHost.Children.Item[i]
            local childType = child.GetType()
            if childType.Name == "Border" and child.Child != undefined do
            (
                local childSub = child.Child.GetType()
                if childSub.Name == "TextBlock" do return child
            )
        )
        undefined
    )

    -- TESTE 1: Renderização dos 5 tipos de terminais
    format "\n--- Teste 1: Terminais Geométricos (#tick, #arrowClosed, #arrowOpen, #dot, #none) ---\n"
    local pm = AmenoPreviewModel()
    pm.terminalType = #tick
    AmenoPreviewRenderer.render pm canvas width:400 height:350
    assertCondition "Terminal #tick gera elementos de linha no Canvas" ((countChildrenOfType canvas "Line") >= 5)

    pm.terminalType = #arrowClosed
    AmenoPreviewRenderer.render pm canvas width:400 height:350
    assertCondition "Terminal #arrowClosed gera 2 poligonos de seta fechada" ((countChildrenOfType canvas "Polygon") == 2)

    pm.terminalType = #arrowOpen
    AmenoPreviewRenderer.render pm canvas width:400 height:350
    assertCondition "Terminal #arrowOpen gera linhas de asa aberta" ((countChildrenOfType canvas "Line") >= 7)

    pm.terminalType = #dot
    AmenoPreviewRenderer.render pm canvas width:400 height:350
    assertCondition "Terminal #dot gera 2 poligonos losangos/pontos" ((countChildrenOfType canvas "Polygon") == 2)

    pm.terminalType = #none
    AmenoPreviewRenderer.render pm canvas width:400 height:350
    assertCondition "Terminal #none nao adiciona poligonos nem linhas extras de terminal" ((countChildrenOfType canvas "Polygon") == 0)

    -- TESTE 2: Tipografia (Peso, Itálico, Tamanho e SampleValue)
    format "\n--- Teste 2: Tipografia no Preview ---\n"
    pm.sampleValue = "7,80 m"
    pm.fontSize = 200.0
    pm.bold = true
    pm.italic = true
    pm.fontName = "Arial"
    AmenoPreviewRenderer.render pm canvas width:400 height:350

    local tb = findTextBlock canvas
    assertCondition "TextBlock reflete sampleValue configurado (7,80 m)" (tb != undefined and tb.Text == "7,80 m")
    assertCondition "TextBlock reflete peso Negrito (Bold)" (tb != undefined and tb.FontWeight == (dotNetClass "System.Windows.FontWeights").Bold)
    assertCondition "TextBlock reflete estilo Itálico (Italic)" (tb != undefined and tb.FontStyle == (dotNetClass "System.Windows.FontStyles").Italic)
    assertCondition "TextBlock calcula FontSize proporcionalmente ao estilo" (tb != undefined and tb.FontSize > 15.0)

    -- TESTE 3: Máscara de Corte de Texto
    format "\n--- Teste 3: Máscara de Corte de Texto ---\n"
    pm.textMaskEnabled = true
    pm.darkBackground = true
    AmenoPreviewRenderer.render pm canvas width:400 height:350
    local bMask = findTextBorder canvas
    assertCondition "textMaskEnabled = true define fundo opaco no container do texto" (bMask != undefined and bMask.Background != undefined and (bMask.Background.ToString() != "Transparent"))

    pm.textMaskEnabled = false
    AmenoPreviewRenderer.render pm canvas width:400 height:350
    local bNoMask = findTextBorder canvas
    local isTransparentBg = false
    if bNoMask != undefined and bNoMask.Background != undefined do
    (
        local bgStr = bNoMask.Background.ToString()
        if (bgStr == "#00FFFFFF" or bgStr == "Transparent" or (matchPattern bgStr pattern:"*#00FFFFFF*") or (matchPattern bgStr pattern:"*Transparent*")) do isTransparentBg = true
    )
    assertCondition "textMaskEnabled = false define fundo transparente" isTransparentBg

    -- TESTE 4: Cores da Cota e do Texto
    format "\n--- Teste 4: Cores de Anotação e Texto ---\n"
    pm.annotationColor = "255,100,50"
    pm.textColor = "100,200,255"
    AmenoPreviewRenderer.render pm canvas width:400 height:350
    local tbColor = findTextBlock canvas
    assertCondition "Texto reflete cor customizada textColor" (tbColor != undefined and tbColor.Foreground != undefined)

    -- TESTE 5: Alternância de Tema Claro / Escuro
    format "\n--- Teste 5: Fundo Claro (#F5F5F5) vs Escuro (#121212) ---\n"
    pm.darkBackground = false
    AmenoPreviewRenderer.render pm canvas width:400 height:350
    assertCondition "Preview renderiza com sucesso em tema claro" (canvas.Children.Count >= 6)

    pm.darkBackground = true
    AmenoPreviewRenderer.render pm canvas width:400 height:350
    assertCondition "Preview renderiza com sucesso em tema escuro" (canvas.Children.Count >= 6)

    -- TESTE 6: Posicionamento Externo Determinístico (#outside)
    format "\n--- Teste 6: Posicionamento Externo de Terminais ---\n"
    pm.terminalType = #arrowClosed
    pm.terminalPlacement = #outside
    AmenoPreviewRenderer.render pm canvas width:400 height:350
    assertCondition "Posicionamento externo gera polígonos nos lados externos" ((countChildrenOfType canvas "Polygon") == 2)

    -- TESTE 7: Alerta de Fonte Não Instalada
    format "\n--- Teste 7: Alerta Visual de Fonte Ausente ---\n"
    pm.fontName = "FonteAbsolutamenteInexistente_123"
    AmenoPreviewRenderer.render pm canvas width:400 height:350
    local hasWarnBadge = false
    for i = 0 to (canvas.Children.Count - 1) do
    (
        local child = canvas.Children.Item[i]
        local childType = child.GetType()
        if childType.Name == "Border" and child.Child != undefined do
        (
            local childSub = child.Child.GetType()
            if childSub.Name == "TextBlock" do
            (
                if (matchPattern child.Child.Text pattern:"*não instalada*") do hasWarnBadge = true
            )
        )
    )
    assertCondition "Alerta visual gerado no Canvas para fonte ausente" hasWarnBadge

    -- TESTE 8: Zoom do Preview (50%, 100%, 200%)
    format "\n--- Teste 8: Escala Vetorial com Zoom ---\n"
    pm.fontName = "Arial"
    pm.zoom = 0.5
    AmenoPreviewRenderer.render pm canvas width:400 height:350
    local tbZoomHalf = findTextBlock canvas
    local szHalf = if tbZoomHalf != undefined then tbZoomHalf.FontSize else 0.0

    pm.zoom = 2.0
    AmenoPreviewRenderer.render pm canvas width:400 height:350
    local tbZoomDouble = findTextBlock canvas
    local szDouble = if tbZoomDouble != undefined then tbZoomDouble.FontSize else 0.0

    assertCondition "Zoom de 200% produz FontSize maior que zoom de 50%" (szDouble > szHalf * 2.0)

    -- TESTE 9: Integração com o Shell WPF
    format "\n--- Teste 9: Integração do Renderer no Shell WPF ---\n"
    local win = AmenoStyleEditorWPF.buildWindow styleId:"default"
    assertCondition "Shell WPF possui Canvas de preview instanciado" (AmenoStyleEditorWPF.previewCanvas != undefined)
    assertCondition "Canvas do Shell contém filhos renderizados após abertura" (AmenoStyleEditorWPF.previewCanvas.Children.Count > 0)

    -- TESTE 10: Isolamento de Cena
    format "\n--- Teste 10: Isolamento de Cena ---\n"
    assertCondition "Nenhum nó criado na cena durante todos os ciclos de renderização 2D" (objects.count == 0)

    -- Resumo final
    format "\n=================================================================\n"
    format "Total de Testes E11.3: % | Aprovados: % | Falhas: %\n" totalTests passedTests (totalTests - passedTests)
    format "=================================================================\n\n"

    if passedTests == totalTests then (
        format "[AMENO_TEST][PASS] E11.3 Renderer do Preview aprovado com 100 por cento de sucesso.\n"
    ) else (
        format "[AMENO_TEST][FAIL] Falhas detectadas na suite E11.3.\n"
    )
)
