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
        AmenoMainPanelRollout.lblVersion.text = AmenoVersion.displayName() + " · Max " + (AmenoVersion.targetMax as string)
        AmenoMainPanelRollout.lblRenderer.text = info.displayName + " · " + info.statusLabel()
        AmenoMainPanelRollout.lblRendererClass.text = info.className
    )
)

rollout AmenoMainPanelRollout "Ameno Tools" width:380 height:260
(
    label lblBrand "AMENO TOOLS" pos:[20,16] width:340 height:24 align:#left
    label lblVersion "" pos:[20,44] width:340 height:18 align:#left

    groupBox grpEnvironment "Ambiente" pos:[12,72] width:356 height:88
    label lblRenderer "Detectando renderer..." pos:[26,96] width:320 height:18 align:#left
    label lblRendererClass "" pos:[26,118] width:320 height:18 align:#left
    button btnRefresh "Atualizar diagnóstico" pos:[218,136] width:136 height:24

    groupBox grpDimensions "Ameno Dimensions" pos:[12,170] width:356 height:54
    label lblDimensions "Fundação carregada. Ferramenta de cotas: próxima etapa." pos:[26,192] width:320 height:18 align:#left

    button btnClose "Fechar" pos:[278,230] width:90 height:24

    on AmenoMainPanelRollout open do
    (
        AmenoRefreshMainPanel()
    )

    on btnRefresh pressed do
    (
        AmenoRefreshMainPanel()
    )

    on btnClose pressed do
    (
        destroyDialog AmenoMainPanelRollout
    )
)

fn AmenoShowMainPanel =
(
    try (destroyDialog AmenoMainPanelRollout) catch ()

    createDialog AmenoMainPanelRollout width:380 height:260 style:#(#style_titlebar, #style_sysmenu, #style_toolwindow) lockWidth:true lockHeight:true
)
