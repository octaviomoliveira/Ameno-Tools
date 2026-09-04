/*
    Ameno Tools bootstrap
    Loaded by PackageContents.xml after the 3ds Max UI is available.
*/

global AmenoBootstrap
global AmenoApp
global AmenoRuntime

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
            format "[Ameno][ERROR] Módulo ausente: %\n" fullPath
            false
        )
        else
        (
            try
            (
                fileIn fullPath quiet:true
                true
            )
            catch
            (
                format "[Ameno][ERROR] Falha ao carregar %: %\n" fullPath (getCurrentException())
                false
            )
        )
    ),

    fn start =
    (
        local moduleFiles = #(
            @"core\ameno_version.ms",
            @"core\ameno_logger.ms",
            @"core\ameno_scene_setup.ms",
            @"renderers\ameno_renderer_probe.ms",
            @"core\ameno_runtime.ms",
            @"ui\ameno_main_panel.ms"
        )

        for moduleFile in moduleFiles do
        (
            if not (loadModule moduleFile) then return false
        )

        if AmenoApp != undefined do
        (
            try (AmenoApp.shutdown()) catch ()
        )

        AmenoApp = AmenoRuntime rootPath:rootPath
        AmenoApp.start()
    )
)

(
    local bootstrapFile = getSourceFileName()
    local startupPath = getFilenamePath bootstrapFile
    local modulesPath = pathConfig.normalizePath (pathConfig.appendPath startupPath @"..\ameno")

    AmenoBootstrap = AmenoBootstrapService rootPath:modulesPath
    AmenoBootstrap.start()
)
