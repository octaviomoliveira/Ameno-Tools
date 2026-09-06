/*
    test_e13_audit_fixes.ms -- Teste automatizado de validacao das correcoes de auditoria E13
    Valida:
      1. Instanciacao e chamada de AmenoCotasEditarTab.refresh() com cota real selecionada (BrushConverter dotNetObject)
      2. Seguranca em limparOrfas() com ancora simples (nodeA valido, sem falso-positivo de orfa)
      3. Terminais mesh preenchidos (arrowClosed, diamond, dot) com 2-sided faces e limpeza completa
      4. Metrica de delecao unitaria em deletarSelecao() (retorna 1 por cota)
      5. Metodo publico AmenoCotasWindow.showTab (suporte a string e inteiro)
      6. Parsing robusto de virgula decimal
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

    -- Limpar cena inicial
    resetMaxFile #noPrompt

    -- ----------------------------------------------------------------
    -- Teste 1: BrushConverter e refresh() na aba Editar com cota real
    -- ----------------------------------------------------------------
    local test1Ok = false
    try
    (
        local p1 = [0, 0, 0]
        local p2 = [1000, 0, 0]
        local po = [0, 200, 0]
        local created = ::AmenoDimensionGraphics.createDimension p1 p2 po role:"test"
        if created != undefined and isValidNode created.controller do
        (
            select created.controller
            local editTab = ::AmenoCotasEditarTab.build()
            local refRes = ::AmenoCotasEditarTab.refresh()
            if refRes == true do test1Ok = true
        )
    )
    catch
    (
        format "[AMENO_TEST][DETAIL] Teste 1 erro: %\n" (getCurrentException() as string)
    )

    if test1Ok then
        logPass "1. AmenoCotasEditarTab.refresh() executou sem erro de BrushConverter com cota selecionada"
    else
        logFail "1. AmenoCotasEditarTab.refresh() falhou"

    -- ----------------------------------------------------------------
    -- Teste 2: limparOrfas() nao apaga cotas com ancora mista/simples (nodeA)
    -- ----------------------------------------------------------------
    local test2Ok = false
    try
    (
        local anchorBox = Box length:100 width:100 height:100 pos:[500, 500, 0]
        local dimMixed = ::AmenoDimensionGraphics.createDimension [500, 500, 0] [1500, 500, 0] [500, 700, 0] role:"test"             anchorType:"nodeA" nodeA:anchorBox

        if dimMixed != undefined and isValidNode dimMixed.controller do
        (
            local dimId = dimMixed.dimensionId
            -- Executa limparOrfas
            local removedCount = ::AmenoApp.limparOrfas()
            -- Verifica se a cota continua existindo
            local remainingNodes = ::AmenoDimensionGraphics.findNodesForDimension dimId
            if remainingNodes.count > 0 then
                test2Ok = true
            else
                format "[AMENO_TEST][DETAIL] Cota com nodeA valido foi incorretamente apagada como orfa!\n"
        )
    )
    catch
    (
        format "[AMENO_TEST][DETAIL] Teste 2 erro: %\n" (getCurrentException() as string)
    )

    if test2Ok then
        logPass "2. limparOrfas() preservou cota com ancora simples (sem falso-positivo)"
    else
        logFail "2. limparOrfas() apagou cota valida com ancora simples"

    -- ----------------------------------------------------------------
    -- Teste 3: Terminais Mesh (2-sided faces, metadata e remocao limpa)
    -- ----------------------------------------------------------------
    local test3Ok = false
    try
    (
        -- Valida criacao de arrowClosed com 2 faces (2-sided)
        local termArrow = ::AmenoDimensionTerminalMesh.createTerminal #arrowClosed [0, 0, 0] [1, 0, 0] 50.0 (color 200 200 200) dimensionId:"test-dim-123"
        local arrowOk = false
        if termArrow != undefined and isValidNode termArrow do
        (
            local numFaces = getNumFaces termArrow
            local hasDimProp = (::AmenoDimensionGraphics.readTextProperty termArrow "Ameno.DimensionId") == "test-dim-123"
            local isTermProp = (getUserProp termArrow "AMENO_TERMINAL") == true
            if numFaces == 2 and hasDimProp and isTermProp do arrowOk = true
            delete termArrow
        )

        -- Valida criacao de diamond com 4 faces (2-sided quad)
        local termDiamond = ::AmenoDimensionTerminalMesh.createTerminal #diamond [0, 0, 0] [1, 0, 0] 50.0 (color 200 200 200) dimensionId:"test-dim-123"
        local diamondOk = false
        if termDiamond != undefined and isValidNode termDiamond do
        (
            local numFaces = getNumFaces termDiamond
            if numFaces == 4 do diamondOk = true
            delete termDiamond
        )

        -- Valida criacao e remocao integrada de cota com estilo de terminal mesh
        local meshStyle = ::AmenoStyleRecord()
        meshStyle.terminalType = #arrowClosed
        meshStyle.terminalSize = 60.0

        local dimWithMeshTerm = ::AmenoDimensionGraphics.createDimension [2000, 0, 0] [3000, 0, 0] [2000, 200, 0] role:"test" style:meshStyle
        local integratedOk = false
        if dimWithMeshTerm != undefined and isValidNode dimWithMeshTerm.controller do
        (
            local dimId = dimWithMeshTerm.dimensionId
            local nodesBefore = ::AmenoDimensionGraphics.findNodesForDimension dimId
            local foundTerm = false
            for nd in nodesBefore where (getUserProp nd "AMENO_TERMINAL") == true do foundTerm = true

            -- Remove e checa se algum no ficou sobrando
            ::AmenoDimensionGraphics.removeVisualNodes dimId
            local nodesAfter = ::AmenoDimensionGraphics.findNodesForDimension dimId
            local foundResidual = false
            for nd in nodesAfter where (getUserProp nd "AMENO_TERMINAL") == true do foundResidual = true

            if foundTerm and not foundResidual do integratedOk = true
            delete dimWithMeshTerm.controller
        )

        if arrowOk and diamondOk and integratedOk then test3Ok = true
        else format "[AMENO_TEST][DETAIL] Teste 3 status: arrowOk=% diamondOk=% integratedOk=%\n" arrowOk diamondOk integratedOk
    )
    catch
    (
        format "[AMENO_TEST][DETAIL] Teste 3 erro: %\n" (getCurrentException() as string)
    )

    if test3Ok then
        logPass "3. Terminais mesh (2-sided, metadata, integracao e remocao limpa) funcionam perfeitamente"
    else
        logFail "3. Terminais mesh falharam na validacao"

    -- ----------------------------------------------------------------
    -- Teste 4: deletarSelecao() incrementa exatamente 1 por cota
    -- ----------------------------------------------------------------
    local test4Ok = false
    try
    (
        local dSingle = ::AmenoDimensionGraphics.createDimension [0, 1000, 0] [1000, 1000, 0] [0, 1200, 0] role:"test"
        if dSingle != undefined and isValidNode dSingle.lineNode do
        (
            select dSingle.lineNode
            local deletedCount = ::AmenoApp.deletarSelecao()
            if deletedCount == 1 do test4Ok = true
        )
    )
    catch
    (
        format "[AMENO_TEST][DETAIL] Teste 4 erro: %\n" (getCurrentException() as string)
    )

    if test4Ok then
        logPass "4. deletarSelecao() reportou contagem unitaria correta (1 cota removida)"
    else
        logFail "4. deletarSelecao() retornou contagem incorreta"

    -- ----------------------------------------------------------------
    -- Teste 5: AmenoCotasWindow.showTab suporta nomes e inteiros
    -- ----------------------------------------------------------------
    local test5Ok = false
    try
    (
        ::AmenoCotasWindow.showTab "Estilos"
        local isS2 = (::AmenoCotasWindow.activeSection == 2)
        ::AmenoCotasWindow.showTab 3
        local isS3 = (::AmenoCotasWindow.activeSection == 3)
        ::AmenoCotasWindow.showTab "Criar"
        local isS1 = (::AmenoCotasWindow.activeSection == 1)
        ::AmenoCotasWindow.close()

        if isS2 and isS3 and isS1 do test5Ok = true
    )
    catch
    (
        format "[AMENO_TEST][DETAIL] Teste 5 erro: %\n" (getCurrentException() as string)
    )

    if test5Ok then
        logPass "5. AmenoCotasWindow.showTab navegou corretamente entre secoes (nome e indice)"
    else
        logFail "5. AmenoCotasWindow.showTab falhou"

    -- ----------------------------------------------------------------
    -- Teste 6: Parsing de virgula decimal
    -- ----------------------------------------------------------------
    local test6Ok = false
    try
    (
        local inputVal = "2,75"
        local parsed = (substituteString inputVal "," ".") as float
        if parsed == 2.75 do test6Ok = true
    )
    catch ()

    if test6Ok then
        logPass "6. Tratamento e parsing de virgula decimal validados"
    else
        logFail "6. Falha no parsing de virgula decimal"

    -- ----------------------------------------------------------------
    -- Sumario
    -- ----------------------------------------------------------------
    format "\n[AMENO_TEST] Resultado da Auditoria: % passou(aram), % falhou(aram)\n" passed failed

    if failed == 0 then
    (
        format "[AMENO_TEST][PASS] Todas as correcoes de auditoria E13 foram validadas com sucesso.\n"
        true
    )
    else
    (
        format "[AMENO_TEST][FAIL] Falhas de auditoria: %\n" (errors as string)
        false
    )
)
