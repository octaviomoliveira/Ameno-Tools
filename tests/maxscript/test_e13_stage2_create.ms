/*
    E13 etapa 2 — comportamento da aba Criar e do comando contínuo.
    O teste usa um App falso para exercitar o caminho do botão sem iniciar
    startTool; os contratos E12 de rejeição/congelamento continuam reais.
*/

struct E13Stage2FakeAppDefinition
(
    continuousCalls = 0,
    individualCalls = 0,
    dimensionStatus = "",

    fn startContinuousDimensionTool =
    (
        continuousCalls += 1
        #fakeContinuousResult
    ),

    fn startDimensionTool =
    (
        individualCalls += 1
        #fakeIndividualResult
    )
)

struct E13Stage2FakeWindowDefinition
(
    IsLoaded = true,
    IsVisible = true,
    hideCalls = 0,
    showCalls = 0,
    activateCalls = 0,

    fn Hide =
    (
        IsVisible = false
        hideCalls += 1
        true
    ),

    fn Show =
    (
        IsVisible = true
        showCalls += 1
        true
    ),

    fn Activate =
    (
        activateCalls += 1
        true
    )
)

struct E13Stage2FakeContinuousDefinition
(
    active = false,
    activeMode = #horizontal,
    activeStyleId = "default",
    previewOutputUnit = #meters,
    previewPrecision = 2,

    fn start =
    (
        #fakeRuntimeContinuousResult
    )
)

