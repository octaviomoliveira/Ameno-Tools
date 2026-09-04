/*
    Suíte de Testes Automatizados E11.4: Aplicação e Persistência de Estilos.
    Valida:
    1. Cancelar: descarta draft, fecha janela, remove callbacks, preserva estilos e cena.
    2. Salvar estilo: atualiza registro, propaga às cotas vinculadas com Undo/Redo atômico.
    3. Salvar como novo: cria novo ID e registro derivado, preserva original, comuta draft e combobox.
    4. Aplicar às selecionadas: deduplica componentes da mesma cota e atualiza em lote com Undo.
    5. Seleção vazia: feedback claro no status bar sem erro de execução.
    6. Seleção de cena alterada: callback atualiza contadores/status sem descartar draft dirty.
    7. Resiliência a erros: rollback de snapshot defensivo em caso de falha simulada.
    8. Isolamento de cena: ciclo completo sem criação indesejada de nós orfãos.
*/

(
    global AmenoStyleEditorWPF
    global AmenoStyleEditorWindow
    global AmenoStyleService
    global AmenoDimensionGraphics
    global AmenoDimensionCA

    local totalTests = 0
    local passedTests = 0

    fn assertCondition msg condition =
    (
        totalTests += 1
        if condition then (
            passedTests += 1
            format "[PASS] %\n" msg
        ) else (
            format "[FAIL] %\n" msg
        )
    )

    format "\n=================================================================\n"
    format "=== [AMENO_TEST] Iniciando Testes da E11.4: Persistência de Estilos ===\n"
    format "=================================================================\n\n"

    -- 0. Setup do ambiente de testes
    resetMaxFile #noPrompt
    local testFile = getSourceFileName()
    local testPath = getFilenamePath testFile
    local repositoryRoot = pathConfig.normalizePath (pathConfig.appendPath testPath @"..\..")
    local bootstrapPath = pathConfig.normalizePath (pathConfig.appendPath repositoryRoot @"Contents\scripts\startup\ameno_bootstrap.ms")
    fileIn bootstrapPath quiet:true

    -- TESTE 1: Ação Cancelar (Discard Draft e Fechamento)
    format "\n--- Teste 1: Cancelar e Descarte de Rascunho ---\n"
    local win1 = AmenoStyleEditorWPF.buildWindow styleId:"default"
    local origSize = AmenoStyleEditorWPF.currentDraft.styleRecord.fontSize
    AmenoStyleEditorWPF.onFieldChanged #fontSize 55.0
    assertCondition "Draft marcado como dirty após alteração" AmenoStyleEditorWPF.currentDraft.isDirty

    AmenoStyleEditorWPF.onCancel()
    assertCondition "Janela fechada após Cancelar" (not AmenoStyleEditorWPF.isOpen())
    local ssCb = stringStream ""
    callbacks.show id:#amenoStyleEditorWpfSelection to:ssCb
    assertCondition "Callback de seleção removido após Cancelar" ((ssCb as string) == "")
    assertCondition "currentDraft limpo após Cancelar" (AmenoStyleEditorWPF.currentDraft == undefined)

    local stDefault = AmenoStyleService.getStyle "default"
    assertCondition "Estilo 'default' no registro intacto após Cancelar" (stDefault.fontSize == origSize)

    -- TESTE 2: Ação Salvar Estilo com Propagação e Undo/Redo
    format "\n--- Teste 2: Salvar Estilo com Propagação e Undo/Redo ---\n"
    AmenoStyleService.saveToScene()
    local dimA = AmenoDimensionGraphics.createDimension [0,0,0] [1000,0,0] [500,200,0] styleId:"default"
    local dimB = AmenoDimensionGraphics.createDimension [0,500,0] [1000,500,0] [500,700,0] styleId:"default"
    assertCondition "Duas cotas criadas na cena para teste de sincronização de estilo" (dimA != undefined and dimB != undefined)

    local win2 = AmenoStyleEditorWPF.buildWindow styleId:"default"
    AmenoStyleEditorWPF.onFieldChanged #fontSize 33.0
    AmenoStyleEditorWPF.onFieldChanged #terminalType #dot
    AmenoStyleEditorWPF.onFieldChanged #lineThickness 2.8

    local savedCount = AmenoStyleEditorWPF.onSaveStyle()
    assertCondition "onSaveStyle retorna contagem de cotas atualizadas" (savedCount >= 2)
    assertCondition "Draft marcado como não-dirty após salvar" (not AmenoStyleEditorWPF.currentDraft.isDirty)

    local updatedStyle = AmenoStyleService.getStyle "default"
    assertCondition "Registro de estilo atualizado com novo fontSize (33.0)" (updatedStyle.fontSize == 33.0)
    assertCondition "Registro de estilo atualizado com novo terminalType (#dot)" (updatedStyle.terminalType == #dot)
    assertCondition "Registro de estilo atualizado com novo lineThickness (2.8)" (updatedStyle.lineThickness == 2.8)
    assertCondition "Mensagem de status informa estilo salvo" (matchPattern AmenoStyleEditorWPF.txtPreviewStatus.Text pattern:"*salvo*")

    -- Testar Undo
    max undo
    local undoStyle = AmenoStyleService.getStyle "default"
    assertCondition "max undo reverte modificação do estilo salvo" (undoStyle.fontSize != 33.0)

    -- Testar Redo
    max redo
    local redoStyle = AmenoStyleService.getStyle "default"
    assertCondition "max redo reaplica modificação do estilo salvo" (redoStyle.fontSize == 33.0)

    AmenoStyleEditorWPF.onCancel()

    -- TESTE 3: Ação Salvar como Novo Estilo
    format "\n--- Teste 3: Salvar Como Novo Estilo ---\n"
    local win3 = AmenoStyleEditorWPF.buildWindow styleId:"default"
    AmenoStyleEditorWPF.onFieldChanged #fontSize 19.5
    AmenoStyleEditorWPF.onFieldChanged #terminalType #arrowOpen

    local newRecord = AmenoStyleEditorWPF.onSaveAsNew()
    assertCondition "onSaveAsNew cria novo registro com sucesso" (newRecord != undefined)
    assertCondition "Novo registro possui ID diferente do de origem" (newRecord.styleId != "default")
    assertCondition "Novo registro possui sufixo (Cópia)" (matchPattern newRecord.name pattern:"*(Cópia)*")
    assertCondition "Estilo de origem 'default' preservado inalterado" ((AmenoStyleService.getStyle "default").terminalType == #dot)
    assertCondition "currentDraft aponta para o novo estilo criado" (AmenoStyleEditorWPF.currentDraft.sourceStyleId == newRecord.styleId)
    assertCondition "currentDraft limpo de dirty após salvar como novo" (not AmenoStyleEditorWPF.currentDraft.isDirty)
    assertCondition "cbStyleSelect contém o novo estilo na lista" (AmenoStyleEditorWPF.cbStyleSelect.Items.Count >= 4)
    assertCondition "Mensagem de status informa novo estilo criado" (matchPattern AmenoStyleEditorWPF.txtPreviewStatus.Text pattern:"*Novo estilo criado*")

    AmenoStyleEditorWPF.onCancel()

    -- TESTE 4: Ação Aplicar às Selecionadas com Deduplicação Estrita
    format "\n--- Teste 4: Aplicar às Selecionadas com Deduplicação ---\n"
    local cota1 = AmenoDimensionGraphics.createDimension [0,1000,0] [800,1000,0] [400,1200,0] styleId:"editorial"
    local cota2 = AmenoDimensionGraphics.createDimension [0,1500,0] [800,1500,0] [400,1700,0] styleId:"editorial"

    -- Selecionar múltiplos nós da cota 1 + 1 nó da cota 2 (Total: >= 4 nós selecionados para 2 cotas reais)
    clearSelection()
    local cota1Nodes = AmenoDimensionGraphics.findNodesForDimension (AmenoDimensionGraphics.getDimensionId cota1.controller)
    select cota1Nodes
    selectMore cota2.controller
    assertCondition "Múltiplos nós selecionados na cena antes da aplicação" (selection.count >= 4)

    local win4 = AmenoStyleEditorWPF.buildWindow styleId:"technical"
    local appliedCount = AmenoStyleEditorWPF.onApplyToSelection()
    assertCondition "onApplyToSelection deduplica nós e atualiza exatamente 2 cotas" (appliedCount == 2)

    local ca1 = ::AmenoDimensionCA.readCA cota1.controller
    local ca2 = ::AmenoDimensionCA.readCA cota2.controller
    assertCondition "Cota 1 atualizada para novo estilo 'technical'" (ca1 != undefined and ca1.styleId == "technical")
    assertCondition "Cota 2 atualizada para novo estilo 'technical'" (ca2 != undefined and ca2.styleId == "technical")

    -- Testar Undo de aplicação à seleção
    max undo
    local ca1Undo = ::AmenoDimensionCA.readCA cota1.controller
    local ca2Undo = ::AmenoDimensionCA.readCA cota2.controller
    assertCondition "max undo reverte aplicação às cotas selecionadas" (ca1Undo.styleId == "editorial" and ca2Undo.styleId == "editorial")

    AmenoStyleEditorWPF.onCancel()

    -- TESTE 5: Seleção Vazia
    format "\n--- Teste 5: Feedback de Seleção Vazia ---\n"
    clearSelection()
    local win5 = AmenoStyleEditorWPF.buildWindow styleId:"default"
    local emptyApplied = AmenoStyleEditorWPF.onApplyToSelection()
    assertCondition "onApplyToSelection com seleção vazia retorna 0" (emptyApplied == 0)
    assertCondition "Status bar informa que nenhuma cota está selecionada" (matchPattern AmenoStyleEditorWPF.txtPreviewStatus.Text pattern:"*Nenhuma cota selecionada*")

    AmenoStyleEditorWPF.onCancel()

    -- TESTE 6: Callback de Seleção em Tempo Real sem Perda de Rascunho
    format "\n--- Teste 6: Seleção em Tempo Real sem Perda de Rascunho ---\n"
    local win6 = AmenoStyleEditorWPF.buildWindow styleId:"default"
    AmenoStyleEditorWPF.onFieldChanged #fontSize 48.0
    assertCondition "Draft marcado como dirty antes da alteração de seleção" AmenoStyleEditorWPF.currentDraft.isDirty

    -- Selecionar nós na cena e disparar callback
    select #(cota1.controller)
    AmenoStyleEditorWPF.onSceneSelectionChanged()

    assertCondition "Draft preserva fontSize após alteração de seleção na cena" (AmenoStyleEditorWPF.currentDraft.styleRecord.fontSize == 48.0)
    assertCondition "Draft permanece marcado como dirty após alteração de seleção" AmenoStyleEditorWPF.currentDraft.isDirty
    assertCondition "Status bar reflete cota selecionada pronta para aplicação" (matchPattern AmenoStyleEditorWPF.txtPreviewStatus.Text pattern:"*pronta(s) para aplicação*")

    AmenoStyleEditorWPF.onCancel()

    -- TESTE 7: Resiliência a Falhas com Rollback de Snapshot
    format "\n--- Teste 7: Resiliência e Rollback de Snapshot ---\n"
    local dimTech = AmenoDimensionGraphics.createDimension [0,2000,0] [800,2000,0] [400,2200,0] styleId:"technical"
    local originalStyleTech = AmenoStyleService.cloneStyle (AmenoStyleService.getStyle "technical")
    local draftFail = AmenoStyleService.createDraftFromStyle "technical"
    draftFail.styleRecord.fontSize = 99.0

    -- Simular falha durante saveDraftAsStyle injetando temporariamente erro em rebuildDimension
    struct AmenoMockFailingGraphics
    (
        originalService = undefined,
        fn findControllers = (if originalService != undefined then originalService.findControllers() else #()),
        fn rebuildDimension node style:undefined = (throw "Erro simulado para teste de rollback")
    )
    local oldGraphics = ::AmenoDimensionGraphics
    local mockG = AmenoMockFailingGraphics originalService:oldGraphics
    ::AmenoDimensionGraphics = mockG

    local caughtError = false
    try (
        AmenoStyleService.saveDraftAsStyle draftFail
    ) catch (
        caughtError = true
    )
    -- Restaurar serviço original
    ::AmenoDimensionGraphics = oldGraphics

    assertCondition "saveDraftAsStyle propagou exceção esperada" caughtError
    local rolledBackStyle = AmenoStyleService.getStyle "technical"
    assertCondition "Rollback restaura snapshot do estilo técnico prévio após falha" (rolledBackStyle.fontSize == originalStyleTech.fontSize)

    -- TESTE 8: Isolamento de Cena e Fechamento Seguro
    format "\n--- Teste 8: Isolamento e Ciclo de Vida ---\n"
    resetMaxFile #noPrompt
    local nodeCountBefore = objects.count

    local winFinal = AmenoStyleEditorWPF.buildWindow styleId:"default"
    AmenoStyleEditorWPF.onFieldChanged #fontSize 25.0
    AmenoStyleEditorWPF.onCancel()

    assertCondition "Nenhum nó criado na cena durante abertura, edição e cancelamento" (objects.count == nodeCountBefore)

    -- Resumo final
    format "\n=================================================================\n"
    format "Total de Testes E11.4: % | Aprovados: % | Falhas: %\n" totalTests passedTests (totalTests - passedTests)
    format "=================================================================\n\n"

    if passedTests == totalTests then (
        format "[AMENO_TEST][PASS] E11.4 Aplicacao e Persistencia aprovada com 100 por cento de sucesso.\n"
    ) else (
        format "[AMENO_TEST][FAIL] Falhas detectadas na suite E11.4.\n"
    )
)
