/*
    test_e13f.ms -- Teste headless E13-F
*/

(
    local testFile     = getSourceFileName()
    local testPath     = getFilenamePath testFile
    local worktreeRoot = pathConfig.normalizePath (pathConfig.appendPath testPath @"..\..")
    local bootstrapPath = pathConfig.normalizePath (pathConfig.appendPath worktreeRoot @"Contents\scripts\startup\ameno_bootstrap.ms")

    if doesFileExist bootstrapPath then
        fileIn bootstrapPath quiet:true
    else
        format "[AMENO_TEST][FAIL] bootstrap nao encontrado\n" bootstrapPath

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

    if ::AmenoDimensionTerminalMesh != undefined then
        logPass "AmenoDimensionTerminalMesh esta definido"
    else
        logFail "AmenoDimensionTerminalMesh e undefined"

    if ::AmenoDimensionTerminalMesh != undefined then
    (
        local hasFn = false
        try (hasFn = (::AmenoDimensionTerminalMesh.createTerminal != undefined)) catch ()
        if hasFn then logPass "createTerminal existe na struct"
        else logFail "createTerminal nao existe na struct"
    )
    else logFail "Teste 2 ignorado"

    if ::AmenoDimensionTerminalMesh != undefined then
    (
        local hasFn = false
        try (hasFn = (::AmenoDimensionTerminalMesh.updateTerminal != undefined)) catch ()
        if hasFn then logPass "updateTerminal existe na struct"
        else logFail "updateTerminal nao existe na struct"
    )
    else logFail "Teste 3 ignorado"

    if ::AmenoDimensionTerminalMesh != undefined then
    (
        local hasFn = false
        try (hasFn = (::AmenoDimensionTerminalMesh.removeTerminal != undefined)) catch ()
        if hasFn then logPass "removeTerminal existe na struct"
        else logFail "removeTerminal nao existe na struct"
    )
    else logFail "Teste 4 ignorado"

    local termNode = undefined
    if ::AmenoDimensionTerminalMesh != undefined then
    (
        try
        (
            termNode = ::AmenoDimensionTerminalMesh.createTerminal #arrowClosed [0,0,0] [1,0,0] 20.0 (color 245 245 245)
        )
        catch (termNode = undefined)
        if termNode != undefined and isValidNode termNode then
            logPass "createTerminal arrowClosed retornou no valido"
        else
            logFail "createTerminal arrowClosed retornou invalido"
    )
    else logFail "Teste 5 ignorado"

    if termNode != undefined and isValidNode termNode then
    (
        local nodeHandle = termNode.handle
        local removed = false
        try (removed = ::AmenoDimensionTerminalMesh.removeTerminal termNode) catch ()
        local stillExists = false
        try (for n in objects where n.handle == nodeHandle do stillExists = true) catch ()
        if removed and not stillExists then
            logPass "removeTerminal deletou o no da cena"
        else if not removed then
            logFail "removeTerminal retornou false"
        else
            logFail "removeTerminal true mas no ainda existe"
    )
    else logFail "Teste 6 ignorado"

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
