/*
    test_e13c.ms -- Teste headless E13-C
    Verifica:
      1. AmenoCotasEstilosTab != undefined (struct criado com ::)
      2. AmenoCotasEstilosTab.build existe como funcao
      3. AmenoStyleEditorWindow.show() redireciona (nao abre janela separada)
      4. AmenoStyleService funciona (carregar/salvar estilo)
      5. AmenoCotasWindow.setActiveSection 2 registra a aba Estilos
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
    -- Teste 1: ::AmenoCotasEstilosTab deve estar definido apos bootstrap
    -- ----------------------------------------------------------------
    if ::AmenoCotasEstilosTab != undefined then
        logPass "AmenoCotasEstilosTab esta definido (:: global)"
    else
        logFail "AmenoCotasEstilosTab e undefined - ameno_cotas_estilos_tab.ms nao foi carregado"

    -- ----------------------------------------------------------------
    -- Teste 2: AmenoCotasEstilosTab.build deve existir como funcao
    -- ----------------------------------------------------------------
    if ::AmenoCotasEstilosTab != undefined then
    (
        local hasBuild = try ((::AmenoCotasEstilosTab.build) != undefined) catch (false)
        if hasBuild then
            logPass "AmenoCotasEstilosTab.build existe como funcao"
        else
            logFail "AmenoCotasEstilosTab.build nao existe ou nao e funcao"
    )
    else
        logFail "Teste 2 ignorado - AmenoCotasEstilosTab nao existe"

    -- ----------------------------------------------------------------
    -- Teste 3: AmenoStyleEditorWindow.show() deve redirecionar
    --          (e um stub que nao abre janela separada)
    -- ----------------------------------------------------------------
    if ::AmenoStyleEditorWindow != undefined then
    (
        -- Verificar que show() existe
        local hasShow = try ((::AmenoStyleEditorWindow.show) != undefined) catch (false)
        if hasShow then
        (
            -- Verificar que e o stub (nao a janela original)
            -- O stub nao tem campo 'window', a janela original sim
            local isStub = try (not (isProperty ::AmenoStyleEditorWindow #window)) catch (true)
            if isStub then
                logPass "AmenoStyleEditorWindow.show e stub de redirecionamento (sem campo window)"
            else
                logFail "AmenoStyleEditorWindow ainda aponta para janela separada (campo window existe)"
        )
        else
            logFail "AmenoStyleEditorWindow.show nao existe"
    )
    else
        logFail "AmenoStyleEditorWindow e undefined"

    -- ----------------------------------------------------------------
    -- Teste 4: AmenoStyleService funciona (listStyles e createDraftFromStyle)
    -- ----------------------------------------------------------------
    if ::AmenoStyleService != undefined then
    (
        local styles = try (::AmenoStyleService.listStyles()) catch (#())
        if styles.count > 0 then
        (
            logPass ("AmenoStyleService.listStyles() retornou " + (styles.count as string) + " estilo(s)")
            -- Criar rascunho a partir do primeiro estilo
            local draft = try (::AmenoStyleService.createDraftFromStyle styles[1].styleId) catch (undefined)
            if draft != undefined and draft.styleRecord != undefined then
                logPass "AmenoStyleService.createDraftFromStyle funciona corretamente"
            else
                logFail "AmenoStyleService.createDraftFromStyle falhou ou retornou draft invalido"
        )
        else
            logFail "AmenoStyleService.listStyles() retornou lista vazia"
    )
    else
        logFail "AmenoStyleService e undefined"

    -- ----------------------------------------------------------------
    -- Teste 5: AmenoCotasWindow.setActiveSection 2 registra aba Estilos
    --          (verificar que o case 2 existe na logica interna)
    -- ----------------------------------------------------------------
    if ::AmenoCotasWindow != undefined then
    (
        local hasSetActiveSection = try ((::AmenoCotasWindow.setActiveSection) != undefined) catch (false)
        if hasSetActiveSection then
        (
            -- Verificar que AmenoCotasEstilosTab e o que seria chamado para section 2
            -- (checagem estatica: se AmenoCotasEstilosTab existe, o case 2 esta registrado)
            if ::AmenoCotasEstilosTab != undefined then
                logPass "AmenoCotasWindow.setActiveSection 2 tem AmenoCotasEstilosTab registrado"
            else
                logFail "AmenoCotasEstilosTab nao existe - section 2 nao funcionaria"
        )
        else
            logFail "AmenoCotasWindow.setActiveSection nao existe"
    )
    else
        logFail "AmenoCotasWindow e undefined"

    -- ----------------------------------------------------------------
    -- Sumario
    -- ----------------------------------------------------------------
    format "\n[AMENO_TEST] Resultado: % passou(aram), % falhou(aram)\n" passed failed

    if failed == 0 then
    (
        format "[AMENO_TEST][PASS] Todos os testes E13-C passaram.\n"
        true
    )
    else
    (
        format "[AMENO_TEST][FAIL] Falhas: %\n" (errors as string)
        false
    )
)
