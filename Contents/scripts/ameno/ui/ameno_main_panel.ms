global AmenoMainPanelRollout
global AmenoRefreshMainPanel
global AmenoShowMainPanel

fn AmenoRefreshMainPanel =
(
    global AmenoApp
    global AmenoVersion
    global AmenoDimensionGraphics
    global AmenoDimensionCA
    global AmenoStyleService

    if AmenoApp != undefined and AmenoMainPanelRollout != undefined and AmenoMainPanelRollout.open do
    (
        local info = AmenoApp.refreshRenderer()
        local sceneInfo = AmenoApp.refreshScene()

        AmenoMainPanelRollout.lblVersion.text = AmenoVersion.displayName() + " · Max " + (AmenoVersion.targetMax as string)
        AmenoMainPanelRollout.lblRenderer.text = info.displayName + " · " + info.statusLabel()
        AmenoMainPanelRollout.lblRendererClass.text = info.className
        AmenoMainPanelRollout.lblSceneStatus.text = sceneInfo.statusLabel
        AmenoMainPanelRollout.lblSceneDetail.text = sceneInfo.detail
        AmenoMainPanelRollout.btnPrepare.caption = if sceneInfo.status == #ready then "Verificar infraestrutura" else "Preparar esta cena"
        AmenoMainPanelRollout.lblDimensions.text = AmenoApp.refreshDimensions()

        -- E7: Atualiza lista de estilos
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
        AmenoMainPanelRollout.ddlSelStyle.items = styleList
        AmenoMainPanelRollout.styleIds = styleIds

        -- E6: Inspeção da cota selecionada
        local ctrl = AmenoApp.getSelectedDimensionController()
        if ctrl != undefined and isValidNode ctrl then
        (
            local audit = AmenoDimensionGraphics.getDimensionAudit ctrl
            if audit != undefined then
            (
                AmenoMainPanelRollout.lblSelName.text = "Cota: " + audit.dimensionId
                AmenoMainPanelRollout.lblMeasured.text = "Medido: " + audit.measuredText
                AmenoMainPanelRollout.lblDisplay.text = "Exibido: " + audit.displayText
                AmenoMainPanelRollout.lblDelta.text = "Delta: " + audit.deltaText + (if audit.isManual then " [MODIFICADA / MANUAL]" else " [EXATO]")

                case audit.mode of
                (
                    #rounded: AmenoMainPanelRollout.rdoMode.state = 2
                    #manualNumeric: AmenoMainPanelRollout.rdoMode.state = 3
                    #manualText: AmenoMainPanelRollout.rdoMode.state = 4
                    default: AmenoMainPanelRollout.rdoMode.state = 1
                )

                AmenoMainPanelRollout.spnManualVal.value = (audit.displayMillimeters / 1000.0) as float
                AmenoMainPanelRollout.edtManualText.text = if audit.mode == #manualText then audit.displayText else ""
                AmenoMainPanelRollout.edtReason.text = audit.manualReason

                -- Estilo da cota selecionada
                local rec = if AmenoDimensionCA != undefined then AmenoDimensionCA.readCA ctrl else undefined
                local sId = "default"
                if rec != undefined and rec.styleId != undefined and rec.styleId != "" then sId = rec.styleId
                else
                (
                    local p = AmenoDimensionGraphics.readTextProperty ctrl "Ameno.StyleId"
                    if p != undefined and p != "" do sId = p
                )

                local sIdx = findItem styleIds sId
                if sIdx > 0 then AmenoMainPanelRollout.ddlSelStyle.selection = sIdx
                else AmenoMainPanelRollout.ddlSelStyle.selection = 1

                AmenoMainPanelRollout.ddlSelStyle.enabled = true
                AmenoMainPanelRollout.btnApplySelStyle.enabled = true

                AmenoMainPanelRollout.rdoMode.enabled = true
                AmenoMainPanelRollout.spnRounding.enabled = true
                AmenoMainPanelRollout.spnManualVal.enabled = true
                AmenoMainPanelRollout.edtManualText.enabled = true
                AmenoMainPanelRollout.edtReason.enabled = true
                AmenoMainPanelRollout.btnApplyMode.enabled = true
                AmenoMainPanelRollout.btnResetMeasured.enabled = true
            )
        )
        else
        (
            AmenoMainPanelRollout.lblSelName.text = "Selecione uma cota na cena para editar."
            AmenoMainPanelRollout.lblMeasured.text = "Medido: -"
            AmenoMainPanelRollout.lblDisplay.text = "Exibido: -"
            AmenoMainPanelRollout.lblDelta.text = "Delta: -"
            AmenoMainPanelRollout.rdoMode.state = 1
            AmenoMainPanelRollout.edtManualText.text = ""
            AmenoMainPanelRollout.edtReason.text = ""

            AmenoMainPanelRollout.ddlSelStyle.enabled = false
            AmenoMainPanelRollout.btnApplySelStyle.enabled = false

            AmenoMainPanelRollout.rdoMode.enabled = false
            AmenoMainPanelRollout.spnRounding.enabled = false
            AmenoMainPanelRollout.spnManualVal.enabled = false
            AmenoMainPanelRollout.edtManualText.enabled = false
            AmenoMainPanelRollout.edtReason.enabled = false
            AmenoMainPanelRollout.btnApplyMode.enabled = false
            AmenoMainPanelRollout.btnResetMeasured.enabled = false
        )
    )
)

