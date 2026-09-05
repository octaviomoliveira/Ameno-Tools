/*
    E12-R0 — diagnóstico opt-in da interação contínua.

    Não altera picking, estados ou resultado dos handlers. O usuário/QA ativa no
    Listener com AmenoContinuousDiagnostics.start(). O log é persistido fora da
    cena e o serviço fica desligado por padrão.
*/

global AmenoContinuousDiagnostics

struct AmenoContinuousDiagnosticsService
(
    enabled = false,
    sessionId = "",
    sequenceNumber = 0,
    logPath = "",
    revisionLabel = "ba55d95-behavior+r0-probe",
    lastThrottleKey = "",

    fn valueText value =
    (
        if value == undefined then "<undefined>" else (value as string)
    ),

    fn nodeText nodeValue =
    (
        if nodeValue == undefined then return "<undefined>"
        if not isValidNode nodeValue then return "<invalid-node>"
        local nodeName = ""
        local nodeHandle = "?"
        try (nodeName = nodeValue.name) catch ()
        try (nodeHandle = nodeValue.handle as string) catch ()
        nodeName + "#" + nodeHandle
    ),

    fn pointText pointValue =
    (
        if pointValue == undefined then "<undefined>" else (pointValue as string)
    ),

    fn fieldsText fields =
    (
        local result = ""
        if fields != undefined do
        (
            for fieldValue in fields do result += (" | " + (fieldValue as string))
        )
        result
    ),

    fn ensureLogPath =
    (
        if logPath != "" then return logPath

        local basePath = getEnvVariable "LOCALAPPDATA"
        if basePath == undefined or basePath == "" do basePath = getEnvVariable "TEMP"
        if basePath == undefined or basePath == "" then return ""

        local diagnosticsPath = pathConfig.normalizePath (pathConfig.appendPath basePath @"AmenoTools\Diagnostics")
        try ((dotNetClass "System.IO.Directory").CreateDirectory diagnosticsPath) catch (return "")

        local nowValue = (dotNetClass "System.DateTime").Now
        sessionId = nowValue.ToString("yyyyMMdd-HHmmss-fff")
        logPath = pathConfig.normalizePath (pathConfig.appendPath diagnosticsPath ("e12-r0-" + sessionId + ".log"))
        logPath
    ),

    fn trace eventName fields:#() throttleKey:undefined =
    (
        if not enabled then return false

        local resolvedThrottle = if throttleKey == undefined then "" else (throttleKey as string)
        if resolvedThrottle != "" and resolvedThrottle == lastThrottleKey then return false
        if resolvedThrottle != "" do lastThrottleKey = resolvedThrottle

        local resolvedPath = ensureLogPath()
        if resolvedPath == "" then return false

        sequenceNumber += 1
        local timestamp = (dotNetClass "System.DateTime").Now.ToString("o")
        local line = timestamp + " | seq=" + (sequenceNumber as string) + " | event=" + (eventName as string) + (fieldsText fields)

        try
        (
            (dotNetClass "System.IO.File").AppendAllText resolvedPath (line + "\r\n")
            format "[Ameno][E12-R0] %\n" line
            true
        )
        catch false
    ),

    fn start revision:undefined =
    (
        enabled = true
        sequenceNumber = 0
        sessionId = ""
        logPath = ""
        lastThrottleKey = ""
        if revision != undefined do revisionLabel = revision as string
        local started = trace #sessionStart #(
            "revision=" + revisionLabel,
            "maxVersion=" + ((maxVersion())[1] as string),
            "scene=" + (maxFilePath + maxFileName)
        )
        if started do format "[Ameno][E12-R0] Diagnóstico ativo: %\n" logPath
        logPath
    ),

    fn stop =
    (
        if enabled do trace #sessionStop #("revision=" + revisionLabel)
        enabled = false
        lastThrottleKey = ""
        format "[Ameno][E12-R0] Diagnóstico encerrado: %\n" logPath
        logPath
    ),

    fn status =
    (
        #("enabled=" + (enabled as string), "revision=" + revisionLabel, "logPath=" + logPath)
    )
)

AmenoContinuousDiagnostics = AmenoContinuousDiagnosticsService()
