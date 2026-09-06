/* Regressao dos ajustes solicitados no gate visual. Apenas Batch descartavel. */
(
    local root = pathConfig.normalizePath (pathConfig.appendPath (getFilenamePath (getSourceFileName())) @"..\..")
    fileIn (pathConfig.appendPath root @"Contents\scripts\startup\ameno_bootstrap.ms") quiet:true
    resetMaxFile #noPrompt
    fn check condition label =
    (
        if not condition do throw ("[AMENO_TEST][FAIL] " + label)
        format "[AMENO_TEST][PASS] %\n" label
    )
    local win = ::AmenoCotasWindow.show()
    check (win != undefined) "janela unificada com recursos compartilhados"
    local combo = ::AmenoCotasCriarTab.findControl "cbEstiloAtivo"
    combo.ApplyTemplate()
    check (combo.Template.FindName "ContentSite" combo != undefined) "ComboBox Criar usa template escuro"
    check (::AmenoCotasCriarTab.findControl "chkTextFollowsLine" != undefined) "opcao de orientacao na criacao"
    local orientation = ::AmenoCotasCriarTab.findControl "chkTextFollowsLine"
    ::AmenoDimensionGraphics.textFollowsLine = false
    ::AmenoCotasCriarTab.syncFromServices()
    check (orientation.IsChecked == false) "checkbox sincroniza false usando Nullable Boolean"
    ::AmenoDimensionGraphics.textFollowsLine = true
    ::AmenoCotasCriarTab.syncFromServices()
    check (orientation.IsChecked == true) "checkbox sincroniza true usando Nullable Boolean"
    ::AmenoCotasWindow.setActiveSection 2
    check (::AmenoCotasEstilosTab.btnApplyAll != undefined) "botao atualizar todas presente"

    ::AmenoDimensionGraphics.textFollowsLine = true
    local v = ::AmenoDimensionGraphics.createDimension [0,0,0] [0,100,0] [30,0,0] dimensionMode:#vertical
    local h = ::AmenoDimensionGraphics.createDimension [0,0,0] [100,0,0] [0,30,0] dimensionMode:#horizontal
    check ((abs v.textNode.transform.row1.y) > 0.99) "texto vertical acompanha linha"
    check ((abs h.textNode.transform.row1.x) > 0.99) "texto horizontal permanece horizontal"
    ::AmenoDimensionGraphics.textFollowsLine = false
    local fixedText = ::AmenoDimensionGraphics.createDimension [0,0,0] [0,100,0] [-30,0,0] dimensionMode:#vertical
    check ((abs fixedText.textNode.transform.row1.x) > 0.99) "opcao desmarcada mantem texto horizontal"
    ::AmenoDimensionGraphics.rebuildDimension v.controller
    local rebuilt = undefined
    for n in ::AmenoDimensionGraphics.findNodesForDimension v.dimensionId where (::AmenoDimensionGraphics.readTextProperty n "Ameno.GraphicRole") == "label" do rebuilt = n
    check (rebuilt != undefined and (abs rebuilt.transform.row1.y) > 0.99) "rebuild preserva orientacao da cota"
    ::AmenoAnchorService.syncAll()
    check ((abs rebuilt.transform.row1.y) > 0.99) "sincronizacao preserva orientacao"

    local tab = ::AmenoCotasEstilosTab
    local draft = tab.currentDraft
    local idBefore = draft.styleRecord.styleId
    local countBefore = (::AmenoStyleService.listStyles()).count
    tab.onSaveStyle nameValue:"Estilo de teste nomeado"
    check ((::AmenoStyleService.getStyle idBefore).name == "Estilo de teste nomeado") "salvar usa nome informado"
    check ((::AmenoStyleService.listStyles()).count == countBefore) "salvar nao duplica estilo"
    tab.onSaveStyle nameValue:"  "
    check ((::AmenoStyleService.getStyle idBefore).name == "Estilo de teste nomeado") "nome vazio nao altera estilo"
    clearSelection()
    draft.styleRecord.fontSize = 88.0
    draft.markDirty()
    local changed = tab.onApplyToSelection allDimensions:true
    check (changed == 3) "aplica todas sem selecao"
    check (selection.count == 0) "aplicar todas preserva selecao"
    max undo
    max redo
    check ((::AmenoDimensionGraphics.findControllers()).count == 3) "Undo Redo mantem cotas"
    tab.setDirtyDecision #discard
    ::AmenoCotasWindow.close()
    format "[AMENO_TEST][PASS] Feedback visual E13 concluido.\n"
)
