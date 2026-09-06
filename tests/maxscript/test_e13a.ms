/*
    test_e13a.ms — Teste headless E13-A
    Verifica:
      1. AmenoCotasWindow != undefined apos bootstrap
      2. AmenoCotasWindow.window == undefined antes de abrir (singleton limpo)
*/

(
    -- Carregar o bootstrap a partir do caminho relativo ao arquivo de teste
    local testFile       = getSourceFileName()
    local testPath       = getFilenamePath testFile
    local worktreeRoot   = pathConfig.normalizePath (pathConfig.appendPath testPath @"..\..")
    local bootstrapPath  = pathConfig.normalizePath (pathConfig.appendPath worktreeRoot @"Contents\scripts\startup\ameno_bootstrap.ms")

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
        logPass "AmenoCotasWindow esta definido (nao e undefined)"
    else
        logFail "AmenoCotasWindow e undefined - bootstrap falhou em carregar ameno_cotas_window.ms"

    -- ----------------------------------------------------------------
    -- Teste 2: window deve ser undefined antes de qualquer show()
    -- ----------------------------------------------------------------
    if ::AmenoCotasWindow != undefined then
    (
        local wRef = try (::AmenoCotasWindow.window) catch (undefined)
        if wRef == undefined then
            logPass "AmenoCotasWindow.window e undefined antes de abrir (singleton limpo)"
        else
            logFail "AmenoCotasWindow.window NAO e undefined antes de abrir - singleton sujo"
    )
    else
    (
        logFail "Teste 2 ignorado - AmenoCotasWindow nao existe"
    )

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