rollout AmenoMainPanelRollout "Ameno Tools" width:380 height:770
(
    local styleIds = #()

    label lblBrand "AMENO TOOLS" pos:[20,16] width:340 height:24 align:#left
    label lblVersion "" pos:[20,44] width:340 height:18 align:#left

    groupBox grpEnvironment "Ambiente" pos:[12,72] width:356 height:88
    label lblRenderer "Detectando renderer..." pos:[26,96] width:320 height:18 align:#left
    label lblRendererClass "" pos:[26,118] width:320 height:18 align:#left
    button btnRefresh "Atualizar diagnóstico" pos:[218,136] width:136 height:24

    groupBox grpScene "Cena" pos:[12,170] width:356 height:88
    label lblSceneStatus "Detectando infraestrutura..." pos:[26,192] width:320 height:18 align:#left
    label lblSceneDetail "" pos:[26,214] width:320 height:18 align:#left
    button btnPrepare "Preparar esta cena" pos:[198,228] width:156 height:24

    groupBox grpDimensions "Ameno Dimensions" pos:[12,268] width:356 height:172
    label lblDimensions "Ameno Dimensions · 0 cota(s) ativa(s)." pos:[26,290] width:320 height:18 align:#left
    button btnCreate "Criar cota" pos:[26,316] width:156 height:24
    button btnRepair "Reparar cotas" pos:[198,316] width:156 height:24
    button btnCreateTest "Criar cota de teste" pos:[26,346] width:156 height:24
    button btnClearTests "Limpar cotas de teste" pos:[198,346] width:156 height:24
    button btnStyleEditor "Editor de Estilos..." pos:[26,376] width:328 height:24
    label lblTestHint "Preview temporário; Esc/botão direito cancela." pos:[26,408] width:320 height:18 align:#left

    groupBox grpAudit "Inspeção e Estilos (E6 / E7)" pos:[12,448] width:356 height:272
    label lblSelName "Selecione uma cota na cena para editar." pos:[26,468] width:320 height:18 align:#left
    label lblMeasured "Medido: -" pos:[26,488] width:150 height:18 align:#left
    label lblDisplay "Exibido: -" pos:[186,488] width:160 height:18 align:#left
    label lblDelta "Delta: -" pos:[26,508] width:320 height:18 align:#left

    radiobuttons rdoMode "Modo de Valor:" pos:[26,528] labels:#("Medido", "Arredondado", "Numérico Manual", "Texto Manual") default:1 columns:2
    spinner spnRounding "Passo arred. (cm):" pos:[26,572] width:140 height:18 range:[1, 100, 5] type:#integer fieldWidth:45
    spinner spnManualVal "Valor Manual (m):" pos:[176,572] width:170 height:18 range:[0.001, 10000.0, 1.0] type:#float scale:0.01 fieldWidth:55
    edittext edtManualText "Texto:" pos:[26,594] width:320 height:18 text:""
    edittext edtReason "Motivo:" pos:[26,616] width:320 height:18 text:""

    label lblStyle "Estilo:" pos:[26,648] width:40 height:18
    dropdownList ddlSelStyle "" pos:[68,644] width:180 height:21
    button btnApplySelStyle "Aplicar Estilo" pos:[254,644] width:100 height:22

    button btnApplyMode "Aplicar Alteração" pos:[26,680] width:156 height:24
    button btnResetMeasured "Restaurar Medido" pos:[198,680] width:156 height:24

    button btnClose "Fechar" pos:[278,730] width:90 height:24

    on AmenoMainPanelRollout open do
    (
        callbacks.removeScripts id:#ameno_selection
        callbacks.addScript #selectionSetChanged "if AmenoRefreshMainPanel != undefined do AmenoRefreshMainPanel()" id:#ameno_selection
        AmenoRefreshMainPanel()
    )

    on AmenoMainPanelRollout close do
    (
        callbacks.removeScripts id:#ameno_selection
    )

    on btnRefresh pressed do
    (
        AmenoRefreshMainPanel()
    )

    on btnPrepare pressed do
    (
        global AmenoApp

        if AmenoApp != undefined then
        (
            AmenoApp.prepareScene()
            AmenoRefreshMainPanel()
        )
    )

    on btnCreate pressed do
    (
        global AmenoApp
        global AmenoDimensionTool

        if AmenoApp != undefined then
        (
            try
            (
                local record = AmenoApp.startDimensionTool()
                if record != undefined do select #(record.lineNode, record.textNode)
                if record == undefined and AmenoDimensionTool != undefined and AmenoDimensionTool.lastError != "" do
                (
                    messageBox ("A cota não foi criada. A prévia foi preservada durante a falha.\n\n" + AmenoDimensionTool.lastError) title:"Ameno Dimensions"
                )
                AmenoRefreshMainPanel()
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

        if AmenoApp != undefined then
        (
            try
            (
                local repairedCount = AmenoApp.repairDimensions()
                messageBox ("Cotas reparadas: " + (repairedCount as string)) title:"Ameno Dimensions"
                AmenoRefreshMainPanel()
            )
            catch
            (
                messageBox ("Não foi possível reparar as cotas:\n" + (getCurrentException() as string)) title:"Ameno Tools"
            )
        )
    )

    on btnCreateTest pressed do
    (
        global AmenoApp

        if AmenoApp != undefined then
        (
            try
            (
                local record = AmenoApp.createTestDimension()
                select #(record.lineNode, record.textNode)
                AmenoRefreshMainPanel()
            )
            catch
            (
                messageBox ("Não foi possível criar a cota de teste:\n" + (getCurrentException() as string)) title:"Ameno Tools"
            )
        )
    )

    on btnClearTests pressed do
    (
        global AmenoApp

        if AmenoApp != undefined then
        (
            AmenoApp.clearTestDimensions()
            AmenoRefreshMainPanel()
        )
    )

    on btnStyleEditor pressed do
    (
        global AmenoApp
        if AmenoApp != undefined do AmenoApp.openStyleEditor()
    )

    on ddlSelStyle selected idx do
    (
        global AmenoApp
        global AmenoStyleService

        if AmenoApp != undefined and ::AmenoStyleService != undefined then
        (
            local ctrl = AmenoApp.getSelectedDimensionController()
            if ctrl != undefined and isValidNode ctrl then
            (
                if idx > 0 and idx <= styleIds.count then
                (
                    local targetId = styleIds[idx]
                    ::AmenoStyleService.applyStyleToDimension ctrl targetId
                    AmenoRefreshMainPanel()
                )
            )
        )
    )

    on btnApplySelStyle pressed do
    (
        global AmenoApp
        global AmenoDimensionGraphics
        global AmenoDimensionCA
        global AmenoStyleService

        if AmenoApp != undefined and ::AmenoStyleService != undefined then
        (
            local ctrl = AmenoApp.getSelectedDimensionController()
            if ctrl != undefined and isValidNode ctrl then
            (
                local selIdx = ddlSelStyle.selection
                if selIdx > 0 and selIdx <= styleIds.count then
                (
                    local targetId = styleIds[selIdx]
                    ::AmenoStyleService.applyStyleToDimension ctrl targetId
                    AmenoRefreshMainPanel()
                )
            )
        )
    )

    on btnApplyMode pressed do
    (
        global AmenoApp

        if AmenoApp != undefined then
        (
            local ctrl = AmenoApp.getSelectedDimensionController()
            if ctrl != undefined then
            (
                local targetMode = case rdoMode.state of
                (
                    1: #measured
                    2: #rounded
                    3: #manualNumeric
                    4: #manualText
                    default: #measured
                )

                local incMm = spnRounding.value * 10.0 -- cm para mm
                local manMm = spnManualVal.value * 1000.0 -- m para mm
                local manTxt = edtManualText.text
                local reasonTxt = edtReason.text

                try
                (
                    AmenoApp.setDimensionMode ctrl targetMode manualValueMm:manMm manualText:manTxt reason:reasonTxt incrementMm:incMm
                    AmenoRefreshMainPanel()
                )
                catch
                (
                    messageBox ("Não foi possível aplicar o modo de valor:\n" + (getCurrentException() as string)) title:"Ameno Dimensions"
                )
            )
        )
    )

    on btnResetMeasured pressed do
    (
        global AmenoApp

        if AmenoApp != undefined then
        (
            local ctrl = AmenoApp.getSelectedDimensionController()
            if ctrl != undefined then
            (
                try
                (
                    AmenoApp.resetDimensionToMeasured ctrl
                    AmenoRefreshMainPanel()
                )
                catch
                (
                    messageBox ("Não foi possível restaurar o valor medido:\n" + (getCurrentException() as string)) title:"Ameno Dimensions"
                )
            )
        )
    )

    on btnClose pressed do
    (
        destroyDialog AmenoMainPanelRollout
    )
)

fn AmenoShowMainPanel =
(
    try (destroyDialog AmenoMainPanelRollout) catch ()

    createDialog AmenoMainPanelRollout width:380 height:770 style:#(#style_titlebar, #style_sysmenu, #style_toolwindow) lockWidth:true lockHeight:true
)