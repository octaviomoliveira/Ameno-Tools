global AmenoMainPanelRollout
global AmenoRefreshMainPanel
global AmenoShowMainPanel

fn AmenoRefreshMainPanel =
(
    global AmenoApp
    global AmenoVersion

    if AmenoApp != undefined and AmenoMainPanelRollout != undefined do
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
    )
)

rollout AmenoMainPanelRollout "Ameno Tools" width:380 height:450
(
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

    groupBox grpDimensions "Ameno Dimensions" pos:[12,268] width:356 height:142
    label lblDimensions "Ameno Dimensions · 0 cota(s) ativa(s)." pos:[26,290] width:320 height:18 align:#left
    button btnCreate "Criar cota" pos:[26,316] width:156 height:24
    button btnCreateTest "Criar cota de teste" pos:[26,346] width:156 height:24
    button btnClearTests "Limpar cotas de teste" pos:[198,346] width:156 height:24
    label lblTestHint "Preview temporário; Esc/botão direito cancela." pos:[26,376] width:320 height:18 align:#left

    button btnClose "Fechar" pos:[278,420] width:90 height:24

    on AmenoMainPanelRollout open do
    (
        AmenoRefreshMainPanel()
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

    on btnClose pressed do
    (
        destroyDialog AmenoMainPanelRollout
    )
)

fn AmenoShowMainPanel =
(
    try (destroyDialog AmenoMainPanelRollout) catch ()

    createDialog AmenoMainPanelRollout width:380 height:450 style:#(#style_titlebar, #style_sysmenu, #style_toolwindow) lockWidth:true lockHeight:true
)
