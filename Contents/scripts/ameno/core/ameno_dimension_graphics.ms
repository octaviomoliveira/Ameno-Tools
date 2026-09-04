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
    isManual = false
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
    audit = undefined
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

    fn createMarkerNode layout textHeight:20.0 textGap:12.0 fontName:"Arial" =
    (
        local textPosition = ((layout.linePointA + layout.linePointB) * 0.5) + (layout.perpendicular * textGap)
        local markerPosition = textPosition + (layout.direction * (textHeight * 2.0))
        local markerNode = TextPlus name:(uniqueName "AMENO_MARK_") pos:markerPosition

        markerNode.layouttype = 0
        markerNode.plane = 1
        markerNode.alignment = 1
        markerNode.size = textHeight * 0.8
        markerNode.ResetString()
        markerNode.SetFont fontName 0
        markerNode.ResetStyle()
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

        audit
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

    fn createController pointA pointB offsetPoint systemLayer role:"test" outputUnit:#meters precision:2 =
    (
        local controller = Point name:(uniqueName "AMENO_DIM_CTRL_") size:5.0
        local dimensionId = "dimension-" + (controller.handle as string)

        try (controller.isHidden = true) catch ()
        try (controller.renderable = false) catch ()
        systemLayer.addNode controller

        if AmenoDimensionCA != undefined do
        (
            local rec = AmenoDimensionRecord()
            rec.schemaVersion = schemaVersion
            rec.dimensionId = dimensionId
            rec.dimensionRole = (role as string)
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
            rec.styleId = "default"

            AmenoDimensionCA.applyCA controller rec
        )

        setTextProperty controller "Ameno.Kind" controllerKind
        setTextProperty controller "Ameno.DimensionId" dimensionId
        setTextProperty controller "Ameno.DimensionRole" (role as string)
        setTextProperty controller "Ameno.SchemaVersion" (schemaVersion as string)
        setPointProperty controller "Ameno.PointA" pointA
        setPointProperty controller "Ameno.PointB" pointB
        setPointProperty controller "Ameno.OffsetPoint" offsetPoint

        controller
    ),

    fn createVisualNodes controller layout auditOrText dimensionsLayer =
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

        local dimensionMaterial = createDimensionMaterial()
        local lineNode = createLineNode layout material:dimensionMaterial
        local textNode = createTextNode labelText layout material:dimensionMaterial
        local markerNode = undefined

        if audit != undefined and audit.isManual then
        (
            markerNode = createMarkerNode layout
            decorateGraphicNode markerNode dimensionId "marker" dimensionsLayer
            try (lineNode.wirecolor = (color 245 166 35)) catch ()
            try (textNode.wirecolor = (color 245 166 35)) catch ()
        )
        else
        (
            try (lineNode.wirecolor = (color 245 245 245)) catch ()
            try (textNode.wirecolor = (color 245 245 245)) catch ()
        )

        decorateGraphicNode lineNode dimensionId "lines" dimensionsLayer
        decorateGraphicNode textNode dimensionId "label" dimensionsLayer

        AmenoGraphicDimensionRecord dimensionId:dimensionId controller:controller lineNode:lineNode textNode:textNode markerNode:markerNode layout:layout displayText:labelText audit:audit
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

        local controller = undefined
        local result = undefined

        try
        (
            undo "Ameno: criar cota" on
            (
                controller = createController pointA pointB offsetPoint sceneState.systemLayer role:role outputUnit:outputUnit precision:precision
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
                result = createVisualNodes controller layout audit sceneState.dimensionsLayer
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

        for node in (findNodesForDimension dimensionId) where (readTextProperty node "Ameno.Kind") == graphicKind do append nodes node
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

        local layout = AmenoDimensionMath.alignedLayout record.pointA record.pointB record.offsetPoint
        if not layout.valid then return undefined

        local outputUnit = #meters
        try (outputUnit = (record.outputUnit as name)) catch ()

        calculateAudit controller layout outputUnit:outputUnit precision:record.precision
    ),

    fn rebuildDimension controller =
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

        local layout = AmenoDimensionMath.alignedLayout pointA pointB offsetPoint
        if not layout.valid then throw ("Não foi possível reconstruir a cota: " + layout.errorMessage)

        local audit = calculateAudit controller layout outputUnit:outputUnit precision:precision
        if record != undefined and AmenoDimensionCA != undefined do
        (
            record.lastMeasuredMm = audit.measuredMillimeters
            record.lastDeltaMm = audit.deltaMillimeters
            AmenoDimensionCA.applyCA controller record
        )

        removeVisualNodes dimensionId
        createVisualNodes controller layout audit sceneState.dimensionsLayer
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
    )
)

AmenoDimensionGraphics = AmenoDimensionGraphicsService()
