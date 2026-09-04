global AmenoApp
global AmenoRendererProbe
global AmenoSceneSetup
global AmenoDimensionGraphics
global AmenoLog
global AmenoVersion
global AmenoShowMainPanel
global AmenoMainPanelRollout

struct AmenoRuntime
(
    rootPath = "",
    rendererInfo = undefined,
    sceneInfo = undefined,
    dimensionStatus = "",
    lastTestDimension = undefined,
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

    fn refreshDimensions =
    (
        local testCount = (AmenoDimensionGraphics.findControllers role:AmenoDimensionGraphics.testRole).count
        dimensionStatus = "E3: cota gráfica de teste · " + (testCount as string) + " ativa(s)."
        dimensionStatus
    ),

    fn createTestDimension =
    (
        lastTestDimension = AmenoDimensionGraphics.createTestDimension()
        refreshScene()
        refreshDimensions()
        lastTestDimension
    ),

    fn clearTestDimensions =
    (
        local removedCount = AmenoDimensionGraphics.clearTestDimensions()
        lastTestDimension = undefined
        refreshScene()
        refreshDimensions()
        removedCount
    ),

    fn start =
    (
        refreshRenderer()
        refreshScene()
        refreshDimensions()
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
