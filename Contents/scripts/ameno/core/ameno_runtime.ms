global AmenoApp
global AmenoRendererProbe
global AmenoSceneSetup
global AmenoDimensionGraphics
global AmenoDimensionTool
global AmenoDimensionMouseTool
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
    lastInteractiveDimension = undefined,
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
        local dimensionCount = (AmenoDimensionGraphics.findControllers()).count
        dimensionStatus = "Ameno Dimensions · " + (dimensionCount as string) + " cota(s) ativa(s)."
        dimensionStatus
    ),

    fn startDimensionTool =
    (
        if AmenoDimensionTool == undefined then throw "A ferramenta interativa Ameno não foi carregada."

        lastInteractiveDimension = AmenoDimensionTool.start()
        refreshScene()
        refreshDimensions()
        lastInteractiveDimension
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

    fn repairDimensions =
    (
        local repairedCount = AmenoDimensionGraphics.repairAllDimensions()
        refreshScene()
        refreshDimensions()
        repairedCount
    ),

    fn onSceneOpened =
    (
        refreshScene()
        refreshDimensions()
        if AmenoRefreshMainPanel != undefined do AmenoRefreshMainPanel()
        true
    ),

    fn onSceneReset =
    (
        refreshScene()
        refreshDimensions()
        if AmenoRefreshMainPanel != undefined do AmenoRefreshMainPanel()
        true
    ),

    fn start =
    (
        refreshRenderer()
        refreshScene()
        refreshDimensions()
        started = true

        callbacks.removeScripts id:#ameno_lifecycle
        callbacks.addScript #filePostOpen "if AmenoApp != undefined do AmenoApp.onSceneOpened()" id:#ameno_lifecycle
        callbacks.addScript #systemPostNew "if AmenoApp != undefined do AmenoApp.onSceneReset()" id:#ameno_lifecycle
        callbacks.addScript #postSceneReset "if AmenoApp != undefined do AmenoApp.onSceneReset()" id:#ameno_lifecycle

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
        callbacks.removeScripts id:#ameno_lifecycle
        try (stopTool AmenoDimensionMouseTool) catch ()
        try (if AmenoDimensionTool != undefined do AmenoDimensionTool.cancel()) catch ()
        try (destroyDialog AmenoMainPanelRollout) catch ()
        started = false
        true
    )
)
