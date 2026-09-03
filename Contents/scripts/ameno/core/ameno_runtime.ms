global AmenoApp
global AmenoRendererProbe
global AmenoLog
global AmenoVersion
global AmenoShowMainPanel
global AmenoMainPanelRollout

struct AmenoRuntime
(
    rootPath = "",
    rendererInfo = undefined,
    started = false,

    fn refreshRenderer =
    (
        rendererInfo = AmenoRendererProbe.detect()
        rendererInfo
    ),

    fn start =
    (
        refreshRenderer()
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
