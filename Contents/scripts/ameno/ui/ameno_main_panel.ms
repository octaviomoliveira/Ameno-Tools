global AmenoMainPanelRollout
global AmenoEnvRollout
global AmenoDimRollout
global AmenoAuditRollout
global AmenoAnchorRollout
global AmenoRenderRollout
global AmenoRefreshMainPanel
global AmenoShowMainPanel

fn AmenoRefreshMainPanel =
(
    global AmenoApp
    global AmenoVersion
    global AmenoDimensionGraphics
    global AmenoDimensionCA
    global AmenoStyleService

    if AmenoApp == undefined or AmenoMainPanelRollout == undefined or not AmenoMainPanelRollout.open do return ()

    local info = AmenoApp.refreshRenderer()
    local sceneInfo = AmenoApp.refreshScene()

    try
    (
        AmenoMainPanelRollout.lblVersion.text = AmenoVersion.displayName() + " · Max " + (AmenoVersion.targetMax as string)
    )
    catch ()

    if AmenoEnvRollout != undefined and AmenoEnvRollout.open do
    (
        try
        (
            AmenoEnvRollout.lblRenderer.text = info.displayName + " · " + info.statusLabel()
            AmenoEnvRollout.lblRendererClass.text = info.className
            AmenoEnvRollout.lblSceneStatus.text = sceneInfo.statusLabel
            AmenoEnvRollout.lblSceneDetail.text = sceneInfo.detail
            AmenoEnvRollout.btnPrepare.caption = if sceneInfo.status == #ready then "Verificar infraestrutura" else "Preparar esta cena"
        )
        catch ()
    )

    if AmenoDimRollout != undefined and AmenoDimRollout.open do
    (
        try
        (
            AmenoDimRollout.lblDimensions.text = AmenoApp.refreshDimensions()
        )
        catch ()
    )

    if AmenoRenderRollout != undefined and AmenoRenderRollout.open do
    (
        try
        (
            local canRender = (info.family == #corona or info.family == #vray)
            AmenoRenderRollout.btnRenderCotas.enabled = canRender
            AmenoRenderRollout.lblRenderSupport.text = if canRender then
            (
                if info.family == #corona then "Corona pronto · PNG transparente"
                else if info.engine == #gpu then "V-Ray GPU (experimental) · PNG transparente"
                else "V-Ray CPU pronto · PNG transparente"
            )
            else (info.displayName + " sem adapter de render")
            if AmenoRenderRollout.edtOutput.text == "" do AmenoRenderRollout.edtOutput.text = AmenoApp.defaultRenderCotasPath()
        )
        catch ()
    )

    -- E7: Atualiza lista de estilos para o painel de inspeção
    local styleList = #()
    local styleIds = #()
    if ::AmenoStyleService != undefined do
    (
        local allStyles = ::AmenoStyleService.listStyles()
        for s in allStyles do
        (
            append styleList s.name
            append styleIds s.styleId
        )
    )
    if styleList.count == 0 do
    (
        styleList = #("Arquitetônico")
        styleIds = #("default")
    )

    if AmenoAuditRollout != undefined and AmenoAuditRollout.open do
    (
        try
        (
            AmenoAuditRollout.ddlSelStyle.items = styleList
            AmenoAuditRollout.styleIds = styleIds
        )
        catch ()
    )

    -- E6 / E8: Inspeção da cota selecionada
    local ctrl = AmenoApp.getSelectedDimensionController()
    if ctrl != undefined and isValidNode ctrl then
    (
        local audit = AmenoDimensionGraphics.getDimensionAudit ctrl
        if audit != undefined then
        (
            if AmenoAuditRollout != undefined and AmenoAuditRollout.open do
            (
                try
                (
                    AmenoAuditRollout.lblSelName.text = "Cota: " + audit.dimensionId
                    AmenoAuditRollout.lblMeasured.text = "Medido: " + audit.measuredText
                    AmenoAuditRollout.lblDisplay.text = "Exibido: " + audit.displayText
                    AmenoAuditRollout.lblDelta.text = "Delta: " + audit.deltaText + (if audit.isManual then " [MANUAL]" else " [EXATO]")

                    case audit.mode of
                    (
                        #rounded: AmenoAuditRollout.rdoMode.state = 2
                        #manualNumeric: AmenoAuditRollout.rdoMode.state = 3
                        #manualText: AmenoAuditRollout.rdoMode.state = 4
                        default: AmenoAuditRollout.rdoMode.state = 1
                    )

                    AmenoAuditRollout.spnManualVal.value = (audit.displayMillimeters / 1000.0) as float
                    AmenoAuditRollout.edtManualText.text = if audit.mode == #manualText then audit.displayText else ""
                    AmenoAuditRollout.edtReason.text = audit.manualReason

                    local rec = if AmenoDimensionCA != undefined then AmenoDimensionCA.readCA ctrl else undefined
                    local sId = "default"
                    if rec != undefined and rec.styleId != undefined and rec.styleId != "" then sId = rec.styleId
                    else
                    (
                        local p = AmenoDimensionGraphics.readTextProperty ctrl "Ameno.StyleId"
                        if p != undefined and p != "" do sId = p
                    )

                    local sIdx = findItem styleIds sId
                    if sIdx > 0 then AmenoAuditRollout.ddlSelStyle.selection = sIdx
                    else AmenoAuditRollout.ddlSelStyle.selection = 1

                    AmenoAuditRollout.ddlSelStyle.enabled = true
                    AmenoAuditRollout.btnApplySelStyle.enabled = true
                    AmenoAuditRollout.rdoMode.enabled = true
                    AmenoAuditRollout.spnRounding.enabled = (AmenoAuditRollout.rdoMode.state == 2)
                    AmenoAuditRollout.spnManualVal.enabled = (AmenoAuditRollout.rdoMode.state == 3)
                    AmenoAuditRollout.edtManualText.enabled = (AmenoAuditRollout.rdoMode.state == 4)
                    AmenoAuditRollout.edtReason.enabled = true
                    AmenoAuditRollout.btnApplyMode.enabled = true
                    AmenoAuditRollout.btnResetMeasured.enabled = true
                )
                catch ()
            )

            if AmenoAnchorRollout != undefined and AmenoAnchorRollout.open do
            (
                try
                (
                    AmenoAnchorRollout.lblAnchors.text = "Âncoras: " + audit.anchorDesc
                    if audit.isOrphan then
                    (
                        AmenoAnchorRollout.lblOrphanStatus.text = "[ALERTA] " + audit.orphanReason
                    )
                    else
                    (
                        AmenoAnchorRollout.lblOrphanStatus.text = "Status: Âncoras sincronizadas"
                    )

                    AmenoAnchorRollout.btnReanchorA.enabled = true
                    AmenoAnchorRollout.btnReanchorB.enabled = true
                    AmenoAnchorRollout.btnSelectAnchors.enabled = true
                )
                catch ()
            )
        )
    )
    else
    (
        if AmenoAuditRollout != undefined and AmenoAuditRollout.open do
        (
            try
            (
                AmenoAuditRollout.lblSelName.text = "Selecione uma cota na cena para editar."
                AmenoAuditRollout.lblMeasured.text = "Medido: -"
                AmenoAuditRollout.lblDisplay.text = "Exibido: -"
                AmenoAuditRollout.lblDelta.text = "Delta: -"
                AmenoAuditRollout.rdoMode.state = 1
                AmenoAuditRollout.edtManualText.text = ""
                AmenoAuditRollout.edtReason.text = ""

                AmenoAuditRollout.ddlSelStyle.enabled = false
                AmenoAuditRollout.btnApplySelStyle.enabled = false
                AmenoAuditRollout.rdoMode.enabled = false
                AmenoAuditRollout.spnRounding.enabled = false
                AmenoAuditRollout.spnManualVal.enabled = false
                AmenoAuditRollout.edtManualText.enabled = false
                AmenoAuditRollout.edtReason.enabled = false
                AmenoAuditRollout.btnApplyMode.enabled = false
                AmenoAuditRollout.btnResetMeasured.enabled = false
            )
            catch ()
        )

        if AmenoAnchorRollout != undefined and AmenoAnchorRollout.open do
        (
            try
            (
                AmenoAnchorRollout.lblAnchors.text = "Âncoras: -"
                AmenoAnchorRollout.lblOrphanStatus.text = "Status: -"
                AmenoAnchorRollout.btnReanchorA.enabled = false
                AmenoAnchorRollout.btnReanchorB.enabled = false
                AmenoAnchorRollout.btnSelectAnchors.enabled = false
            )
            catch ()
        )
    )
)

rollout AmenoDimRollout "Criação de Cotas" width:344
(
    label lblDimensions "Ameno Dimensions · 0 cota(s) ativa(s)." pos:[14, 10] width:316 height:18 align:#left
    -- E10.1: seletor de modo de cota
    radiobuttons rdoMode "Modo:" pos:[14, 32] labels:#("Alinhada", "Horizontal", "Vertical") default:1 columns:3
    button btnCreate "Criar cota (3 cliques)" pos:[14, 62] width:150 height:26
    button btnRepair "Reparar cotas" pos:[180, 62] width:150 height:26
    button btnCreateTest "Criar cota de teste" pos:[14, 94] width:150 height:24
    button btnClearTests "Limpar de teste" pos:[180, 94] width:150 height:24
    button btnStyleEditor "Editor de Estilos..." pos:[14, 124] width:316 height:24
    label lblTestHint "Preview em tempo real · Esc ou botão direito cancela." pos:[14, 154] width:316 height:18 align:#left

    on rdoMode changed state do
    (
        global AmenoDimensionTool
        if AmenoDimensionTool != undefined do
        (
            case state of
            (
                1: AmenoDimensionTool.activeMode = #aligned
                2: AmenoDimensionTool.activeMode = #horizontal
                3: AmenoDimensionTool.activeMode = #vertical
            )
        )
    )

    on btnCreate pressed do
    (
        global AmenoApp
        global AmenoDimensionTool
        if AmenoApp != undefined do
        (
            try
            (
                local record = AmenoApp.startDimensionTool()
                if record != undefined do select #(record.lineNode, record.textNode)
                if record == undefined and AmenoDimensionTool != undefined and AmenoDimensionTool.lastError != "" do
                (
                    messageBox ("A cota não foi criada. A prévia foi preservada durante a falha.\n\n" + AmenoDimensionTool.lastError) title:"Ameno Dimensions"
                )
                if ::AmenoRefreshMainPanel != undefined do ::AmenoRefreshMainPanel()
            )
            catch
            (
                messageBox ("Não foi possível iniciar a ferramenta de cota:\n" + (getCurrentException() as string)) title:"Ameno Tools"
            )
        )
    )

    on btnRepair pressed do
    (
        global AmenoApp
        if AmenoApp != undefined do
        (
            local repairedCount = AmenoApp.repairDimensions()
            messageBox ("Cotas reparadas nesta cena: " + (repairedCount as string)) title:"Ameno Dimensions"
            if ::AmenoRefreshMainPanel != undefined do ::AmenoRefreshMainPanel()
        )
    )

    on btnCreateTest pressed do
    (
        global AmenoApp
        if AmenoApp != undefined do
        (
            try
            (
                AmenoApp.createTestDimension()
                if ::AmenoRefreshMainPanel != undefined do ::AmenoRefreshMainPanel()
            )
            catch
            (
                messageBox ("Não foi possível criar a cota de teste:\n" + (getCurrentException() as string)) title:"Ameno Dimensions"
            )
        )
    )

    on btnClearTests pressed do
    (
        global AmenoApp
        if AmenoApp != undefined do
        (
            local removedCount = AmenoApp.clearTestDimensions()
            messageBox ("Cotas de teste removidas: " + (removedCount as string)) title:"Ameno Dimensions"
            if ::AmenoRefreshMainPanel != undefined do ::AmenoRefreshMainPanel()
        )
    )

    on btnStyleEditor pressed do
    (
        global AmenoApp
        if AmenoApp != undefined do AmenoApp.openStyleEditor()
    )
)

rollout AmenoAuditRollout "Inspeção e Estilos" width:344
(
    local styleIds = #()

    label lblSelName "Selecione uma cota na cena para editar." pos:[14, 10] width:316 height:18 align:#left
    label lblMeasured "Medido: -" pos:[14, 30] width:150 height:18 align:#left
    label lblDisplay "Exibido: -" pos:[174, 30] width:156 height:18 align:#left
    label lblDelta "Delta: -" pos:[14, 50] width:316 height:18 align:#left

    radiobuttons rdoMode "Modo de Valor:" pos:[14, 72] labels:#("Medido", "Arredondado", "Numérico Manual", "Texto Manual") default:1 columns:2
    spinner spnRounding "Passo arred. (cm):" pos:[14, 114] width:140 height:18 range:[1, 100, 5] type:#integer fieldWidth:45
    spinner spnManualVal "Valor Manual (m):" pos:[164, 114] width:166 height:18 range:[0.001, 10000.0, 1.0] type:#float scale:0.01 fieldWidth:55
    edittext edtManualText "Texto:" pos:[14, 136] width:316 height:18 text:""
    edittext edtReason "Motivo:" pos:[14, 158] width:316 height:18 text:""

    label lblStyle "Estilo:" pos:[14, 184] width:38 height:18
    dropdownList ddlSelStyle "" pos:[56, 180] width:170 height:21
    button btnApplySelStyle "Aplicar Estilo" pos:[234, 180] width:96 height:22

    button btnApplyMode "Aplicar Alteração" pos:[14, 210] width:150 height:24
    button btnResetMeasured "Restaurar Medido" pos:[180, 210] width:150 height:24

    on rdoMode changed state do
    (
        spnRounding.enabled = (state == 2)
        spnManualVal.enabled = (state == 3)
        edtManualText.enabled = (state == 4)
    )

    on btnApplySelStyle pressed do
    (
        global AmenoApp
        if AmenoApp != undefined and ddlSelStyle.selection > 0 and ddlSelStyle.selection <= styleIds.count do
        (
            local targetId = styleIds[ddlSelStyle.selection]
            local ctrl = AmenoApp.getSelectedDimensionController()
            if ctrl != undefined do
            (
                AmenoStyleService.applyStyleToDimension ctrl targetId
                if ::AmenoRefreshMainPanel != undefined do ::AmenoRefreshMainPanel()
            )
        )
    )

    on btnApplyMode pressed do
    (
        global AmenoApp
        if AmenoApp != undefined do
        (
            local ctrl = AmenoApp.getSelectedDimensionController()
            if ctrl != undefined do
            (
                local modeName = case rdoMode.state of
                (
                    2: #rounded
                    3: #manualNumeric
                    4: #manualText
                    default: #measured
                )

                local incMm = (spnRounding.value * 10.0) as float
                local manValMm = (spnManualVal.value * 1000.0) as float
                local manTxt = edtManualText.text
                local reasonTxt = edtReason.text

                try
                (
                    AmenoApp.setDimensionMode ctrl modeName manualValueMm:manValMm manualText:manTxt reason:reasonTxt incrementMm:incMm
                    if ::AmenoRefreshMainPanel != undefined do ::AmenoRefreshMainPanel()
                )
                catch
                (
                    messageBox ("Não foi possível aplicar a alteração de modo:\n" + (getCurrentException() as string)) title:"Ameno Dimensions"
                )
            )
        )
    )

    on btnResetMeasured pressed do
    (
        global AmenoApp
        if AmenoApp != undefined do
        (
            local ctrl = AmenoApp.getSelectedDimensionController()
            if ctrl != undefined do
            (
                try
                (
                    AmenoApp.resetDimensionToMeasured ctrl
                    if ::AmenoRefreshMainPanel != undefined do ::AmenoRefreshMainPanel()
                )
                catch
                (
                    messageBox ("Não foi possível restaurar o valor medido:\n" + (getCurrentException() as string)) title:"Ameno Dimensions"
                )
            )
        )
    )
)

rollout AmenoAnchorRollout "Âncoras e Diagnóstico" width:344
(
    label lblAnchors "Âncoras: -" pos:[14, 10] width:316 height:18 align:#left
    label lblOrphanStatus "Status: -" pos:[14, 30] width:316 height:18 align:#left
    button btnReanchorA "Reancorar Ponto A" pos:[14, 54] width:150 height:24
    button btnReanchorB "Reancorar Ponto B" pos:[180, 54] width:150 height:24
    button btnSelectAnchors "Selecionar Nós Âncoras" pos:[14, 84] width:150 height:24
    button btnRepairOrphans "Reparar Cotas Órfãs" pos:[180, 84] width:150 height:24

    on btnReanchorA pressed do
    (
        global AmenoApp
        global AmenoDimensionCA
        global AmenoDimensionTool
        global AmenoRefreshMainPanel

        if AmenoApp == undefined then return ()
        local ctrl = AmenoApp.getSelectedDimensionController()
        if ctrl == undefined then
        (
            messageBox "Selecione uma cota na cena para reancorar." title:"Ameno Dimensions"
            return ()
        )

        local pt = pickPoint snap:#3D prompt:"Clique no novo ponto de ancoragem A no objeto (Esc cancela)"
        if pt != undefined and pt != #rightClick and (classof pt == Point3) then
        (
            local snapped = false
            local snappedNode = undefined
            local snappedWorldPoint = undefined
            try
            (
                snapped = (snapMode.hit == true)
                if snapped do
                (
                    snappedNode = snapMode.node
                    snappedWorldPoint = snapMode.worldHitpoint
                )
            )
            catch ()

            local hitResult = if AmenoDimensionTool != undefined then \
                (AmenoDimensionTool.detectHitNode pt snapNode:snappedNode snapWorldPoint:snappedWorldPoint snapHit:snapped) \
                else undefined
            local foundNode = if hitResult != undefined then hitResult.node else undefined
            local resolvedPoint = if hitResult != undefined and hitResult.vertexWorldPoint != undefined then hitResult.vertexWorldPoint else pt
            if foundNode == undefined do
            (
                foundNode = pickObject prompt:"Objeto não detectado automaticamente. Clique no objeto para vincular o ponto A (ou Esc para manter mundial):"
            )
            AmenoApp.reanchorDimension ctrl #pointA foundNode resolvedPoint
            if AmenoRefreshMainPanel != undefined do AmenoRefreshMainPanel()
        )
    )

    on btnReanchorB pressed do
    (
        global AmenoApp
        global AmenoDimensionCA
        global AmenoDimensionTool
        global AmenoRefreshMainPanel

        if AmenoApp == undefined then return ()
        local ctrl = AmenoApp.getSelectedDimensionController()
        if ctrl == undefined then
        (
            messageBox "Selecione uma cota na cena para reancorar." title:"Ameno Dimensions"
            return ()
        )

        local pt = pickPoint snap:#3D prompt:"Clique no novo ponto de ancoragem B no objeto (Esc cancela)"
        if pt != undefined and pt != #rightClick and (classof pt == Point3) then
        (
            local snapped = false
            local snappedNode = undefined
            local snappedWorldPoint = undefined
            try
            (
                snapped = (snapMode.hit == true)
                if snapped do
                (
                    snappedNode = snapMode.node
                    snappedWorldPoint = snapMode.worldHitpoint
                )
            )
            catch ()

            local hitResult = if AmenoDimensionTool != undefined then \
                (AmenoDimensionTool.detectHitNode pt snapNode:snappedNode snapWorldPoint:snappedWorldPoint snapHit:snapped) \
                else undefined
            local foundNode = if hitResult != undefined then hitResult.node else undefined
            local resolvedPoint = if hitResult != undefined and hitResult.vertexWorldPoint != undefined then hitResult.vertexWorldPoint else pt
            if foundNode == undefined do
            (
                foundNode = pickObject prompt:"Objeto não detectado automaticamente. Clique no objeto para vincular o ponto B (ou Esc para manter mundial):"
            )
            AmenoApp.reanchorDimension ctrl #pointB foundNode resolvedPoint
            if AmenoRefreshMainPanel != undefined do AmenoRefreshMainPanel()
        )
    )

    on btnSelectAnchors pressed do
    (
        global AmenoApp
        if AmenoApp == undefined then return ()
        local ctrl = AmenoApp.getSelectedDimensionController()
        if ctrl == undefined then
        (
            messageBox "Selecione uma cota na cena para inspecionar as âncoras." title:"Ameno Dimensions"
            return ()
        )

        local ok = AmenoApp.selectAnchors ctrl
        if not ok do displayTempPrompt "Ameno Dimensions: a cota selecionada não possui âncoras em objetos válidos." 1800
    )

    on btnRepairOrphans pressed do
    (
        global AmenoApp
        global AmenoRefreshMainPanel
        if AmenoApp != undefined do
        (
            local repCount = AmenoApp.repairOrphans()
            messageBox ("Cotas órfãs reparadas e convertidas para coordenadas mundiais: " + (repCount as string)) title:"Ameno Dimensions"
            if AmenoRefreshMainPanel != undefined do AmenoRefreshMainPanel()
        )
    )

    -- E10.2: operacoes em lote nas cotas selecionadas na viewport --------
    label lblBatch "Selecionadas:" pos:[14, 118] width:316 height:16 align:#left

    -- Linha 1: unidade e precisao
    dropdownlist ddlBatchUnit "Unidade" pos:[14, 138] width:150 height:21 items:#("metros","centimetros","milimetros") selection:1
    spinner spnBatchPrecision "Precisao" pos:[180, 138] width:150 height:21 range:[0, 6, 2] type:#integer

    button btnApplyUnit "Aplicar Unidade" pos:[14, 166] width:150 height:24
    button btnApplyPrecision "Aplicar Precisao" pos:[180, 166] width:150 height:24

    -- Linha 2: modo e bake
    button btnApplyModeSel "Aplicar Modo Atual" pos:[14, 196] width:150 height:24 tooltip:"Aplica o modo selecionado no radio acima (Alinhada/Horizontal/Vertical) a todas as cotas selecionadas"
    button btnBakeSel "Bake Ancoras" pos:[180, 196] width:150 height:24 tooltip:"Converte ancoras reativas em posicao mundial fixa. Apos o bake a cota nao segue mais o objeto."

    on ddlBatchUnit selected i do ()  -- sem acao imediata; usado por btnApplyUnit

    on btnApplyUnit pressed do
    (
        global AmenoApp
        global AmenoRefreshMainPanel
        if AmenoApp == undefined then return ()
        local unitMap = #("meters", "centimeters", "millimeters")
        local unit = unitMap[ddlBatchUnit.selection] as name
        local count = AmenoApp.applyUnitToSelected unit
        displayTempPrompt ("Ameno: unidade aplicada a " + (count as string) + " cota(s).") 1800
        if AmenoRefreshMainPanel != undefined do AmenoRefreshMainPanel()
    )

    on btnApplyPrecision pressed do
    (
        global AmenoApp
        global AmenoRefreshMainPanel
        if AmenoApp == undefined then return ()
        local count = AmenoApp.applyPrecisionToSelected (spnBatchPrecision.value as integer)
        displayTempPrompt ("Ameno: precisao aplicada a " + (count as string) + " cota(s).") 1800
        if AmenoRefreshMainPanel != undefined do AmenoRefreshMainPanel()
    )

    on btnApplyModeSel pressed do
    (
        global AmenoApp
        global AmenoDimensionTool
        global AmenoRefreshMainPanel
        if AmenoApp == undefined then return ()
        local mode = if AmenoDimensionTool != undefined then AmenoDimensionTool.activeMode else #aligned
        local count = AmenoApp.applyDimensionModeToSelected mode
        displayTempPrompt ("Ameno: modo " + (mode as string) + " aplicado a " + (count as string) + " cota(s).") 1800
        if AmenoRefreshMainPanel != undefined do AmenoRefreshMainPanel()
    )

    on btnBakeSel pressed do
    (
        global AmenoApp
        global AmenoRefreshMainPanel
        if AmenoApp == undefined then return ()
        local ctrls = AmenoApp.getSelectedDimensionControllers()
        if ctrls.count == 0 do
        (
            displayTempPrompt "Ameno: selecione cotas na cena antes de fazer o bake." 1800
            return ()
        )
        local ok = queryBox ("Bake de " + (ctrls.count as string) + " cota(s) selecionada(s).\nApos o bake as cotas nao seguirao mais os objetos.\n\nContinuar?") title:"Ameno: Bake de Ancoras"
        if ok do
        (
            local count = AmenoApp.bakeSelected()
            messageBox ("Bake concluido: " + (count as string) + " cota(s) convertida(s) para posicao fixa.") title:"Ameno Dimensions"
            if AmenoRefreshMainPanel != undefined do AmenoRefreshMainPanel()
        )
    )

    -- E10.4: Relatório de Diagnóstico da Cena
    button btnDiagnosticReport "Relatório de Diagnóstico" pos:[14, 228] width:316 height:24 tooltip:"Gera relatório completo de saúde, âncoras e modos de todas as cotas da cena"

    on btnDiagnosticReport pressed do
    (
        global AmenoApp
        if AmenoApp != undefined do
        (
            local txt = AmenoApp.printDiagnosticReport()
            messageBox txt title:"Ameno - Diagnóstico de Cena"
        )
    )
)

rollout AmenoRenderRollout "Render Separado de Cotas" width:344
(
    label lblRenderSupport "Verificando renderer..." pos:[14, 10] width:316 height:18 align:#left
    radiobuttons rdoRenderScope "Incluir:" pos:[14, 32] labels:#("Todas", "Selecionadas") default:1 columns:2
    edittext edtOutput "PNG:" pos:[14, 64] width:234 height:18 text:""
    button btnBrowseOutput "..." pos:[256, 62] width:32 height:22 tooltip:"Escolher arquivo PNG"
    button btnResetOutput "Auto" pos:[294, 62] width:36 height:22 tooltip:"Voltar ao nome automático"
    button btnRenderCotas "Renderizar Cotas" pos:[14, 92] width:316 height:28
    label lblRenderHint "Usa a vista, frame, resolução, pixel aspect e crop atuais." pos:[14, 124] width:316 height:18 align:#left

    on btnBrowseOutput pressed do
    (
        global AmenoApp
        local suggestedPath = edtOutput.text
        if suggestedPath == "" and AmenoApp != undefined do suggestedPath = AmenoApp.defaultRenderCotasPath()

        local chosenPath = getSaveFileName caption:"Salvar overlay de cotas" filename:suggestedPath types:"PNG com alpha (*.png)|*.png|"
        if chosenPath != undefined do edtOutput.text = chosenPath
    )

    on btnResetOutput pressed do
    (
        global AmenoApp
        if AmenoApp != undefined do edtOutput.text = AmenoApp.defaultRenderCotasPath()
    )

    on btnRenderCotas pressed do
    (
        global AmenoApp
        if AmenoApp == undefined then return ()

        local scope = if rdoRenderScope.state == 2 then #selected else #all
        btnRenderCotas.enabled = false
        lblRenderSupport.text = "Renderizando cotas... Esc cancela."

        try
        (
            local result = AmenoApp.renderCotas outputPath:edtOutput.text selectionMode:scope
            if result.success then
            (
                edtOutput.text = result.outputPath
                lblRenderSupport.text = "Concluído · alpha confirmado"
                messageBox ("Overlay criado com sucesso:\n\n" + result.outputPath + "\n\nA cena foi restaurada.") title:"Ameno Dimensions"
            )
            else if result.cancelled then
            (
                lblRenderSupport.text = "Cancelado · cena restaurada"
            )
            else
            (
                lblRenderSupport.text = "Falha · cena restaurada"
                messageBox ("Não foi possível renderizar as cotas:\n\n" + result.errorMessage) title:"Ameno Dimensions"
            )
        )
        catch
        (
            lblRenderSupport.text = "Falha · confira o diagnóstico"
            messageBox ("Falha inesperada no passe de cotas:\n\n" + (getCurrentException() as string)) title:"Ameno Dimensions"
        )

        if ::AmenoRefreshMainPanel != undefined do ::AmenoRefreshMainPanel()
    )
)

rollout AmenoEnvRollout "Ambiente e Cena" width:344
(
    label lblRenderer "Detectando renderer..." pos:[14, 10] width:316 height:18 align:#left
    label lblRendererClass "" pos:[14, 30] width:316 height:18 align:#left
    button btnRefresh "Atualizar diagnóstico" pos:[194, 52] width:136 height:24

    label lblSceneStatus "Detectando infraestrutura..." pos:[14, 82] width:316 height:18 align:#left
    label lblSceneDetail "" pos:[14, 102] width:316 height:18 align:#left
    button btnPrepare "Preparar esta cena" pos:[174, 124] width:156 height:24

    on btnRefresh pressed do
    (
        if ::AmenoRefreshMainPanel != undefined do ::AmenoRefreshMainPanel()
    )

    on btnPrepare pressed do
    (
        global AmenoApp
        if AmenoApp != undefined do
        (
            AmenoApp.prepareScene()
            if ::AmenoRefreshMainPanel != undefined do ::AmenoRefreshMainPanel()
        )
    )
)

rollout AmenoMainPanelRollout "Ameno Tools" width:380 height:640
(
    label lblBrand "AMENO TOOLS" pos:[16, 10] width:220 height:20 align:#left
    label lblVersion "" pos:[16, 30] width:220 height:16 align:#left
    button btnClose "Fechar" pos:[284, 14] width:80 height:24

    subRollout subPanel "" pos:[8, 52] width:364 height:580

    on AmenoMainPanelRollout open do
    (
        addSubRollout subPanel AmenoDimRollout rolledUp:false
        addSubRollout subPanel AmenoRenderRollout rolledUp:false
        addSubRollout subPanel AmenoAuditRollout rolledUp:false
        addSubRollout subPanel AmenoAnchorRollout rolledUp:false
        addSubRollout subPanel AmenoEnvRollout rolledUp:true

        callbacks.removeScripts id:#ameno_selection
        callbacks.addScript #selectionSetChanged "if AmenoRefreshMainPanel != undefined do AmenoRefreshMainPanel()" id:#ameno_selection
        AmenoRefreshMainPanel()
    )

    on AmenoMainPanelRollout close do
    (
        callbacks.removeScripts id:#ameno_selection
    )

    on btnClose pressed do
    (
        destroyDialog AmenoMainPanelRollout
    )
)

fn AmenoShowMainPanel =
(
    try (destroyDialog AmenoMainPanelRollout) catch ()
    createDialog AmenoMainPanelRollout width:380 height:640 style:#(#style_titlebar, #style_sysmenu, #style_toolwindow) lockWidth:true lockHeight:true
)
