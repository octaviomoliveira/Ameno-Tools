/*
    E3 — Construtor gráfico de uma cota alinhada.

    Esta camada recebe uma geometria já resolvida por AmenoDimensionMath e cria
    apenas os nós visuais e o controlador técnico da cota. A ferramenta de
    cliques entra na E4; por enquanto createTestDimension() é o ponto de entrada
    intencionalmente determinístico para validar a presença no viewport e render.
*/

global AmenoDimensionGraphics
global AmenoDimensionCA
global AmenoDimensionRecord
global AmenoStyleService
global AmenoAnchorService
global AmenoDimensionTerminalMesh

struct AmenoDimensionAuditRecord
(
    dimensionId = "",
    mode = #measured,
    measuredMillimeters = 0.0,
    displayMillimeters = 0.0,
    deltaMillimeters = 0.0,
    measuredText = "",
    displayText = "",
    deltaText = "",
    manualReason = "",
    isManual = false,
    anchorType = "world",
    anchorDesc = "Mundial",
    isOrphan = false,
    orphanReason = ""
)

struct AmenoGraphicDimensionRecord
(
    dimensionId = "",
    controller = undefined,
    lineNode = undefined,
    textNode = undefined,
    markerNode = undefined,
    layout = undefined,
    displayText = "",
    audit = undefined,
    style = undefined,
    termNodeA = undefined,
    termNodeB = undefined
)

