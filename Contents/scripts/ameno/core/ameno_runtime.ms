global AmenoApp
global AmenoRendererProbe
global AmenoSceneSetup
global AmenoLog
global AmenoVersion
global AmenoShowMainPanel
global AmenoMainPanelRollout

struct AmenoRuntime
(
    rootPath = "",
    rendererInfo = undefined,
    sceneInfo = undefined,
    started = false,

    fn refreshRenderer =
    (
        rendererInfo = AmenoRendererProbe.detect()
        rendererInfo
    ),

    fn refreshScene =
    (
        sceneInfo = AmenoSceneSetup.inspect()
        sceneInfo
    ),

    fn prepareScene =
    (
        sceneInfo = AmenoSceneSetup.prepare()
        sceneInfo
    ),

    fn start =
    (
        refreshRenderer()
        refreshScene()
        started = true

        AmenoLog.info (AmenoVersion.displayName() + " carregado.")
        AmenoLog.info ("Renderer: " + rendererInfo.displayName + " · " + rendererInfo.statusLabel())
        true
    ),

    fn openMainPanel =
    (
        AmenoShowMainPanel()
    ),

    fn shutdown =
    (
        try (destroyDialog AmenoMainPanelRollout) catch ()
        started = false
        true
    )
)
