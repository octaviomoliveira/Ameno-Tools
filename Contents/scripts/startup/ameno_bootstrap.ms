/*
    Ameno Tools bootstrap
    Loaded by PackageContents.xml after the 3ds Max UI is available.
*/

global AmenoBootstrap
global AmenoBootstrapState
global AmenoApp
global AmenoRuntime
global AmenoStartupError
global AmenoVersion
global AmenoLog
global AmenoRendererProbe
global AmenoSceneSetup
global AmenoUnitService
global AmenoDimensionPlane
global AmenoDimensionPlaneService
global AmenoDimensionMath
global AmenoDimensionChainMath
global AmenoDimensionChainLayout
global AmenoDimensionChainReferenceLayout
global AmenoDimensionChainSegmentLayout
global AmenoDimensionCA
global AmenoDimensionRecord
global AmenoStyleRecord
global AmenoPreviewModel
global AmenoStyleDraft
global AmenoStyleServiceDefinition
global AmenoStyleService
global AmenoAnchorService
global AmenoDimensionTerminalMesh
global AmenoDimensionGraphics
global AmenoDimensionTool
global AmenoDimensionMouseTool
global AmenoDimensionContinuousTool
global AmenoDimensionContinuousMouseTool
global AmenoContinuousClickClassification
global AmenoContinuousInputSample
global AmenoContinuousSurfaceHit
global AmenoContinuousVertexProbe
global AmenoContinuousPickResult
global AmenoContinuousInputResolver
global AmenoContinuousDiagnostics
global AmenoCoronaRendererAdapter
global AmenoVRayRendererAdapter
global AmenoAdapterRenderResult
global AmenoOutputVerification
global AmenoRenderCotasRequest
global AmenoRenderCotasResult
global AmenoRenderCotasService
global AmenoDiagnosticReport
global AmenoDiagnosticService
global AmenoStyleEditorRollout
global AmenoShowStyleEditor
global AmenoPreviewRenderer
global AmenoStyleEditorWPF
global AmenoStyleEditorWindow
global AmenoMainPanelRollout
global AmenoRenderRollout
global AmenoShowMainPanel
global AmenoRefreshMainPanel
global AmenoCotasWindow
global AmenoCotasCriarTab
global AmenoCotasEstilosTab
global AmenoCotasEditarTab
global AmenoCotasRenderTab
global AmenoPythonUI
global AmenoUiBridge

