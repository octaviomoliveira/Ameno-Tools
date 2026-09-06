/* E12-R0 — probe opt-in, desligado por padrão e sem alterar outcomes. */
(
    global AmenoContinuousDiagnostics
    global AmenoDimensionContinuousTool
    global AmenoContinuousClickClassification

    format "\n=== [AMENO_E12_R0] START source=% ===\n" (getSourceFileName())
    resetMaxFile #noPrompt

    local testPath = getFilenamePath (getSourceFileName())
    local repoRoot = pathConfig.normalizePath (pathConfig.appendPath testPath @"..\..")
    local bootstrapPath = pathConfig.normalizePath (pathConfig.appendPath repoRoot @"Contents\scripts\startup\ameno_bootstrap.ms")
    format "[AMENO_E12_R0] bootstrap=%\n" bootstrapPath
    fileIn bootstrapPath quiet:true

    local totalTests = 0
    local passedTests = 0

    fn r0Eq description actual expected =
    (
        totalTests += 1
        if actual == expected then
        (
            passedTests += 1
            format "[PASS] %\n" description
        )
        else format "[FAIL] % expected=<%> actual=<%>\n" description expected actual
    )

    fn r0Ok description conditionValue = r0Eq description conditionValue true

    r0Ok "diagnostics service loaded" (AmenoContinuousDiagnostics != undefined)
    r0Eq "probe disabled by default" AmenoContinuousDiagnostics.enabled false
    r0Eq "disabled trace is a no-op" (AmenoContinuousDiagnostics.trace #disabledMarker) false
    r0Eq "disabled trace creates no path" AmenoContinuousDiagnostics.logPath ""

    local diagnosticPath = AmenoContinuousDiagnostics.start revision:"test-e12-r0"
    r0Ok "probe starts" AmenoContinuousDiagnostics.enabled
    r0Ok "probe creates a log path" (diagnosticPath != "")
    r0Ok "probe log exists" (doesFileExist diagnosticPath)

    local sourceNode = box name:"E12_R0_SOURCE" length:100 width:100 height:100
    convertToPoly sourceNode
    AmenoDimensionContinuousTool.active = true
    AmenoDimensionContinuousTool.stage = #collecting
    AmenoDimensionContinuousTool.points = #()
    AmenoDimensionContinuousTool.anchorNodes = #()
    AmenoDimensionContinuousTool.anchorVertexIds = #()

    local referenceClick = AmenoContinuousClickClassification kind:#reference node:sourceNode \
        vertexId:1 worldPoint:(polyOp.getVert sourceNode 1) detail:"r0-test-reference"
    local referenceOutcome = AmenoDimensionContinuousTool.handleClassifiedClick referenceClick
    AmenoDimensionContinuousTool.diagnosticTrace #testOutcome #("outcome=" + (referenceOutcome as string))
    r0Eq "instrumentation preserves reference outcome" referenceOutcome #referenceAdded
    r0Eq "instrumentation preserves draft" AmenoDimensionContinuousTool.points.count 1

    AmenoContinuousDiagnostics.trace #throttledMarker throttleKey:"same-candidate"
    local sequenceAfterFirst = AmenoContinuousDiagnostics.sequenceNumber
    AmenoContinuousDiagnostics.trace #throttledMarker throttleKey:"same-candidate"
    r0Eq "identical movement marker is throttled" AmenoContinuousDiagnostics.sequenceNumber sequenceAfterFirst

    local stoppedPath = AmenoContinuousDiagnostics.stop()
    r0Eq "stop returns the same path" stoppedPath diagnosticPath
    r0Eq "probe disabled after stop" AmenoContinuousDiagnostics.enabled false

    local logText = (dotNetClass "System.IO.File").ReadAllText diagnosticPath
    r0Ok "log identifies session start" ((findString logText "event=sessionStart") != undefined)
    r0Ok "log identifies test revision" ((findString logText "revision=test-e12-r0") != undefined)
    r0Ok "log records unchanged outcome" ((findString logText "event=testOutcome | outcome=referenceAdded") != undefined)
    r0Ok "log identifies session stop" ((findString logText "event=sessionStop") != undefined)

    AmenoDimensionContinuousTool.cancel()
    format "=== [AMENO_E12_R0] RESULT %/% PASS ===\n" passedTests totalTests
    if passedTests == totalTests then
        format "[AMENO_TEST][PASS] E12-R0 diagnostics contract passed.\n"
    else
    (
        format "[AMENO_TEST][FAIL] E12-R0 failures=%\n" (totalTests - passedTests)
        throw ("E12-R0 failed: " + ((totalTests - passedTests) as string))
    )
)
