/* E16.5 — lifecycle do callback: 0 ocioso, 1 durante, 0 ao sair. */
(
    global AmenoApp
    global AmenoDimensionContinuousTool
    global AmenoContinuousOverlayService

    resetMaxFile #noPrompt
    local testPath = getFilenamePath (getSourceFileName())
    local repoRoot = pathConfig.normalizePath (pathConfig.appendPath testPath @"..\..")
    local bootstrapPath = pathConfig.normalizePath (pathConfig.appendPath repoRoot @"Contents\scripts\startup\ameno_bootstrap.ms")
    fileIn bootstrapPath quiet:true
    if AmenoApp == undefined then throw "AmenoApp não foi criado."

    local totalTests = 0
    local passedTests = 0
    fn e16cEq description actual expected =
    (
        totalTests += 1
        if actual == expected then
        (
            passedTests += 1
            format "[PASS] %\n" description
        )
        else format "[FAIL] % expected=<%> actual=<%>\n" description expected actual
    )
    fn e16cOk description value = (e16cEq description value true)

    fn callbackCount =
    (
        local callbacks = #()
        try (callbacks = showregisteredRedrawViewsCallbacks asArray:true) catch (callbacks = #())
        if callbacks == undefined then 0 else callbacks.count
    )

    AmenoDimensionContinuousTool.previewBackend = #gw
    AmenoDimensionContinuousTool.active = false
    AmenoDimensionContinuousTool.viewportCallbackRegistered = false
    AmenoDimensionContinuousTool.removeAllPreviews()
    AmenoContinuousOverlayService.clearSession()
    local idleCount = callbackCount()
    local maximumCount = idleCount
    local registrationFailures = 0

    for cycle = 1 to 100 do
    (
        AmenoDimensionContinuousTool.inputSessionId = ("e16-callback-" + (cycle as string))
        AmenoContinuousOverlayService.beginSession AmenoDimensionContinuousTool.inputSessionId style:undefined outputUnitValue:#meters precisionValue:2
        if not AmenoDimensionContinuousTool.registerViewportOverlay() do registrationFailures += 1
        local duringCount = callbackCount()
        if duringCount > maximumCount do maximumCount = duringCount
        if duringCount > idleCount + 1 do registrationFailures += 1
        AmenoDimensionContinuousTool.unregisterViewportOverlay()
        local afterCount = callbackCount()
        if afterCount != idleCount do registrationFailures += 1
    )

    e16cEq "cardinalidade ociosa inicial" idleCount (callbackCount())
    e16cEq "nenhuma falha de registro/teardown" registrationFailures 0
    e16cOk "no máximo um callback adicional" (maximumCount <= idleCount + 1)
    e16cEq "serviço desabilitado ao final" AmenoContinuousOverlayService.enabled false
    e16cEq "modelo limpo ao final" AmenoContinuousOverlayService.model.segments.count 0
    e16cEq "contador de erro de draw finito" (AmenoContinuousOverlayService.model.drawErrorCount >= 0) true

    format "=== [AMENO_E16_CALLBACK] RESULT %/% PASS max=% ===\n" passedTests totalTests maximumCount
    if passedTests == totalTests then
        format "[AMENO_TEST][PASS] E16 callback lifecycle passed.\n"
    else
    (
        format "[AMENO_TEST][FAIL] E16 callback lifecycle failures=%\n" (totalTests - passedTests)
        throw ("E16 callback lifecycle failed: " + ((totalTests - passedTests) as string))
    )
    resetMaxFile #noPrompt
)
