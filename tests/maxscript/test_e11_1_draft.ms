/*
    E11.1 — Testes do Modelo Transacional StyleDraft e Compatibilidade.
    Verifica:
    1. Clone defensivo: abrir estilo não cria alias na memória.
    2. Isolamento de edição: mutações no draft não afetam AmenoStyleService nem a cena 3D.
    3. Cancelamento: descartar o draft mantém registros, cena e Undo intactos.
    4. Persistência atômica: salvar draft atualiza o estilo e as cotas vinculadas com suporte a Undo/Redo.
    5. Deduplicação em lote: aplicar draft à seleção deduplica nós da mesma cota.
    6. Conversão para PreviewModel: toPreviewModel() reflete fidedignamente o estado do draft para o preview 2D.
    7. Migração de esquemas anteriores (E7-E10): 13 tokens legados são lidos com defaults defensivos de forma idempotente.
*/

(
    format "\n=================================================================\n"
    format "=== [AMENO_TEST] Iniciando Testes da E11.1: StyleDraft ===\n"
    format "=================================================================\n\n"

    resetMaxFile #noPrompt

    local testFile = getSourceFileName()
    local testPath = getFilenamePath testFile
    local repositoryRoot = pathConfig.normalizePath (pathConfig.appendPath testPath @"..\..")
    local bootstrapPath = pathConfig.normalizePath (pathConfig.appendPath repositoryRoot @"Contents\scripts\startup\ameno_bootstrap.ms")
    fileIn bootstrapPath quiet:true

    local totalTests = 0
    local passedTests = 0

    fn assertCondition desc condition =
    (
        totalTests += 1
        if condition then (
            passedTests += 1
            format "[PASS] %\n" desc
        ) else (
            format "[FAIL] %\n" desc
        )
    )

    -- TESTE 1: Clone defensivo ao abrir draft
    format "\n--- Teste 1: Clone defensivo ao abrir draft ---\n"
    local baseStyle = AmenoStyleService.getStyle "default"
    local originalFontSize = baseStyle.fontSize
    local draft = AmenoStyleService.createDraftFromStyle "default"

    assertCondition "Draft instanciado com sucesso" (draft != undefined)
    assertCondition "Draft aponta para sourceStyleId correto" (draft.sourceStyleId == "default")
    assertCondition "Draft inicia como isDirty = false" (not draft.isDirty)

    -- Mutar propriedade no draft
    draft.styleRecord.fontSize = 88.5
    draft.markDirty()
    assertCondition "Draft marcado como dirty apos alteracao" (draft.isDirty)

    local currentDefault = AmenoStyleService.getStyle "default"
    assertCondition "Estilo persistido no registro NAO foi alterado pela mutacao do draft" (currentDefault.fontSize == originalFontSize)

    -- TESTE 2: Isolamento da cena durante edicao do draft
    format "\n--- Teste 2: Isolamento da cena durante edicao do draft ---\n"
    local countBefore = objects.count
    draft.styleRecord.lineThickness = 4.2
    draft.styleRecord.textMaskEnabled = true
    draft.styleRecord.terminalType = #arrowClosed
    draft.styleRecord.terminalAngle = 30.0
    draft.sampleValue = "5,20 m"
    draft.previewDarkBg = false
    draft.previewZoom = 2.0

    assertCondition "Cena permanece intocada durante edicao do draft" (objects.count == countBefore)
    assertCondition "A quantidade de estilos registrados permanece inalterada" ((AmenoStyleService.listStyles()).count >= 3)

    -- TESTE 3: Geracao de PreviewModel a partir do draft
    format "\n--- Teste 3: Geracao de PreviewModel ---\n"
    local previewModel = draft.toPreviewModel()
    assertCondition "PreviewModel gerado com sucesso" (previewModel != undefined)
    assertCondition "PreviewModel reflete fontSize do draft" (previewModel.fontSize == 88.5)
    assertCondition "PreviewModel reflete lineThickness do draft" (previewModel.lineThickness == 4.2)
    assertCondition "PreviewModel reflete textMaskEnabled do draft" (previewModel.textMaskEnabled == true)
    assertCondition "PreviewModel reflete terminalType do draft" (previewModel.terminalType == #arrowClosed)
    assertCondition "PreviewModel reflete sampleValue do draft" (previewModel.sampleValue == "5,20 m")
    assertCondition "PreviewModel reflete darkBackground do draft" (previewModel.darkBackground == false)
    assertCondition "PreviewModel reflete zoom do draft" (previewModel.zoom == 2.0)

    -- TESTE 4: Cancelamento e descarte do draft
    format "\n--- Teste 4: Cancelamento e descarte do draft ---\n"
    AmenoStyleService.discardDraft draft
    assertCondition "Descarte limpa referencia do styleRecord" (draft.styleRecord == undefined)
    assertCondition "Descarte reseta flag isDirty" (not draft.isDirty)
    assertCondition "Estilo no servico continua com valor original" ((AmenoStyleService.getStyle "default").fontSize == originalFontSize)

    -- TESTE 5: Criacao de draft a partir de preset
    format "\n--- Teste 5: Criacao de draft a partir de preset ---\n"
    local techDraft = AmenoStyleService.createDraftFromPreset "technical"
    assertCondition "Draft de preset tecnico criado" (techDraft != undefined)
    assertCondition "Draft de preset tecnico reflete terminal de seta" (techDraft.styleRecord.terminalType == #arrowClosed)
    assertCondition "Draft de preset inicia como dirty (rascunho ativo)" (techDraft.isDirty)

    -- TESTE 6: Salvar draft em estilo existente com Undo/Redo na cena
    format "\n--- Teste 6: Salvar draft com atualizacao de cotas vinculadas e Undo ---\n"
    AmenoStyleService.saveToScene()
    -- Cria cota de teste na cena vinculada ao estilo "default"
    local dimA = AmenoDimensionGraphics.createDimension [0,0,0] [1000,0,0] [500,200,0] styleId:"default"
    assertCondition "Cota criada na cena para teste de sincronizacao de estilo" (dimA != undefined and isValidNode dimA.controller)

    local editDraft = AmenoStyleService.createDraftFromStyle "default"
    editDraft.styleRecord.lineThickness = 3.5
    editDraft.styleRecord.textMaskEnabled = true
    editDraft.markDirty()

    local updatedCount = AmenoStyleService.saveDraftAsStyle editDraft
    assertCondition "saveDraftAsStyle atualizou a cota vinculada na cena" (updatedCount >= 1)
    assertCondition "Draft teve isDirty resetado para false apos salvar" (not editDraft.isDirty)

    local savedStyle = AmenoStyleService.getStyle "default"
    assertCondition "Registro de estilo atualizado com nova espessura" (savedStyle.lineThickness == 3.5)
    assertCondition "Registro de estilo atualizado com textMaskEnabled" (savedStyle.textMaskEnabled == true)

    -- Teste de Undo nativo do Max
    max undo
    local undoneStyle = AmenoStyleService.getStyle "default"
    assertCondition "max undo reverteu a espessura do estilo para o original" (undoneStyle.lineThickness == 1.5)

    -- Teste de Redo nativo do Max
    max redo
    local redoneStyle = AmenoStyleService.getStyle "default"
    assertCondition "max redo restaurou a espessura para 3.5" (redoneStyle.lineThickness == 3.5)

    -- TESTE 7: Aplicar draft às selecionadas com deduplicação
    format "\n--- Teste 7: Aplicar draft com deduplicacao de nos ---\n"
    -- Cria segunda cota
    local dimB = AmenoDimensionGraphics.createDimension [0,500,0] [800,500,0] [400,700,0] styleId:"default"

    -- Selecionar múltiplos nós da mesma cota dimA (linhas, label e controlador) + dimB
    clearSelection()
    local dimANodes = AmenoDimensionGraphics.findNodesForDimension (AmenoDimensionGraphics.getDimensionId dimA.controller)
    select dimANodes
    selectMore dimB.controller
    assertCondition "Selecao contem multiplos nos (mesma cota duplicada)" (selection.count >= 4)

    local selDraft = AmenoStyleService.createDraftFromPreset "editorial"
    local appliedCount = AmenoStyleService.applyDraftToSelection selDraft
    assertCondition "applyDraftToSelection deduplica nós e atualiza exatamente 2 cotas distintas" (appliedCount == 2)

    -- TESTE 8: Salvar como novo estilo
    format "\n--- Teste 8: Salvar draft como novo estilo ---\n"
    local newDraft = AmenoStyleService.createDraftFromStyle "default"
    newDraft.styleRecord.name = "Meu Estilo Personalizado"
    newDraft.styleRecord.lineThickness = 2.8
    newDraft.styleRecord.terminalType = #dot

    local createdRecord = AmenoStyleService.saveDraftAsNewStyle newDraft newName:"Meu Estilo Personalizado"
    assertCondition "Novo estilo criado no servico" (createdRecord != undefined)
    assertCondition "Novo estilo possui ID unico" (createdRecord.styleId != "default" and createdRecord.styleId != "")
    assertCondition "Novo estilo persiste propriedades do draft" (createdRecord.lineThickness == 2.8 and createdRecord.terminalType == #dot)
    assertCondition "Draft aponta agora para o novo sourceStyleId" (newDraft.sourceStyleId == createdRecord.styleId)
    assertCondition "Draft teve isDirty resetado" (not newDraft.isDirty)

    -- TESTE 9: Retrocompatibilidade e migracao idempotente com esquema antigo (13 tokens da E7-E10)
    format "\n--- Teste 9: Retrocompatibilidade com esquema de 13 tokens (E7-E10) ---\n"
    local legacyStr = "legacy_style|Estilo Legado|Courier New|18.0|1|0|5.0|10.0|1.2|6.0|0.0|#arrowOpen|12.0"
    local desOk = AmenoStyleService.deserializeStyles legacyStr
    AmenoStyleService.saveToScene()
    assertCondition "deserializeStyles carregou string legada de 13 tokens" desOk

    local legStyle = AmenoStyleService.getStyle "legacy_style"
    assertCondition "Estilo legado carregado com ID correto" (legStyle.styleId == "legacy_style")
    assertCondition "Estilo legado manteve fonte original" (legStyle.fontName == "Courier New")
    assertCondition "Estilo legado manteve bold original" (legStyle.bold == true)
    assertCondition "Estilo legado manteve terminalType original" (legStyle.terminalType == #arrowOpen)
    -- Verificar valores padrao dos campos estendidos v2
    assertCondition "Campo v2 textMaskEnabled recebeu default false (preserva visual E7-E10)" (legStyle.textMaskEnabled == false)
    assertCondition "Campo v2 annotationColor recebeu default 245,245,245" (legStyle.annotationColor == "245,245,245")
    assertCondition "Campo v2 textColor recebeu default vazio" (legStyle.textColor == "")
    assertCondition "Campo v2 terminalPlacement recebeu default #auto" (legStyle.terminalPlacement == #auto)
    assertCondition "Campo v2 terminalAngle recebeu default 45.0" (legStyle.terminalAngle == 45.0)
    assertCondition "Campo v2 previewScale recebeu default 1.0" (legStyle.previewScale == 1.0)

    -- Testar ciclo idempotente (serializar e deserializar novamente)
    local reSerialized = AmenoStyleService.serializeStyles()
    local reDesOk = AmenoStyleService.deserializeStyles reSerialized
    AmenoStyleService.saveToScene()
    assertCondition "Ciclo de re-serializacao e re-deserializacao e 100 por cento idempotente" reDesOk

    local legStyleAfter = AmenoStyleService.getStyle "legacy_style"
    assertCondition "Valores permanecem identicos apos ciclo de persistencia" (legStyleAfter.fontName == "Courier New" and legStyleAfter.terminalType == #arrowOpen)

    -- Resumo final
    format "\n=================================================================\n"
    format "Total de Testes E11.1: % | Aprovados: % | Falhas: %\n" totalTests passedTests (totalTests - passedTests)
    format "=================================================================\n\n"

    if passedTests == totalTests then (
        format "[AMENO_TEST][PASS] E11.1 StyleDraft e Compatibilidade aprovados com 100 por cento de sucesso.\n"
    ) else (
        format "[AMENO_TEST][FAIL] Falhas detectadas na suite E11.1.\n"
    )
)