struct AmenoBootstrapService
(
    rootPath = "",

    fn resolveModulePath relativePath =
    (
        pathConfig.normalizePath (pathConfig.appendPath rootPath relativePath)
    ),

    fn loadModule relativePath =
    (
        local fullPath = resolveModulePath relativePath

        if not doesFileExist fullPath then
        (
            if AmenoLog != undefined do
                try (AmenoLog.error ("Módulo ausente: " + fullPath)) catch ()
            format "[Ameno][ERROR] Módulo ausente: %\n" fullPath
            false
        )
        else
            (
                try
                (
                    fileIn fullPath quiet:true
                    if relativePath == @"core\ameno_logger.ms" and AmenoLog != undefined do
                        try (AmenoLog.startSession()) catch ()
                    true
                )
                catch
                (
                    AmenoStartupError = "Falha ao carregar " + fullPath + ": " + (getCurrentException() as string)
                    if AmenoLog != undefined do
                        try (AmenoLog.error AmenoStartupError) catch ()
                    format "[Ameno][ERROR] %\n" AmenoStartupError
                    false
                )
        )
    ),

    fn start =
    (
        -- O bootstrap e carregado pelo 3ds Max durante o startup. Reexecutar
        -- este arquivo dentro do mesmo processo recompila os structs enquanto
        -- janelas WPF, handlers DotNet e MouseTools da geracao anterior ainda
        -- existem. Isso deixa objetos de duas geracoes vivos e pode derrubar o
        -- bridge mxsdotNet. Um restart completo do Max e o unico teardown
        -- confiavel; portanto a segunda chamada e deliberadamente recusada.
        local currentState = try (AmenoBootstrapState) catch (undefined)
        if currentState == undefined do currentState = #idle

        if currentState == #starting then
        (
            local message = "Bootstrap ignorado: inicializacao ja esta em andamento."
            if AmenoLog != undefined do try (AmenoLog.warn message) catch ()
            format "[Ameno][WARN] %\n" message
            return false
        )

        if currentState == #started then
        (
            local message = "Bootstrap ignorado: Ameno ja esta carregado. Feche e reabra o 3ds Max para recarregar."
            if AmenoLog != undefined do try (AmenoLog.warn message) catch ()
            format "[Ameno][WARN] %\n" message
            return false
        )

        if currentState == #failed then
        (
            local message = "Bootstrap bloqueado apos falha anterior. Feche e reabra o 3ds Max antes de tentar novamente."
            if AmenoLog != undefined do try (AmenoLog.error message) catch ()
            format "[Ameno][ERROR] %\n" message
            return false
        )

        -- Mesmo sem o marcador de estado (por exemplo, apos uma versao
        -- antiga), a existencia de AmenoApp indica que este processo ja teve
        -- uma geracao do plugin. Nao substituir structs/handlers em voo.
        if AmenoApp != undefined then
        (
            local message = "Bootstrap bloqueado: AmenoApp ja existe neste processo. Feche e reabra o 3ds Max para recarregar."
            if AmenoLog != undefined do try (AmenoLog.warn message) catch ()
            format "[Ameno][WARN] %\n" message
            AmenoBootstrapState = #started
            return false
        )

        AmenoBootstrapState = #starting
        AmenoStartupError = ""

        local moduleFiles = #(
            @"core\ameno_version.ms",
            @"core\ameno_logger.ms",
            @"core\ameno_scene_setup.ms",
            @"core\ameno_dimension_plane.ms",
            @"core\ameno_dimensions_math.ms",
            @"core\ameno_dimension_chain_math.ms",
            @"core\ameno_dimension_ca.ms",
            @"core\ameno_dimension_terminal_mesh.ms",
            @"core\ameno_dimension_graphics.ms",
            @"core\ameno_anchor_service.ms",
            @"core\ameno_style_service.ms",
            @"core\ameno_dimension_tool.ms",
            @"core\ameno_continuous_input.ms",
            @"core\ameno_continuous_diagnostics.ms",
            @"core\ameno_continuous_overlay.ms",
            @"core\ameno_dimension_continuous_tool.ms",
            @"renderers\ameno_renderer_probe.ms",
            @"renderers\ameno_corona_adapter.ms",
            @"renderers\ameno_vray_adapter.ms",
            @"core\ameno_render_cotas_service.ms",
            @"core\ameno_diagnostic_service.ms",
            @"core\ameno_runtime.ms",
            @"ui\ameno_ui_bridge.ms",
            @"ui\ameno_python_ui.ms"
        )

        for moduleFile in moduleFiles do
        (
            if not (loadModule moduleFile) then
            (
                AmenoBootstrapState = #failed
                return false
            )
        )

        try
        (
            AmenoApp = AmenoRuntime rootPath:rootPath
            local startResult = AmenoApp.start()
            AmenoBootstrapState = if startResult then #started else #failed
            startResult
        )
        catch
        (
            AmenoStartupError = "Falha ao iniciar Ameno: " + (getCurrentException() as string)
            AmenoBootstrapState = #failed
            if AmenoLog != undefined do try (AmenoLog.error AmenoStartupError) catch ()
            format "[Ameno][ERROR] %\n" AmenoStartupError
            false
        )
    )
)

(
    local bootstrapFile = getSourceFileName()
    local startupPath = getFilenamePath bootstrapFile
    local modulesPath = pathConfig.normalizePath (pathConfig.appendPath startupPath @"..\ameno")

    local existingApp = try (AmenoApp) catch (undefined)
    local currentState = try (AmenoBootstrapState) catch (undefined)
    if currentState == undefined do currentState = #idle

    if existingApp != undefined or currentState != #idle then
    (
        local message = "Bootstrap ignorado: ja existe uma geracao do Ameno neste processo. Feche e reabra o 3ds Max para recarregar."
        if AmenoLog != undefined do try (AmenoLog.warn message) catch ()
        format "[Ameno][WARN] %\n" message
    )
    else
    (
        AmenoBootstrap = AmenoBootstrapService rootPath:modulesPath
        AmenoBootstrap.start()
    )
)
