/*
    test_e13g.ms -- Teste headless E13-G
    Verifica:
      1. AmenoTools.mcr compila e carrega os 5 macroscripts sem erros
      2. Os 10 arquivos de icones .bmp existem em Contents/icons/ameno/
      3. Macroscripts estao disponiveis no ambiente MaxScript
*/

(
    local testFile      = getSourceFileName()
    local testPath      = getFilenamePath testFile
    local worktreeRoot  = pathConfig.normalizePath (pathConfig.appendPath testPath @"..\..")
    local bootstrapPath = pathConfig.normalizePath (pathConfig.appendPath worktreeRoot @"Contents\scripts\startup\ameno_bootstrap.ms")
    local mcrPath       = pathConfig.normalizePath (pathConfig.appendPath worktreeRoot @"Contents\macroscripts\AmenoTools.mcr")
    local iconsDir      = pathConfig.normalizePath (pathConfig.appendPath worktreeRoot @"Contents\icons\ameno")

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
    -- Teste 1: AmenoTools.mcr deve carregar sem erros
    -- ----------------------------------------------------------------
    if doesFileExist mcrPath then
    (
        local mcrLoaded = false
        try
        (
            fileIn mcrPath quiet:true
            mcrLoaded = true
        )
        catch
        (
            format "[AMENO_TEST][DETAIL] Erro ao carregar MCR: %\n" (getCurrentException() as string)
            mcrLoaded = false
        )

        if mcrLoaded then
            logPass "AmenoTools.mcr compilou e carregou com sucesso"
        else
            logFail "AmenoTools.mcr falhou ao carregar"
    )
    else
        logFail ("AmenoTools.mcr nao encontrado em: " + mcrPath)

    -- ----------------------------------------------------------------
    -- Teste 2: Verificar icones de toolbar (16x16 e 24x24)
    -- ----------------------------------------------------------------
    local iconNames = #(
        "cotas_panel_16.bmp",
        "cotas_panel_24.bmp",
        "cota_individual_16.bmp",
        "cota_individual_24.bmp",
        "cota_continua_16.bmp",
        "cota_continua_24.bmp",
        "editor_estilos_16.bmp",
        "editor_estilos_24.bmp",
        "render_cotas_16.bmp",
        "render_cotas_24.bmp"
    )

    local missingIcons = #()
    for ic in iconNames do
    (
        local icPath = pathConfig.appendPath iconsDir ic
        if not (doesFileExist icPath) do append missingIcons ic
    )

    if missingIcons.count == 0 then
        logPass "Todos os 10 icones .bmp foram verificados em Contents/icons/ameno/"
    else
        logFail ("Icones ausentes: " + (missingIcons as string))

    -- ----------------------------------------------------------------
    -- Teste 3: Verificar que AmenoCotasWindow e AmenoApp estao prontos
    -- ----------------------------------------------------------------
    if ::AmenoCotasWindow != undefined and ::AmenoApp != undefined then
        logPass "AmenoCotasWindow e AmenoApp estao prontos para execucao dos MacroScripts"
    else
        logFail "AmenoCotasWindow ou AmenoApp nao estao disponiveis"

    -- ----------------------------------------------------------------
    -- Sumario
    -- ----------------------------------------------------------------
    format "\n[AMENO_TEST] Resultado: % passou(aram), % falhou(aram)\n" passed failed

    if failed == 0 then
    (
        format "[AMENO_TEST][PASS] Todos os testes E13-G passaram.\n"
        true
    )
    else
    (
        format "[AMENO_TEST][FAIL] Falhas: %\n" (errors as string)
        false
    )
)
