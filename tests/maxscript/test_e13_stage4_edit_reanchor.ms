/*
    E13 etapa 4 - editar, validar e reancorar.
    A suite usa uma cena descartavel e chama somente contratos deterministas;
    o pickPoint interativo continua reservado ao gate manual.
*/

(
    local testFile      = getSourceFileName()
    local testPath      = getFilenamePath testFile
    local worktreeRoot  = pathConfig.normalizePath (pathConfig.appendPath testPath @"..\..")
    local bootstrapPath = pathConfig.normalizePath (pathConfig.appendPath worktreeRoot @"Contents\scripts\startup\ameno_bootstrap.ms")

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

    fn nearValue a b tolerance:0.001 =
    (
        a != undefined and b != undefined and (abs (a - b)) <= tolerance
    )

    fn nearPoint a b tolerance:0.001 =
    (
        a != undefined and b != undefined and (length (a - b)) <= tolerance
    )

    fn roleNode dimensionId roleName =
    (
        if ::AmenoDimensionGraphics == undefined then return undefined
        for nodeValue in (::AmenoDimensionGraphics.findNodesForDimension dimensionId) where isValidNode nodeValue do
        (
            if (::AmenoDimensionGraphics.readTextProperty nodeValue "Ameno.GraphicRole") == roleName do
                return nodeValue
        )
        undefined
    )

    fn setMode tabValue modeName =
    (
        local nullTrue = dotNetObject "System.Nullable`1[System.Boolean]" true
        case modeName of
        (
            #rounded: (tabValue.findControl "rbModeRounded").IsChecked = nullTrue
            #manualNumeric: (tabValue.findControl "rbModeNumeric").IsChecked = nullTrue
            #manualText: (tabValue.findControl "rbModeText").IsChecked = nullTrue
            default: tabValue.findControl "rbModeMeasured".IsChecked = nullTrue
        )
        true
    )

    AmenoApp.prepareScene()

    local tab = ::AmenoCotasEditarTab
    local built = try (tab.build()) catch (undefined)
    check "aba Editar construida" (built != undefined and tab.hostControl != undefined)
    local cachedBuild = try (tab.build()) catch (undefined)
    check "build da aba Editar reutiliza o host" (cachedBuild == built)

    local shown = try (::AmenoCotasWindow.show()) catch (undefined)
    try (::AmenoCotasWindow.setActiveSection 3) catch ()
    check "janela unificada abriu a aba Editar" (shown != undefined and ::AmenoCotasWindow.isOpen() and ::AmenoCotasWindow.activeSection == 3)
    check "callbacks de selecao e Undo/Redo da aba Editar foram registrados" (tab.callbacksRegistered == true)

    local editCallbackStream = stringStream ""
    callbacks.show id:#amenoCotasEditSync to:editCallbackStream
    check "callback proprio da aba Editar possui script" ((editCallbackStream as string) != "")

    local sourceA = undefined
    local sourceB = undefined
    local dim = undefined
    local dim2 = undefined
    with undo off
    (
        sourceA = box name:"E13_STAGE4_SOURCE_A" pos:[0, 0, 0] width:40 length:40 height:40
        sourceB = box name:"E13_STAGE4_SOURCE_B" pos:[180, 0, 0] width:40 length:40 height:40
        dim = AmenoDimensionGraphics.createDimension [0, 0, 0] [180, 0, 0] [90, 40, 0] role:"test" outputUnit:#centimeters \
            nodeA:sourceA nodeB:sourceB useUndo:false
        dim2 = AmenoDimensionGraphics.createDimension [0, 100, 0] [180, 100, 0] [90, 140, 0] role:"test" outputUnit:#centimeters useUndo:false
    )

    select dim.lineNode
    tab.refresh()
    local txtRounding = tab.findControl "txtRounding"
    local txtManualVal = tab.findControl "txtManualVal"
    local txtManualText = tab.findControl "txtManualText"
    local txtReason = tab.findControl "txtReason"
    local cbStyle = tab.findControl "cbEstilo"
    local editStatus = tab.findControl "txtEditStatus"
    local panelEmpty = tab.findControl "panelEmpty"
    local rbMeasured = tab.findControl "rbModeMeasured"
    local rbRounded = tab.findControl "rbModeRounded"

    check "selecionar cota atualiza o controlador da aba Editar" (tab.currentCtrl == dim.controller)

    local commaNumber = tab.parsePositiveNumber "2,5" "Teste"
    local pointNumber = tab.parsePositiveNumber "2.5" "Teste"
    local lettersNumber = tab.parsePositiveNumber "abc" "Teste"
    local exponentNumber = tab.parsePositiveNumber "1e3" "Teste"
    local zeroNumber = tab.parsePositiveNumber "0" "Teste"
    local negativeNumber = tab.parsePositiveNumber "-1" "Teste"
    check "parser aceita virgula decimal" (commaNumber[1] and nearValue commaNumber[2] 2.5)
    check "parser aceita ponto decimal" (pointNumber[1] and nearValue pointNumber[2] 2.5)
    check "parser rejeita letras" (not lettersNumber[1])
    check "parser rejeita notacao com letras" (not exponentNumber[1])
    check "parser rejeita zero" (not zeroNumber[1])
    check "parser rejeita negativo" (not negativeNumber[1])

    local measuredRequest = tab.validateChangeRequest #measured "abc" "abc" "" ""
    local roundedRequest = tab.validateChangeRequest #rounded "2,5" "abc" "" "motivo"
    local numericRequest = tab.validateChangeRequest #manualNumeric "abc" "1.25" "" "motivo"
    local textRequest = tab.validateChangeRequest #manualText "abc" "abc" " Texto especial " "motivo"
    local emptyTextRequest = tab.validateChangeRequest #manualText "" "" "   " "motivo"
    check "modo Medido ignora campos que nao pertencem ao modo" (measuredRequest.valid and measuredRequest.manualValueMm == undefined and measuredRequest.incrementMm == undefined)
    check "modo Arredondado converte cm para mm" (roundedRequest.valid and nearValue roundedRequest.incrementMm 25.0)
    check "modo Numerico converte m para mm" (numericRequest.valid and nearValue numericRequest.manualValueMm 1250.0)
    check "modo Texto aceita texto e ignora numeros invalidos" (textRequest.valid and textRequest.manualText == "Texto especial")
    check "modo Texto vazio e rejeitado" (not emptyTextRequest.valid)

    local baseAudit = AmenoDimensionGraphics.getDimensionAudit dim.controller
    local baseRecord = AmenoDimensionCA.readCA dim.controller

    -- Entrada invalida nao pode aplicar defaults nem criar Undo vazio.
    with undo off
    (
        setMode tab #rounded
        txtRounding.Text = "abc"
        txtManualVal.Text = "1.50"
        txtReason.Text = "nao aplicar"
    )
    local invalidApply = tab.applyChanges()
    local invalidRecord = AmenoDimensionCA.readCA dim.controller
    check "aplicar entrada invalida falha" (invalidApply == false)
    check "entrada invalida nao altera CA nem modo" (invalidRecord.displayMode == baseRecord.displayMode and nearValue invalidRecord.roundingIncrementMm baseRecord.roundingIncrementMm and editStatus != undefined and matchPattern editStatus.Text pattern:"*numero decimal*")

    local undoSentinel = undefined
    with undo off undoSentinel = point name:"E13_STAGE4_UNDO_SENTINEL" pos:[0, 0, 0]
    undo "E13 stage4 sentinel" on (undoSentinel.pos = [25, 0, 0])
    local invalidAfterSentinel = tab.applyChanges()
    max undo
    check "entrada invalida nao insere Undo vazio" (invalidAfterSentinel == false and isValidNode undoSentinel and nearValue undoSentinel.pos.x 0.0)

    -- Arredondado usa somente o campo do modo selecionado.
    setMode tab #rounded
    txtRounding.Text = "2,5"
    txtManualVal.Text = "letras ignoradas"
    txtReason.Text = "Arredondamento de obra"
    local roundedApply = tab.applyChanges()
    local roundedRecord = AmenoDimensionCA.readCA dim.controller
    check "aplicar Arredondado valida e persiste mm" (roundedApply and roundedRecord.displayMode == "rounded" and nearValue roundedRecord.roundingIncrementMm 25.0 and roundedRecord.outputUnit == baseRecord.outputUnit and nearValue roundedRecord.lastMeasuredMm baseAudit.measuredMillimeters)
    max undo
    local roundedUndoRecord = AmenoDimensionCA.readCA dim.controller
    check "Undo da edicao restaura modo anterior" (roundedUndoRecord.displayMode == "measured" and rbMeasured.IsChecked == true)
    max redo
    local roundedRedoRecord = AmenoDimensionCA.readCA dim.controller
    check "Redo da edicao restaura modo e callback atualiza UI" (roundedRedoRecord.displayMode == "rounded" and rbRounded.IsChecked == true)

    -- Numerico e Texto validam apenas o campo ativo.
    setMode tab #manualNumeric
    txtRounding.Text = "nao usado"
    txtManualVal.Text = "1,25"
    txtManualText.Text = "nao usado"
    txtReason.Text = "Valor executivo"
    local numericApply = tab.applyChanges()
    local numericRecord = AmenoDimensionCA.readCA dim.controller
    check "aplicar Numerico persiste 1,25 m como 1250 mm" (numericApply and numericRecord.displayMode == "manualNumeric" and nearValue numericRecord.manualValueMm 1250.0 and numericRecord.manualReason == "Valor executivo")

    setMode tab #manualText
    txtRounding.Text = "nao usado"
    txtManualVal.Text = "nao usado"
    txtManualText.Text = " Texto especial "
    txtReason.Text = "Nota de projeto"
    local textApply = tab.applyChanges()
    local textRecord = AmenoDimensionCA.readCA dim.controller
    check "aplicar Texto persiste texto e motivo" (textApply and textRecord.displayMode == "manualText" and textRecord.manualText == "Texto especial" and textRecord.manualReason == "Nota de projeto")

    local restored = tab.restoreMeasured()
    local restoredRecord = AmenoDimensionCA.readCA dim.controller
    local restoredAudit = AmenoDimensionGraphics.getDimensionAudit dim.controller
    check "Restaurar Medido remove override e motivo" (restored and restoredRecord.displayMode == "measured" and restoredRecord.manualReason == "" and nearValue restoredAudit.measuredMillimeters baseAudit.measuredMillimeters and nearValue restoredAudit.displayMillimeters baseAudit.measuredMillimeters)

    -- Aplicacao de estilo continua usando um Undo atomico.
    local technicalIndex = 0
    local availableStyles = AmenoStyleService.listStyles()
    for i = 1 to availableStyles.count do if availableStyles[i].styleId == "technical" do technicalIndex = i
    if technicalIndex > 0 and cbStyle != undefined do cbStyle.SelectedIndex = technicalIndex - 1
    local styleApplied = if technicalIndex > 0 then tab.applyStyle() else false
    local styledRecord = AmenoDimensionCA.readCA dim.controller
    check "aplicar estilo na aba Editar atualiza a cota" (styleApplied and styledRecord.styleId == "technical")
    max undo
    local styleUndoRecord = AmenoDimensionCA.readCA dim.controller
    check "Undo do estilo retorna ao estilo anterior" (styleUndoRecord.styleId == "default")
    max redo
    local styleRedoRecord = AmenoDimensionCA.readCA dim.controller
    check "Redo do estilo restaura a aplicacao" (styleRedoRecord.styleId == "technical")

    -- Selecoes multiplas, selecao sem cota e controlador invalido.
    local currentDimLine = roleNode dim.dimensionId "lines"
    select #(currentDimLine, dim2.textNode)
    tab.refresh()
    check "selecao multipla encontra uma cota sem duplicar" (tab.currentCtrl != undefined and isValidNode tab.currentCtrl and AmenoDimensionCA.hasCA tab.currentCtrl)
    select sourceA
    tab.refresh()
    check "selecao sem cota mostra estado vazio" (tab.currentCtrl == undefined and panelEmpty.Visibility.ToString() == "Visible")
    local invalidControllerApply = tab.applyChangeToController sourceA #rounded "2" "1" "" ""
    check "controlador invalido e rejeitado sem excecao" (invalidControllerApply == false)
    select dim.controller
    tab.refresh()

    -- Reancoragem deterministica em vertices da geometria.
    local targetA = undefined
    local targetB = undefined
    with undo off
    (
        targetA = box name:"E13_STAGE4_TARGET_A" pos:[40, 260, 0] width:30 length:30 height:30
        convertToPoly targetA
        targetB = box name:"E13_STAGE4_TARGET_B" pos:[240, 260, 0] width:30 length:30 height:30
        convertToPoly targetB
    )
    local targetVertexId = 1
    local targetWorldPoint = AmenoDimensionCA.resolveVertexWorld targetA targetVertexId
    local targetBPoint = AmenoDimensionCA.resolveVertexWorld targetB targetVertexId
    local beforeAnchorRecord = AmenoDimensionCA.readCA dim.controller
    local canceledTarget = tab.applyReanchorTarget dim.controller #pointA undefined targetWorldPoint vertexId:targetVertexId
    local afterCancelRecord = AmenoDimensionCA.readCA dim.controller
    check "cancelar reancoragem nao converte para mundial" (canceledTarget == false and afterCancelRecord.nodeA == beforeAnchorRecord.nodeA and afterCancelRecord.anchorType == beforeAnchorRecord.anchorType)

    local technicalLine = roleNode dim.dimensionId "lines"
    local technicalTarget = tab.applyReanchorTarget dim.controller #pointA technicalLine targetWorldPoint vertexId:targetVertexId
    local afterTechnicalRecord = AmenoDimensionCA.readCA dim.controller
    check "reancoragem rejeita linha tecnica Ameno" (technicalTarget == false and afterTechnicalRecord.nodeA == beforeAnchorRecord.nodeA)

    local badVertex = tab.applyReanchorTarget dim.controller #pointA targetA targetWorldPoint vertexId:999999
    local afterBadVertexRecord = AmenoDimensionCA.readCA dim.controller
    check "reancoragem rejeita vertexId inexistente" (badVertex == false and afterBadVertexRecord.nodeA == beforeAnchorRecord.nodeA)

    local reanchoredA = tab.applyReanchorTarget dim.controller #pointA targetA targetWorldPoint vertexId:targetVertexId
    local reanchoredARecord = AmenoDimensionCA.readCA dim.controller
    check "reancorar A grava no e vertexId" (reanchoredA and reanchoredARecord.nodeA == targetA and reanchoredARecord.anchorVertexIdA == targetVertexId and nearPoint reanchoredARecord.pointA targetWorldPoint)
    max undo
    local reanchorUndoRecord = AmenoDimensionCA.readCA dim.controller
    check "Undo da reancoragem A restaura referencia anterior" (reanchorUndoRecord.nodeA == beforeAnchorRecord.nodeA and reanchorUndoRecord.anchorVertexIdA == beforeAnchorRecord.anchorVertexIdA)
    max redo
    local reanchorRedoRecord = AmenoDimensionCA.readCA dim.controller
    check "Redo da reancoragem A restaura vertexId" (reanchorRedoRecord.nodeA == targetA and reanchorRedoRecord.anchorVertexIdA == targetVertexId)

    local reanchoredB = tab.applyReanchorTarget dim.controller #pointB targetB targetBPoint vertexId:targetVertexId
    local reanchoredBRecord = AmenoDimensionCA.readCA dim.controller
    check "reancorar B grava no e vertexId" (reanchoredB and reanchoredBRecord.nodeB == targetB and reanchoredBRecord.anchorVertexIdB == targetVertexId and nearPoint reanchoredBRecord.pointB targetBPoint)

    local targetLocalPoint = try (polyOp.getVert targetA targetVertexId) catch (undefined)
    if targetLocalPoint != undefined do
    (
        with undo off
        (
            polyOp.setVert targetA targetVertexId (targetLocalPoint + [35, 10, 0])
            update targetA
        )
    )
    local movedTargetPoint = AmenoDimensionCA.resolveVertexWorld targetA targetVertexId
    AmenoAnchorService.syncDimension dim.controller
    local movedRecord = AmenoDimensionCA.readCA dim.controller
    check "cota acompanha movimento do vertexId reancorado" (movedRecord.anchorVertexIdA == targetVertexId and nearPoint movedRecord.pointA movedTargetPoint)

    undo "E13 stage4 delete target" on (delete targetA)
    AmenoAnchorService.syncDimension dim.controller
    local orphanRecord = AmenoDimensionCA.readCA dim.controller
    check "excluir geometria marca cota como orfa" (orphanRecord.isOrphan == true)
    max undo
    AmenoAnchorService.syncDimension dim.controller
    local restoredAnchorRecord = AmenoDimensionCA.readCA dim.controller
    check "Undo da exclusao restaura a ancora sem perder vertexId" (restoredAnchorRecord.isOrphan == false and restoredAnchorRecord.nodeA != undefined and isValidNode restoredAnchorRecord.nodeA and restoredAnchorRecord.anchorVertexIdA == targetVertexId)

    select dim.controller
    tab.refresh()
    local selectedAnchors = tab.selectAnchors()
    check "Selecionar Nos seleciona as duas geometrias ancora" (selectedAnchors and selection.count == 2)
    select dim.controller
    tab.refresh()

    callbacks.addScript #selectionSetChanged "format \"E13 stage4 callback sentinel\\n\"" id:#e13Stage4CallbackSentinel
    try (::AmenoCotasWindow.close()) catch ()
    local afterCloseEditStream = stringStream ""
    local afterCloseSentinelStream = stringStream ""
    callbacks.show id:#amenoCotasEditSync to:afterCloseEditStream
    callbacks.show id:#e13Stage4CallbackSentinel to:afterCloseSentinelStream
    check "fechamento remove callback da aba sem remover sentinela" ((afterCloseEditStream as string) == "" and (afterCloseSentinelStream as string) != "")
    callbacks.removeScripts id:#e13Stage4CallbackSentinel

    try (resetMaxFile #noPrompt) catch ()

    format "\n[AMENO_TEST] Resultado etapa 4: % passou(aram), % falhou(aram)\n" passed failed
    if failed == 0 then
        format "[AMENO_TEST][PASS] E13 etapa 4 passou.\n"
    else
    (
        format "[AMENO_TEST][FAIL] Falhas etapa 4: %\n" (errors as string)
        throw ("E13 etapa 4 falhou: " + (failed as string))
    )
)
