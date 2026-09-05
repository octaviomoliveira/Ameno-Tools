/* E12-A — contrato de input, sem layout, nós gráficos ou instalação. */
(
    global AmenoDimensionContinuousTool
    global AmenoContinuousClickClassification

    format "\n=== [AMENO_E12_A] START source=% ===\n" (getSourceFileName())
    resetMaxFile #noPrompt

    local testPath = getFilenamePath (getSourceFileName())
    local repoRoot = pathConfig.normalizePath (pathConfig.appendPath testPath @"..\..")
    local bootstrapPath = pathConfig.normalizePath (pathConfig.appendPath repoRoot @"Contents\scripts\startup\ameno_bootstrap.ms")
    format "[AMENO_E12_A] bootstrap=%\n" bootstrapPath
    fileIn bootstrapPath quiet:true

    local totalTests = 0
    local passedTests = 0

    fn e12aEq description actual expected =
    (
        totalTests += 1
        if actual == expected then
        (
            passedTests += 1
            format "[PASS] %\n" description
        )
        else format "[FAIL] % expected=<%> actual=<%>\n" description expected actual
    )

    fn e12aOk description conditionValue = e12aEq description conditionValue true

    fn e12aReset =
    (
        AmenoDimensionContinuousTool.active = true
        AmenoDimensionContinuousTool.stage = #collecting
        AmenoDimensionContinuousTool.points = #()
        AmenoDimensionContinuousTool.anchorNodes = #()
        AmenoDimensionContinuousTool.anchorVertexIds = #()
        AmenoDimensionContinuousTool.segmentPreviews = #()
        AmenoDimensionContinuousTool.activePreview = undefined
        AmenoDimensionContinuousTool.hudOpen = false
    )

    local sourceNode = box name:"E12_INPUT_SOURCE" length:100 width:100 height:100
    convertToPoly sourceNode
    local refA = AmenoContinuousClickClassification kind:#reference node:sourceNode vertexId:1 worldPoint:[-50,-50,0]
    local refB = AmenoContinuousClickClassification kind:#reference node:sourceNode vertexId:2 worldPoint:[50,-50,0]
    local geometryHit = AmenoContinuousClickClassification kind:#geometryWithoutReference node:sourceNode
    local emptyHit = AmenoContinuousClickClassification kind:#empty
    local ambiguousHit = AmenoContinuousClickClassification kind:#ambiguous

    e12aReset()
    e12aEq "reference A is added" (AmenoDimensionContinuousTool.handleClassifiedClick refA) #referenceAdded
    e12aEq "first reference count" AmenoDimensionContinuousTool.points.count 1
    e12aEq "geometry without vertex does not finish" (AmenoDimensionContinuousTool.handleClassifiedClick geometryHit) #geometryWithoutReference
    e12aEq "geometry click preserves count" AmenoDimensionContinuousTool.points.count 1
    e12aEq "ambiguous snap does not finish" (AmenoDimensionContinuousTool.handleClassifiedClick ambiguousHit) #ambiguous
    e12aEq "ambiguous click preserves stage" AmenoDimensionContinuousTool.stage #collecting
    e12aEq "empty with one reference needs more" (AmenoDimensionContinuousTool.handleClassifiedClick emptyHit) #needsMoreReferences
    e12aEq "empty with one preserves stage" AmenoDimensionContinuousTool.stage #collecting

    -- Chamadas consecutivas, sem timer: ambas devem ser aceitas.
    e12aEq "rapid reference B is added" (AmenoDimensionContinuousTool.handleClassifiedClick refB) #referenceAdded
    e12aEq "two consecutive references retained" AmenoDimensionContinuousTool.points.count 2
    e12aEq "duplicate identity rejected" (AmenoDimensionContinuousTool.handleClassifiedClick refB) #duplicateReference
    e12aEq "duplicate preserves count" AmenoDimensionContinuousTool.points.count 2
    e12aEq "first empty requests commit" (AmenoDimensionContinuousTool.handleClassifiedClick emptyHit) #commitRequested
    e12aEq "commit request freezes state" AmenoDimensionContinuousTool.stage #committing
    e12aEq "input ignored while committing" (AmenoDimensionContinuousTool.handleClassifiedClick refA) #ignored

    e12aReset()
    local anchorA = AmenoDimensionAnchorHit node:sourceNode vertexId:1 vertexWorldPoint:[-50,-50,0]
    local anchorGeometry = AmenoDimensionAnchorHit node:sourceNode vertexId:-1
    e12aEq "detected vertex classifies reference" (AmenoDimensionContinuousTool.classifyDetectedHit anchorA).kind #reference
    e12aEq "detected node without vertex classifies geometry" (AmenoDimensionContinuousTool.classifyDetectedHit anchorGeometry).kind #geometryWithoutReference
    e12aEq "no hit and no snap classifies empty" (AmenoDimensionContinuousTool.classifyDetectedHit undefined).kind #empty
    e12aEq "snap without eligible node is ambiguous" (AmenoDimensionContinuousTool.classifyDetectedHit undefined snapHit:true).kind #ambiguous

    AmenoDimensionContinuousTool.onAbort 1
    e12aEq "right-click/abort cancels" AmenoDimensionContinuousTool.stage #idle
    e12aEq "cancel clears references" AmenoDimensionContinuousTool.points.count 0

    format "=== [AMENO_E12_A] RESULT %/% PASS ===\n" passedTests totalTests
    if passedTests == totalTests then
        format "[AMENO_TEST][PASS] E12-A input contract passed.\n"
    else
    (
        format "[AMENO_TEST][FAIL] E12-A failures=%\n" (totalTests - passedTests)
        throw ("E12-A failed: " + ((totalTests - passedTests) as string))
    )
)
