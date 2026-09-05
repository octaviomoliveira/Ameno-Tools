/* E12-B — testes numéricos da linha comum H/V, sem criação de nós gráficos. */
(
    global AmenoDimensionChainMath

    format "\n=== [AMENO_E12_B] START source=% ===\n" (getSourceFileName())
    resetMaxFile #noPrompt

    local testPath = getFilenamePath (getSourceFileName())
    local repoRoot = pathConfig.normalizePath (pathConfig.appendPath testPath @"..\..")
    local bootstrapPath = pathConfig.normalizePath (pathConfig.appendPath repoRoot @"Contents\scripts\startup\ameno_bootstrap.ms")
    format "[AMENO_E12_B] bootstrap=%\n" bootstrapPath
    fileIn bootstrapPath quiet:true

    local totalTests = 0
    local passedTests = 0

    fn e12bEq description actual expected =
    (
        totalTests += 1
        if actual == expected then
        (
            passedTests += 1
            format "[PASS] %\n" description
        )
        else format "[FAIL] % expected=<%> actual=<%>\n" description expected actual
    )

    fn e12bNear description actual expected toleranceValue:0.00001 =
    (
        totalTests += 1
        if abs (actual - expected) <= toleranceValue then
        (
            passedTests += 1
            format "[PASS] %\n" description
        )
        else format "[FAIL] % expected=<%> actual=<%> tolerance=<%>\n" description expected actual toleranceValue
    )

    fn e12bPointNear description actual expected toleranceValue:0.00001 =
    (
        totalTests += 1
        if length (actual - expected) <= toleranceValue then
        (
            passedTests += 1
            format "[PASS] %\n" description
        )
        else format "[FAIL] % expected=<%> actual=<%>\n" description expected actual
    )

    local objectCountBefore = objects.count
    local horizontalPoints = #([0,0,0], [4,1,0], [8,0,0], [12,2,0])
    local horizontalLayout = AmenoDimensionChainMath.layout horizontalPoints [6,3,0] mode:#horizontal millimetersPerSceneUnit:1.0
    e12bEq "horizontal valid" horizontalLayout.valid true
    e12bEq "horizontal has three segments" horizontalLayout.segments.count 3
    for refIndex = 1 to horizontalLayout.orderedReferences.count do
        e12bNear ("horizontal shared Y " + (refIndex as string)) horizontalLayout.orderedReferences[refIndex].projectedPoint.y 3.0
    for segIndex = 1 to horizontalLayout.segments.count do
        e12bNear ("horizontal measure " + (segIndex as string)) horizontalLayout.segments[segIndex].measuredSceneUnits 4.0

    local verticalPoints = #([0,0,0], [1,4,0], [0,8,0], [2,12,0])
    local verticalLayout = AmenoDimensionChainMath.layout verticalPoints [3,6,0] mode:#vertical millimetersPerSceneUnit:1.0
    e12bEq "vertical valid" verticalLayout.valid true
    e12bEq "vertical has three segments" verticalLayout.segments.count 3
    for refIndex = 1 to verticalLayout.orderedReferences.count do
        e12bNear ("vertical shared X " + (refIndex as string)) verticalLayout.orderedReferences[refIndex].projectedPoint.x 3.0
    for segIndex = 1 to verticalLayout.segments.count do
        e12bNear ("vertical measure " + (segIndex as string)) verticalLayout.segments[segIndex].measuredSceneUnits 4.0

    local negativeLayout = AmenoDimensionChainMath.layout horizontalPoints [2,-2,0] mode:#horizontal millimetersPerSceneUnit:1.0
    e12bNear "negative offset retained" negativeLayout.signedOffsetSceneUnits -2.0
    e12bNear "negative baseline retained" negativeLayout.orderedReferences[4].projectedPoint.y -2.0

    local reversePoints = #([12,2,0], [0,0,0], [8,0,0], [4,1,0])
    local reverseLayout = AmenoDimensionChainMath.layout reversePoints [6,3,0] mode:#horizontal millimetersPerSceneUnit:1.0
    e12bEq "reverse pick remains valid" reverseLayout.valid true
    e12bPointNear "reverse order starts spatially at X=0" reverseLayout.orderedReferences[1].sourcePoint [0,0,0]
    e12bEq "reverse order preserves original source index" reverseLayout.orderedReferences[1].sourceIndex 2
    e12bPointNear "reverse order ends spatially at X=12" reverseLayout.orderedReferences[4].sourcePoint [12,2,0]

    local duplicateStation = AmenoDimensionChainMath.layout #([0,0,0], [0,5,0]) [3,2,0] mode:#horizontal millimetersPerSceneUnit:1.0
    e12bEq "coincident projected station invalid" duplicateStation.valid false
    e12bEq "coincident projected station error" duplicateStation.errorCode #coincidentStations

    local scaledLayout = AmenoDimensionChainMath.layout horizontalPoints [6,3,0] mode:#horizontal millimetersPerSceneUnit:1000.0
    e12bNear "unit scale affects millimeters" scaledLayout.segments[1].measuredMillimeters 4000.0

    local invalidScale = AmenoDimensionChainMath.layout horizontalPoints [6,3,0] mode:#horizontal millimetersPerSceneUnit:0.0
    e12bEq "zero unit scale invalid" invalidScale.errorCode #invalidUnitScale
    e12bEq "pure math creates no scene nodes" objects.count objectCountBefore

    format "=== [AMENO_E12_B] RESULT %/% PASS ===\n" passedTests totalTests
    if passedTests == totalTests then
        format "[AMENO_TEST][PASS] E12-B shared H/V layout passed.\n"
    else
    (
        format "[AMENO_TEST][FAIL] E12-B failures=%\n" (totalTests - passedTests)
        throw ("E12-B failed: " + ((totalTests - passedTests) as string))
    )
)
