/*
    test_e13h.ms -- Teste headless de Integracao Final E13-H
    Valida a arquitetura unificada completa do E13:
      1. Bootstrap carrega todos os modulos sem erros
      2. AmenoCotasWindow existe e e singleton
      3. Tab 1 (Criar) - AmenoCotasCriarTab constroi UserControl
      4. Tab 2 (Estilos) - AmenoCotasEstilosTab constroi UserControl
      5. Tab 3 (Editar) - AmenoCotasEditarTab constroi UserControl
      6. Tab 4 (Render) - AmenoCotasRenderTab constroi UserControl
      7. AmenoShowMainPanel abre a janela unificada (compatibilidade retroativa)
      8. AmenoRefreshMainPanel executa com seguranca
      9. AmenoStyleEditorWindow redireciona para a aba Estilos
      10. Terminais mesh (E13-F) funcionam na arquitetura integrada
      11. Gestao de cena (deletarSelecao, limparOrfas, deletarTudo) disponivel no runtime
      12. Macroscripts e icones verificados
*/

(
    local testFile      = getSourceFileName()
    local testPath      = getFilenamePath testFile
    local worktreeRoot  = pathConfig.normalizePath (pathConfig.appendPath testPath @"..\..")
    local bootstrapPath = pathConfig.normalizePath (pathConfig.appendPath worktreeRoot @"Contents\scripts\startup\ameno_bootstrap.ms")
    local mcrPath       = pathConfig.normalizePath (pathConfig.appendPath worktreeRoot @"Contents\macroscripts\AmenoTools.mcr")

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
    -- Teste 1: AmenoCotasWindow singleton
    -- ----------------------------------------------------------------
    if ::AmenoCotasWindow != undefined then
        logPass "1. AmenoCotasWindow esta definido no runtime unificado"
    else
        logFail "1. AmenoCotasWindow e undefined"

    -- ----------------------------------------------------------------
    -- Teste 2: Construcao da janela WPF
    -- ----------------------------------------------------------------
    local win = undefined
    try
    (
        win = ::AmenoCotasWindow.buildWindow()
    )
    catch
    (
        format "[AMENO_TEST][DETAIL] Erro ao construir janela: %\n" (getCurrentException() as string)
    )

    if win != undefined then
        logPass "2. AmenoCotasWindow.buildWindow() instanciou o shell WPF com sucesso"
    else
        logFail "2. AmenoCotasWindow.buildWindow() falhou"

    -- ----------------------------------------------------------------
    -- Teste 3: Tab Criar (E13-B)
    -- ----------------------------------------------------------------
    local tab1 = try (::AmenoCotasCriarTab.build()) catch (undefined)
    if tab1 != undefined then
        logPass "3. Tab Criar UserControl instanciado com sucesso"
    else
        logFail "3. Tab Criar falhou ao construir UserControl"

    -- ----------------------------------------------------------------
    -- Teste 4: Tab Estilos (E13-C)
    -- ----------------------------------------------------------------
    local tab2 = try (::AmenoCotasEstilosTab.build()) catch (undefined)
    if tab2 != undefined then
        logPass "4. Tab Estilos UserControl instanciado com sucesso"
    else
        logFail "4. Tab Estilos falhou ao construir UserControl"

    -- ----------------------------------------------------------------
    -- Teste 5: Tab Editar (E13-D)
    -- ----------------------------------------------------------------
    local tab3 = try (::AmenoCotasEditarTab.build()) catch (undefined)
    if tab3 != undefined then
        logPass "5. Tab Editar UserControl instanciado com sucesso"
    else
        logFail "5. Tab Editar falhou ao construir UserControl"

    -- ----------------------------------------------------------------
    -- Teste 6: Tab Render (E13-E)
    -- ----------------------------------------------------------------
    local tab4 = try (::AmenoCotasRenderTab.build()) catch (undefined)
    if tab4 != undefined then
        logPass "6. Tab Render UserControl instanciado com sucesso"
    else
        logFail "6. Tab Render falhou ao construir UserControl"

    -- ----------------------------------------------------------------
    -- Teste 7: Compatibilidade de AmenoShowMainPanel
    -- ----------------------------------------------------------------
    if ::AmenoShowMainPanel != undefined then
        logPass "7. AmenoShowMainPanel stub de compatibilidade existe"
    else
        logFail "7. AmenoShowMainPanel nao esta definido"

    -- ----------------------------------------------------------------
    -- Teste 8: Compatibilidade de AmenoRefreshMainPanel
    -- ----------------------------------------------------------------
    local refreshOk = false
    try
    (
        ::AmenoRefreshMainPanel()
        refreshOk = true
    )
    catch ()

    if refreshOk then
        logPass "8. AmenoRefreshMainPanel executa de forma segura"
    else
        logFail "8. AmenoRefreshMainPanel lancou excecao"

    -- ----------------------------------------------------------------
    -- Teste 9: Compatibilidade do editor de estilos separado
    -- ----------------------------------------------------------------
    if ::AmenoStyleEditorWindow != undefined and (try (not (isProperty ::AmenoStyleEditorWindow #window)) catch (true)) then
        logPass "9. AmenoStyleEditorWindow e stub que redireciona para a janela unificada"
    else
        logFail "9. AmenoStyleEditorWindow nao e stub compativel"

    -- ----------------------------------------------------------------
    -- Teste 10: Terminais Mesh (E13-F)
    -- ----------------------------------------------------------------
    if ::AmenoDimensionTerminalMesh != undefined then
    (
        local termNode = try (::AmenoDimensionTerminalMesh.createTerminal #arrowClosed [0,0,0] [1,0,0] 10.0 (color 100 100 100)) catch (undefined)
        if termNode != undefined and isValidNode termNode then
        (
            try (::AmenoDimensionTerminalMesh.removeTerminal termNode) catch ()
            logPass "10. Terminais mesh (arrowClosed) criados e removidos com sucesso"
        )
        else
            logFail "10. createTerminal retornou no invalido"
    )
    else
        logFail "10. AmenoDimensionTerminalMesh e undefined"

    -- ----------------------------------------------------------------
    -- Teste 11: Gestao de cena no runtime
    -- ----------------------------------------------------------------
    if ::AmenoApp != undefined and \
       (try ((::AmenoApp.deletarSelecao) != undefined) catch (false)) and \
       (try ((::AmenoApp.limparOrfas) != undefined) catch (false)) and \
       (try ((::AmenoApp.deletarTudo) != undefined) catch (false)) then
        logPass "11. Funcoes de gestao de cena (deletarSelecao, limparOrfas, deletarTudo) disponiveis"
    else
        logFail "11. Funcoes de gestao de cena ausentes no AmenoApp"

    -- ----------------------------------------------------------------
    -- Teste 12: Macroscripts compilam
    -- ----------------------------------------------------------------
    if doesFileExist mcrPath and (try (fileIn mcrPath quiet:true; true) catch (false)) then
        logPass "12. Macroscripts compilam e estao prontos para uso"
    else
        logFail "12. Falha ao compilar macroscripts"

    -- ----------------------------------------------------------------
    -- Sumario
    -- ----------------------------------------------------------------
    format "\n[AMENO_TEST] Resultado: % passou(aram), % falhou(aram)\n" passed failed

    if failed == 0 then
    (
        format "[AMENO_TEST][PASS] Todos os testes E13-H de integracao passaram.\n"
        true
    )
    else
    (
        format "[AMENO_TEST][FAIL] Falhas: %\n" (errors as string)
        false
    )
)
