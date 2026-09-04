/*
    E3 — Construtor gráfico de uma cota alinhada.

    Esta camada recebe uma geometria já resolvida por AmenoDimensionMath e cria
    apenas os nós visuais e o controlador técnico da cota. A ferramenta de
    cliques entra na E4; por enquanto createTestDimension() é o ponto de entrada
    intencionalmente determinístico para validar a presença no viewport e render.
*/

global AmenoDimensionGraphics

struct AmenoGraphicDimensionRecord
(
    dimensionId = "",
    controller = undefined,
    lineNode = undefined,
    textNode = undefined,
    layout = undefined,
    displayText = ""
)

struct AmenoDimensionGraphicsService
(
    schemaVersion = 1,
    controllerKind = "dimension",
    graphicKind = "dimensionGraphic",
    testRole = "test",

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

    fn addLineSpline shapeNode pointA pointB =
    (
        local splineIndex = addNewSpline shapeNode
        addKnot shapeNode splineIndex #corner #line pointA
        addKnot shapeNode splineIndex #corner #line pointB
        splineIndex
    ),

    fn configureLineShape lineNode thickness =
    (
        if isProperty lineNode #render_renderable do lineNode.render_renderable = true
        if isProperty lineNode #render_thickness do lineNode.render_thickness = thickness
        if isProperty lineNode #render_sides do lineNode.render_sides = 4
        if isProperty lineNode #render_angle do lineNode.render_angle = 0.0

        try (lineNode.renderable = true) catch ()
        true
    ),

    fn updateLineSplinePoints lineNode layout terminalSize:14.0 extensionOverhang:8.0 =
    (
        if lineNode == undefined or not isValidNode lineNode then return false
        if layout == undefined or not layout.valid then return false

        local lineEndA = layout.linePointA
        local lineEndB = layout.linePointB
        local extensionEndA = lineEndA + (layout.perpendicular * extensionOverhang)
        local extensionEndB = lineEndB + (layout.perpendicular * extensionOverhang)
        local tickVector = normalize (layout.direction + layout.perpendicular) * (terminalSize * 0.5)

        try
        (
            setKnotPoint lineNode 1 1 layout.projectedA
            setKnotPoint lineNode 1 2 extensionEndA
            setKnotPoint lineNode 2 1 layout.projectedB
            setKnotPoint lineNode 2 2 extensionEndB
            setKnotPoint lineNode 3 1 lineEndA
            setKnotPoint lineNode 3 2 lineEndB
            setKnotPoint lineNode 4 1 (lineEndA - tickVector)
            setKnotPoint lineNode 4 2 (lineEndA + tickVector)
            setKnotPoint lineNode 5 1 (lineEndB - tickVector)
            setKnotPoint lineNode 5 2 (lineEndB + tickVector)
            updateShape lineNode
            true
        )
        catch
        (
            false
        )
    ),

    fn updateTextNode textNode labelText layout textGap:12.0 =
    (
        if textNode == undefined or not isValidNode textNode then return false
        if layout == undefined or not layout.valid then return false

        local textPosition = ((layout.linePointA + layout.linePointB) * 0.5) + (layout.perpendicular * textGap)

        try
        (
            textNode.pos = textPosition
            textNode.ResetString()
            textNode.AppendString labelText
            true
        )
        catch
        (
            false
        )
    ),

    fn createLineNode layout lineThickness:1.5 terminalSize:14.0 extensionOverhang:8.0 material:undefined =
    (
        local lineNode = splineShape name:(uniqueName "AMENO_DIM_")
        local lineEndA = layout.linePointA
        local lineEndB = layout.linePointB
        local extensionEndA = lineEndA + (layout.perpendicular * extensionOverhang)
        local extensionEndB = lineEndB + (layout.perpendicular * extensionOverhang)
        local tickVector = normalize (layout.direction + layout.perpendicular) * (terminalSize * 0.5)

        addLineSpline lineNode layout.projectedA extensionEndA
        addLineSpline lineNode layout.projectedB extensionEndB
        addLineSpline lineNode lineEndA lineEndB
        addLineSpline lineNode (lineEndA - tickVector) (lineEndA + tickVector)
        addLineSpline lineNode (lineEndB - tickVector) (lineEndB + tickVector)
        updateShape lineNode

        configureLineShape lineNode lineThickness
        if material != undefined do lineNode.material = material

        lineNode
    ),

    fn createTextNode labelText layout textHeight:20.0 textGap:12.0 fontName:"Arial" material:undefined =
    (
        local textPosition = ((layout.linePointA + layout.linePointB) * 0.5) + (layout.perpendicular * textGap)
        local textNode = TextPlus name:(uniqueName "AMENO_LABEL_") pos:textPosition

        textNode.layouttype = 0
        textNode.plane = 1
        textNode.alignment = 1
        textNode.size = textHeight
        textNode.ResetString()
        textNode.SetFont fontName 0
        textNode.ResetStyle()
        textNode.AppendString labelText

        try (textNode.renderable = true) catch ()
        if material != undefined do textNode.material = material

        textNode
    ),

    fn decorateGraphicNode node dimensionId role dimensionsLayer =
    (
        if node == undefined or not isValidNode node then return false

        dimensionsLayer.addNode node
        setTextProperty node "Ameno.Kind" graphicKind
        setTextProperty node "Ameno.DimensionId" dimensionId
        setTextProperty node "Ameno.GraphicRole" role
        setTextProperty node "Ameno.SchemaVersion" (schemaVersion as string)
        true
    ),

    fn createController pointA pointB offsetPoint systemLayer role:"test" =
    (
        local controller = Point name:(uniqueName "AMENO_DIM_CTRL_") size:5.0
        local dimensionId = "dimension-" + (controller.handle as string)

        try (controller.isHidden = true) catch ()
        try (controller.renderable = false) catch ()
        systemLayer.addNode controller

        setTextProperty controller "Ameno.Kind" controllerKind
        setTextProperty controller "Ameno.DimensionId" dimensionId
        setTextProperty controller "Ameno.DimensionRole" (role as string)
        setTextProperty controller "Ameno.SchemaVersion" (schemaVersion as string)
        setPointProperty controller "Ameno.PointA" pointA
        setPointProperty controller "Ameno.PointB" pointB
        setPointProperty controller "Ameno.OffsetPoint" offsetPoint

        controller
    ),

    fn createVisualNodes controller layout labelText dimensionsLayer =
    (
        local dimensionId = readTextProperty controller "Ameno.DimensionId"
        local dimensionMaterial = createDimensionMaterial()
        local lineNode = createLineNode layout material:dimensionMaterial
        local textNode = createTextNode labelText layout material:dimensionMaterial

        decorateGraphicNode lineNode dimensionId "lines" dimensionsLayer
        decorateGraphicNode textNode dimensionId "label" dimensionsLayer

        AmenoGraphicDimensionRecord dimensionId:dimensionId controller:controller lineNode:lineNode textNode:textNode layout:layout displayText:labelText
    ),

    fn createPreviewDimension pointA pointB offsetPoint outputUnit:#meters precision:2 =
    (
        local sceneState = ensureSceneReady()

        if sceneState.status != #ready then throw ("Ameno não conseguiu preparar a cena: " + sceneState.detail)

        local layout = AmenoDimensionMath.alignedLayout pointA pointB offsetPoint
        if not layout.valid then throw ("Não foi possível criar a prévia: " + layout.errorMessage)

        local measurement = AmenoUnitService.formatMillimeters layout.measuredMillimeters outputUnit:outputUnit precision:precision decimalSeparator:#comma
        local result = undefined

        with undo off
        (
            local dimensionMaterial = createDimensionMaterial()
            local lineNode = createLineNode layout material:dimensionMaterial
            local textNode = createTextNode measurement.text layout material:dimensionMaterial
            local dimensionId = "preview-" + (lineNode.handle as string)

            try (lineNode.isHidden = false) catch ()
            try (textNode.isHidden = false) catch ()
            decorateGraphicNode lineNode dimensionId "preview-lines" sceneState.dimensionsLayer
            decorateGraphicNode textNode dimensionId "preview-label" sceneState.dimensionsLayer
            setTextProperty lineNode "Ameno.Kind" "dimensionPreview"
            setTextProperty textNode "Ameno.Kind" "dimensionPreview"
            setTextProperty lineNode "Ameno.Preview" "1"
            setTextProperty textNode "Ameno.Preview" "1"

            result = AmenoGraphicDimensionRecord dimensionId:dimensionId lineNode:lineNode textNode:textNode layout:layout displayText:measurement.text
        )

        result
    ),

    fn updatePreviewDimension preview pointA pointB offsetPoint outputUnit:#meters precision:2 =
    (
        if preview == undefined then return undefined

        local layout = AmenoDimensionMath.alignedLayout pointA pointB offsetPoint
        if not layout.valid then return undefined

        local measurement = AmenoUnitService.formatMillimeters layout.measuredMillimeters outputUnit:outputUnit precision:precision decimalSeparator:#comma

        with undo off
        (
            updateLineSplinePoints preview.lineNode layout
            updateTextNode preview.textNode measurement.text layout
        )

        preview.layout = layout
        preview.displayText = measurement.text
        preview
    ),

    fn removePreviewDimension preview =
    (
        if preview == undefined then return false

        local nodes = #()
        if preview.lineNode != undefined and isValidNode preview.lineNode do append nodes preview.lineNode
        if preview.textNode != undefined and isValidNode preview.textNode do append nodes preview.textNode

        with undo off
        (
            for node in nodes where node != undefined and isValidNode node do delete node
        )

        true
    ),

    fn createDimension pointA pointB offsetPoint role:"test" outputUnit:#meters precision:2 =
    (
        local sceneState = ensureSceneReady()

        if sceneState.status != #ready then throw ("Ameno não conseguiu preparar a cena: " + sceneState.detail)

        local layout = AmenoDimensionMath.alignedLayout pointA pointB offsetPoint
        if not layout.valid then throw ("Não foi possível criar a cota: " + layout.errorMessage)

        local measurement = AmenoUnitService.formatMillimeters layout.measuredMillimeters outputUnit:outputUnit precision:precision decimalSeparator:#comma
        local controller = undefined
        local result = undefined

        try
        (
            undo "Ameno: criar cota" on
            (
                controller = createController pointA pointB offsetPoint sceneState.systemLayer role:role
                result = createVisualNodes controller layout measurement.text sceneState.dimensionsLayer
            )
        )
        catch
        (
            if controller != undefined and isValidNode controller do delete controller
            throw
        )

        result
    ),

    fn findControllers role:undefined =
    (
        local controllers = #()

        for node in objects where isValidNode node do
        (
            if (readTextProperty node "Ameno.Kind") == controllerKind do
            (
                if role == undefined or (readTextProperty node "Ameno.DimensionRole") == (role as string) do append controllers node
            )
        )

        controllers
    ),

    fn findNodesForDimension dimensionId =
    (
        local matches = #()

        for node in objects where isValidNode node do
        (
            if (readTextProperty node "Ameno.DimensionId") == dimensionId do append matches node
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

        for node in (findNodesForDimension dimensionId) where (readTextProperty node "Ameno.Kind") == graphicKind do append nodes node
        deleteNodes nodes
    ),

    fn rebuildDimension controller =
    (
        if controller == undefined or not isValidNode controller then throw "O controlador da cota não existe mais."
        if (readTextProperty controller "Ameno.Kind") != controllerKind then throw "O nó informado não é um controlador Ameno."

        local pointA = readPointProperty controller "Ameno.PointA"
        local pointB = readPointProperty controller "Ameno.PointB"
        local offsetPoint = readPointProperty controller "Ameno.OffsetPoint"
        local sceneState = ensureSceneReady()

        if pointA == undefined or pointB == undefined or offsetPoint == undefined then throw "Os dados geométricos da cota estão incompletos."
        if sceneState.status != #ready then throw ("Ameno não conseguiu preparar a cena: " + sceneState.detail)

        local layout = AmenoDimensionMath.alignedLayout pointA pointB offsetPoint
        if not layout.valid then throw ("Não foi possível reconstruir a cota: " + layout.errorMessage)

        local measurement = AmenoUnitService.formatMillimeters layout.measuredMillimeters outputUnit:#meters precision:2 decimalSeparator:#comma
        removeVisualNodes (readTextProperty controller "Ameno.DimensionId")
        createVisualNodes controller layout measurement.text sceneState.dimensionsLayer
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
    )
)

AmenoDimensionGraphics = AmenoDimensionGraphicsService()
