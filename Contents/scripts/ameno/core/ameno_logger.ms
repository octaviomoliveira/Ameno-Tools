global AmenoLog
global AmenoVersion

/*
    Logger persistente do Ameno Tools.

    O Listener continua recebendo as mensagens para depuração imediata, mas
    cada sessão também é gravada em:
        %LOCALAPPDATA%\AmenoTools\Logs\ameno-<sessao>.log

    A gravação é deliberadamente best-effort: uma falha de I/O nunca pode
    interromper o MaxScript nem derrubar o 3ds Max. O arquivo muda para uma
    parte nova ao atingir o limite de tamanho configurado.
*/

struct AmenoLogger
(
    prefix = "Ameno",
    entries = #(),
    logDirectory = "",
    logPath = "",
    sessionId = "",
    filePart = 1,
    maxFileBytes = 2097152,
    maxMemoryEntries = 200,

    fn nowText =
    (
        try
        (
            local dateTimeClass = dotNetClass "System.DateTime"
            dateTimeClass.Now.ToString("yyyy-MM-dd HH:mm:ss.fff")
        )
        catch "unknown-time"
    ),

    fn safeVersionText =
    (
        local result = "unknown"
        try
        (
            if AmenoVersion != undefined do result = AmenoVersion.displayName()
        )
        catch ()
        result
    ),

    fn safeMaxText =
    (
        local result = "unknown"
        try (result = (maxVersion())[1] as string) catch ()
        result
    ),

    fn safeSceneText =
    (
        local result = ""
        try (result = maxFilePath + maxFileName) catch ()
        if result == "" then "<untitled>" else result
    ),

    fn buildLogPath =
    (
        local environmentClass = dotNetClass "System.Environment"
        local basePath = environmentClass.GetEnvironmentVariable "LOCALAPPDATA"
        if basePath == undefined or basePath == "" do
            basePath = environmentClass.GetEnvironmentVariable "TEMP"
        if basePath == undefined or basePath == "" then return ""

        logDirectory = pathConfig.normalizePath (pathConfig.appendPath basePath @"AmenoTools\Logs")
        try ((dotNetClass "System.IO.Directory").CreateDirectory logDirectory) catch (return "")

        local nowValue = dotNetClass "System.DateTime"
        sessionId = nowValue.Now.ToString("yyyyMMdd-HHmmss-fff")
        filePart = 1
        logPath = pathConfig.normalizePath (pathConfig.appendPath logDirectory ("ameno-" + sessionId + ".log"))
        logPath
    ),

    fn ensureLogPath =
    (
        if logPath == "" do buildLogPath()
        logPath
    ),

    fn rotateIfNeeded =
    (
        local currentPath = ensureLogPath()
        if currentPath == "" then return ""

        try
        (
            if doesFileExist currentPath do
            (
                local fileInfo = dotNetObject "System.IO.FileInfo" currentPath
                if fileInfo.Length >= maxFileBytes do
                (
                    filePart += 1
                    local stem = pathConfig.appendPath logDirectory ("ameno-" + sessionId + "-part" + (filePart as string) + ".log")
                    logPath = pathConfig.normalizePath stem
                )
            )
        )
        catch ()
        logPath
    ),

    fn write level message =
    (
        local line = ""
        try
        (
            local levelText = toUpper (level as string)
            local messageText = if message == undefined then "<undefined>" else (message as string)
            line = "[" + (nowText()) + "][" + prefix + "][" + levelText + "] " + messageText

            append entries line
            if entries.count > maxMemoryEntries do deleteItem entries 1
            format "%\n" line

            local currentPath = rotateIfNeeded()
            if currentPath != "" do
                try ((dotNetClass "System.IO.File").AppendAllText currentPath (line + "\r\n")) catch ()
        )
        catch
        (
            -- O logger não pode lançar uma segunda exceção no caminho de erro.
            try (format "[Ameno][LOGGER_ERROR] falha ao registrar mensagem.\n") catch ()
        )
        line
    ),

    fn startSession =
    (
        entries = #()
        logDirectory = ""
        logPath = ""
        sessionId = ""
        filePart = 1
        local currentPath = ensureLogPath()
        if currentPath != "" do
        (
            write #info ("Sessão iniciada · versão=" + (safeVersionText()) + " · max=" + (safeMaxText()))
            write #info ("Cena=" + (safeSceneText()))
        )
        currentPath
    ),

    fn info message =
    (
        write #info message
    ),

    fn warn message =
    (
        write #warn message
    ),

    fn error message =
    (
        write #error message
    ),

    fn clear =
    (
        entries = #()
        true
    )
)

AmenoLog = AmenoLogger()
