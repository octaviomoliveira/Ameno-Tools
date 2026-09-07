/*
    test_e13b.ms -- Teste headless E13-B
    Verifica:
      1. AmenoCotasWindow != undefined apos bootstrap
      2. AmenoCotasCriarTab != undefined (struct criado)
      3. AmenoApp.deletarSelecao existe e e chamavel
      4. AmenoApp.limparOrfas existe e e chamavel
      5. AmenoApp.deletarTudo existe e e chamavel
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
    -- Teste 1: AmenoCotasWindow deve estar definido apos o bootstrap
    -- ----------------------------------------------------------------
    if ::AmenoCotasWindow != undefined then
        logPass "AmenoCotasWindow esta definido"
    else
        logFail "AmenoCotasWindow e undefined - bootstrap falhou"

    -- ----------------------------------------------------------------
    -- Teste 2: AmenoCotasCriarTab deve estar definido
    -- ----------------------------------------------------------------
    if ::AmenoCotasCriarTab != undefined then
        logPass "AmenoCotasCriarTab esta definido (struct criado)"
    else
        logFail "AmenoCotasCriarTab e undefined - ameno_cotas_criar_tab.ms nao foi carregado"

    -- ----------------------------------------------------------------
    -- Teste 3: AmenoApp.deletarSelecao deve existir
    -- ----------------------------------------------------------------
    if ::AmenoApp != undefined then
    (
        local hasFn = try ((::AmenoApp.deletarSelecao) != undefined) catch (false)
        if hasFn then
            logPass "AmenoApp.deletarSelecao existe e pode ser chamado"
        else
            logFail "AmenoApp.deletarSelecao nao existe no runtime"
    )
    else
        logFail "Teste 3 ignorado - AmenoApp nao existe"

    -- ----------------------------------------------------------------
    -- Teste 4: AmenoApp.limparOrfas deve existir
    -- ----------------------------------------------------------------
    if ::AmenoApp != undefined then
    (
        local hasFn = try ((::AmenoApp.limparOrfas) != undefined) catch (false)
        if hasFn then
            logPass "AmenoApp.limparOrfas existe e pode ser chamado"
        else
            logFail "AmenoApp.limparOrfas nao existe no runtime"
    )
    else
        logFail "Teste 4 ignorado - AmenoApp nao existe"

    -- ----------------------------------------------------------------
    -- Teste 5: AmenoApp.deletarTudo deve existir
    -- ----------------------------------------------------------------
    if ::AmenoApp != undefined then
    (
        local hasFn = try ((::AmenoApp.deletarTudo) != undefined) catch (false)
        if hasFn then
            logPass "AmenoApp.deletarTudo existe e pode ser chamado"
        else
            logFail "AmenoApp.deletarTudo nao existe no runtime"
    )
    else
        logFail "Teste 5 ignorado - AmenoApp nao existe"

    -- ----------------------------------------------------------------
    -- Sumario
    -- ----------------------------------------------------------------
    format "\n[AMENO_TEST] Resultado: % passou(aram), % falhou(aram)\n" passed failed

    if failed == 0 then
    (
        format "[AMENO_TEST][PASS] Todos os testes passaram.\n"
        true
    )
    else
    (
        format "[AMENO_TEST][FAIL] Falhas: %\n" (errors as string)
        false
    )
)
