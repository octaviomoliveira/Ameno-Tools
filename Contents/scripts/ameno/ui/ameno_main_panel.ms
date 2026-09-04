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
    )
)

rollout AmenoMainPanelRollout "Ameno Tools" width:380 height:360
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

    groupBox grpDimensions "Ameno Dimensions" pos:[12,268] width:356 height:54
    label lblDimensions "Etapa E1: infraestrutura de cena e layers." pos:[26,290] width:320 height:18 align:#left

    button btnClose "Fechar" pos:[278,330] width:90 height:24

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

    on btnClose pressed do
    (
        destroyDialog AmenoMainPanelRollout
    )
)

fn AmenoShowMainPanel =
(
    try (destroyDialog AmenoMainPanelRollout) catch ()

    createDialog AmenoMainPanelRollout width:380 height:360 style:#(#style_titlebar, #style_sysmenu, #style_toolwindow) lockWidth:true lockHeight:true
)