struct AmenoDimensionGraphicsService
(
    dataSchemaVersion = 5,
    graphicSchemaVersion = 1,
    schemaVersion = 3, -- mantido para compatibilidade retroativa
    controllerKind = "dimension",
    graphicKind = "dimensionGraphic",
    testRole = "test",
    allocationRegistry = #(),
    allocationActive = false,
    failureInjection = "",
    failureInjectionRemaining = 1,
    textFollowsLine = true,

    fn orientTextNode textNode layout followLine =
    (
        local angle = 0.0
        if followLine do
        (
            angle = atan2 layout.direction.y layout.direction.x
            if angle > 90.0 do angle -= 180.0
            if angle <= -90.0 do angle += 180.0
        )
        textNode.rotation = quat angle [0,0,1]
        true
    ),

    fn setFailureInjection stageName occurrence:1 =
    (
        failureInjection = if stageName == undefined then "" else (stageName as string)
        failureInjectionRemaining = if occurrence == undefined or occurrence < 1 then 1 else occurrence
        true
    ),

    fn maybeInjectFailure stageName =
    (
        if failureInjection == (stageName as string) do
        (
            if failureInjectionRemaining <= 1 then
                throw ("Falha injetada: " + (stageName as string))
            failureInjectionRemaining -= 1
        )
        true
    ),

    fn beginAllocation =
    (
        allocationRegistry = #()
        allocationActive = true
        true
    ),

    fn registerAllocation nodeValue =
    (
        if allocationActive and nodeValue != undefined and isValidNode nodeValue and (findItem allocationRegistry nodeValue) == 0 do
            append allocationRegistry nodeValue
        nodeValue
    ),

    fn finishAllocation =
    (
        local allocated = allocationRegistry
        allocationRegistry = #()
        allocationActive = false
        allocated
    ),

    fn rollbackAllocation =
    (
        local allocated = allocationRegistry
        local undoHolding = false
        try (undoHolding = theHold.Holding()) catch ()

        -- Quando uma fábrica falha dentro de um `undo ... on` externo, não
        -- suspenda o mesmo Hold novamente. Remover explicitamente os nós
        -- alocados antes de propagar a exceção torna o rollback independente
        -- do comportamento do chamador e ainda preserva o Hold externo.
        if undoHolding then
        (
            for i = allocated.count to 1 by -1 do
                if allocated[i] != undefined and isValidNode allocated[i] do delete allocated[i]
            allocationRegistry = #()
            allocationActive = false
        )
        else
        (
            with undo off
            (
                for i = allocated.count to 1 by -1 do
                    if allocated[i] != undefined and isValidNode allocated[i] do delete allocated[i]
            )
            allocationRegistry = #()
            allocationActive = false
        )
        true
    ),

    fn toSceneUnits valMm =
    (
        if ::AmenoUnitService != undefined then
            ::AmenoUnitService.millimetersToSceneUnits (valMm as float)
        else
            (valMm as float)
    ),

    fn setTextProperty node propertyName value =
    (
        AmenoSceneSetup.setTextProperty node propertyName value
    ),

    fn readTextProperty node propertyName =
    (
        AmenoSceneSetup.readTextProperty node propertyName
    ),

    fn setPointProperty node propertyName pointValue =
    (
        if node == undefined or not isValidNode node then return false

        try
        (
            setUserPropVal node propertyName pointValue
            true
        )
        catch
        (
            false
        )
    ),

    fn readPointProperty node propertyName =
    (
        if node == undefined or not isValidNode node then return undefined

        local value = undefined
        try (value = getUserPropVal node propertyName) catch ()

        if value != undefined and (classof value == Point3) then value else undefined
    ),

    fn getDimensionId node =
    (
        if node == undefined or not isValidNode node then return ""
        if AmenoDimensionCA != undefined and AmenoDimensionCA.hasCA node then
        (
            local rec = AmenoDimensionCA.readCA node
            if rec != undefined and rec.dimensionId != "" then return rec.dimensionId
        )
        local idVal = readTextProperty node "Ameno.DimensionId"
        if idVal == undefined then "" else idVal
    ),

    fn getDimensionRole node =
    (
        if node == undefined or not isValidNode node then return ""
        if AmenoDimensionCA != undefined and AmenoDimensionCA.hasCA node then
        (
            local rec = AmenoDimensionCA.readCA node
            if rec != undefined and rec.dimensionRole != "" then return rec.dimensionRole
        )
        local roleVal = readTextProperty node "Ameno.DimensionRole"
        if roleVal == undefined then "" else roleVal
    ),

    fn ensureSceneReady =
    (
        local sceneState = AmenoSceneSetup.inspect()
        if sceneState.status != #ready do sceneState = AmenoSceneSetup.prepare()
        sceneState
    ),

    fn createDimensionMaterial =
    (
        local dimensionMaterial = standardMaterial name:(uniqueName "AMENO_DIMENSION_MTL_")

        try (dimensionMaterial.diffuse = (color 245 245 245)) catch ()
        try (dimensionMaterial.selfIllumAmount = 100.0) catch ()

        dimensionMaterial
    ),

    fn isMeshTerminalType terminalType =
    (
        terminalType == #arrowClosed or terminalType == #diamond or terminalType == #dot
    ),

    fn layoutPlaneNormal layout =
    (
        if layout == undefined then return undefined

        local planeNormal = undefined
        try (planeNormal = layout.planeNormal) catch ()
        if planeNormal == undefined or (try ((length planeNormal) < 0.00001) catch (true)) do
        (
            try (planeNormal = cross layout.direction layout.perpendicular) catch (planeNormal = undefined)
        )

        local normalLength = 0.0
        try (normalLength = length planeNormal) catch (normalLength = 0.0)
        if normalLength < 0.00001 then return undefined
        normalize planeNormal
    ),

    fn terminalColour audit =
    (
        if audit != undefined and audit.isOrphan then (color 230 70 70)
        else if audit != undefined and audit.isManual then (color 245 166 35)
        else (color 245 245 245)
    ),

    fn terminalNodesForDimension dimensionId =
    (
        local matches = #()
        if dimensionId == undefined or dimensionId == "" then return matches
        if ::AmenoDimensionTerminalMesh == undefined then return matches

        -- Este helper fica antes de findNodesForDimension na struct. Fazer a
        -- varredura local evita uma chamada antecipada a um método ainda não
        -- resolvido pelo runtime MaxScript.
        for node in objects where isValidNode node do
        (
            if (getDimensionId node) == dimensionId do
            (
                local isTerminalNode = false
                try (isTerminalNode = ::AmenoDimensionTerminalMesh.isTerminal node) catch ()
                if isTerminalNode do append matches node
            )
        )
        matches
    ),

    fn terminalSide nodeValue =
    (
        if ::AmenoDimensionTerminalMesh == undefined or nodeValue == undefined or not isValidNode nodeValue then ""
        else (try (::AmenoDimensionTerminalMesh.terminalSideOf nodeValue) catch (""))
    ),

    fn terminalPairForDimension dimensionId layout =
    (
        local pair = #(undefined, undefined)
        local candidates = terminalNodesForDimension dimensionId
        for node in candidates do
        (
            local sideValue = terminalSide node
            if sideValue == "A" and pair[1] == undefined then pair[1] = node
            else if sideValue == "B" and pair[2] == undefined then pair[2] = node
        )

        local unassigned = for node in candidates where (findItem pair node) == 0 collect node
        if pair[1] == undefined and unassigned.count > 0 do
        (
            pair[1] = unassigned[1]
            deleteItem unassigned 1
        )
        if pair[2] == undefined and unassigned.count > 0 do pair[2] = unassigned[1]
        pair
    ),

    fn decorateTerminalNode nodeValue dimensionId dimensionsLayer material preview:false side:"" =
    (
        if nodeValue == undefined or not isValidNode nodeValue then return false
        if ::AmenoDimensionTerminalMesh != undefined and side != "" do
            try (::AmenoDimensionTerminalMesh.setTerminalSide nodeValue side) catch ()

        local roleValue = if preview then "preview-terminal" else "terminal"
        -- Este helper precede decorateGraphicNode/configurePreviewNode na
        -- struct; qualificar pelo serviço evita resolução antecipada de método.
        ::AmenoDimensionGraphics.decorateGraphicNode nodeValue dimensionId roleValue dimensionsLayer
        if material != undefined do nodeValue.material = material
        if preview then
        (
            setTextProperty nodeValue "Ameno.Kind" "dimensionPreview"
            setTextProperty nodeValue "Ameno.Preview" "1"
            ::AmenoDimensionGraphics.configurePreviewNode nodeValue
        )
        true
    ),

    fn _syncTerminalNodesCore dimensionId layout audit style dimensionsLayer material:undefined preview:false =
    (
        if layout == undefined or not layout.valid then throw "Não foi possível sincronizar terminais: layout inválido."

        local expectedType = #tick
        local expectedSize = 80.0
        if style != undefined do
        (
            expectedType = style.terminalType
            expectedSize = style.terminalSize
        )

        local existingPair = terminalPairForDimension dimensionId layout
        local currentA = existingPair[1]
        local currentB = existingPair[2]
        local expectedMesh = isMeshTerminalType expectedType

        if not expectedMesh then
        (
            for node in (terminalNodesForDimension dimensionId) where isValidNode node do
                try (::AmenoDimensionTerminalMesh.removeTerminal node) catch (delete node)
            return #(undefined, undefined)
        )

        if ::AmenoDimensionTerminalMesh == undefined then
            throw "O serviço de terminais mesh não está disponível; a cota não pode ser concluída."

        local planeNormal = layoutPlaneNormal layout
        if planeNormal == undefined then
            throw "O layout não expõe um plano suportado para os terminais mesh."

        local terminalSizeScene = toSceneUnits expectedSize
        if terminalSizeScene <= 0.00001 then
            throw "O tamanho do terminal mesh deve ser maior que zero."

        local pairMatches = (currentA != undefined and currentB != undefined)
        if pairMatches do
        (
            pairMatches = ((::AmenoDimensionTerminalMesh.terminalTypeOf currentA) == expectedType and \
                           (::AmenoDimensionTerminalMesh.terminalTypeOf currentB) == expectedType)
            if pairMatches and expectedType == #dot do
            (
                pairMatches = (getNumVerts currentA == 13 and getNumFaces currentA == 24 and \
                               getNumVerts currentB == 13 and getNumFaces currentB == 24)
            )
        )

        local newA = currentA
        local newB = currentB
        if not pairMatches then
        (
            -- Cria o par novo antes de remover o antigo. Se a segunda criação
            -- falhar, a alocação corrente faz rollback sem deixar uma cota
            -- incompleta nem apagar um par antigo ainda utilizável.
            newA = ::AmenoDimensionTerminalMesh.createTerminal expectedType layout.linePointA (-layout.direction) terminalSizeScene (terminalColour audit) planeNormal:planeNormal dimensionId:dimensionId
            registerAllocation newA
            if newA == undefined or not isValidNode newA then throw "O terminal A obrigatório não foi criado."
            maybeInjectFailure #afterTerminalA

            newB = ::AmenoDimensionTerminalMesh.createTerminal expectedType layout.linePointB layout.direction terminalSizeScene (terminalColour audit) planeNormal:planeNormal dimensionId:dimensionId
            registerAllocation newB
            if newB == undefined or not isValidNode newB then throw "O terminal B obrigatório não foi criado."
            maybeInjectFailure #afterTerminalB

            if currentA != undefined and isValidNode currentA do try (::AmenoDimensionTerminalMesh.removeTerminal currentA) catch (delete currentA)
            if currentB != undefined and isValidNode currentB do try (::AmenoDimensionTerminalMesh.removeTerminal currentB) catch (delete currentB)
        )
        else
        (
            if not (::AmenoDimensionTerminalMesh.updateTerminal currentA layout.linePointA (-layout.direction) size:terminalSizeScene planeNormal:planeNormal dimensionId:dimensionId) then
                throw "O terminal A obrigatório não pôde ser atualizado."
            if not (::AmenoDimensionTerminalMesh.updateTerminal currentB layout.linePointB layout.direction size:terminalSizeScene planeNormal:planeNormal dimensionId:dimensionId) then
                throw "O terminal B obrigatório não pôde ser atualizado."
            maybeInjectFailure #afterTerminalUpdate
        )

        decorateTerminalNode newA dimensionId dimensionsLayer material preview:preview side:"A"
        decorateTerminalNode newB dimensionId dimensionsLayer material preview:preview side:"B"
        newA.wirecolor = terminalColour audit
        newB.wirecolor = terminalColour audit
        #(newA, newB)
    ),

    fn syncTerminalNodes dimensionId layout audit style dimensionsLayer material:undefined preview:false =
    (
        -- Chamadas de atualização/previsão podem ocorrer fora de uma criação
        -- transacional. Abrir um escopo local garante rollback também nesse
        -- caminho; criação/rebuild continuam usando o escopo externo.
        local ownsAllocation = not allocationActive
        if ownsAllocation do beginAllocation()

        try
        (
            local result = _syncTerminalNodesCore dimensionId layout audit style dimensionsLayer material:material preview:preview
            if ownsAllocation do finishAllocation()
            result
        )
        catch
        (
            if ownsAllocation do rollbackAllocation()
            throw
        )
    ),

    fn addLineSpline shapeNode pointA pointB =
    (
        local splineIndex = addNewSpline shapeNode
        addKnot shapeNode splineIndex #corner #line pointA
        addKnot shapeNode splineIndex #corner #line pointB
        splineIndex
    ),

    fn addClosedPolygonSpline shapeNode points =
    (
        local splineIndex = addNewSpline shapeNode
        for p in points do addKnot shapeNode splineIndex #corner #line p
        close shapeNode splineIndex
        splineIndex
    ),

    fn addOpenPolylineSpline shapeNode points =
    (
        local splineIndex = addNewSpline shapeNode
        for p in points do addKnot shapeNode splineIndex #corner #line p
        splineIndex
    ),

    fn addTerminals shapeNode layout terminalType terminalSize =
    (
        local lineEndA = layout.linePointA
        local lineEndB = layout.linePointB

        case terminalType of
        (
            #arrowClosed:
            (
                -- Terminais mesh flat preenchidos sao criados como nos separados via AmenoDimensionTerminalMesh
            )
            #diamond:
            (
                -- Terminais mesh flat preenchidos sao criados como nos separados via AmenoDimensionTerminalMesh
            )
            #dot:
            (
                -- Terminais mesh flat preenchidos sao criados como nos separados via AmenoDimensionTerminalMesh
            )
            #arrowOpen:
            (
                local arrowLen = terminalSize
                local arrowHalfWidth = terminalSize * 0.25
                local wingA1 = lineEndA + (layout.direction * arrowLen) + (layout.perpendicular * arrowHalfWidth)
                local wingA2 = lineEndA + (layout.direction * arrowLen) - (layout.perpendicular * arrowHalfWidth)
                addOpenPolylineSpline shapeNode #(wingA1, lineEndA, wingA2)

                local wingB1 = lineEndB - (layout.direction * arrowLen) + (layout.perpendicular * arrowHalfWidth)
                local wingB2 = lineEndB - (layout.direction * arrowLen) - (layout.perpendicular * arrowHalfWidth)
                addOpenPolylineSpline shapeNode #(wingB1, lineEndB, wingB2)
            )
            #none:
            (
                -- sem terminais
            )
            default: -- #tick (traço arquitetônico)
            (
                local tickVector = normalize (layout.direction + layout.perpendicular) * (terminalSize * 0.5)
                addLineSpline shapeNode (lineEndA - tickVector) (lineEndA + tickVector)
                addLineSpline shapeNode (lineEndB - tickVector) (lineEndB + tickVector)
            )
        )
    ),

    fn configureLineShape lineNode thickness =
    (
        local thicknessScene = toSceneUnits thickness
        if isProperty lineNode #render_renderable do lineNode.render_renderable = true
        if isProperty lineNode #render_displayRenderMesh do lineNode.render_displayRenderMesh = true
        if isProperty lineNode #render_useViewportSettings do lineNode.render_useViewportSettings = false
        if isProperty lineNode #render_thickness do lineNode.render_thickness = thicknessScene
        if isProperty lineNode #render_viewport_thickness do lineNode.render_viewport_thickness = thicknessScene
        if isProperty lineNode #render_sides do lineNode.render_sides = 4
        if isProperty lineNode #render_angle do lineNode.render_angle = 0.0

        try (lineNode.renderable = true) catch ()
        true
    ),

    fn updateLineSplinePoints lineNode layout style:undefined terminalSize:14.0 extensionOverhang:8.0 extensionGap:0.0 terminalType:#tick =
    (
        if lineNode == undefined or not isValidNode lineNode then return false
        if layout == undefined or not layout.valid then return false

        local resolvedThickness = 1.5
        local resolvedTerminalType = terminalType
        local resolvedTerminalSize = terminalSize
        local resolvedOverhang = extensionOverhang
        local resolvedGapExt = extensionGap

        if style != undefined do
        (
            resolvedThickness = style.lineThickness
            resolvedTerminalType = style.terminalType
            resolvedTerminalSize = style.terminalSize
            resolvedOverhang = style.extensionOverhang
            resolvedGapExt = style.extensionGap
        )

        local thicknessScene = toSceneUnits resolvedThickness
        local terminalSizeScene = toSceneUnits resolvedTerminalSize
        local overhangScene = toSceneUnits resolvedOverhang
        local gapExtScene = toSceneUnits resolvedGapExt

        local extDir = if layout.signedOffsetSceneUnits >= 0.0 then layout.perpendicular else -layout.perpendicular
        local lineEndA = layout.linePointA
        local lineEndB = layout.linePointB
        local extStartA = layout.projectedA + (extDir * gapExtScene)
        local extEndA = lineEndA + (extDir * overhangScene)
        local extStartB = layout.projectedB + (extDir * gapExtScene)
        local extEndB = lineEndB + (extDir * overhangScene)

        -- Se for tick padrão com 5 splines
        if resolvedTerminalType == #tick and (numSplines lineNode) == 5 then
        (
            local tickVector = normalize (layout.direction + layout.perpendicular) * (terminalSizeScene * 0.5)

            try
            (
                setKnotPoint lineNode 1 1 extStartA
                setKnotPoint lineNode 1 2 extEndA
                setKnotPoint lineNode 2 1 extStartB
                setKnotPoint lineNode 2 2 extEndB
                setKnotPoint lineNode 3 1 lineEndA
                setKnotPoint lineNode 3 2 lineEndB
                setKnotPoint lineNode 4 1 (lineEndA - tickVector)
                setKnotPoint lineNode 4 2 (lineEndA + tickVector)
                setKnotPoint lineNode 5 1 (lineEndB - tickVector)
                setKnotPoint lineNode 5 2 (lineEndB + tickVector)
                updateShape lineNode
                configureLineShape lineNode resolvedThickness
                return true
            )
            catch ()
        )

        -- Caso contrário, reconstrói as splines no mesmo nó
        try
        (
            while (numSplines lineNode) > 0 do deleteSpline lineNode 1
            addLineSpline lineNode extStartA extEndA
            addLineSpline lineNode extStartB extEndB
            addLineSpline lineNode lineEndA lineEndB
            addTerminals lineNode layout resolvedTerminalType terminalSizeScene
            updateShape lineNode
            configureLineShape lineNode resolvedThickness
            true
        )
        catch
        (
            false
        )
    ),

    fn updateTextNode textNode labelText layout style:undefined textHeight:140.0 textGap:60.0 =
    (
        if textNode == undefined or not isValidNode textNode then return false
        if layout == undefined or not layout.valid then return false

        local resolvedGap = textGap
        local resolvedHeight = textHeight
        if style != undefined do
        (
            resolvedGap = style.textGap
            resolvedHeight = style.fontSize
        )

        local resolvedGapScene = toSceneUnits resolvedGap
        local resolvedHeightScene = toSceneUnits resolvedHeight
        local extDir = if layout.signedOffsetSceneUnits >= 0.0 then layout.perpendicular else -layout.perpendicular
        local textPosition = ((layout.linePointA + layout.linePointB) * 0.5) + (extDir * resolvedGapScene)

        try
        (
            textNode.pos = textPosition
            orientTextNode textNode layout ((getUserProp textNode "Ameno.TextFollowsLine") == true)
            textNode.size = resolvedHeightScene
            textNode.ResetString()
            textNode.AppendString labelText
            true
        )
        catch
        (
            false
        )
    ),

    fn createLineNode layout style:undefined lineThickness:1.5 terminalType:#tick terminalSize:100.0 extensionOverhang:80.0 extensionGap:0.0 material:undefined =
    (
        local resolvedThickness = lineThickness
        local resolvedTerminalType = terminalType
        local resolvedTerminalSize = terminalSize
        local resolvedOverhang = extensionOverhang
        local resolvedGapExt = extensionGap

        if style != undefined do
        (
            resolvedThickness = style.lineThickness
            resolvedTerminalType = style.terminalType
            resolvedTerminalSize = style.terminalSize
            resolvedOverhang = style.extensionOverhang
            resolvedGapExt = style.extensionGap
        )

        local terminalSizeScene = toSceneUnits resolvedTerminalSize
        local overhangScene = toSceneUnits resolvedOverhang
        local gapExtScene = toSceneUnits resolvedGapExt

        local lineNode = splineShape name:(uniqueName "AMENO_DIM_")
        local extDir = if layout.signedOffsetSceneUnits >= 0.0 then layout.perpendicular else -layout.perpendicular
        local lineEndA = layout.linePointA
        local lineEndB = layout.linePointB
        local extStartA = layout.projectedA + (extDir * gapExtScene)
        local extEndA = lineEndA + (extDir * overhangScene)
        local extStartB = layout.projectedB + (extDir * gapExtScene)
        local extEndB = lineEndB + (extDir * overhangScene)

        addLineSpline lineNode extStartA extEndA
        addLineSpline lineNode extStartB extEndB
        addLineSpline lineNode lineEndA lineEndB
        addTerminals lineNode layout resolvedTerminalType terminalSizeScene
        updateShape lineNode

        configureLineShape lineNode resolvedThickness
        if material != undefined do lineNode.material = material

        lineNode
    ),

    fn createTextNode labelText layout style:undefined textHeight:140.0 textGap:60.0 fontName:"Arial" bold:false italic:false tracking:0.0 material:undefined followLine:undefined =
    (
        local resolvedHeight = textHeight
        local resolvedGap = textGap
        local resolvedFont = fontName
        local resolvedBold = bold
        local resolvedItalic = italic
        local resolvedTracking = tracking

        if style != undefined do
        (
            resolvedHeight = style.fontSize
            resolvedGap = style.textGap
            resolvedFont = style.fontName
            resolvedBold = style.bold
            resolvedItalic = style.italic
            resolvedTracking = style.tracking
        )

        if resolvedTracking == undefined do resolvedTracking = 0.0
        resolvedTracking = (amin (amax (resolvedTracking as float) -10.0) 100.0)

        if ::AmenoStyleService != undefined do
        (
            resolvedFont = ::AmenoStyleService.validateFont resolvedFont
        )

        local resolvedGapScene = toSceneUnits resolvedGap
        local resolvedHeightScene = toSceneUnits resolvedHeight
        local extDir = if layout.signedOffsetSceneUnits >= 0.0 then layout.perpendicular else -layout.perpendicular
        local textPosition = ((layout.linePointA + layout.linePointB) * 0.5) + (extDir * resolvedGapScene)
        local textNode = TextPlus name:(uniqueName "AMENO_LABEL_") pos:textPosition
        local follow = if followLine == undefined then textFollowsLine else followLine
        setUserProp textNode "Ameno.TextFollowsLine" follow
        orientTextNode textNode layout follow

        textNode.layouttype = 0
        textNode.plane = 1
        textNode.alignment = 1
        textNode.size = resolvedHeightScene
        textNode.tracking = resolvedTracking
        textNode.ResetString()
        textNode.ResetStyle()
        textNode.SetFont resolvedFont 0
        try (textNode.SetBold resolvedBold) catch ()
        try (textNode.SetItalic resolvedItalic) catch ()
        textNode.AppendString labelText

        try (textNode.renderable = true) catch ()
        if material != undefined do textNode.material = material

        textNode
    ),

    fn createMarkerNode layout style:undefined textHeight:140.0 textGap:60.0 fontName:"Arial" =
    (
        local resolvedHeight = textHeight
        local resolvedGap = textGap
        local resolvedFont = fontName

        if style != undefined do
        (
            resolvedHeight = style.fontSize
            resolvedGap = style.textGap
            resolvedFont = style.fontName
        )

        if ::AmenoStyleService != undefined do
        (
            resolvedFont = ::AmenoStyleService.validateFont resolvedFont
        )

        local resolvedGapScene = toSceneUnits resolvedGap
        local resolvedHeightScene = toSceneUnits resolvedHeight
        local extDir = if layout.signedOffsetSceneUnits >= 0.0 then layout.perpendicular else -layout.perpendicular
        local textPosition = ((layout.linePointA + layout.linePointB) * 0.5) + (extDir * resolvedGapScene)
        local markerPosition = textPosition + (layout.direction * (resolvedHeightScene * 2.0))
        local markerNode = TextPlus name:(uniqueName "AMENO_MARK_") pos:markerPosition

        markerNode.layouttype = 0
        markerNode.plane = 1
        markerNode.alignment = 1
        markerNode.size = resolvedHeightScene * 0.8
        markerNode.ResetString()
        markerNode.ResetStyle()
        markerNode.SetFont resolvedFont 0
        markerNode.AppendString "[M]"

        try (markerNode.wirecolor = (color 245 166 35)) catch ()
        try (markerNode.renderable = false) catch ()

        markerNode
    ),

    fn formatDelta deltaMm outputUnit:#meters precision:2 =
    (
        local signStr = if deltaMm > 0.0001 then "+" else if deltaMm < -0.0001 then "-" else ""
        local absVal = abs deltaMm
        local formatted = AmenoUnitService.formatMillimeters absVal outputUnit:outputUnit precision:precision decimalSeparator:#comma
        if signStr == "" then ("0 " + (AmenoUnitService.outputUnitSuffix outputUnit))
        else (signStr + formatted.text)
    ),

    fn calculateAudit controller layout outputUnit:#meters precision:2 =
    (
        local audit = AmenoDimensionAuditRecord()
        local dimensionId = getDimensionId controller
        audit.dimensionId = dimensionId
        audit.measuredMillimeters = layout.measuredMillimeters

        local resolvedUnit = outputUnit
        local resolvedPrecision = precision

        local record = undefined
        if AmenoDimensionCA != undefined and isValidNode controller do
        (
            record = AmenoDimensionCA.readCA controller
        )

        local mode = #measured
        local roundingInc = 0.0
        local manValMm = 0.0
        local manTxt = ""
        local reasonTxt = ""

        if record != undefined then
        (
            try (mode = record.displayMode as name) catch (mode = #measured)
            try (resolvedUnit = record.outputUnit as name) catch ()
            resolvedPrecision = record.precision
            roundingInc = record.roundingIncrementMm
            manValMm = record.manualValueMm
            manTxt = record.manualText
            reasonTxt = record.manualReason
        )
        else if isValidNode controller then
        (
            local mProp = readTextProperty controller "Ameno.DisplayMode"
            if mProp != undefined and mProp != "" do try (mode = mProp as name) catch ()
        )

        local measuredFormat = AmenoUnitService.formatMillimeters audit.measuredMillimeters outputUnit:resolvedUnit precision:resolvedPrecision decimalSeparator:#comma
        audit.measuredText = measuredFormat.text

        audit.mode = mode
        audit.manualReason = reasonTxt

        case mode of
        (
            #rounded:
            (
                local inc = if roundingInc > 0.0 then roundingInc else 10.0 -- 1 cm padrão (10 mm)
                audit.displayMillimeters = AmenoUnitService.roundToIncrement audit.measuredMillimeters inc
                audit.deltaMillimeters = audit.displayMillimeters - audit.measuredMillimeters
                audit.isManual = (abs audit.deltaMillimeters > 0.001)
                local dispFormat = AmenoUnitService.formatMillimeters audit.displayMillimeters outputUnit:resolvedUnit precision:resolvedPrecision decimalSeparator:#comma
                audit.displayText = dispFormat.text
                audit.deltaText = formatDelta audit.deltaMillimeters outputUnit:resolvedUnit precision:resolvedPrecision
            )
            #manualNumeric:
            (
                audit.displayMillimeters = if manValMm > 0.0 then manValMm else audit.measuredMillimeters
                audit.deltaMillimeters = audit.displayMillimeters - audit.measuredMillimeters
                audit.isManual = true
                local dispFormat = AmenoUnitService.formatMillimeters audit.displayMillimeters outputUnit:resolvedUnit precision:resolvedPrecision decimalSeparator:#comma
                audit.displayText = dispFormat.text
                audit.deltaText = formatDelta audit.deltaMillimeters outputUnit:resolvedUnit precision:resolvedPrecision
            )
            #manualText:
            (
                audit.displayMillimeters = audit.measuredMillimeters
                audit.deltaMillimeters = 0.0
                audit.isManual = true
                audit.displayText = if manTxt != "" then manTxt else audit.measuredText
                audit.deltaText = "Texto manual"
            )
            default: -- #measured
            (
                audit.mode = #measured
                audit.displayMillimeters = audit.measuredMillimeters
                audit.deltaMillimeters = 0.0
                audit.isManual = false
                audit.displayText = audit.measuredText
                audit.deltaText = "0 " + (AmenoUnitService.outputUnitSuffix resolvedUnit)
            )
        )

        -- E8: Informações de âncoras e órfãs
        if record != undefined then
        (
            audit.isOrphan = record.isOrphan
            audit.orphanReason = record.orphanReason
            audit.anchorType = record.anchorType

            if record.anchorType == "world" or (record.nodeA == undefined and record.nodeB == undefined and not record.isOrphan) then
            (
                audit.anchorDesc = "Mundial"
            )
            else
            (
                local nameA = if record.nodeA != undefined and isValidNode record.nodeA then record.nodeA.name else (if (record.anchorType == "nodeA" or record.anchorType == "both") then "[Nó A excluído]" else "Livre")
                local nameB = if record.nodeB != undefined and isValidNode record.nodeB then record.nodeB.name else (if (record.anchorType == "nodeB" or record.anchorType == "both") then "[Nó B excluído]" else "Livre")
                audit.anchorDesc = nameA + " · " + nameB
                if audit.isOrphan do audit.anchorDesc += " [ÓRFÃ]"
            )
        )
        else
        (
            audit.isOrphan = false
            audit.orphanReason = ""
            audit.anchorDesc = "Mundial"
            audit.anchorType = "world"
        )

        audit
    ),

    fn decorateGraphicNode node dimensionId role dimensionsLayer =
    (
        if node == undefined or not isValidNode node then return false

        dimensionsLayer.addNode node
        setTextProperty node "Ameno.Kind" graphicKind
        setTextProperty node "Ameno.DimensionId" dimensionId
        setTextProperty node "Ameno.GraphicRole" role
        setTextProperty node "Ameno.GraphicSchemaVersion" (graphicSchemaVersion as string)
        setTextProperty node "Ameno.SchemaVersion" (graphicSchemaVersion as string)
        true
    ),

    fn createController pointA pointB offsetPoint systemLayer role:"test" outputUnit:#meters precision:2 styleId:"default" \
        anchorType:"world" nodeA:undefined localPointA:undefined anchorVertexIdA:-1 anchorEdgeIdA:-1 anchorEdgeMidA:false \
        nodeB:undefined localPointB:undefined anchorVertexIdB:-1 anchorEdgeIdB:-1 anchorEdgeMidB:false dimensionMode:#aligned =
    (
        local controller = Point name:(uniqueName "AMENO_DIM_CTRL_") size:5.0
        registerAllocation controller
        setUserProp controller "Ameno.TextFollowsLine" textFollowsLine
        maybeInjectFailure #afterController
        local dimensionId = "dimension-" + (controller.handle as string)

        try (controller.isHidden = true) catch ()
        try (controller.renderable = false) catch ()
        systemLayer.addNode controller

        if AmenoDimensionCA != undefined do
        (
            local rec = AmenoDimensionRecord()
            rec.schemaVersion = 5
            rec.dimensionId = dimensionId
            rec.dimensionRole = (role as string)
            rec.dimensionMode = (dimensionMode as string)
            rec.pointA = pointA
            rec.pointB = pointB
            rec.offsetPoint = offsetPoint
            rec.outputUnit = (outputUnit as string)
            rec.precision = precision
            rec.displayMode = "measured"
            rec.roundingIncrementMm = 0.0
            rec.manualValue = ""
            rec.manualValueMm = 0.0
            rec.manualText = ""
            rec.manualReason = ""
            rec.lastMeasuredMm = 0.0
            rec.lastDeltaMm = 0.0
            rec.styleId = styleId

            rec.anchorType = (anchorType as string)
            rec.nodeA = nodeA
            rec.localPointA = if localPointA != undefined then localPointA else [0, 0, 0]
            rec.anchorVertexIdA = anchorVertexIdA
            rec.anchorEdgeIdA = anchorEdgeIdA
            rec.anchorEdgeMidA = anchorEdgeMidA
            rec.nodeB = nodeB
            rec.localPointB = if localPointB != undefined then localPointB else [0, 0, 0]
            rec.anchorVertexIdB = anchorVertexIdB
            rec.anchorEdgeIdB = anchorEdgeIdB
            rec.anchorEdgeMidB = anchorEdgeMidB
            rec.isOrphan = false
            rec.orphanReason = ""

            AmenoDimensionCA.applyCA controller rec
        )

        setTextProperty controller "Ameno.Kind" controllerKind
        setTextProperty controller "Ameno.DimensionId" dimensionId
        setTextProperty controller "Ameno.DimensionRole" (role as string)
        setTextProperty controller "Ameno.DataSchemaVersion" (dataSchemaVersion as string)
        setTextProperty controller "Ameno.SchemaVersion" (dataSchemaVersion as string)
        setTextProperty controller "Ameno.StyleId" styleId
        setPointProperty controller "Ameno.PointA" pointA
        setPointProperty controller "Ameno.PointB" pointB
        setPointProperty controller "Ameno.OffsetPoint" offsetPoint

        controller
    ),

    fn createVisualNodes controller layout auditOrText dimensionsLayer style:undefined =
    (
        local dimensionId = readTextProperty controller "Ameno.DimensionId"
        local audit = undefined
        local labelText = ""

        if isProperty auditOrText #displayText then
        (
            audit = auditOrText
            labelText = audit.displayText
        )
        else
        (
            labelText = auditOrText as string
        )

        local resolvedStyle = style
        if resolvedStyle == undefined and ::AmenoStyleService != undefined do
        (
            local sId = "default"
            if AmenoDimensionCA != undefined and isValidNode controller do
            (
                local rec = AmenoDimensionCA.readCA controller
                if rec != undefined and rec.styleId != undefined and rec.styleId != "" do sId = rec.styleId
            )
            if sId == "default" and isValidNode controller do
            (
                local propId = readTextProperty controller "Ameno.StyleId"
                if propId != undefined and propId != "" do sId = propId
            )
            resolvedStyle = ::AmenoStyleService.getStyle sId
        )

        local dimensionMaterial = createDimensionMaterial()
        local lineNode = createLineNode layout style:resolvedStyle material:dimensionMaterial
        registerAllocation lineNode
        maybeInjectFailure #afterLine
        local follow = (getUserProp controller "Ameno.TextFollowsLine") == true
        local textNode = createTextNode labelText layout style:resolvedStyle material:dimensionMaterial followLine:follow
        registerAllocation textNode
        maybeInjectFailure #afterText
        local markerNode = undefined

        local resolvedTerminalType = #tick
        local resolvedTerminalSize = 80.0
        if resolvedStyle != undefined do
        (
            resolvedTerminalType = resolvedStyle.terminalType
            resolvedTerminalSize = resolvedStyle.terminalSize
        )
        local termNodeA = undefined
        local termNodeB = undefined
        local terminalPair = syncTerminalNodes dimensionId layout audit resolvedStyle dimensionsLayer material:dimensionMaterial
        termNodeA = terminalPair[1]
        termNodeB = terminalPair[2]

        if audit != undefined and audit.isManual then
        (
            markerNode = createMarkerNode layout style:resolvedStyle
            registerAllocation markerNode
            maybeInjectFailure #afterMarker
            decorateGraphicNode markerNode dimensionId "marker" dimensionsLayer
        )

        -- Prioridade visual (wirecolor):
        -- 1º Órfã (Alerta vermelho 230, 70, 70)
        -- 2º Manual Válida (Âmbar 245, 166, 35)
        -- 3º Normal / Medida (Branco neutro 245, 245, 245)
        -- O material renderizável permanece branco neutro independente do estado.
        if audit != undefined and audit.isOrphan then
        (
            try (lineNode.wirecolor = (color 230 70 70)) catch ()
            try (textNode.wirecolor = (color 230 70 70)) catch ()
            if markerNode != undefined do try (markerNode.wirecolor = (color 230 70 70)) catch ()
            if termNodeA != undefined and isValidNode termNodeA do try (termNodeA.wirecolor = (color 230 70 70)) catch ()
            if termNodeB != undefined and isValidNode termNodeB do try (termNodeB.wirecolor = (color 230 70 70)) catch ()
        )
        else if audit != undefined and audit.isManual then
        (
            try (lineNode.wirecolor = (color 245 166 35)) catch ()
            try (textNode.wirecolor = (color 245 166 35)) catch ()
            if markerNode != undefined do try (markerNode.wirecolor = (color 245 166 35)) catch ()
            if termNodeA != undefined and isValidNode termNodeA do try (termNodeA.wirecolor = (color 245 166 35)) catch ()
            if termNodeB != undefined and isValidNode termNodeB do try (termNodeB.wirecolor = (color 245 166 35)) catch ()
        )
        else
        (
            try (lineNode.wirecolor = (color 245 245 245)) catch ()
            try (textNode.wirecolor = (color 245 245 245)) catch ()
            if termNodeA != undefined and isValidNode termNodeA do try (termNodeA.wirecolor = (color 245 245 245)) catch ()
            if termNodeB != undefined and isValidNode termNodeB do try (termNodeB.wirecolor = (color 245 245 245)) catch ()
        )

        decorateGraphicNode lineNode dimensionId "lines" dimensionsLayer
        decorateGraphicNode textNode dimensionId "label" dimensionsLayer

        AmenoGraphicDimensionRecord dimensionId:dimensionId controller:controller lineNode:lineNode textNode:textNode markerNode:markerNode layout:layout displayText:labelText audit:audit style:resolvedStyle termNodeA:termNodeA termNodeB:termNodeB
    ),

    fn configurePreviewNode nodeValue =
    (
        if nodeValue == undefined or not isValidNode nodeValue then return false
        try (nodeValue.renderable = false) catch ()
        try (if isProperty nodeValue #render_renderable do nodeValue.render_renderable = false) catch ()
        try (if isProperty nodeValue #render_displayRenderMesh do nodeValue.render_displayRenderMesh = false) catch ()
        try (nodeValue.showFrozenInGray = false) catch ()
        try (nodeValue.isFrozen = true) catch ()
        true
    ),

    fn createPreviewDimension pointA pointB offsetPoint outputUnit:#meters precision:2 styleId:"default" mode:#aligned =
    (
        local sceneState = ensureSceneReady()

        if sceneState.status != #ready then throw ("Ameno não conseguiu preparar a cena: " + sceneState.detail)

        local layout = AmenoDimensionMath.layoutForMode pointA pointB offsetPoint mode:mode
        if not layout.valid then throw ("Não foi possível criar a prévia: " + layout.errorMessage)

        local measurement = AmenoUnitService.formatMillimeters layout.measuredMillimeters outputUnit:outputUnit precision:precision decimalSeparator:#comma
        local result = undefined
        local resolvedStyle = undefined
        if ::AmenoStyleService != undefined do resolvedStyle = ::AmenoStyleService.getStyle styleId

        beginAllocation()
        try
        (
            with undo off
            (
                local dimensionMaterial = createDimensionMaterial()
                local lineNode = createLineNode layout style:resolvedStyle material:dimensionMaterial
                registerAllocation lineNode
                local textNode = createTextNode measurement.text layout style:resolvedStyle material:dimensionMaterial
                registerAllocation textNode
                local dimensionId = "preview-" + (lineNode.handle as string)

                try (lineNode.isHidden = false) catch ()
                try (textNode.isHidden = false) catch ()
                decorateGraphicNode lineNode dimensionId "preview-lines" sceneState.dimensionsLayer
                decorateGraphicNode textNode dimensionId "preview-label" sceneState.dimensionsLayer
                setTextProperty lineNode "Ameno.Kind" "dimensionPreview"
                setTextProperty textNode "Ameno.Kind" "dimensionPreview"
                setTextProperty lineNode "Ameno.Preview" "1"
                setTextProperty textNode "Ameno.Preview" "1"
                configurePreviewNode lineNode
                configurePreviewNode textNode

                local terminalPair = syncTerminalNodes dimensionId layout undefined resolvedStyle sceneState.dimensionsLayer material:dimensionMaterial preview:true

                result = AmenoGraphicDimensionRecord dimensionId:dimensionId lineNode:lineNode textNode:textNode layout:layout displayText:measurement.text style:resolvedStyle termNodeA:terminalPair[1] termNodeB:terminalPair[2]
            )
        )
        catch
        (
            rollbackAllocation()
            throw
        )
        finishAllocation()

        result
    ),

    fn updatePreviewDimension preview pointA pointB offsetPoint outputUnit:#meters precision:2 styleId:"default" mode:#aligned =
    (
        if preview == undefined then return undefined

        local layout = AmenoDimensionMath.layoutForMode pointA pointB offsetPoint mode:mode
        if not layout.valid then return undefined

        local measurement = AmenoUnitService.formatMillimeters layout.measuredMillimeters outputUnit:outputUnit precision:precision decimalSeparator:#comma
        local resolvedStyle = undefined
        if ::AmenoStyleService != undefined do resolvedStyle = ::AmenoStyleService.getStyle styleId

        with undo off
        (
            updateLineSplinePoints preview.lineNode layout style:resolvedStyle
            updateTextNode preview.textNode measurement.text layout style:resolvedStyle
            local terminalPair = syncTerminalNodes preview.dimensionId layout undefined resolvedStyle (AmenoSceneSetup.inspect()).dimensionsLayer material:(try (preview.lineNode.material) catch (undefined)) preview:true
            configurePreviewNode preview.lineNode
            configurePreviewNode preview.textNode

            preview.termNodeA = terminalPair[1]
            preview.termNodeB = terminalPair[2]
        )

        preview.layout = layout
        preview.displayText = measurement.text
        preview.style = resolvedStyle
        preview
    ),

    fn removePreviewDimension preview =
    (
        if preview == undefined then return false

        local nodes = #()
        if preview.lineNode != undefined and isValidNode preview.lineNode do append nodes preview.lineNode
        if preview.textNode != undefined and isValidNode preview.textNode do append nodes preview.textNode
        if preview.termNodeA != undefined and isValidNode preview.termNodeA do append nodes preview.termNodeA
        if preview.termNodeB != undefined and isValidNode preview.termNodeB do append nodes preview.termNodeB

        with undo off
        (
            for node in nodes where node != undefined and isValidNode node do delete node
        )

        true
    ),

    fn createDimension pointA pointB offsetPoint role:"test" outputUnit:#meters precision:2 styleId:"default" style:undefined \
        anchorType:"world" nodeA:undefined localPointA:undefined anchorVertexIdA:-1 anchorEdgeIdA:-1 anchorEdgeMidA:false \
        nodeB:undefined localPointB:undefined anchorVertexIdB:-1 anchorEdgeIdB:-1 anchorEdgeMidB:false dimensionMode:#aligned useUndo:true =
    (
        local sceneState = ensureSceneReady()

        if sceneState.status != #ready then throw ("Ameno não conseguiu preparar a cena: " + sceneState.detail)

        local resolvedAnchorType = anchorType
        local resolvedLocalA = localPointA
        local resolvedLocalB = localPointB

        if nodeA != undefined and isValidNode nodeA do
        (
            if resolvedLocalA == undefined do resolvedLocalA = pointA * (inverse nodeA.transform)
        )
        if nodeB != undefined and isValidNode nodeB do
        (
            if resolvedLocalB == undefined do resolvedLocalB = pointB * (inverse nodeB.transform)
        )

        if nodeA != undefined and nodeB != undefined then resolvedAnchorType = "both"
        else if nodeA != undefined then resolvedAnchorType = "nodeA"
        else if nodeB != undefined then resolvedAnchorType = "nodeB"

        local layout = AmenoDimensionMath.layoutForMode pointA pointB offsetPoint mode:dimensionMode
        if not layout.valid then throw ("Não foi possível criar a cota: " + layout.errorMessage)

        local controller = undefined
        local result = undefined

        beginAllocation()
        try
        (
            if useUndo then
            (
                undo "Ameno: criar cota" on
                (
                    controller = createController pointA pointB offsetPoint sceneState.systemLayer role:role outputUnit:outputUnit precision:precision styleId:styleId \
                        anchorType:resolvedAnchorType nodeA:nodeA localPointA:resolvedLocalA anchorVertexIdA:anchorVertexIdA anchorEdgeIdA:anchorEdgeIdA anchorEdgeMidA:anchorEdgeMidA \
                        nodeB:nodeB localPointB:resolvedLocalB anchorVertexIdB:anchorVertexIdB anchorEdgeIdB:anchorEdgeIdB anchorEdgeMidB:anchorEdgeMidB dimensionMode:dimensionMode
                    local audit = calculateAudit controller layout outputUnit:outputUnit precision:precision
                    if AmenoDimensionCA != undefined do
                    (
                        local rec = AmenoDimensionCA.readCA controller
                        if rec != undefined do
                        (
                            rec.lastMeasuredMm = audit.measuredMillimeters
                            rec.lastDeltaMm = audit.deltaMillimeters
                            AmenoDimensionCA.applyCA controller rec
                        )
                    )
                    result = createVisualNodes controller layout audit sceneState.dimensionsLayer style:style
                )
            )
            else
            (
                local resolvedStyleId = styleId
                if style != undefined and (resolvedStyleId == "default" or resolvedStyleId == undefined) and isProperty style #styleId do
                    resolvedStyleId = style.styleId

                controller = createController pointA pointB offsetPoint sceneState.systemLayer role:role outputUnit:outputUnit precision:precision styleId:resolvedStyleId \
                    anchorType:resolvedAnchorType nodeA:nodeA localPointA:resolvedLocalA anchorVertexIdA:anchorVertexIdA anchorEdgeIdA:anchorEdgeIdA anchorEdgeMidA:anchorEdgeMidA \
                    nodeB:nodeB localPointB:resolvedLocalB anchorVertexIdB:anchorVertexIdB anchorEdgeIdB:anchorEdgeIdB anchorEdgeMidB:anchorEdgeMidB dimensionMode:dimensionMode
                local audit = calculateAudit controller layout outputUnit:outputUnit precision:precision
                if AmenoDimensionCA != undefined do
                (
                    local rec = AmenoDimensionCA.readCA controller
                    if rec != undefined do
                    (
                        rec.lastMeasuredMm = audit.measuredMillimeters
                        rec.lastDeltaMm = audit.deltaMillimeters
                        AmenoDimensionCA.applyCA controller rec
                    )
                )
                result = createVisualNodes controller layout audit sceneState.dimensionsLayer style:style
            )
        )
        catch
        (
            rollbackAllocation()
            throw
        )

        finishAllocation()

        result
    ),

    fn findControllers role:undefined =
    (
        local controllers = #()

        for node in objects where isValidNode node do
        (
            local isCtrl = ((readTextProperty node "Ameno.Kind") == controllerKind)
            if not isCtrl and AmenoDimensionCA != undefined do
            (
                isCtrl = AmenoDimensionCA.hasCA node
            )

            if isCtrl do
            (
                local nodeRole = getDimensionRole node
                if role == undefined or nodeRole == (role as string) do append controllers node
            )
        )

        controllers
    ),

    fn findNodesForDimension dimensionId =
    (
        local matches = #()
        if dimensionId == undefined or dimensionId == "" then return matches

        for node in objects where isValidNode node do
        (
            if (getDimensionId node) == dimensionId do append matches node
        )

        matches
    ),

    fn deleteNodes nodes =
    (
        for node in nodes where node != undefined and isValidNode node do delete node
        true
    ),

    fn removeDimension dimensionId =
    (
        if dimensionId == undefined or dimensionId == "" then return false

        local nodes = findNodesForDimension dimensionId
        if nodes.count == 0 then return false

        undo "Ameno: remover cota" on
        (
            deleteNodes nodes
        )

        true
    ),

    fn removeVisualNodes dimensionId =
    (
        local nodes = #()

        for node in (findNodesForDimension dimensionId) where ((readTextProperty node "Ameno.Kind") == graphicKind or (try ((getUserProp node "AMENO_TERMINAL") == true) catch (false))) do append nodes node
        deleteNodes nodes
    ),

    fn inspectDimension controller =
    (
        if controller == undefined or not isValidNode controller then return #missing

        local dimensionId = getDimensionId controller
        if dimensionId == "" then return #invalid

        local nodes = findNodesForDimension dimensionId
        local hasLines = false
        local hasLabel = false
        local hasMarker = false

        for n in nodes where isValidNode n do
        (
            local r = readTextProperty n "Ameno.GraphicRole"
            if r == "lines" do hasLines = true
            if r == "label" do hasLabel = true
            if r == "marker" do hasMarker = true
        )

        local record = undefined
        if AmenoDimensionCA != undefined do record = AmenoDimensionCA.readCA controller
        local isManualExpected = false
        if record != undefined do
        (
            isManualExpected = (record.displayMode == "manualNumeric" or record.displayMode == "manualText" or (record.displayMode == "rounded" and (abs record.lastDeltaMm > 0.001)))
        )

        if isManualExpected and not hasMarker then return #missing_marker
        if not isManualExpected and hasMarker then return #unexpected_marker

        local terminalNodes = terminalNodesForDimension dimensionId
        local expectedStyle = undefined
        if record != undefined and ::AmenoStyleService != undefined do
        (
            local expectedStyleId = if record.styleId != undefined and record.styleId != "" then record.styleId else "default"
            expectedStyle = ::AmenoStyleService.getStyle expectedStyleId
        )
        if expectedStyle != undefined do
        (
            if isMeshTerminalType expectedStyle.terminalType then
            (
                if ::AmenoDimensionTerminalMesh == undefined then return #missing_terminal
                if terminalNodes.count != 2 then return #missing_terminal
                for terminalNode in terminalNodes where (::AmenoDimensionTerminalMesh.terminalTypeOf terminalNode) != expectedStyle.terminalType do
                    return #invalid_terminal
            )
            else if terminalNodes.count > 0 then return #unexpected_terminal
        )

        if hasLines and hasLabel then #healthy
        else if hasLines or hasLabel then #partial
        else #missing_graphics
    ),

    fn getDimensionAudit controller =
    (
        if controller == undefined or not isValidNode controller then return undefined
        local record = undefined
        if AmenoDimensionCA != undefined do record = AmenoDimensionCA.readCA controller
        if record == undefined then return undefined

        local mode = #aligned
        try (mode = record.dimensionMode as name) catch ()
        local layout = AmenoDimensionMath.layoutForMode record.pointA record.pointB record.offsetPoint mode:mode
        if not layout.valid then return undefined

        local outputUnit = #meters
        try (outputUnit = (record.outputUnit as name)) catch ()

        calculateAudit controller layout outputUnit:outputUnit precision:record.precision
    ),

    fn rebuildDimension controller style:undefined =
    (
        if controller == undefined or not isValidNode controller then throw "O controlador da cota não existe mais."

        local dimensionId = getDimensionId controller
        if dimensionId == "" then throw "O nó informado não é um controlador Ameno válido."

        local record = undefined
        if AmenoDimensionCA != undefined do record = AmenoDimensionCA.readCA controller

        local pointA = undefined
        local pointB = undefined
        local offsetPoint = undefined
        local outputUnit = #meters
        local precision = 2

        if record != undefined then
        (
            pointA = record.pointA
            pointB = record.pointB
            offsetPoint = record.offsetPoint
            try (outputUnit = (record.outputUnit as name)) catch ()
            precision = record.precision

            -- E8: Resolve âncoras para obter coordenadas mundiais atualizadas
            local resolved = AmenoDimensionCA.resolvePoints record
            if resolved != undefined do
            (
                pointA = resolved.pointA
                pointB = resolved.pointB
                offsetPoint = resolved.offsetPoint
                record.pointA = resolved.pointA
                record.pointB = resolved.pointB
                record.offsetPoint = resolved.offsetPoint
                record.isOrphan = resolved.isOrphan
                record.orphanReason = resolved.orphanReason
                AmenoDimensionCA.applyCA controller record
            )
        )
        else
        (
            pointA = readPointProperty controller "Ameno.PointA"
            pointB = readPointProperty controller "Ameno.PointB"
            offsetPoint = readPointProperty controller "Ameno.OffsetPoint"
        )

        local sceneState = ensureSceneReady()

        if pointA == undefined or pointB == undefined or offsetPoint == undefined then throw "Os dados geométricos da cota estão incompletos."
        if sceneState.status != #ready then throw ("Ameno não conseguiu preparar a cena: " + sceneState.detail)

        local mode = #aligned
        if record != undefined do try (mode = record.dimensionMode as name) catch ()
        local layout = AmenoDimensionMath.layoutForMode pointA pointB offsetPoint mode:mode
        if not layout.valid then throw ("Não foi possível reconstruir a cota: " + layout.errorMessage)

        local audit = calculateAudit controller layout outputUnit:outputUnit precision:precision
        if record != undefined and AmenoDimensionCA != undefined do
        (
            record.lastMeasuredMm = audit.measuredMillimeters
            record.lastDeltaMm = audit.deltaMillimeters
            AmenoDimensionCA.applyCA controller record
        )

        local resolvedStyle = style
        if resolvedStyle == undefined and ::AmenoStyleService != undefined do
        (
            local sId = "default"
            if record != undefined and record.styleId != undefined and record.styleId != "" then sId = record.styleId
            else
            (
                local propId = readTextProperty controller "Ameno.StyleId"
                if propId != undefined and propId != "" do sId = propId
            )
            resolvedStyle = ::AmenoStyleService.getStyle sId
        )

        local wasSelected = false
        local oldNodes = findNodesForDimension dimensionId
        for n in oldNodes where isValidNode n do
        (
            if n.isSelected do wasSelected = true
        )

        -- Rebuild transacional: cria os filhos novos antes de remover os
        -- antigos. Assim uma falha de terminal, material ou TextPlus mantém
        -- a cota anterior íntegra até o chamador abortar o Undo externo.
        local oldVisualNodes = #()
        for oldNode in oldNodes where isValidNode oldNode do
        (
            local oldIsGraphic = ((readTextProperty oldNode "Ameno.Kind") == graphicKind)
            local oldIsTerminal = (try (::AmenoDimensionTerminalMesh.isTerminal oldNode) catch (false))
            if oldIsGraphic or oldIsTerminal do append oldVisualNodes oldNode
        )

        beginAllocation()
        local created = undefined
        try
        (
            created = createVisualNodes controller layout audit sceneState.dimensionsLayer style:resolvedStyle
            if created == undefined then throw "Ameno não conseguiu criar os visuais da cota."
            for oldNode in oldVisualNodes where isValidNode oldNode do
                if (findItem #(created.lineNode, created.textNode, created.markerNode, created.termNodeA, created.termNodeB) oldNode) == 0 do
                    delete oldNode
            finishAllocation()
        )
        catch
        (
            rollbackAllocation()
            throw
        )

        if wasSelected and created != undefined do
        (
            local toSelect = #()
            if created.lineNode != undefined and isValidNode created.lineNode do append toSelect created.lineNode
            if created.textNode != undefined and isValidNode created.textNode do append toSelect created.textNode
            if toSelect.count > 0 do selectMore toSelect
        )
        created
    ),

    fn rebuildDimensionsByStyle targetStyleId =
    (
        local controllers = findControllers()
        local count = 0
        local styleObj = undefined
        if ::AmenoStyleService != undefined do styleObj = ::AmenoStyleService.getStyle targetStyleId

        for ctrl in controllers where isValidNode ctrl do
        (
            local sId = "default"
            if AmenoDimensionCA != undefined do
            (
                local rec = AmenoDimensionCA.readCA ctrl
                if rec != undefined and rec.styleId != undefined and rec.styleId != "" do sId = rec.styleId
            )
            if sId == "default" do
            (
                local p = readTextProperty ctrl "Ameno.StyleId"
                if p != undefined and p != "" do sId = p
            )

            if sId == targetStyleId do
            (
                try
                (
                    rebuildDimension ctrl style:styleObj
                    count += 1
                )
                catch ()
            )
        )
        count
    ),

    fn setDimensionMode controller mode manualValueMm:undefined manualText:undefined reason:undefined incrementMm:undefined =
    (
        if controller == undefined or not isValidNode controller then return false
        if AmenoDimensionCA == undefined then return false

        local rec = AmenoDimensionCA.readCA controller
        if rec == undefined then return false

        undo "Ameno: alterar modo de valor" on
        (
            rec.displayMode = (mode as string)
            if manualValueMm != undefined do rec.manualValueMm = (manualValueMm as float)
            if manualText != undefined do rec.manualText = (manualText as string)
            if reason != undefined do rec.manualReason = (reason as string)
            if incrementMm != undefined and incrementMm > 0.0 do rec.roundingIncrementMm = (incrementMm as float)

            AmenoDimensionCA.applyCA controller rec
            rebuildDimension controller
        )
        true
    ),

    fn resetDimensionToMeasured controller =
    (
        if controller == undefined or not isValidNode controller then return false
        if AmenoDimensionCA == undefined then return false

        local rec = AmenoDimensionCA.readCA controller
        if rec == undefined then return false

        undo "Ameno: restaurar valor medido" on
        (
            rec.displayMode = "measured"
            rec.manualReason = ""
            AmenoDimensionCA.applyCA controller rec
            rebuildDimension controller
        )
        true
    ),

    fn repairDimension controller =
    (
        local status = inspectDimension controller
        if status == #healthy then return true
        if status == #missing or status == #invalid then return false

        undo "Ameno: reparar cota" on
        (
            rebuildDimension controller
        )
        true
    ),

    fn repairAllDimensions =
    (
        local controllers = findControllers()
        local repairedCount = 0

        for controller in controllers where isValidNode controller do
        (
            local status = inspectDimension controller
            if status != #healthy do
            (
                if repairDimension controller do repairedCount += 1
            )
        )

        repairedCount
    ),

    fn createTestDimension =
    (
        createDimension [0, 0, 0] [500, 0, 0] [0, 100, 0] role:testRole
    ),

    fn clearTestDimensions =
    (
        local controllers = findControllers role:testRole
        local removedCount = 0

        for controller in controllers where isValidNode controller do
        (
            if removeDimension (readTextProperty controller "Ameno.DimensionId") do removedCount += 1
        )

        removedCount
    ),

    fn reanchorDimension controller whichPoint targetNode targetWorldPoint =
    (
        if ::AmenoAnchorService != undefined then
        (
            ::AmenoAnchorService.reanchorDimension controller whichPoint targetNode targetWorldPoint
        )
        else false
    ),

    fn selectAnchors controller =
    (
        if ::AmenoAnchorService != undefined then
        (
            ::AmenoAnchorService.selectAnchors controller
        )
        else false
    ),

    fn repairOrphans =
    (
        if ::AmenoAnchorService != undefined then
        (
            ::AmenoAnchorService.repairOrphans()
        )
        else 0
    )
)

AmenoDimensionGraphics = AmenoDimensionGraphicsService()
