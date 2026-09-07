/*
    E13 - estabilidade do ciclo WPF.
    Exercita a janela real em Batch sem iniciar MouseTool nem alterar a cena do
    usuario: singleton oculto, cache das abas, navegacao repetida, rollback de
    falha e suspensao sem Hide/Show.
*/

struct E13UiFailureTabDefinition
(
    fn build =
    (
        throw "falha de aba injetada pelo teste"
    )
)

(
    local testFile      = getSourceFileName()
    local testPath      = getFilenamePath testFile
    local worktreeRoot  = pathConfig.normalizePath (pathConfig.appendPath testPath @"..\..")
    local bootstrapPath = pathConfig.normalizePath (pathConfig.appendPath worktreeRoot @"Contents\scripts\startup\ameno_bootstrap.ms")

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

    local shown = try (::AmenoCotasWindow.show()) catch
    (
        format "[AMENO_TEST][DETAIL] abertura WPF: %\n" (getCurrentException() as string)
        undefined
    )
    check "janela WPF real abriu" (shown != undefined and ::AmenoCotasWindow.isOpen())

    local createHostA = try (::AmenoCotasCriarTab.build()) catch (undefined)
    local createHostB = try (::AmenoCotasCriarTab.build()) catch (undefined)
    local renderHostA = try (::AmenoCotasRenderTab.build()) catch (undefined)
    local renderHostB = try (::AmenoCotasRenderTab.build()) catch (undefined)
    check "Criar reutiliza uma unica instancia" (createHostA != undefined and createHostA == createHostB)
    check "Render reutiliza uma unica instancia" (renderHostA != undefined and renderHostA == renderHostB)

    local cycleOk = true
    for cycleIndex = 1 to 12 while cycleOk do
    (
        cycleOk = (::AmenoCotasWindow.setActiveSection 1) and
                  (::AmenoCotasWindow.setActiveSection 2) and
                  (::AmenoCotasWindow.setActiveSection 3) and
                  (::AmenoCotasWindow.setActiveSection 4)
    )
    check "doze ciclos Criar Estilos Editar Render completaram" cycleOk
    check "ciclos preservam os hosts de Criar e Render" \
        (::AmenoCotasCriarTab.build() == createHostA and ::AmenoCotasRenderTab.build() == renderHostA)

    ::AmenoCotasWindow.setActiveSection 2
    local contentBorder = ::AmenoCotasWindow.findControl "ContentArea"
    local previousChild = try (contentBorder.Child) catch (undefined)
    local previousSection = ::AmenoCotasWindow.activeSection
    local realRenderTab = ::AmenoCotasRenderTab
    ::AmenoCotasRenderTab = E13UiFailureTabDefinition()
    local failedSwitchResult = try (::AmenoCotasWindow.setActiveSection 4) catch (true)
    ::AmenoCotasRenderTab = realRenderTab
    check "falha de construcao rejeita a troca de aba" (failedSwitchResult == false)
    check "falha preserva aba ativa e conteudo anterior" \
        (::AmenoCotasWindow.activeSection == previousSection and contentBorder.Child == previousChild)

    local loggedNavigationError = false
    if ::AmenoLog != undefined do
    (
        for entry in ::AmenoLog.entries while not loggedNavigationError do
            loggedNavigationError = ((findString entry "falha ao construir aba 4") != undefined)
    )
    check "falha de navegacao fica registrada no logger" loggedNavigationError

    local suspended = try (::AmenoCotasWindow.suspendForInteractiveTool()) catch (false)
    local stayedVisible = try (::AmenoCotasWindow.window.IsVisible and not ::AmenoCotasWindow.window.IsEnabled) catch (false)
    local resumed = try (::AmenoCotasWindow.resumeAfterInteractiveTool()) catch (false)
    local reenabled = try (::AmenoCotasWindow.window.IsVisible and ::AmenoCotasWindow.window.IsEnabled) catch (false)
    check "suspensao bloqueia controles sem esconder a janela" (suspended and stayedVisible)
    check "retorno reabilita a mesma janela" (resumed and reenabled)

    local originalWindow = ::AmenoCotasWindow.window
    try (originalWindow.Hide()) catch ()
    local hiddenStillOpen = ::AmenoCotasWindow.isOpen()
    local restoredWindow = try (::AmenoCotasWindow.show()) catch (undefined)
    check "janela carregada e oculta continua sendo o singleton" \
        (hiddenStillOpen and restoredWindow == originalWindow and originalWindow.IsVisible)

    try (::AmenoCotasWindow.close()) catch ()

    format "\n[AMENO_TEST] Resultado lifecycle WPF: % passou(aram), % falhou(aram)\n" passed failed
    if failed == 0 then
        format "[AMENO_TEST][PASS] E13 lifecycle WPF passou.\n"
    else
    (
        format "[AMENO_TEST][FAIL] Falhas lifecycle WPF: %\n" (errors as string)
        throw ("E13 lifecycle WPF falhou: " + (failed as string))
    )
)
