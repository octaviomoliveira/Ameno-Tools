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
global AmenoAnchorService
global AmenoRenderCotasService

struct AmenoRuntime
(
    rootPath = "",
    rendererInfo = undefined,
    sceneInfo = undefined,
    dimensionStatus = "",
    lastTestDimension = undefined,
    lastInteractiveDimension = undefined,
    lastRenderResult = undefined,
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
        if ::AmenoDimensionTool != undefined and ::AmenoDimensionTool.lastAnchorSummary != "" do
            dimensionStatus += " | " + ::AmenoDimensionTool.lastAnchorSummary
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

    fn reanchorDimension controller whichPoint targetNode targetWorldPoint =
    (
        if ::AmenoAnchorService == undefined then return false
        local res = ::AmenoAnchorService.reanchorDimension controller whichPoint targetNode targetWorldPoint
        refreshDimensions()
        res
    ),

    fn selectAnchors controller =
    (
        if ::AmenoAnchorService == undefined then return false
        ::AmenoAnchorService.selectAnchors controller
    ),

    fn repairOrphans =
    (
        if ::AmenoAnchorService == undefined then return 0
        local count = ::AmenoAnchorService.repairOrphans()
        refreshDimensions()
        count
    ),

    fn syncDimensions force:false =
    (
        if ::AmenoAnchorService == undefined then return 0
        local count = ::AmenoAnchorService.syncAll force:force
        refreshDimensions()
        count
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

    -- E10.2: retorna array com todos os controladores de cota na selecao atual
    fn getSelectedDimensionControllers =
    (
        local controllers = #()
        if selection.count == 0 then return controllers
        for obj in selection where isValidNode obj do
        (
            local dimId = AmenoDimensionGraphics.getDimensionId obj
            if dimId != "" do
            (
                local nodes = AmenoDimensionGraphics.findNodesForDimension dimId
                for n in nodes where isValidNode n do
                (
                    local isCtrl = (AmenoDimensionCA != undefined and AmenoDimensionCA.hasCA n)
                    if isCtrl and (findItem controllers n) == 0 do append controllers n
                )
            )
            -- Tambem aceita controlador selecionado diretamente
            if AmenoDimensionCA != undefined and AmenoDimensionCA.hasCA obj and (findItem controllers obj) == 0 do
                append controllers obj
        )
        controllers
    ),

    -- E10.2: aplica unidade de saida a todas as cotas selecionadas em um Undo
    fn applyUnitToSelected outputUnit =
    (
        local ctrls = getSelectedDimensionControllers()
        if ctrls.count == 0 then return 0
        local count = 0
        undo "Ameno: aplicar unidade a selecionadas" on
        (
            for ctrl in ctrls where isValidNode ctrl do
            (
                if AmenoDimensionCA != undefined do
                (
                    local rec = AmenoDimensionCA.readCA ctrl
                    if rec != undefined do
                    (
                        rec.outputUnit = outputUnit as string
                        AmenoDimensionCA.applyCA ctrl rec
                        try (AmenoDimensionGraphics.rebuildDimension ctrl) catch ()
                        count += 1
                    )
                )
            )
        )
        refreshDimensions()
        count
    ),

    -- E10.2: aplica precisao decimal a todas as cotas selecionadas em um Undo
    fn applyPrecisionToSelected precision =
    (
        local ctrls = getSelectedDimensionControllers()
        if ctrls.count == 0 then return 0
        local count = 0
        undo "Ameno: aplicar precisao a selecionadas" on
        (
            for ctrl in ctrls where isValidNode ctrl do
            (
                if AmenoDimensionCA != undefined do
                (
                    local rec = AmenoDimensionCA.readCA ctrl
                    if rec != undefined do
                    (
                        rec.precision = precision
                        AmenoDimensionCA.applyCA ctrl rec
                        try (AmenoDimensionGraphics.rebuildDimension ctrl) catch ()
                        count += 1
                    )
                )
            )
        )
        refreshDimensions()
        count
    ),

    -- E10.2: aplica modo de cota (aligned/horizontal/vertical) a selecionadas em um Undo
    fn applyDimensionModeToSelected mode =
    (
        local ctrls = getSelectedDimensionControllers()
        if ctrls.count == 0 then return 0
        local count = 0
        undo "Ameno: aplicar modo a selecionadas" on
        (
            for ctrl in ctrls where isValidNode ctrl do
            (
                if AmenoDimensionCA != undefined do
                (
                    local rec = AmenoDimensionCA.readCA ctrl
                    if rec != undefined do
                    (
                        rec.dimensionMode = mode as string
                        AmenoDimensionCA.applyCA ctrl rec
                        try (AmenoDimensionGraphics.rebuildDimension ctrl) catch ()
                        count += 1
                    )
                )
            )
        )
        refreshDimensions()
        count
    ),

    -- E10.2: bake — converte ancoras reativas para posicao mundial fixa
    -- Apos o bake a cota nao segue mais o objeto
    fn bakeSelected =
    (
        local ctrls = getSelectedDimensionControllers()
        if ctrls.count == 0 then return 0
        local count = 0
        undo "Ameno: bake de ancoras a selecionadas" on
        (
            for ctrl in ctrls where isValidNode ctrl do
            (
                if AmenoDimensionCA != undefined do
                (
                    local rec = AmenoDimensionCA.readCA ctrl
                    if rec == undefined then continue
                    if rec.anchorType == "world" then continue  -- ja e mundial, nada a fazer

                    -- Resolver posicoes atuais antes de apagar as ancoras
                    local resolved = AmenoDimensionCA.resolvePoints rec
                    if resolved == undefined then continue

                    rec.anchorType  = "world"
                    rec.pointA      = resolved.pointA
                    rec.pointB      = resolved.pointB
                    rec.offsetPoint = resolved.offsetPoint
                    rec.nodeA       = undefined
                    rec.nodeB       = undefined
                    rec.localPointA = [0, 0, 0]
                    rec.localPointB = [0, 0, 0]
                    rec.anchorVertexIdA = -1
                    rec.anchorVertexIdB = -1
                    rec.anchorEdgeIdA = -1
                    rec.anchorEdgeIdB = -1
                    rec.anchorEdgeMidA = false
                    rec.anchorEdgeMidB = false
                    rec.isOrphan    = false
                    rec.orphanReason = ""

                    AmenoDimensionCA.applyCA ctrl rec
                    try (AmenoDimensionGraphics.rebuildDimension ctrl) catch ()
                    count += 1
                )
            )
        )
        -- Remover nos bakeados do indice reativo de ancoras
        if ::AmenoAnchorService != undefined do
            try (::AmenoAnchorService.rebuildIndex()) catch ()
        refreshDimensions()
        count
    ),

    fn openStyleEditor styleId:undefined useLegacy:false =
    (
        if not useLegacy and ::AmenoStyleEditorWPF != undefined then
        (
            try
            (
                return ::AmenoStyleEditorWPF.open styleId:styleId
            )
            catch
            (
                local exc = getCurrentException() as string
                if ::AmenoLog != undefined do
                    ::AmenoLog.error ("Falha ao abrir editor visual WPF: " + exc + ". Acionando fallback para editor legado.")
                format "[Ameno][ERROR] Falha ao abrir editor visual WPF: %. Acionando fallback para editor legado.\n" exc
            )
        )

        if ::AmenoShowStyleEditor != undefined do ::AmenoShowStyleEditor()
    ),

    fn generateDiagnosticReport =
    (
        if ::AmenoDiagnosticService != undefined then ::AmenoDiagnosticService.generateReport() else undefined
    ),

    fn printDiagnosticReport =
    (
        if ::AmenoDiagnosticService != undefined then ::AmenoDiagnosticService.printReport() else ""
    ),

    fn exportDiagnosticReport targetPath =
    (
        if ::AmenoDiagnosticService != undefined then ::AmenoDiagnosticService.exportReportToFile targetPath else false
    ),

    fn defaultRenderCotasPath =
    (
        if ::AmenoRenderCotasService == undefined then "" else ::AmenoRenderCotasService.defaultOutputPath()
    ),

    fn renderCotas outputPath:"" selectionMode:#all =
    (
        if ::AmenoRenderCotasService == undefined then throw "O serviço Renderizar Cotas não foi carregado."

        local request = ::AmenoRenderCotasService.createRequest outputPath:outputPath selectionMode:selectionMode overwrite:false
        lastRenderResult = ::AmenoRenderCotasService.renderDimensions request
        lastRenderResult
    ),

    fn onSceneOpened =
    (
        if ::AmenoStyleService != undefined do ::AmenoStyleService.loadFromScene()
        if ::AmenoAnchorService != undefined do ::AmenoAnchorService.init()
        if ::AmenoStyleEditorWPF != undefined and ::AmenoStyleEditorWPF.isOpen() do
        (
            try (::AmenoStyleEditorWPF.onSceneReset()) catch ()
        )
        refreshScene()
        refreshDimensions()
        if AmenoRefreshMainPanel != undefined do AmenoRefreshMainPanel()
        true
    ),

    fn onSceneReset =
    (
        if ::AmenoStyleService != undefined do ::AmenoStyleService.loadFromScene()
        if ::AmenoAnchorService != undefined do ::AmenoAnchorService.init()
        if ::AmenoStyleEditorWPF != undefined and ::AmenoStyleEditorWPF.isOpen() do
        (
            try (::AmenoStyleEditorWPF.onSceneReset()) catch ()
        )
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
        if ::AmenoAnchorService != undefined do ::AmenoAnchorService.init()
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
        if ::AmenoAnchorService != undefined do ::AmenoAnchorService.shutdown()
        try (stopTool AmenoDimensionMouseTool) catch ()
        try (if AmenoDimensionTool != undefined do AmenoDimensionTool.cancel()) catch ()
        try (destroyDialog AmenoMainPanelRollout) catch ()
        try (destroyDialog AmenoStyleEditorRollout) catch ()
        try (if ::AmenoStyleEditorWPF != undefined do ::AmenoStyleEditorWPF.close()) catch ()
        started = false
        true
    )
)
