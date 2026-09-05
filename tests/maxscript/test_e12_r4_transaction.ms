/* E12-R4 — rollback de alocações parciais nas fábricas gráficas. */
(
    global AmenoDimensionGraphics
    global AmenoDimensionCA
    global AmenoSceneSetup
    global AmenoApp
    format "\n=== [AMENO_E12_R4] START source=% ===\n" (getSourceFileName())
    resetMaxFile #noPrompt
    local testPath = getFilenamePath (getSourceFileName())
    local repoRoot = pathConfig.normalizePath (pathConfig.appendPath testPath @"..\..")
    local bootstrapPath = pathConfig.normalizePath (pathConfig.appendPath repoRoot @"Contents\scripts\startup\ameno_bootstrap.ms")
    fileIn bootstrapPath quiet:true
    AmenoApp.prepareScene()

    local totalTests = 0
    local passedTests = 0
    fn r4Eq description actual expected =
    (
        totalTests += 1
        if actual == expected then (passedTests += 1; format "[PASS] %\n" description)
        else format "[FAIL] % expected=<%> actual=<%>\n" description expected actual
    )
    fn r4Ok description value = r4Eq description value true

    local pointA = [0,0,0]
    local pointB = [100,40,0]
    local offset = [0,80,0]
    local baseline = (for n in objects where isValidNode n collect n.handle).count

    for failureStage in #("afterController", "afterLine", "afterText") do
    (
        AmenoDimensionGraphics.setFailureInjection failureStage
        local caught = false
        try (AmenoDimensionGraphics.createDimension pointA pointB offset role:"r4-failure" dimensionMode:#horizontal useUndo:false) catch (caught = true)
        r4Ok ("falha " + failureStage + " propaga excecao") caught
        local current = (for n in objects where isValidNode n collect n.handle).count
        r4Eq ("falha " + failureStage + " restaura contagem de nos") current baseline
        r4Eq ("registro de alocacao fica vazio em " + failureStage) AmenoDimensionGraphics.allocationRegistry.count 0
        r4Eq ("registro de alocacao desativa em " + failureStage) AmenoDimensionGraphics.allocationActive false
    )

    AmenoDimensionGraphics.setFailureInjection ""
    local created = AmenoDimensionGraphics.createDimension pointA pointB offset role:"r4-success" dimensionMode:#horizontal useUndo:false
    r4Ok "sucesso cria uma cota completa" (created != undefined and isValidNode created.controller and isValidNode created.lineNode and isValidNode created.textNode)
    r4Eq "sucesso finaliza registro de alocacao" AmenoDimensionGraphics.allocationActive false
    r4Eq "sucesso limpa registro de alocacao" AmenoDimensionGraphics.allocationRegistry.count 0
    local dimensionId = created.dimensionId
    local createdNodes = AmenoDimensionGraphics.findNodesForDimension dimensionId
    r4Eq "sucesso mantém os três nós" createdNodes.count 3
    AmenoDimensionGraphics.deleteNodes createdNodes
    r4Eq "cleanup da cota de sucesso funciona" (AmenoDimensionGraphics.findNodesForDimension dimensionId).count 0

    format "=== [AMENO_E12_R4] RESULT %/% PASS ===\n" passedTests totalTests
    if passedTests == totalTests then format "[AMENO_TEST][PASS] E12-R4 transaction contract passed.\n"
    else (format "[AMENO_TEST][FAIL] E12-R4 failures=%\n" (totalTests - passedTests); throw "E12-R4 failed")
)
