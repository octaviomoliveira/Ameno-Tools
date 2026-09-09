/* Launcher MAXScript da interface Python/Qt. */

global AmenoPythonUI
global AmenoPythonUIRequestedPage
global AmenoStartupError

struct AmenoPythonUiService
(
    scriptPath = "",
    initialized = false,

    fn reportError prefix detail =
    (
        AmenoStartupError = prefix + ": " + detail
        format "[Ameno][ERROR] %\n" AmenoStartupError
        if ::AmenoLog != undefined do try (::AmenoLog.error AmenoStartupError) catch ()
        false
    ),

    fn ensurePython =
    (
        try
        (
            python.Init()
            initialized = true
            true
        )
        catch
        (
            -- Init pode informar que o runtime já foi inicializado; nesse caso
            -- ExecuteFile continua sendo seguro.
            initialized = true
            true
        )
    ),

    fn show pageName:"login" =
    (
        if scriptPath == "" then return (reportError "Interface Qt indisponível" "entrypoint.py não foi encontrado.")
        AmenoPythonUIRequestedPage = if pageName == undefined or pageName == "" then "login" else (pageName as string)
        if not (ensurePython()) then return false
        try
        (
            python.ExecuteFile scriptPath
            true
        )
        catch
        (
            reportError "Falha ao abrir interface Python/Qt" (getCurrentException() as string)
        )
    ),

    fn close =
    (
        if not ensurePython() then return false
        try
        (
            python.Execute "import ameno_ui; ameno_ui.close()"
            true
        )
        catch (reportError "Falha ao fechar interface Python/Qt" (getCurrentException() as string))
    ),

    fn isOpen =
    (
        if not ensurePython() then return false
        try
        (
            local value = python.Execute "import ameno_ui; ameno_ui.is_open()"
            value == true
        )
        catch (false)
    )
)

(
    local sourcePath = getSourceFileName()
    local uiPath = getFilenamePath sourcePath
    local pythonRoot = pathConfig.normalizePath (pathConfig.appendPath uiPath @"..\..\..\python")
    local entrypoint = pathConfig.normalizePath (pathConfig.appendPath pythonRoot @"ameno_ui\entrypoint.py")
    if doesFileExist entrypoint then
    (
        AmenoPythonUI = AmenoPythonUiService scriptPath:entrypoint
    )
    else
    (
        AmenoPythonUI = AmenoPythonUiService()
        AmenoStartupError = "Interface Qt indisponível: " + entrypoint
    )
)
