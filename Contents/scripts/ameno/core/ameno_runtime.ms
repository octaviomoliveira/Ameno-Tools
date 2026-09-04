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
global AmenoStyleService
global AmenoShowStyleEditor
global AmenoStyleEditorRollout

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

    fn getSelectedDimensionController =
    (
        if selection.count == 0 then return undefined
        for obj in selection where isValidNode obj do
        (
            local dimId = AmenoDimensionGraphics.getDimensionId obj
            if dimId != "" do
            (
                local nodes = AmenoDimensionGraphics.findNodesForDimension dimId
                for n in nodes where isValidNode n do
                (
                    if (AmenoDimensionGraphics.readTextProperty n "Ameno.Kind") == "dimension" or (AmenoDimensionCA != undefined and AmenoDimensionCA.hasCA n) then
                    (
                        return n
                    )
                )
            )
        )
        undefined
    ),

    fn getSelectedDimensionAudit =
    (
        local ctrl = getSelectedDimensionController()
        if ctrl != undefined then AmenoDimensionGraphics.getDimensionAudit ctrl else undefined
    ),

    fn setDimensionMode controller mode manualValueMm:undefined manualText:undefined reason:undefined incrementMm:undefined =
    (
        local res = AmenoDimensionGraphics.setDimensionMode controller mode manualValueMm:manualValueMm manualText:manualText reason:reason incrementMm:incrementMm
        refreshDimensions()
        res
    ),

    fn resetDimensionToMeasured controller =
    (
        local res = AmenoDimensionGraphics.resetDimensionToMeasured controller
        refreshDimensions()
        res
    ),

    fn getStyles =
    (
        if ::AmenoStyleService != undefined then ::AmenoStyleService.listStyles() else #()
    ),

    fn applyStyleToSelection styleId =
    (
        if ::AmenoStyleService == undefined then return 0
        local count = ::AmenoStyleService.applyStyleToSelection styleId
        refreshDimensions()
        count
    ),

    fn openStyleEditor =
    (
        if ::AmenoShowStyleEditor != undefined do ::AmenoShowStyleEditor()
    ),

    fn onSceneOpened =
    (
        if ::AmenoStyleService != undefined do ::AmenoStyleService.loadFromScene()
        refreshScene()
        refreshDimensions()
        if AmenoRefreshMainPanel != undefined do AmenoRefreshMainPanel()
        true
    ),

    fn onSceneReset =
    (
        if ::AmenoStyleService != undefined do ::AmenoStyleService.loadFromScene()
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
        callbacks.removeScripts id:#ameno_selection
        try (stopTool AmenoDimensionMouseTool) catch ()
        try (if AmenoDimensionTool != undefined do AmenoDimensionTool.cancel()) catch ()
        try (destroyDialog AmenoMainPanelRollout) catch ()
        try (destroyDialog AmenoStyleEditorRollout) catch ()
        started = false
        true
    )
)
