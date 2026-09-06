/*
    E13 etapa 3 - estilos, navegacao e ciclo de cena.
    A suite usa somente cenas descartaveis e overrides de decisao para
    exercitar Save/Discard/Cancel sem abrir dialogs modais no Batch.
*/

(
    local testFile      = getSourceFileName()
    local testPath      = getFilenamePath testFile
    local worktreeRoot  = pathConfig.normalizePath (pathConfig.appendPath testPath @"..\..")
    local bootstrapPath = pathConfig.normalizePath (pathConfig.appendPath worktreeRoot @"Contents\scripts\startup\ameno_bootstrap.ms")
    local localAppData = (dotNetClass "System.Environment").GetEnvironmentVariable "LOCALAPPDATA"
    local globalStylesPath = pathConfig.normalizePath (pathConfig.appendPath localAppData @"AmenoTools\Profiles\styles.library")
    deleteFile globalStylesPath
    deleteFile (globalStylesPath + ".bak")
    deleteFile (globalStylesPath + ".tmp")

    resetMaxFile #noPrompt
    if doesFileExist bootstrapPath then
        fileIn bootstrapPath quiet:true
    else
        throw ("bootstrap nao encontrado: " + bootstrapPath)

    local passed = 0
    local failed = 0
    local errors = #()

    fn check label conditionValue =
    (
        if conditionValue == true then
        (
            passed += 1
            format "[AMENO_TEST][PASS] %\n" label
        )
        else
        (
            failed += 1
            append errors label
            format "[AMENO_TEST][FAIL] %\n" label
        )
    )

    fn styleIndex styleId =
    (
        local stylesList = ::AmenoStyleService.listStyles()
        for i = 1 to stylesList.count do
            if stylesList[i].styleId == styleId do return i
        0
    )

    local tabControl = try (::AmenoCotasEstilosTab.build()) catch (undefined)
    check "tab Estilos construida e host inicializado" (tabControl != undefined and ::AmenoCotasEstilosTab.currentDraft != undefined)

    local cachedHost = ::AmenoCotasEstilosTab.build()
    check "build reutiliza o UserControl e nao cria uma segunda visita" (cachedHost == tabControl)

    local shown = try (::AmenoCotasWindow.show()) catch (undefined)
    try (::AmenoCotasWindow.setActiveSection 2) catch ()
    check "janela unificada abriu a aba Estilos" (shown != undefined and ::AmenoCotasWindow.isOpen() and ::AmenoCotasWindow.activeSection == 2)

    -- Alterar -> outra aba -> voltar: o mesmo draft e o mesmo host devem sobreviver.
    local originalSize = ::AmenoStyleService.getStyle "default"
    originalSize = originalSize.fontSize
    ::AmenoCotasEstilosTab.onFieldChanged #fontSize 321.0
    local draftBeforeNavigation = ::AmenoCotasEstilosTab.currentDraft
    check "edicao local marca o draft como dirty" (draftBeforeNavigation != undefined and draftBeforeNavigation.isDirty and draftBeforeNavigation.styleRecord.fontSize == 321.0)
    ::AmenoCotasWindow.setActiveSection 1
    ::AmenoCotasWindow.setActiveSection 2
    check "troca de aba preserva valores e dirty" (::AmenoCotasEstilosTab.currentDraft != undefined and ::AmenoCotasEstilosTab.currentDraft.styleRecord.fontSize == 321.0 and ::AmenoCotasEstilosTab.currentDraft.isDirty)
    check "refresh global nao substitui o draft editado" ((::AmenoRefreshMainPanel(); ::AmenoCotasEstilosTab.currentDraft.styleRecord.fontSize == 321.0 and ::AmenoCotasEstilosTab.currentDraft.isDirty))

    -- Troca explicita de estilo: Cancel conserva, Discard troca sem persistir.
    ::AmenoCotasEstilosTab.setDirtyDecision #cancel
    local canceledSwitch = ::AmenoCotasEstilosTab.requestStyleSwitch "editorial"
    check "Cancel na troca de estilo preserva o draft" (not canceledSwitch and ::AmenoCotasEstilosTab.currentDraft.sourceStyleId == "default" and ::AmenoCotasEstilosTab.currentDraft.styleRecord.fontSize == 321.0 and ::AmenoCotasEstilosTab.currentDraft.isDirty and ::AmenoCotasEstilosTab.cbStyleSelect.SelectedIndex == (styleIndex "default") - 1)

    ::AmenoCotasEstilosTab.setDirtyDecision #discard
    local discardedSwitch = ::AmenoCotasEstilosTab.requestStyleSwitch "editorial"
    check "Discard na troca de estilo descarta somente o draft" (discardedSwitch and ::AmenoCotasEstilosTab.currentDraft.sourceStyleId == "editorial" and not ::AmenoCotasEstilosTab.currentDraft.isDirty and (::AmenoStyleService.getStyle "default").fontSize == originalSize)

    -- Save na troca explicita persiste o draft antes de abrir o novo estilo.
    ::AmenoCotasEstilosTab.requestStyleSwitch "default"
    ::AmenoCotasEstilosTab.onFieldChanged #fontSize 333.0
    ::AmenoCotasEstilosTab.setDirtyDecision #save
    local savedSwitch = ::AmenoCotasEstilosTab.requestStyleSwitch "editorial"
    check "Save na troca de estilo persiste antes da troca" (savedSwitch and (::AmenoStyleService.getStyle "default").fontSize == 333.0 and ::AmenoCotasEstilosTab.currentDraft.sourceStyleId == "editorial")

    -- Preset e duplicacao continuam usando o modelo transacional.
    ::AmenoCotasEstilosTab.requestStyleSwitch "default"
    local presetResult = ::AmenoCotasEstilosTab.onPresetClick "technical"
    check "preset cria draft dirty sem alterar o registro persistido" (presetResult and ::AmenoCotasEstilosTab.currentDraft.isDirty and ::AmenoCotasEstilosTab.currentDraft.styleRecord.terminalType == #arrowClosed and (::AmenoStyleService.getStyle "default").terminalType == #tick)
    ::AmenoCotasEstilosTab.setDirtyDecision #cancel
    local presetCancel = ::AmenoCotasEstilosTab.requestStyleSwitch "default"
    check "Cancel apos preset preserva o draft do preset" (not presetCancel and ::AmenoCotasEstilosTab.currentDraft.sourceStyleId == "technical" and ::AmenoCotasEstilosTab.currentDraft.isDirty)
    ::AmenoCotasEstilosTab.setDirtyDecision #discard
    ::AmenoCotasEstilosTab.requestStyleSwitch "default"
    ::AmenoCotasEstilosTab.onFieldChanged #lineThickness 2.7
    local duplicate = ::AmenoCotasEstilosTab.onDuplicateStyle()
    check "duplicar salva como novo e limpa o draft ativo" (duplicate != undefined and duplicate.styleId != "default" and ::AmenoCotasEstilosTab.currentDraft.sourceStyleId == duplicate.styleId and not ::AmenoCotasEstilosTab.currentDraft.isDirty)

    -- Fechamento com draft dirty: Cancel mantem a janela; Discard fecha.
    ::AmenoCotasEstilosTab.requestStyleSwitch "default"
    ::AmenoCotasEstilosTab.onFieldChanged #fontSize 444.0
    ::AmenoCotasEstilosTab.setDirtyDecision #cancel
    local canceledClose = ::AmenoCotasWindow.close()
    check "Cancel no fechamento mantem janela e trabalho" (not canceledClose and ::AmenoCotasWindow.isOpen() and ::AmenoCotasEstilosTab.currentDraft.isDirty and ::AmenoCotasEstilosTab.currentDraft.styleRecord.fontSize == 444.0)
    callbacks.addScript #selectionSetChanged "format \"E13 stage3 callback sentinel\\n\"" id:#e13Stage3CallbackSentinel
    ::AmenoCotasEstilosTab.setDirtyDecision #discard
    local discardedClose = ::AmenoCotasWindow.close()
    check "Discard no fechamento fecha e limpa o draft" (discardedClose and not ::AmenoCotasWindow.isOpen() and ::AmenoCotasEstilosTab.currentDraft == undefined)
    local styleCallbackStream = stringStream ""
    local sentinelCallbackStream = stringStream ""
    callbacks.show id:#amenoCotasStyleSelection to:styleCallbackStream
    callbacks.show id:#e13Stage3CallbackSentinel to:sentinelCallbackStream
    check "fechamento remove somente o callback proprio da aba" ((styleCallbackStream as string) == "" and (sentinelCallbackStream as string) != "")
    callbacks.removeScripts id:#e13Stage3CallbackSentinel

    -- Reabrir parte do estado persistido e nao do ultimo rascunho.
    ::AmenoCotasWindow.showTab "estilos"
    check "reabertura cria draft limpo a partir do estilo persistido" (::AmenoCotasWindow.isOpen() and ::AmenoCotasEstilosTab.currentDraft != undefined and not ::AmenoCotasEstilosTab.currentDraft.isDirty and ::AmenoCotasEstilosTab.currentDraft.styleRecord.fontSize == 333.0)
    ::AmenoCotasEstilosTab.onFieldChanged #fontSize 456.0
    ::AmenoCotasEstilosTab.setDirtyDecision #save
    local savedClose = ::AmenoCotasWindow.close()
    ::AmenoCotasWindow.showTab "estilos"
    check "Save no fechamento persiste e a reabertura recarrega o valor" (savedClose and (::AmenoStyleService.getStyle "default").fontSize == 456.0 and ::AmenoCotasEstilosTab.currentDraft.styleRecord.fontSize == 456.0 and not ::AmenoCotasEstilosTab.currentDraft.isDirty)

    -- Salvar uma cena e reabri-la deve invalidar o draft da cena anterior.
    ::AmenoCotasEstilosTab.onFieldChanged #fontSize 987.0
    local oldSceneDraft = ::AmenoCotasEstilosTab.currentDraft
    local sceneFile = pathConfig.appendPath (getDir #temp) ("ameno_e13_stage3_" + (timestamp() as string) + ".max")
    deleteFile sceneFile
    local sceneSaved = false
    local sceneLoaded = false
    try
    (
        saveMaxFile sceneFile clearNeedSaveFlag:true quiet:true
        sceneSaved = true
        loadMaxFile sceneFile quiet:true
        sceneLoaded = true
    )
    catch
    (
        format "[AMENO_TEST][DETAIL] ciclo save/load: %\n" (getCurrentException() as string)
    )
    try (deleteFile sceneFile) catch ()
    if ::AmenoCotasEstilosTab.currentDraft != undefined do
        format "[AMENO_TEST][DETAIL] apos load: source=% font=% dirty=% generation=%\n" \
            ::AmenoCotasEstilosTab.currentDraft.sourceStyleId \
            ::AmenoCotasEstilosTab.currentDraft.styleRecord.fontSize \
            ::AmenoCotasEstilosTab.currentDraft.isDirty \
            ::AmenoCotasEstilosTab.sceneGeneration
    check "save/load de cena executado no Batch" (sceneSaved and sceneLoaded)
    check "reset de cena invalida o draft antigo e carrega o novo estilo" (::AmenoCotasEstilosTab.currentDraft != undefined and ::AmenoCotasEstilosTab.currentDraft != oldSceneDraft and not ::AmenoCotasEstilosTab.currentDraft.isDirty and ::AmenoCotasEstilosTab.currentDraft.styleRecord.fontSize == 456.0)
    check "reset de cena nao reaplica alteracao nao salva" (::AmenoCotasEstilosTab.currentDraft.styleRecord.fontSize != 987.0)

    -- Estilo em uso nao pode ser excluido silenciosamente e preserva o registro.
    local inUseRecord = ::AmenoStyleService.saveAsNewStyle "E13 Stage3 In Use" (::AmenoStyleService.getStyle "default")
    local inUseDim = try (::AmenoDimensionGraphics.createDimension [0,0,0] [1000,0,0] [500,200,0] role:"test" styleId:inUseRecord.styleId) catch (undefined)
    ::AmenoCotasEstilosTab.requestStyleSwitch inUseRecord.styleId
    local deleteInUse = ::AmenoCotasEstilosTab.onDeleteStyle()
    check "excluir estilo em uso e bloqueado com feedback" (not deleteInUse and (::AmenoStyleService.getStyle inUseRecord.styleId) != undefined and matchPattern ::AmenoCotasEstilosTab.txtPreviewStatus.Text pattern:"*estilo em uso*")

    -- Aplicar as selecionadas continua atomico e com Undo/Redo.
    local applyDim = try (::AmenoDimensionGraphics.createDimension [0,500,0] [1000,500,0] [500,700,0] role:"test" styleId:"default") catch (undefined)
    clearSelection()
    if applyDim != undefined and isValidNode applyDim.controller do select applyDim.controller
    ::AmenoCotasEstilosTab.requestStyleSwitch "technical"
    ::AmenoCotasEstilosTab.onFieldChanged #lineThickness 4.6
    local appliedCount = ::AmenoCotasEstilosTab.onApplyToSelection()
    local appliedCA = if applyDim != undefined then ::AmenoDimensionCA.readCA applyDim.controller else undefined
    check "aplicar draft a selecao atualiza exatamente uma cota" (appliedCount == 1 and appliedCA != undefined and appliedCA.styleId == "technical")
    max undo
    local undoCA = if applyDim != undefined and isValidNode applyDim.controller then ::AmenoDimensionCA.readCA applyDim.controller else undefined
    check "Undo reverte aplicacao do estilo" (undoCA != undefined and undoCA.styleId == "default")
    max redo
    local redoCA = if applyDim != undefined and isValidNode applyDim.controller then ::AmenoDimensionCA.readCA applyDim.controller else undefined
    check "Redo restaura aplicacao do estilo" (redoCA != undefined and redoCA.styleId == "technical")

    try
    (
        if inUseDim != undefined and isValidNode inUseDim.controller do
            ::AmenoDimensionGraphics.removeDimension inUseDim.dimensionId
        if applyDim != undefined and isValidNode applyDim.controller do
            ::AmenoDimensionGraphics.removeDimension applyDim.dimensionId
    )
    catch ()
    ::AmenoCotasEstilosTab.setDirtyDecision #discard
    try (::AmenoCotasWindow.close()) catch ()

    -- Os estilos globais são deliberadamente persistentes em uso real, mas
    -- esta suíte Batch deve deixar o perfil isolado limpo para a próxima.
    deleteFile globalStylesPath
    deleteFile (globalStylesPath + ".bak")
    deleteFile (globalStylesPath + ".tmp")

    format "\n[AMENO_TEST] Resultado etapa 3: % passou(aram), % falhou(aram)\n" passed failed
    if failed == 0 then
        format "[AMENO_TEST][PASS] E13 etapa 3 passou.\n"
    else
    (
        format "[AMENO_TEST][FAIL] Falhas etapa 3: %\n" (errors as string)
        throw ("E13 etapa 3 falhou: " + (failed as string))
    )
)
