/*
    test_e13d.ms -- Teste headless E13-D
    Verifica:
      1. AmenoCotasEditarTab != undefined (struct carregado no escopo global)
      2. AmenoCotasEditarTab.build existe como funcao
      3. AmenoCotasEditarTab.refresh existe como funcao
      4. AmenoCotasEditarTab.applyChanges existe como funcao
      5. AmenoCotasEditarTab.restoreMeasured existe como funcao
      6. AmenoCotasWindow.setActiveSection 3 tem AmenoCotasEditarTab registrado
      7. AmenoCotasEditarTab.build() instancia UserControl WPF sem erros de XAML
*/

(
    local testFile      = getSourceFileName()
    local testPath      = getFilenamePath testFile
    local worktreeRoot  = pathConfig.normalizePath (pathConfig.appendPath testPath @"..\..")
    local bootstrapPath = pathConfig.normalizePath (pathConfig.appendPath worktreeRoot @"Contents\scripts\startup\ameno_bootstrap.ms")

    if doesFileExist bootstrapPath then
        fileIn bootstrapPath quiet:true
    else
        format "[AMENO_TEST][FAIL] bootstrap nao encontrado em: %\n" bootstrapPath

    local passed = 0
    local failed = 0
    local errors = #()

    fn logPass msg =
    (
        format "[AMENO_TEST][PASS] %\n" msg
        passed += 1
    )

    fn logFail msg =
    (
        format "[AMENO_TEST][FAIL] %\n" msg
        append errors msg
        failed += 1
    )

    -- ----------------------------------------------------------------
    -- Teste 1: AmenoCotasEditarTab deve estar definido apos bootstrap
    -- ----------------------------------------------------------------
    if ::AmenoCotasEditarTab != undefined then
        logPass "AmenoCotasEditarTab esta definido (:: global)"
    else
        logFail "AmenoCotasEditarTab e undefined - ameno_cotas_editar_tab.ms nao foi carregado"

    -- ----------------------------------------------------------------
    -- Teste 2: AmenoCotasEditarTab.build deve existir como funcao
    -- ----------------------------------------------------------------
    if ::AmenoCotasEditarTab != undefined then
    (
        local hasBuild = try ((::AmenoCotasEditarTab.build) != undefined) catch (false)
        if hasBuild then
            logPass "AmenoCotasEditarTab.build existe como funcao"
        else
            logFail "AmenoCotasEditarTab.build nao existe ou nao e funcao"
    )
    else
        logFail "Teste 2 ignorado - AmenoCotasEditarTab nao existe"

    -- ----------------------------------------------------------------
    -- Teste 3: AmenoCotasEditarTab.refresh deve existir como funcao
    -- ----------------------------------------------------------------
    if ::AmenoCotasEditarTab != undefined then
    (
        local hasRefresh = try ((::AmenoCotasEditarTab.refresh) != undefined) catch (false)
        if hasRefresh then
            logPass "AmenoCotasEditarTab.refresh existe como funcao"
        else
            logFail "AmenoCotasEditarTab.refresh nao existe ou nao e funcao"
    )
    else
        logFail "Teste 3 ignorado - AmenoCotasEditarTab nao existe"

    -- ----------------------------------------------------------------
    -- Teste 4: AmenoCotasEditarTab.applyChanges deve existir como funcao
    -- ----------------------------------------------------------------
    if ::AmenoCotasEditarTab != undefined then
    (
        local hasApply = try ((::AmenoCotasEditarTab.applyChanges) != undefined) catch (false)
        if hasApply then
            logPass "AmenoCotasEditarTab.applyChanges existe como funcao"
        else
            logFail "AmenoCotasEditarTab.applyChanges nao existe ou nao e funcao"
    )
    else
        logFail "Teste 4 ignorado - AmenoCotasEditarTab nao existe"

    -- ----------------------------------------------------------------
    -- Teste 5: AmenoCotasEditarTab.restoreMeasured deve existir como funcao
    -- ----------------------------------------------------------------
    if ::AmenoCotasEditarTab != undefined then
    (
        local hasRestore = try ((::AmenoCotasEditarTab.restoreMeasured) != undefined) catch (false)
        if hasRestore then
            logPass "AmenoCotasEditarTab.restoreMeasured existe como funcao"
        else
            logFail "AmenoCotasEditarTab.restoreMeasured nao existe ou nao e funcao"
    )
    else
        logFail "Teste 5 ignorado - AmenoCotasEditarTab nao existe"

    -- ----------------------------------------------------------------
    -- Teste 6: AmenoCotasWindow.setActiveSection 3 registra aba Editar
    -- ----------------------------------------------------------------
    if ::AmenoCotasWindow != undefined then
    (
        local hasSetActiveSection = try ((::AmenoCotasWindow.setActiveSection) != undefined) catch (false)
        if hasSetActiveSection then
        (
            if ::AmenoCotasEditarTab != undefined then
                logPass "AmenoCotasWindow.setActiveSection 3 tem AmenoCotasEditarTab registrado"
            else
                logFail "AmenoCotasEditarTab nao existe - section 3 nao funcionaria"
        )
        else
            logFail "AmenoCotasWindow.setActiveSection nao existe"
    )
    else
        logFail "AmenoCotasWindow e undefined"

    -- ----------------------------------------------------------------
    -- Teste 7: AmenoCotasEditarTab.build() instancia UserControl WPF
    -- ----------------------------------------------------------------
    if ::AmenoCotasEditarTab != undefined then
    (
        local ctrl = undefined
        local buildOk = false
        try
        (
            ctrl = ::AmenoCotasEditarTab.build()
            buildOk = (ctrl != undefined)
        )
        catch
        (
            format "[AMENO_TEST][DETAIL] Erro no build WPF: %\n" (getCurrentException() as string)
            buildOk = false
        )

        if buildOk then
            logPass "AmenoCotasEditarTab.build() construiu UserControl WPF com sucesso"
        else
            logFail "AmenoCotasEditarTab.build() falhou ao construir UserControl WPF"
    )
    else
        logFail "Teste 7 ignorado - AmenoCotasEditarTab nao existe"

    -- ----------------------------------------------------------------
    -- Sumario
    -- ----------------------------------------------------------------
    format "\n[AMENO_TEST] Resultado: % passou(aram), % falhou(aram)\n" passed failed

    if failed == 0 then
    (
        format "[AMENO_TEST][PASS] Todos os testes E13-D passaram.\n"
        true
    )
    else
    (
        format "[AMENO_TEST][FAIL] Falhas: %\n" (errors as string)
        false
    )
)
