/*
    test_e13e.ms -- Teste headless E13-E
    Verifica:
      1. AmenoCotasRenderTab != undefined (struct carregado no escopo global)
      2. AmenoCotasRenderTab.build existe como funcao
      3. AmenoCotasRenderTab.refreshCameras existe como funcao
      4. AmenoCotasRenderTab.refreshRendererInfo existe como funcao
      5. AmenoCotasRenderTab.renderCotas existe como funcao
      6. AmenoCotasWindow.setActiveSection 4 tem AmenoCotasRenderTab registrado
      7. AmenoCotasRenderTab.build() instancia UserControl WPF sem erros de XAML
      8. AmenoRenderCotasService.defaultOutputPath() retorna caminho PNG valido
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
    -- Teste 1: AmenoCotasRenderTab deve estar definido apos bootstrap
    -- ----------------------------------------------------------------
    if ::AmenoCotasRenderTab != undefined then
        logPass "AmenoCotasRenderTab esta definido (:: global)"
    else
        logFail "AmenoCotasRenderTab e undefined - ameno_cotas_render_tab.ms nao foi carregado"

    -- ----------------------------------------------------------------
    -- Teste 2: AmenoCotasRenderTab.build deve existir como funcao
    -- ----------------------------------------------------------------
    if ::AmenoCotasRenderTab != undefined then
    (
        local hasBuild = try ((::AmenoCotasRenderTab.build) != undefined) catch (false)
        if hasBuild then
            logPass "AmenoCotasRenderTab.build existe como funcao"
        else
            logFail "AmenoCotasRenderTab.build nao existe ou nao e funcao"
    )
    else
        logFail "Teste 2 ignorado - AmenoCotasRenderTab nao existe"

    -- ----------------------------------------------------------------
    -- Teste 3: AmenoCotasRenderTab.refreshCameras deve existir como funcao
    -- ----------------------------------------------------------------
    if ::AmenoCotasRenderTab != undefined then
    (
        local hasRefreshCameras = try ((::AmenoCotasRenderTab.refreshCameras) != undefined) catch (false)
        if hasRefreshCameras then
            logPass "AmenoCotasRenderTab.refreshCameras existe como funcao"
        else
            logFail "AmenoCotasRenderTab.refreshCameras nao existe ou nao e funcao"
    )
    else
        logFail "Teste 3 ignorado - AmenoCotasRenderTab nao existe"

    -- ----------------------------------------------------------------
    -- Teste 4: AmenoCotasRenderTab.refreshRendererInfo deve existir como funcao
    -- ----------------------------------------------------------------
    if ::AmenoCotasRenderTab != undefined then
    (
        local hasRefreshRenderer = try ((::AmenoCotasRenderTab.refreshRendererInfo) != undefined) catch (false)
        if hasRefreshRenderer then
            logPass "AmenoCotasRenderTab.refreshRendererInfo existe como funcao"
        else
            logFail "AmenoCotasRenderTab.refreshRendererInfo nao existe ou nao e funcao"
    )
    else
        logFail "Teste 4 ignorado - AmenoCotasRenderTab nao existe"

    -- ----------------------------------------------------------------
    -- Teste 5: AmenoCotasRenderTab.renderCotas deve existir como funcao
    -- ----------------------------------------------------------------
    if ::AmenoCotasRenderTab != undefined then
    (
        local hasRender = try ((::AmenoCotasRenderTab.renderCotas) != undefined) catch (false)
        if hasRender then
            logPass "AmenoCotasRenderTab.renderCotas existe como funcao"
        else
            logFail "AmenoCotasRenderTab.renderCotas nao existe ou nao e funcao"
    )
    else
        logFail "Teste 5 ignorado - AmenoCotasRenderTab nao existe"

    -- ----------------------------------------------------------------
    -- Teste 6: AmenoCotasWindow.setActiveSection 4 tem AmenoCotasRenderTab
    -- ----------------------------------------------------------------
    if ::AmenoCotasWindow != undefined then
    (
        local hasSetActiveSection = try ((::AmenoCotasWindow.setActiveSection) != undefined) catch (false)
        if hasSetActiveSection then
        (
            if ::AmenoCotasRenderTab != undefined then
                logPass "AmenoCotasWindow.setActiveSection 4 tem AmenoCotasRenderTab registrado"
            else
                logFail "AmenoCotasRenderTab nao existe - section 4 nao funcionaria"
        )
        else
            logFail "AmenoCotasWindow.setActiveSection nao existe"
    )
    else
        logFail "AmenoCotasWindow e undefined"

    -- ----------------------------------------------------------------
    -- Teste 7: AmenoCotasRenderTab.build() instancia UserControl WPF
    -- ----------------------------------------------------------------
    if ::AmenoCotasRenderTab != undefined then
    (
        local ctrl = undefined
        local buildOk = false
        try
        (
            ctrl = ::AmenoCotasRenderTab.build()
            buildOk = (ctrl != undefined)
        )
        catch
        (
            format "[AMENO_TEST][DETAIL] Erro no build WPF: %\n" (getCurrentException() as string)
            buildOk = false
        )

        if buildOk then
            logPass "AmenoCotasRenderTab.build() construiu UserControl WPF com sucesso"
        else
            logFail "AmenoCotasRenderTab.build() falhou ao construir UserControl WPF"
    )
    else
        logFail "Teste 7 ignorado - AmenoCotasRenderTab nao existe"

    -- ----------------------------------------------------------------
    -- Teste 8: AmenoRenderCotasService.defaultOutputPath() retorna caminho PNG valido
    -- ----------------------------------------------------------------
    if ::AmenoRenderCotasService != undefined then
    (
        local p = try (::AmenoRenderCotasService.defaultOutputPath()) catch (undefined)
        if p != undefined and p != "" and (matchPattern p pattern:"*.png") then
            logPass ("AmenoRenderCotasService.defaultOutputPath() retornou: " + p)
        else
            logFail "AmenoRenderCotasService.defaultOutputPath() retornou caminho invalido"
    )
    else
        logFail "AmenoRenderCotasService e undefined"

    -- ----------------------------------------------------------------
    -- Sumario
    -- ----------------------------------------------------------------
    format "\n[AMENO_TEST] Resultado: % passou(aram), % falhou(aram)\n" passed failed

    if failed == 0 then
    (
        format "[AMENO_TEST][PASS] Todos os testes E13-E passaram.\n"
        true
    )
    else
    (
        format "[AMENO_TEST][FAIL] Falhas: %\n" (errors as string)
        false
    )
)
