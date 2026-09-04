/*
    E11.2 — Testes do Shell e Navegação do Editor Visual de Estilos (WPF .NET 8).
    Verifica:
    1. Instanciação e layout responsivo do Shell WPF.
    2. Singleton: instância única mantida por sessão.
    3. Sincronização de controles a partir do StyleDraft.
    4. Mutações na UI marcam rascunho como dirty e atualizam indicador visual.
    5. Presença de Tooltips e ordem de Tabulação (TabIndex).
    6. Persistência de preferências de UI (Width, Height, Fundo) sem afetar a cena.
    7. Ações de Presets, Cancelamento e Salvamento.
    8. Isolamento de cena (0 nós e 0 layers criados na cena pelo editor).
*/

(
    global AmenoStyleEditorWPF
    global AmenoStyleEditorWindow
    global AmenoStyleService

    format "\n=================================================================\n"
    format "=== [AMENO_TEST] Iniciando Testes da E11.2: Shell e Navegação ===\n"
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

    -- TESTE 1: Instanciação e Controles da Janela WPF
    format "\n--- Teste 1: Instanciação e Controles da Janela WPF ---\n"
    local win = AmenoStyleEditorWPF.buildWindow styleId:"default"

    assertCondition "Janela WPF instanciada com sucesso" (win != undefined)
    assertCondition "Título da janela correto" (win.Title == "Ameno — Editor de Estilo")
    assertCondition "Largura mínima configurada (>= 740)" (win.MinWidth >= 740)
    assertCondition "Altura mínima configurada (>= 480)" (win.MinHeight >= 480)

    -- Verificar controles essenciais
    assertCondition "ComboBox de seleção de estilos presente" (AmenoStyleEditorWPF.cbStyleSelect != undefined)
    assertCondition "Indicador de alterações (dirty) presente" (AmenoStyleEditorWPF.txtDirtyMark != undefined)
    assertCondition "Contador de uso de cotas presente" (AmenoStyleEditorWPF.txtInUseCount != undefined)
    assertCondition "ComboBox de fontes presente" (AmenoStyleEditorWPF.cbFontName != undefined)
    assertCondition "Slider de tamanho de fonte presente" (AmenoStyleEditorWPF.sliderFontSize != undefined)
    assertCondition "CheckBox Negrito presente" (AmenoStyleEditorWPF.chkBold != undefined)
    assertCondition "CheckBox Itálico presente" (AmenoStyleEditorWPF.chkItalic != undefined)
    assertCondition "Slider de tracking presente" (AmenoStyleEditorWPF.sliderTracking != undefined)
    assertCondition "Slider de espessura de linha presente" (AmenoStyleEditorWPF.sliderLineThickness != undefined)
    assertCondition "ComboBox de tipo de terminal presente" (AmenoStyleEditorWPF.cbTerminalType != undefined)
    assertCondition "Botões de ação presentes (Cancelar, Aplicar, Salvar)" (AmenoStyleEditorWPF.btnCancel != undefined and AmenoStyleEditorWPF.btnApplySelection != undefined and AmenoStyleEditorWPF.btnSaveStyle != undefined)

    -- TESTE 2: Singleton por sessão
    format "\n--- Teste 2: Padrão Singleton por sessão ---\n"
    win.Show()
    assertCondition "Editor reporta estado aberto (isOpen = true)" (AmenoStyleEditorWPF.isOpen())

    local win2 = AmenoStyleEditorWPF.open styleId:"default"
    assertCondition "Reabrir o editor retorna a mesma instância sem duplicar janelas" (win == win2)

    -- TESTE 3: Sincronização de dados do StyleDraft para os controles da UI
    format "\n--- Teste 3: Sincronização StyleDraft -> UI ---\n"
    local draft = AmenoStyleEditorWPF.currentDraft
    assertCondition "Rascunho ativo instanciado" (draft != undefined and draft.styleRecord != undefined)
    assertCondition "UI reflete tamanho da fonte do estilo padrão (20.0)" (AmenoStyleEditorWPF.sliderFontSize.Value == 20.0)
    assertCondition "UI reflete espessura de linha do estilo padrão (1.5)" (AmenoStyleEditorWPF.sliderLineThickness.Value == 1.5)
    assertCondition "UI inicia com indicador dirty oculto" (AmenoStyleEditorWPF.txtDirtyMark.Visibility == (dotNetClass "System.Windows.Visibility").Collapsed)

    -- TESTE 4: Mutações na UI marcam o rascunho como dirty
    format "\n--- Teste 4: Mutações na UI e indicador dirty ---\n"
    AmenoStyleEditorWPF.sliderFontSize.Value = 32.0
    assertCondition "Alterar slider de tamanho atualizou o styleRecord no draft" (AmenoStyleEditorWPF.currentDraft.styleRecord.fontSize == 32.0)
    assertCondition "Draft marcado como dirty apos alteracao de controle" (AmenoStyleEditorWPF.currentDraft.isDirty)
    assertCondition "Indicador visual dirty exibido na UI" (AmenoStyleEditorWPF.txtDirtyMark.Visibility == (dotNetClass "System.Windows.Visibility").Visible)

    -- TESTE 5: Acessibilidade - Tooltips e Ordem de Tabulação
    format "\n--- Teste 5: Tooltips e Ordem de Tabulação ---\n"
    local hasCancelTip = (AmenoStyleEditorWPF.btnCancel.ToolTip as string) != ""
    local hasSaveTip = (AmenoStyleEditorWPF.btnSaveStyle.ToolTip as string) != ""
    local hasTabIndices = (AmenoStyleEditorWPF.btnCancel.TabIndex > 0 and AmenoStyleEditorWPF.btnSaveStyle.TabIndex > 0)
    assertCondition "Botão Cancelar possui ToolTip contextual" hasCancelTip
    assertCondition "Botão Salvar possui ToolTip contextual" hasSaveTip
    assertCondition "Controles possuem TabIndex positivo definido" hasTabIndices

    -- TESTE 6: Preferências de Interface Seguras (INI do usuário)
    format "\n--- Teste 6: Preferências de Interface Seguras ---\n"
    local prefSaveOk = AmenoStyleEditorWPF.savePreferences 940.0 620.0 false
    assertCondition "Preferências salvas com sucesso em arquivo INI" prefSaveOk

    local loadedPrefs = AmenoStyleEditorWPF.loadPreferences()
    assertCondition "Largura recuperada corretamente" (loadedPrefs[1] == 940.0)
    assertCondition "Altura recuperada corretamente" (loadedPrefs[2] == 620.0)
    assertCondition "Preferência de tema escuro recuperada corretamente" (loadedPrefs[3] == false)

    -- Restaurar defaults para não afetar próximas sessões
    AmenoStyleEditorWPF.savePreferences 860.0 560.0 true

    -- TESTE 7: Presets Rápidos na UI
    format "\n--- Teste 7: Presets Rápidos na UI ---\n"
    AmenoStyleEditorWPF.onPresetClick "technical"
    assertCondition "Preset Técnico carregou terminal de seta fechada" (AmenoStyleEditorWPF.currentDraft.styleRecord.terminalType == #arrowClosed)
    assertCondition "Preset Técnico atualizou ComboBox de terminais na UI" (AmenoStyleEditorWPF.cbTerminalType.SelectedIndex == 1)
    assertCondition "Preset Técnico marcou draft como dirty para revisão visual" (AmenoStyleEditorWPF.currentDraft.isDirty)

    -- TESTE 8: Fechamento Seguro e Limpeza de Singleton
    format "\n--- Teste 8: Fechamento Seguro e Limpeza de Singleton ---\n"
    AmenoStyleEditorWPF.close()
    assertCondition "close() fecha a janela WPF" (not AmenoStyleEditorWPF.isOpen())
    assertCondition "Referência singleton liberada" (AmenoStyleEditorWPF.window == undefined and AmenoStyleEditorWindow == undefined)
    assertCondition "Draft descartado com segurança" (AmenoStyleEditorWPF.currentDraft == undefined)

    -- TESTE 9: Isolamento Total da Cena
    format "\n--- Teste 9: Isolamento Total da Cena ---\n"
    assertCondition "Nenhum objeto criado na cena durante abertura, edição e fechamento do editor" (objects.count == 0)

    -- Resumo final
    format "\n=================================================================\n"
    format "Total de Testes E11.2: % | Aprovados: % | Falhas: %\n" totalTests passedTests (totalTests - passedTests)
    format "=================================================================\n\n"

    if passedTests == totalTests then (
        format "[AMENO_TEST][PASS] E11.2 Shell e Navegacao aprovados com 100 por cento de sucesso.\n"
    ) else (
        format "[AMENO_TEST][FAIL] Falhas detectadas na suite E11.2.\n"
    )
)
