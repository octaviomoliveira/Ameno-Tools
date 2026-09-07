/* Persistent logger contract: file output is safe and bounded. */

global AmenoVersion
global AmenoLog

(
    local testFile = getSourceFileName()
    local testPath = getFilenamePath testFile
    local repositoryRoot = pathConfig.normalizePath (pathConfig.appendPath testPath @"..\..")
    local versionPath = pathConfig.normalizePath (pathConfig.appendPath repositoryRoot @"Contents\scripts\ameno\core\ameno_version.ms")
    local loggerPath = pathConfig.normalizePath (pathConfig.appendPath repositoryRoot @"Contents\scripts\ameno\core\ameno_logger.ms")

    fileIn versionPath quiet:true
    fileIn loggerPath quiet:true

    local totalTests = 0
    local passedTests = 0

    fn expect description conditionValue =
    (
        totalTests += 1
        if conditionValue then
        (
            passedTests += 1
            format "[PASS] %\n" description
        )
        else format "[FAIL] %\n" description
    )

    format "=== [AMENO_LOGGER] START ===\n"
    local pathValue = AmenoLog.startSession()
    expect "logger returns a path" (pathValue != "")
    expect "logger path exists" (doesFileExist pathValue)
    expect "logger path is under AmenoTools" ((findString pathValue "AmenoTools") != undefined)

    AmenoLog.info "logger-contract-info"
    AmenoLog.warn "logger-contract-warn"
    AmenoLog.error "logger-contract-error"
    local textValue = (dotNetClass "System.IO.File").ReadAllText pathValue
    expect "info is persisted" ((findString textValue "logger-contract-info") != undefined)
    expect "warn is persisted" ((findString textValue "logger-contract-warn") != undefined)
    expect "error is persisted" ((findString textValue "logger-contract-error") != undefined)
    expect "entries remain bounded in memory" (AmenoLog.entries.count <= AmenoLog.maxMemoryEntries)

    AmenoLog.maxFileBytes = 1
    AmenoLog.info "logger-contract-rotation"
    expect "rotation creates a new path" ((findString AmenoLog.logPath "-part2.log") != undefined)
    expect "rotated path exists" (doesFileExist AmenoLog.logPath)

    format "=== [AMENO_LOGGER] RESULT %/% PASS ===\n" passedTests totalTests
    if passedTests == totalTests then
        format "[AMENO_TEST][PASS] Persistent logger contract passed.\n"
    else
    (
        format "[AMENO_TEST][FAIL] Persistent logger failures=%\n" (totalTests - passedTests)
        throw ("Persistent logger failed: " + ((totalTests - passedTests) as string))
    )
)