(
    local testFile      = getSourceFileName()
    local testPath      = getFilenamePath testFile
    local worktreeRoot  = pathConfig.normalizePath (pathConfig.appendPath testPath @"..\..")
    local bootstrapPath = pathConfig.normalizePath (pathConfig.appendPath worktreeRoot @"Contents\scripts\startup\ameno_bootstrap.ms")
    local macroPath     = pathConfig.normalizePath (pathConfig.appendPath worktreeRoot @"Contents\macroscripts\AmenoTools.mcr")

    resetMaxFile #noPrompt
    if doesFileExist bootstrapPath then
        fileIn bootstrapPath quiet:true
    else
        throw ("bootstrap nao encontrado: " + bootstrapPath)

    local passed = 0
    local failed = 0
    local errors = #()

    fn check label conditionValue =
    (
        if conditionValue == true then
        (
            passed += 1
            format "[AMENO_TEST][PASS] %\n" label
        )
        else
        (
            failed += 1
            append errors label
            format "[AMENO_TEST][FAIL] %\n" label
        )
    )

    local tabControl = try (::AmenoCotasCriarTab.build()) catch (undefined)
    check "Tab Criar foi construida para a etapa 2" (tabControl != undefined)

    -- Botao, runtime e macro devem compartilhar o mesmo comando.
    local realApp = ::AmenoApp
    local fakeApp = E13Stage2FakeAppDefinition()
    ::AmenoApp = fakeApp

    local directResult = try (::AmenoCotasCriarTab.executeContinuousCommand()) catch (undefined)
    check "comando continuo da aba usa o runtime compartilhado" (directResult == #fakeContinuousResult and fakeApp.continuousCalls == 1)

    local buttonClickOk = false
    local continuousButton = ::AmenoCotasCriarTab.findControl "btnCotaContinua"
    try
    (
        local buttonType = dotNetClass "System.Windows.Controls.Button"
        local clickArgs = dotNetObject "System.Windows.RoutedEventArgs" buttonType.ClickEvent
        continuousButton.RaiseEvent clickArgs
        buttonClickOk = true
    )
    catch
    (
        format "[AMENO_TEST][DETAIL] clique WPF continuo: %\n" (getCurrentException() as string)
    )
    check "clique WPF da cota continua usa o mesmo caminho" (buttonClickOk and fakeApp.continuousCalls == 2)

    local macroRunOk = false
    if doesFileExist macroPath do
    (
        try
        (
            fileIn macroPath quiet:true
            macros.run "Ameno Tools" "CriarCotaContinua"
            macroRunOk = true
        )
        catch
        (
            format "[AMENO_TEST][DETAIL] macro continuo: %\n" (getCurrentException() as string)
        )
    )
    check "macro CriarCotaContinua usa o runtime compartilhado" (macroRunOk and fakeApp.continuousCalls == 3)
    ::AmenoApp = realApp

    -- Sincronizacao parte dos campos existentes do servico individual e
    -- replica a configuracao para o servico continuo quando em repouso.
    ::AmenoDimensionTool.activeMode = #vertical
    ::AmenoDimensionTool.activeStyleId = "technical"
    ::AmenoDimensionTool.previewOutputUnit = #centimeters
    ::AmenoDimensionTool.previewPrecision = 3
    ::AmenoDimensionContinuousTool.activeMode = #aligned
    ::AmenoDimensionContinuousTool.activeStyleId = "default"
    ::AmenoDimensionContinuousTool.previewOutputUnit = #meters
    ::AmenoDimensionContinuousTool.previewPrecision = 0
    ::AmenoCotasCriarTab.syncFromServices()

    local settings = ::AmenoCotasCriarTab.getSettings()
    local styleIndex = ::AmenoCotasCriarTab.getStyleIndex "technical"
    local modeButton = ::AmenoCotasCriarTab.findControl "btnModoVertical"
    local unitControl = ::AmenoCotasCriarTab.findControl "cbUnidade"
    local precisionControl = ::AmenoCotasCriarTab.findControl "cbPrecisao"
    local styleControl = ::AmenoCotasCriarTab.findControl "cbEstiloAtivo"
    check "syncFromServices preserva modo ativo" (settings[1] == #vertical and ::AmenoDimensionContinuousTool.activeMode == #vertical)
    check "syncFromServices preserva estilo ativo" (settings[2] == "technical" and ::AmenoDimensionContinuousTool.activeStyleId == "technical")
    check "syncFromServices seleciona unidade e precisao" (unitControl.SelectedIndex == 1 and precisionControl.SelectedIndex == 3)
    check "syncFromServices seleciona estilo e modo visual" (styleControl.SelectedIndex == styleIndex - 1 and modeButton != undefined)

    -- Os handlers escrevem nos dois servicos, usando somente propriedades ja
    -- existentes em E12/E4.
    ::AmenoCotasCriarTab.setActiveMode #horizontal
    ::AmenoCotasCriarTab.setActiveStyle "editorial"
    ::AmenoCotasCriarTab.setOutputUnit #millimeters
    ::AmenoCotasCriarTab.setPrecision 1
    check "alteracao de modo sincroniza os dois servicos" (::AmenoDimensionTool.activeMode == #horizontal and ::AmenoDimensionContinuousTool.activeMode == #horizontal)
    check "alteracao de estilo sincroniza os dois servicos" (::AmenoDimensionTool.activeStyleId == "editorial" and ::AmenoDimensionContinuousTool.activeStyleId == "editorial")
    check "alteracao de unidade e precisao sincroniza os dois servicos" (::AmenoDimensionTool.previewOutputUnit == #millimeters and ::AmenoDimensionContinuousTool.previewOutputUnit == #millimeters and ::AmenoDimensionTool.previewPrecision == 1 and ::AmenoDimensionContinuousTool.previewPrecision == 1)

    -- Uma sessao ativa rejeita mudancas e mantém o snapshot de configuracao.
    local frozenMode = ::AmenoDimensionContinuousTool.activeMode
    local frozenStyle = ::AmenoDimensionContinuousTool.activeStyleId
    local frozenUnit = ::AmenoDimensionContinuousTool.previewOutputUnit
    local frozenPrecision = ::AmenoDimensionContinuousTool.previewPrecision
    ::AmenoDimensionContinuousTool.active = true
    ::AmenoDimensionContinuousTool.stage = #collecting
    ::AmenoDimensionContinuousTool.sessionMode = #horizontal
    ::AmenoDimensionContinuousTool.sessionStyleId = frozenStyle
    ::AmenoDimensionContinuousTool.sessionOutputUnit = frozenUnit
    ::AmenoDimensionContinuousTool.sessionPrecision = frozenPrecision
    local rejectedMode = (::AmenoCotasCriarTab.setActiveMode #vertical) == false
    local rejectedStyle = (::AmenoCotasCriarTab.setActiveStyle "technical") == false
    local rejectedUnit = (::AmenoCotasCriarTab.setOutputUnit #meters) == false
    local rejectedPrecision = (::AmenoCotasCriarTab.setPrecision 3) == false
    check "sessao continua bloqueia alteracao de modo/estilo/unidade/precisao" (rejectedMode and rejectedStyle and rejectedUnit and rejectedPrecision)
    check "sessao continua mantém configuracao congelada" (::AmenoDimensionContinuousTool.activeMode == frozenMode and ::AmenoDimensionContinuousTool.activeStyleId == frozenStyle and ::AmenoDimensionContinuousTool.previewOutputUnit == frozenUnit and ::AmenoDimensionContinuousTool.previewPrecision == frozenPrecision and ::AmenoDimensionContinuousTool.sessionMode == #horizontal)
    ::AmenoDimensionContinuousTool.active = false
    ::AmenoDimensionContinuousTool.stage = #idle
    ::AmenoDimensionContinuousTool.clearSessionConfiguration()

    -- Alinhada continua continua explicitamente rejeitada; alinhada individual
    -- permanece selecionavel.
    ::AmenoCotasCriarTab.setActiveMode #aligned
    local rejectedContinuousAligned = try (::AmenoDimensionContinuousTool.begin() == false) catch (false)
    check "cadeia alinhada continua rejeitada explicitamente" rejectedContinuousAligned
    check "modo alinhado individual permanece disponivel" (::AmenoDimensionTool.activeMode == #aligned)

    -- O helper de foco pode ser testado sem abrir uma janela real no batch.
    local previousWindow = ::AmenoCotasWindow.window
    local fakeWindow = E13Stage2FakeWindowDefinition()
    ::AmenoCotasWindow.window = fakeWindow
    local suspended = ::AmenoCotasWindow.suspendForInteractiveTool()
    local hiddenAfterSuspend = (fakeWindow.hideCalls == 1 and fakeWindow.IsVisible == false)
    local resumed = ::AmenoCotasWindow.resumeAfterInteractiveTool()
    local visibleAfterResume = (fakeWindow.showCalls == 1 and fakeWindow.activateCalls == 1 and fakeWindow.IsVisible == true)
    check "janela é suspensa antes do startTool" (suspended and hiddenAfterSuspend)
    check "janela é restaurada depois do startTool" (resumed and visibleAfterResume)
    ::AmenoCotasWindow.window = previousWindow

    -- O runtime também precisa executar o ciclo hide -> startTool -> show,
    -- inclusive para o caminho chamado pela macro.
    local realContinuousTool = ::AmenoDimensionContinuousTool
    local runtimeFakeContinuous = E13Stage2FakeContinuousDefinition()
    local runtimeFakeWindow = E13Stage2FakeWindowDefinition()
    ::AmenoDimensionContinuousTool = runtimeFakeContinuous
    ::AmenoCotasWindow.window = runtimeFakeWindow
    local runtimeResult = try (realApp.startContinuousDimensionTool()) catch (undefined)
    check "runtime preserva retorno do startTool continuo e foco da janela" (runtimeResult == #fakeRuntimeContinuousResult and runtimeFakeWindow.hideCalls == 1 and runtimeFakeWindow.showCalls == 1 and runtimeFakeWindow.activateCalls == 1)
    ::AmenoDimensionContinuousTool = realContinuousTool
    ::AmenoCotasWindow.window = previousWindow

    -- A contagem acompanha a cena sem depender de refresh global do painel.
    local beforeCount = (::AmenoDimensionGraphics.findControllers()).count
    local createdTestDimension = try (::AmenoDimensionGraphics.createTestDimension()) catch (undefined)
    local afterCreateCount = (::AmenoDimensionGraphics.findControllers()).count
    ::AmenoCotasCriarTab.updateCotaCount()
    local countControl = ::AmenoCotasCriarTab.findControl "txtCotaCount"
    local expectedCreateText = (afterCreateCount as string) + (if afterCreateCount == 1 then " cota" else " cotas")
    check "criar cota incrementa a contagem da aba" (createdTestDimension != undefined and afterCreateCount == beforeCount + 1 and countControl.Text == expectedCreateText)
    local removedTestDimensions = try (::AmenoDimensionGraphics.clearTestDimensions()) catch (0)
    local afterRemoveCount = (::AmenoDimensionGraphics.findControllers()).count
    ::AmenoCotasCriarTab.updateCotaCount()
    check "remover cota atualiza a contagem da aba" (removedTestDimensions >= 1 and afterRemoveCount == beforeCount)

    try (::AmenoCotasWindow.unregisterSceneCountCallbacks()) catch ()
    try (::AmenoCotasWindow.close()) catch ()

    format "\n[AMENO_TEST] Resultado etapa 2: % passou(aram), % falhou(aram)\n" passed failed
    if failed == 0 then
        format "[AMENO_TEST][PASS] E13 etapa 2 passou.\n"
    else
    (
        format "[AMENO_TEST][FAIL] Falhas etapa 2: %\n" (errors as string)
        throw ("E13 etapa 2 falhou: " + (failed as string))
    )
)
