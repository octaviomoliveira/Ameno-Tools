/*
    E13 etapa 5 — terminais, preview e transação.
    Tudo é executado em uma cena Batch descartável; não usa a cena interativa.
*/

(
    global AmenoApp
    global AmenoDimensionGraphics
    global AmenoDimensionTerminalMesh
    global AmenoDimensionCA
    global AmenoDimensionMath
    global AmenoDimensionContinuousTool
    global AmenoContinuousClickClassification
    global AmenoContinuousInputResolver
    global AmenoContinuousInputSample
    global AmenoContinuousSurfaceHit
    global AmenoContinuousVertexProbe
    global AmenoAnchorService
    global AmenoSceneSetup
    global AmenoStyleService

    local testFile = getSourceFileName()
    local testPath = getFilenamePath testFile
    local worktreeRoot = pathConfig.normalizePath (pathConfig.appendPath testPath @"..\..")
    local bootstrapPath = pathConfig.normalizePath (pathConfig.appendPath worktreeRoot @"Contents\scripts\startup\ameno_bootstrap.ms")

    resetMaxFile #noPrompt
    if doesFileExist bootstrapPath then
        fileIn bootstrapPath quiet:true
    else
        throw ("bootstrap nao encontrado: " + bootstrapPath)

    local passed = 0
    local failed = 0
    local errors = #()

    fn check label conditionValue =
    (
        if conditionValue == true then
        (
            passed += 1
            format "[AMENO_TEST][PASS] %\n" label
        )
        else
        (
            failed += 1
            append errors label
            format "[AMENO_TEST][FAIL] %\n" label
        )
    )

    fn nearPoint pointA pointB tolerance:0.001 =
    (
        pointA != undefined and pointB != undefined and (length (pointA - pointB)) <= tolerance
    )

    fn nearValue valueA valueB tolerance:0.001 =
    (
        valueA != undefined and valueB != undefined and (abs (valueA - valueB)) <= tolerance
    )

    fn validNode nodeValue =
    (
        nodeValue != undefined and (try (isValidNode nodeValue) catch false)
    )

    fn worldVert nodeValue vertexIndex =
    (
        if not (validNode nodeValue) then undefined
        else (try (in coordsys world (getVert nodeValue vertexIndex)) catch (undefined))
    )

    fn terminalsFor dimensionId =
    (
        local result = #()
        if ::AmenoDimensionGraphics == undefined or ::AmenoDimensionTerminalMesh == undefined then return result
        for nodeValue in (::AmenoDimensionGraphics.findNodesForDimension dimensionId) where (validNode nodeValue) do
        (
            local isTerminalNode = false
            try (isTerminalNode = ::AmenoDimensionTerminalMesh.isTerminal nodeValue) catch ()
            if isTerminalNode do append result nodeValue
        )
        result
    )

    fn terminalKindSet terminalNodes =
    (
        local kinds = #()
        for nodeValue in terminalNodes where (validNode nodeValue) do
        (
            local kindValue = ::AmenoDimensionTerminalMesh.terminalTypeOf nodeValue
            if (findItem kinds kindValue) == 0 do append kinds kindValue
        )
        kinds
    )

    fn deleteDimensionById dimensionId =
    (
        if dimensionId == undefined or dimensionId == "" then return false
        with undo off
        (
            ::AmenoDimensionGraphics.deleteNodes (::AmenoDimensionGraphics.findNodesForDimension dimensionId)
        )
        true
    )

    fn permanentTerminalCount =
    (
        local count = 0
        if ::AmenoDimensionTerminalMesh == undefined then return count
        for nodeValue in objects where (validNode nodeValue) do
        (
            local isTerminalNode = false
            try (isTerminalNode = ::AmenoDimensionTerminalMesh.isTerminal nodeValue) catch ()
            if isTerminalNode and (::AmenoDimensionGraphics.readTextProperty nodeValue "Ameno.Kind") == "dimensionGraphic" do
                count += 1
        )
        count
    )

    check "servicos de terminais e graficos carregados" (::AmenoDimensionTerminalMesh != undefined and ::AmenoDimensionGraphics != undefined)
    ::AmenoApp.prepareScene()

    -- F: topologia, simetria, plano e estabilidade após várias atualizações.
    local directTypes = #(#arrowClosed, #diamond, #dot)
    local directNames = #("arrowClosed", "diamond", "dot")
    for typeIndex = 1 to directTypes.count do
    (
        local termType = directTypes[typeIndex]
        local nodeValue = undefined
        try
        (
            nodeValue = ::AmenoDimensionTerminalMesh.createTerminal termType [10, 20, 0] [1, 0, 0] 20.0 (color 245 245 245) planeNormal:[0, 0, 1] dimensionId:"stage5-direct"
        )
        catch ()

        check ("cria terminal " + directNames[typeIndex]) (validNode nodeValue)
        if validNode nodeValue do
        (
            local expectedVerts = if termType == #dot then 13 else (if termType == #arrowClosed then 3 else 4)
            local expectedFaces = if termType == #dot then 24 else (if termType == #arrowClosed then 2 else 4)
            check (directNames[typeIndex] + " preserva topologia esperada") (getNumVerts nodeValue == expectedVerts and getNumFaces nodeValue == expectedFaces)
            check (directNames[typeIndex] + " grava tipo e tamanho estaveis") (::AmenoDimensionTerminalMesh.terminalTypeOf nodeValue == termType and nearValue (::AmenoDimensionTerminalMesh.terminalSizeOf nodeValue fallback:undefined) 20.0)
            check (directNames[typeIndex] + " grava normal do plano") (nearPoint (::AmenoDimensionTerminalMesh.terminalPlaneNormalOf nodeValue) [0, 0, 1])

            local stable = true
            local nonZeroArea = true
            local directions = #([1, 0, 0], [0, 1, 0], [-1, 0, 0], [0, -1, 0])
            for stepIndex = 1 to directions.count do
            (
                local targetPoint = [100.0 * stepIndex, 20.0 + (10.0 * stepIndex), 0]
                local updated = false
                try (updated = ::AmenoDimensionTerminalMesh.updateTerminal nodeValue targetPoint directions[stepIndex] size:20.0 planeNormal:[0, 0, 1] dimensionId:"stage5-direct") catch ()
                if not updated do stable = false

                if termType == #arrowClosed then
                (
                    local tipPoint = worldVert nodeValue 1
                    local baseOne = worldVert nodeValue 2
                    local baseTwo = worldVert nodeValue 3
                    local baseCenter = (baseOne + baseTwo) * 0.5
                    local areaValue = length (cross (baseOne - tipPoint) (baseTwo - tipPoint))
                    if not (nearValue (length (tipPoint - baseCenter)) 20.0 tolerance:0.01) do stable = false
                    if not (nearValue (length (baseOne - baseTwo)) 10.0 tolerance:0.01) do stable = false
                    if areaValue <= 0.00001 do nonZeroArea = false
                    if nearPoint baseOne baseTwo tolerance:0.00001 do stable = false
                )
                else if termType == #diamond then
                (
                    local frontPoint = worldVert nodeValue 1
                    local leftPoint = worldVert nodeValue 2
                    local backPoint = worldVert nodeValue 3
                    local rightPoint = worldVert nodeValue 4
                    local areaValue = length (cross (leftPoint - frontPoint) (rightPoint - frontPoint))
                    if not (nearValue (length (frontPoint - backPoint)) 20.0 tolerance:0.01) do stable = false
                    if not (nearValue (length (leftPoint - rightPoint)) 20.0 tolerance:0.01) do stable = false
                    if areaValue <= 0.00001 do nonZeroArea = false
                )
                else
                (
                    local centerPoint = worldVert nodeValue 1
                    if not (nearPoint centerPoint targetPoint tolerance:0.01) do stable = false
                )
            )
            check (directNames[typeIndex] + " atualiza varias vezes sem crescer ou degenerar") (stable and nonZeroArea)
            delete nodeValue
        )
    )

    local rejectedPlane = false
    try
    (
        local invalidNode = ::AmenoDimensionTerminalMesh.createTerminal #arrowClosed [0, 0, 0] [0, 0, 1] 20.0 (color 245 245 245) planeNormal:[0, 0, 1] dimensionId:"stage5-invalid"
        if validNode invalidNode do delete invalidNode
    )
    catch (rejectedPlane = true)
    check "terminal rejeita direcao fora do plano suportado" rejectedPlane

    -- Integração com cota permanente: material, layer, roles e inspect.
    local sceneState = ::AmenoSceneSetup.inspect()
    local technicalStyle = ::AmenoStyleService.getStyle "technical"
    local editorialStyle = ::AmenoStyleService.getStyle "editorial"
    local technicalDim = ::AmenoDimensionGraphics.createDimension [0, 0, 0] [180, 0, 0] [90, 40, 0] role:"stage5" styleId:"technical" style:technicalStyle useUndo:false
    local editorialDim = ::AmenoDimensionGraphics.createDimension [0, 100, 0] [180, 100, 0] [90, 140, 0] role:"stage5" styleId:"editorial" style:editorialStyle useUndo:false

    check "cota tecnica cria dois terminais" (technicalDim != undefined and (terminalsFor technicalDim.dimensionId).count == 2)
    check "cota editorial cria dois terminais" (editorialDim != undefined and (terminalsFor editorialDim.dimensionId).count == 2)
    local technicalTerminals = if technicalDim != undefined then (terminalsFor technicalDim.dimensionId) else #()
    local snapGeometry = box name:"E13_STAGE5_SNAP_GEOMETRY" length:30 width:30 height:30 pos:[0, 40, 0]
    convertToPoly snapGeometry
    local snapRealPoint = ::AmenoDimensionCA.resolveVertexWorld snapGeometry 1
    local snapTerminalPoint = if technicalTerminals.count > 0 then (worldVert technicalTerminals[1] 1) else [0, 0, 0]
    local snapSample = ::AmenoContinuousInputSample eventType:#mouseMove screenPoint:[100, 100] rawWorldPoint:snapTerminalPoint \
        rayValue:(ray [0, 0, 100] [0, 0, -1]) rayStatus:#ok snapHit:true snapNode:(if technicalTerminals.count > 0 then technicalTerminals[1] else undefined) \
        snapWorldPoint:snapTerminalPoint snapStatus:#ok geometryStatus:#ok shortlistStatus:#ok planePoint:[0, 0, 0] planeStatus:#ok
    snapSample.surfaceHits = #(
        (AmenoContinuousSurfaceHit node:(if technicalTerminals.count > 0 then technicalTerminals[1] else undefined) worldPoint:snapTerminalPoint depth:1.0),
        (AmenoContinuousSurfaceHit node:snapGeometry worldPoint:snapRealPoint depth:2.0)
    )
    snapSample.shortlistNodes = if technicalTerminals.count > 0 then #(technicalTerminals[1], snapGeometry) else #(snapGeometry)
    snapSample.vertexProbes = #((AmenoContinuousVertexProbe node:snapGeometry vertexId:1 worldPoint:snapRealPoint screenPoint:[100, 100] depth:2.0))
    local snapPick = ::AmenoContinuousInputResolver.resolveSample snapSample
    check "mesh tecnico coincidente nao e elegivel para snap" (technicalTerminals.count == 2 and not (::AmenoContinuousInputResolver.isEligibleGeometryNode technicalTerminals[1]))
    check "snap sobre terminal nao bloqueia o vertice real coincidente" (snapPick.kind == #reference and snapPick.node == snapGeometry and snapPick.vertexId == 1)
    for dimensionRecord in #(technicalDim, editorialDim) where dimensionRecord != undefined do
    (
        local termNodes = terminalsFor dimensionRecord.dimensionId
        local expectedStyle = if dimensionRecord == technicalDim then technicalStyle else editorialStyle
        local metadataOk = true
        local layerOk = true
        local materialOk = true
        for termNode in termNodes where validNode termNode do
        (
            if ::AmenoDimensionGraphics.readTextProperty termNode "Ameno.GraphicRole" != "terminal" do metadataOk = false
            if ::AmenoDimensionGraphics.readTextProperty termNode "Ameno.Kind" != "dimensionGraphic" do metadataOk = false
            if ::AmenoDimensionGraphics.readTextProperty termNode "Ameno.DimensionId" != dimensionRecord.dimensionId do metadataOk = false
            if termNode.layer.name != sceneState.dimensionsLayer.name do layerOk = false
            if (try (termNode.material == undefined) catch true) do materialOk = false
            if ::AmenoDimensionTerminalMesh.terminalTypeOf termNode != expectedStyle.terminalType do metadataOk = false
        )
        check ("metadata, layer e material do terminal " + dimensionRecord.dimensionId) (metadataOk and layerOk and materialOk)
        check ("inspectDimension reconhece cota " + dimensionRecord.dimensionId + " como saudavel") (::AmenoDimensionGraphics.inspectDimension dimensionRecord.controller == #healthy)
    )

    -- updateDimensionFast através de uma âncora real.
    local anchorNode = box name:"E13_STAGE5_ANCHOR" length:20 width:20 height:20 pos:[20, 220, 0]
    convertToPoly anchorNode
    local anchorPoint = ::AmenoDimensionCA.resolveVertexWorld anchorNode 1
    local anchoredDim = ::AmenoDimensionGraphics.createDimension anchorPoint [220, 220, 0] [120, 270, 0] role:"stage5-anchor" styleId:"technical" style:technicalStyle useUndo:false nodeA:anchorNode anchorVertexIdA:1
    local anchoredTerms = if anchoredDim != undefined then (terminalsFor anchoredDim.dimensionId) else #()
    local oldAnchorTip = if anchoredTerms.count > 0 then worldVert anchoredTerms[1] 1 else undefined
    local localAnchorVertex = try (polyOp.getVert anchorNode 1) catch (undefined)
    if localAnchorVertex != undefined do
    (
        with undo off
        (
            polyOp.setVert anchorNode 1 (localAnchorVertex + [30, 15, 0])
            update anchorNode
        )
    )
    local syncResult = ::AmenoAnchorService.syncDimension anchoredDim.controller
    local anchoredTermsAfter = if anchoredDim != undefined then (terminalsFor anchoredDim.dimensionId) else #()
    local newAnchorTip = if anchoredTermsAfter.count > 0 then worldVert anchoredTermsAfter[1] 1 else undefined
    check "updateDimensionFast acompanha o movimento da ancora nos terminais" (syncResult and anchoredTermsAfter.count == 2 and not (nearPoint oldAnchorTip newAnchorTip tolerance:0.001))
    check "updateDimensionFast preserva tamanho do terminal" (anchoredTermsAfter.count == 2 and nearValue (::AmenoDimensionTerminalMesh.terminalSizeOf anchoredTermsAfter[1] fallback:0.0) (::AmenoDimensionTerminalMesh.terminalSizeOf anchoredTerms[1] fallback:0.0))

    -- Preview de posicionamento: mantém paridade de terminal sem criar preview de segmento extra.
    local preview = ::AmenoDimensionGraphics.createPreviewDimension [0, 360, 0] [180, 360, 0] [90, 400, 0] styleId:"technical"
    local previewTerms = if preview != undefined then (terminalsFor preview.dimensionId) else #()
    local previewStateOk = true
    for previewTerm in previewTerms where validNode previewTerm do
    (
        if ::AmenoDimensionGraphics.readTextProperty previewTerm "Ameno.Kind" != "dimensionPreview" do previewStateOk = false
        if ::AmenoDimensionGraphics.readTextProperty previewTerm "Ameno.GraphicRole" != "preview-terminal" do previewStateOk = false
        if (try (previewTerm.renderable) catch true) do previewStateOk = false
        if (try (previewTerm.isFrozen != true) catch true) do previewStateOk = false
    )
    check "preview tecnica cria terminais nao renderizaveis" (preview != undefined and previewTerms.count == 2 and previewStateOk)

    local updatedPreview = ::AmenoDimensionGraphics.updatePreviewDimension preview [20, 360, 0] [200, 360, 0] [110, 420, 0] styleId:"editorial"
    local updatedPreviewTerms = if updatedPreview != undefined then (terminalsFor updatedPreview.dimensionId) else #()
    local previewDotOk = true
    for previewTerm in updatedPreviewTerms where validNode previewTerm do
        if ::AmenoDimensionTerminalMesh.terminalTypeOf previewTerm != #dot do previewDotOk = false
    check "preview troca o par de terminais ao mudar estilo" (updatedPreview != undefined and updatedPreviewTerms.count == 2 and previewDotOk)
    if preview != undefined do
    (
        ::AmenoDimensionGraphics.removePreviewDimension preview
        check "remocao do preview nao deixa nos" ((::AmenoDimensionGraphics.findNodesForDimension preview.dimensionId).count == 0)
    )

    -- Rebuild/style switch: o par antigo é trocado apenas depois de haver par novo.
    local styleSwitchOk = false
    try
    (
        styleSwitchOk = ::AmenoStyleService.applyStyleToDimension technicalDim.controller "editorial"
    )
    catch ()
    local switchedTerms = terminalsFor technicalDim.dimensionId
    local switchedDot = true
    for switchedTerm in switchedTerms where validNode switchedTerm do
        if ::AmenoDimensionTerminalMesh.terminalTypeOf switchedTerm != #dot do switchedDot = false
    check "rebuild por estilo troca arrowClosed por dot sem cota incompleta" (styleSwitchOk and switchedTerms.count == 2 and switchedDot and ::AmenoDimensionGraphics.inspectDimension technicalDim.controller == #healthy)

    -- Remove fixtures antes da transação para que a contagem de resíduos seja objetiva.
    deleteDimensionById technicalDim.dimensionId
    deleteDimensionById editorialDim.dimensionId
    deleteDimensionById anchoredDim.dimensionId
    if validNode anchorNode do delete anchorNode
    if validNode snapGeometry do delete snapGeometry
    clearUndoBuffer()

    -- E12: duas preview records ficam preservadas em uma falha no segundo par.
    ::AmenoDimensionContinuousTool.cancel()
    ::AmenoDimensionContinuousTool.activeMode = #horizontal
    ::AmenoDimensionContinuousTool.activeStyleId = "technical"
    local began = ::AmenoDimensionContinuousTool.begin()
    local chainA = box name:"E13_STAGE5_CHAIN_A" length:10 width:10 height:10 pos:[0, 520, 0]
    local chainB = box name:"E13_STAGE5_CHAIN_B" length:10 width:10 height:10 pos:[100, 520, 0]
    local chainC = box name:"E13_STAGE5_CHAIN_C" length:10 width:10 height:10 pos:[200, 520, 0]
    convertToPoly chainA
    convertToPoly chainB
    convertToPoly chainC
    local chainPointA = ::AmenoDimensionCA.resolveVertexWorld chainA 1
    local chainPointB = ::AmenoDimensionCA.resolveVertexWorld chainB 1
    local chainPointC = ::AmenoDimensionCA.resolveVertexWorld chainC 1
    local clickA = ::AmenoDimensionContinuousTool.handleClassifiedClick (::AmenoContinuousClickClassification kind:#reference node:chainA vertexId:1 worldPoint:chainPointA)
    local clickB = ::AmenoDimensionContinuousTool.handleClassifiedClick (::AmenoContinuousClickClassification kind:#reference node:chainB vertexId:1 worldPoint:chainPointB)
    local clickC = ::AmenoDimensionContinuousTool.handleClassifiedClick (::AmenoContinuousClickClassification kind:#reference node:chainC vertexId:1 worldPoint:chainPointC)
    local chainPreviewOk = ::AmenoDimensionContinuousTool.refreshChainPreview [100, 600, 0]
    local previewCountBeforeFailure = ::AmenoDimensionContinuousTool.segmentPreviews.count
    local interactiveBeforeFailure = (::AmenoDimensionGraphics.findControllers role:"interactive").count
    ::AmenoDimensionGraphics.setFailureInjection "afterTerminalA" occurrence:2
    local failedCommit = ::AmenoDimensionContinuousTool.commitChain [100, 600, 0]
    check "falha no segundo par de terminais propaga para commitChain" (not failedCommit and ::AmenoDimensionContinuousTool.lastResult == #failed)
    check "falha transacional nao deixa cota permanente parcial" ((::AmenoDimensionGraphics.findControllers role:"interactive").count == interactiveBeforeFailure and permanentTerminalCount() == 0)
    check "falha transacional preserva draft e previews" (::AmenoDimensionContinuousTool.points.count == 3 and ::AmenoDimensionContinuousTool.segmentPreviews.count == previewCountBeforeFailure and ::AmenoDimensionContinuousTool.stage == #collecting)
    check "falha transacional fecha Hold sem suspender Undo" (not (theHold.Holding()) and not (theHold.IsSuspended()))

    ::AmenoDimensionGraphics.setFailureInjection ""
    clearUndoBuffer()
    local committed = ::AmenoDimensionContinuousTool.commitChain [100, 600, 0]
    local committedControllers = ::AmenoDimensionGraphics.findControllers role:"interactive"
    check "nova tentativa cria a cadeia completa" (committed and committedControllers.count == 2 and ::AmenoDimensionContinuousTool.points.count == 0 and ::AmenoDimensionContinuousTool.segmentPreviews.count == 0)
    check "cadeia persistente contem dois pares de terminais" ((terminalsFor (::AmenoDimensionGraphics.getDimensionId committedControllers[1])).count == 2 and (terminalsFor (::AmenoDimensionGraphics.getDimensionId committedControllers[2])).count == 2)

    max undo
    check "Ctrl+Z logico remove a cadeia inteira" ((::AmenoDimensionGraphics.findControllers role:"interactive").count == 0)
    max redo
    check "Ctrl+Y logico restaura a cadeia inteira" ((::AmenoDimensionGraphics.findControllers role:"interactive").count == 2)

    -- Persistência save/load dos nós técnicos.
    local persistedControllers = ::AmenoDimensionGraphics.findControllers role:"interactive"
    local persistedId = if persistedControllers.count > 0 then ::AmenoDimensionGraphics.getDimensionId persistedControllers[1] else ""
    local tempScene = pathConfig.appendPath (getDir #temp) "ameno_e13_stage5.max"
    local saveLoadOk = false
    local autosaveWasEnabled = undefined
    try
    (
        autosaveWasEnabled = autosave.enable
        autosave.enable = false
    )
    catch ()
    deleteFile tempScene
    try
    (
        saveMaxFile tempScene clearNeedSaveFlag:true useNewFile:false quiet:true
        loadMaxFile tempScene quiet:true
        ::AmenoApp.onSceneOpened()
        saveLoadOk = (persistedId != "" and (terminalsFor persistedId).count == 2)
    )
    catch ()
    try (deleteFile tempScene) catch ()
    try (if autosaveWasEnabled != undefined do autosave.enable = autosaveWasEnabled) catch ()
    check "save/load preserva o par de terminais e seus metadados" saveLoadOk

    ::AmenoDimensionContinuousTool.cancel()
    for controllerValue in (::AmenoDimensionGraphics.findControllers role:"interactive") do
        deleteDimensionById (::AmenoDimensionGraphics.getDimensionId controllerValue)
    for nodeValue in #(chainA, chainB, chainC) where validNode nodeValue do delete nodeValue

    format "\n[AMENO_TEST] Resultado etapa 5: % passou(aram), % falhou(aram)\n" passed failed
    if failed == 0 then
        format "[AMENO_TEST][PASS] E13 etapa 5 passou.\n"
    else
    (
        format "[AMENO_TEST][FAIL] Falhas etapa 5: %\n" (errors as string)
        throw ("E13 etapa 5 falhou: " + (failed as string))
    )
)
