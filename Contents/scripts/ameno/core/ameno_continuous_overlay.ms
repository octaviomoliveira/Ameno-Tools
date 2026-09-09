/*
    E16 — modelo transitório da cotação contínua.

    Este módulo é deliberadamente independente da fábrica gráfica. Ele recebe
    um AmenoDimensionChainLayout já calculado, copia somente valores simples e
    devolve primitivas para o redraw callback. Nenhum método deste arquivo cria,
    procura, atualiza ou remove um nó da cena.

    O callback que consome o modelo continua sendo AmenoContinuousViewportDraw,
    definido no módulo da ferramenta. Manter uma única função global evita que
    recargas acumulem valores de callback no 3ds Max.
*/

global AmenoContinuousOverlayPrimitive
global AmenoContinuousOverlayStyleSnapshot
global AmenoContinuousOverlaySegment
global AmenoContinuousOverlayModel
global AmenoContinuousOverlayService
global AmenoDimensionGraphics
global AmenoDimensionPlaneService
global AmenoUnitService
global AmenoStyleService

struct AmenoContinuousOverlayPrimitive
(
    kind = #polyline, -- #polyline | #polygon | #marker
    points = #(),
    point = undefined,
    size = 1.0,
    colorValue = (color 245 245 245)
)

struct AmenoContinuousOverlayStyleSnapshot
(
    styleId = "default",
    lineColor = (color 245 245 245),
    textColor = (color 245 245 245),
    referenceColor = (color 80 220 120),
    emptyColor = (color 230 170 60),
    errorColor = (color 230 70 70),
    lineWidthScene = 1.0,
    extensionGapScene = 0.0,
    extensionOverhangScene = 0.0,
    terminalType = #tick,
    terminalSizeScene = 1.0,
    terminalPlacement = #auto,
    terminalAngle = 45.0,
    textGapScene = 0.0,
    outputUnit = #meters,
    precision = 2
)

struct AmenoContinuousOverlaySegment
(
    sourceIndexA = 0,
    sourceIndexB = 0,
    projectedA = [0, 0, 0],
    projectedB = [0, 0, 0],
    linePointA = [0, 0, 0],
    linePointB = [0, 0, 0],
    extensionA = undefined,
    extensionB = undefined,
    labelPoint = [0, 0, 0],
    labelText = "",
    terminalA = #(),
    terminalB = #(),
    measuredSceneUnits = 0.0,
    measuredMillimeters = 0.0,
    valid = false,
    errorCode = #none,
    errorMessage = ""
)

struct AmenoContinuousOverlayModel
(
    sessionId = "",
    revision = 0,
    visible = false,
    dirty = false,
    mode = #horizontal,
    planeType = #worldXY,
    planeOrigin = [0, 0, 0],
    planeAxisU = [1, 0, 0],
    planeAxisV = [0, 1, 0],
    planeNormal = [0, 0, 1],
    referencePoints = #(),
    hoverVisible = false,
    hoverKind = #none,
    hoverPoint = undefined,
    hoverColor = (color 230 170 60),
    offsetPoint = undefined,
    segments = #(),
    status = #idle,
    errorCode = #none,
    errorDetail = "",
    lastDrawnRevision = 0,
    drawErrorCount = 0,
    lastDrawError = ""
)

struct AmenoContinuousOverlayServiceDefinition
(
    model = AmenoContinuousOverlayModel(),
    styleSnapshot = AmenoContinuousOverlayStyleSnapshot(),
    sessionId = "",
    enabled = false,
    lastPublishedRevision = 0,
    lastRequestedRevision = 0,
    redrawRequests = 0,

    fn _finiteNumber value fallbackValue:0.0 =
    (
        local result = fallbackValue
        try
        (
            local numericValue = value as float
            if numericValue == numericValue and (abs numericValue) < 1e30 do result = numericValue
        )
        catch ()
        result
    ),

    fn _safeColor colorValue fallbackColor:(color 245 245 245) =
    (
        if colorValue == undefined then return fallbackColor
        try
        (
            local r = _finiteNumber colorValue.r fallbackValue:245.0
            local g = _finiteNumber colorValue.g fallbackValue:245.0
            local b = _finiteNumber colorValue.b fallbackValue:245.0
            color (amax 0 (amin 255 (r as integer))) (amax 0 (amin 255 (g as integer))) (amax 0 (amin 255 (b as integer)))
        )
        catch (fallbackColor)
    ),

    fn _colorFromText textValue fallbackColor:(color 245 245 245) =
    (
        if textValue == undefined or textValue == "" then return fallbackColor
        if ::AmenoStyleService != undefined do
            try (return (::AmenoStyleService.colorFromString textValue defaultColor:fallbackColor)) catch ()
        local parts = filterString (textValue as string) ","
        if parts.count != 3 then return fallbackColor
        try
        (
            color (amax 0 (amin 255 (parts[1] as integer))) \
                (amax 0 (amin 255 (parts[2] as integer))) \
                (amax 0 (amin 255 (parts[3] as integer)))
        )
        catch (fallbackColor)
    ),

    fn _sceneUnits millimetersValue =
    (
        local result = millimetersValue as float
        if ::AmenoDimensionGraphics != undefined do
            try (result = ::AmenoDimensionGraphics.toSceneUnits (millimetersValue as float)) catch ()
        result
    ),

    fn _styleField styleValue propertyName fallbackValue =
    (
        local result = fallbackValue
        if styleValue != undefined do try (result = getProperty styleValue propertyName) catch ()
        if result == undefined then fallbackValue else result
    ),

    fn snapshotStyle styleValue outputUnitValue:#meters precisionValue:2 =
    (
        local snapshot = AmenoContinuousOverlayStyleSnapshot()
        snapshot.outputUnit = outputUnitValue
        snapshot.precision = precisionValue
        if styleValue != undefined do
        (
            snapshot.styleId = (_styleField styleValue #styleId "default") as string
            local lineText = _styleField styleValue #annotationColor "245,245,245"
            local textText = _styleField styleValue #textColor ""
            snapshot.lineColor = _colorFromText lineText fallbackColor:(color 245 245 245)
            snapshot.textColor = if textText == undefined or textText == "" then snapshot.lineColor else (_colorFromText textText fallbackColor:snapshot.lineColor)
            snapshot.lineWidthScene = _sceneUnits (_finiteNumber (_styleField styleValue #lineThickness 1.5) fallbackValue:1.5)
            snapshot.extensionGapScene = _sceneUnits (_finiteNumber (_styleField styleValue #extensionGap 0.0) fallbackValue:0.0)
            snapshot.extensionOverhangScene = _sceneUnits (_finiteNumber (_styleField styleValue #extensionOverhang 80.0) fallbackValue:80.0)
            snapshot.terminalType = _styleField styleValue #terminalType #tick
            snapshot.terminalSizeScene = _sceneUnits (_finiteNumber (_styleField styleValue #terminalSize 100.0) fallbackValue:100.0)
            snapshot.terminalPlacement = _styleField styleValue #terminalPlacement #auto
            snapshot.terminalAngle = _finiteNumber (_styleField styleValue #terminalAngle 45.0) fallbackValue:45.0
            snapshot.textGapScene = _sceneUnits (_finiteNumber (_styleField styleValue #textGap 60.0) fallbackValue:60.0)
        )
        if snapshot.terminalSizeScene <= 0.00001 do snapshot.terminalSizeScene = _sceneUnits 100.0
        snapshot
    ),

    fn beginSession sessionIdValue styleValue:undefined outputUnitValue:#meters precisionValue:2 =
    (
        sessionId = if sessionIdValue == undefined then ((timeStamp()) as string) else (sessionIdValue as string)
        styleSnapshot = snapshotStyle styleValue outputUnitValue:outputUnitValue precisionValue:precisionValue
        model = AmenoContinuousOverlayModel sessionId:sessionId revision:0 visible:false dirty:false
        enabled = true
        lastPublishedRevision = 0
        lastRequestedRevision = 0
        redrawRequests = 0
        true
    ),

    fn clearSession =
    (
        local nextRevision = model.revision + 1
        model = AmenoContinuousOverlayModel sessionId:sessionId revision:nextRevision visible:false dirty:true
        enabled = false
        lastPublishedRevision = nextRevision
        lastRequestedRevision = nextRevision
        true
    ),

    fn clearModel =
    (
        if not enabled then return true
        local nextRevision = model.revision + 1
        local currentSession = sessionId
        model = AmenoContinuousOverlayModel sessionId:currentSession revision:nextRevision visible:false dirty:true
        lastPublishedRevision = nextRevision
        lastRequestedRevision = nextRevision
        true
    ),

    fn _projectToPlane pointValue layoutValue =
    (
        if pointValue == undefined then return undefined
        local originValue = try (layoutValue.planeOrigin) catch ([0,0,0])
        local axisUValue = try (layoutValue.planeAxisU) catch ([1,0,0])
        local axisVValue = try (layoutValue.planeAxisV) catch ([0,1,0])
        local delta = pointValue - originValue
        local uValue = 0.0
        local vValue = 0.0
        try
        (
            uValue = dot delta axisUValue
            vValue = dot delta axisVValue
        )
        catch (return pointValue)
        originValue + (axisUValue * uValue) + (axisVValue * vValue)
    ),

    fn _normalise vectorValue fallback:[1,0,0] =
    (
        local result = fallback
        try
        (
            local lengthValue = length vectorValue
            if lengthValue > 0.00001 then result = vectorValue / lengthValue
        )
        catch ()
        result
    ),

    fn _primitive kindValue pointArray colorValue =
    (
        if kindValue == #marker then
            AmenoContinuousOverlayPrimitive kind:kindValue point:pointArray[1] size:pointArray[2] colorValue:colorValue
        else
            AmenoContinuousOverlayPrimitive kind:kindValue points:pointArray colorValue:colorValue
    ),

    fn _buildTerminals linePointA linePointB direction perpendicular terminalType terminalSize terminalPlacement terminalAngle colorValue =
    (
        local a = #()
        local b = #()
        local resolvedSize = if terminalSize > 0.00001 then terminalSize else 1.0
        local halfWidth = resolvedSize * 0.25
        local placementSign = if terminalPlacement == #outside then -1.0 else 1.0
        local angleRadians = (terminalAngle as float) * (pi / 180.0)
        local angleDirection = _normalise ((direction * (cos angleRadians)) + (perpendicular * (sin angleRadians))) fallback:direction
        local endpointDirectionA = direction * placementSign
        local endpointDirectionB = -direction * placementSign
        case terminalType of
        (
            #arrowOpen:
            (
                append a (_primitive #polyline #(linePointA + (endpointDirectionA * resolvedSize) + (perpendicular * halfWidth), linePointA, linePointA + (endpointDirectionA * resolvedSize) - (perpendicular * halfWidth)) colorValue)
                append b (_primitive #polyline #(linePointB + (endpointDirectionB * resolvedSize) + (perpendicular * halfWidth), linePointB, linePointB + (endpointDirectionB * resolvedSize) - (perpendicular * halfWidth)) colorValue)
            )
            #arrowClosed:
            (
                append a (_primitive #polygon #(linePointA, linePointA + (endpointDirectionA * resolvedSize) + (perpendicular * halfWidth), linePointA + (endpointDirectionA * resolvedSize) - (perpendicular * halfWidth)) colorValue)
                append b (_primitive #polygon #(linePointB, linePointB + (endpointDirectionB * resolvedSize) + (perpendicular * halfWidth), linePointB + (endpointDirectionB * resolvedSize) - (perpendicular * halfWidth)) colorValue)
            )
            #diamond:
            (
                local half = resolvedSize * 0.5
                append a (_primitive #polygon #(linePointA + (direction * half), linePointA + (perpendicular * half), linePointA - (direction * half), linePointA - (perpendicular * half)) colorValue)
                append b (_primitive #polygon #(linePointB + (direction * half), linePointB + (perpendicular * half), linePointB - (direction * half), linePointB - (perpendicular * half)) colorValue)
            )
            #dot:
            (
                append a (_primitive #marker #(linePointA, (resolvedSize * 0.35)) colorValue)
                append b (_primitive #marker #(linePointB, (resolvedSize * 0.35)) colorValue)
            )
            #none: ()
            default:
            (
                local tickVector = _normalise angleDirection fallback:direction
                if terminalPlacement == #outside do tickVector = -tickVector
                tickVector *= (resolvedSize * 0.5)
                append a (_primitive #polyline #(linePointA - tickVector, linePointA + tickVector) colorValue)
                append b (_primitive #polyline #(linePointB - tickVector, linePointB + tickVector) colorValue)
            )
        )
        #(a, b)
    ),

    fn _buildSegment segmentLayout layoutValue snapshotValue pointsValue =
    (
        local segment = AmenoContinuousOverlaySegment()
        segment.sourceIndexA = segmentLayout.sourceIndexA
        segment.sourceIndexB = segmentLayout.sourceIndexB
        segment.linePointA = segmentLayout.linePointA
        segment.linePointB = segmentLayout.linePointB
        segment.projectedA = _projectToPlane segmentLayout.pointA layoutValue
        segment.projectedB = _projectToPlane segmentLayout.pointB layoutValue
        segment.measuredSceneUnits = segmentLayout.measuredSceneUnits
        segment.measuredMillimeters = segmentLayout.measuredMillimeters

        local directionValue = _normalise (segment.linePointB - segment.linePointA) fallback:(try (layoutValue.direction) catch ([1,0,0]))
        local perpendicularValue = _normalise (try (layoutValue.perpendicular) catch ([0,1,0])) fallback:[0,1,0]
        local extensionDirection = if (try (layoutValue.signedOffsetSceneUnits >= 0.0) catch true) then perpendicularValue else -perpendicularValue
        segment.extensionA = #(
            segment.projectedA + (extensionDirection * snapshotValue.extensionGapScene),
            segment.linePointA + (extensionDirection * snapshotValue.extensionOverhangScene)
        )
        segment.extensionB = #(
            segment.projectedB + (extensionDirection * snapshotValue.extensionGapScene),
            segment.linePointB + (extensionDirection * snapshotValue.extensionOverhangScene)
        )
        local labelValue = ""
        try
        (
            local formatted = AmenoUnitService.formatMillimeters segment.measuredMillimeters outputUnit:snapshotValue.outputUnit precision:snapshotValue.precision decimalSeparator:#comma
            labelValue = formatted.text
        )
        catch (labelValue = (formattedPrint segment.measuredMillimeters format:"0.00") + " mm")
        segment.labelText = labelValue
        segment.labelPoint = ((segment.linePointA + segment.linePointB) * 0.5) + (extensionDirection * snapshotValue.textGapScene)
        local terminals = _buildTerminals segment.linePointA segment.linePointB directionValue perpendicularValue snapshotValue.terminalType snapshotValue.terminalSizeScene snapshotValue.terminalPlacement snapshotValue.terminalAngle snapshotValue.lineColor
        segment.terminalA = terminals[1]
        segment.terminalB = terminals[2]
        segment.valid = true
        segment
    ),

    fn buildModel pointsValue layoutValue snapshotValue:undefined =
    (
        if layoutValue == undefined or not layoutValue.valid then return undefined
        local resolvedSnapshot = if snapshotValue == undefined then styleSnapshot else snapshotValue
        local nextModel = AmenoContinuousOverlayModel sessionId:sessionId visible:true dirty:true mode:layoutValue.dimensionMode
        nextModel.planeType = try (layoutValue.planeType) catch (#worldXY)
        nextModel.planeOrigin = try (layoutValue.planeOrigin) catch ([0,0,0])
        nextModel.planeAxisU = try (layoutValue.planeAxisU) catch ([1,0,0])
        nextModel.planeAxisV = try (layoutValue.planeAxisV) catch ([0,1,0])
        nextModel.planeNormal = try (layoutValue.planeNormal) catch ([0,0,1])
        nextModel.offsetPoint = layoutValue.offsetPoint
        nextModel.referencePoints = if pointsValue == undefined then #() else (for p in pointsValue collect p)
        for segmentLayout in layoutValue.segments do
            append nextModel.segments (_buildSegment segmentLayout layoutValue resolvedSnapshot pointsValue)
        nextModel
    ),

    fn _samePoint firstValue secondValue tolerance:0.00001 =
    (
        if firstValue == undefined or secondValue == undefined then return (firstValue == secondValue)
        try ((distance firstValue secondValue) <= tolerance) catch (firstValue == secondValue)
    ),

    fn _sameColor firstValue secondValue =
    (
        if firstValue == undefined or secondValue == undefined then return (firstValue == secondValue)
        try
        (
            (abs ((firstValue.r as float) - (secondValue.r as float)) <= 0.001) and
            (abs ((firstValue.g as float) - (secondValue.g as float)) <= 0.001) and
            (abs ((firstValue.b as float) - (secondValue.b as float)) <= 0.001) and
            (abs ((firstValue.a as float) - (secondValue.a as float)) <= 0.001)
        )
        catch (firstValue == secondValue)
    ),

    fn _layoutMatchesModel pointsValue layoutValue =
    (
        if layoutValue == undefined or not layoutValue.valid then return false
        if not model.visible or model.status != #ready then return false
        if model.mode != layoutValue.dimensionMode then return false
        if not _samePoint model.offsetPoint layoutValue.offsetPoint then return false
        if model.referencePoints.count != pointsValue.count then return false
        for pointIndex = 1 to pointsValue.count do
            if not _samePoint model.referencePoints[pointIndex] pointsValue[pointIndex] then return false
        if model.segments.count != layoutValue.segments.count then return false
        for segmentIndex = 1 to layoutValue.segments.count do
        (
            local oldSegment = model.segments[segmentIndex]
            local newSegment = layoutValue.segments[segmentIndex]
            if oldSegment == undefined or newSegment == undefined then return false
            if oldSegment.sourceIndexA != newSegment.sourceIndexA or oldSegment.sourceIndexB != newSegment.sourceIndexB then return false
            if not _samePoint oldSegment.linePointA newSegment.linePointA then return false
            if not _samePoint oldSegment.linePointB newSegment.linePointB then return false
            if not _samePoint oldSegment.projectedA (_projectToPlane newSegment.pointA layoutValue) then return false
            if not _samePoint oldSegment.projectedB (_projectToPlane newSegment.pointB layoutValue) then return false
            if abs ((oldSegment.measuredSceneUnits as float) - (newSegment.measuredSceneUnits as float)) > 0.00001 then return false
        )
        true
    ),

    fn publishLayout pointsValue layoutValue =
    (
        if not enabled then return false
        if layoutValue == undefined or not layoutValue.valid then
        (
            model.visible = false
            model.dirty = true
            model.status = #invalid
            model.errorCode = if layoutValue == undefined then #missingLayout else layoutValue.errorCode
            model.errorDetail = if layoutValue == undefined then "Layout indisponível." else layoutValue.errorMessage
            model.segments = #()
            model.revision += 1
            lastPublishedRevision = model.revision
            model.dirty = true
            return false
        )
        -- O mouseMove pode repetir o mesmo ponto dezenas de vezes. Não
        -- reconstrua o snapshot nem incremente revision quando nada mudou.
        if _layoutMatchesModel pointsValue layoutValue then return false
        local previousHoverVisible = model.hoverVisible
        local previousHoverKind = model.hoverKind
        local previousHoverPoint = model.hoverPoint
        local previousHoverColor = model.hoverColor
        local nextModel = buildModel pointsValue layoutValue
        if nextModel == undefined then return false
        nextModel.hoverVisible = previousHoverVisible
        nextModel.hoverKind = previousHoverKind
        nextModel.hoverPoint = previousHoverPoint
        nextModel.hoverColor = previousHoverColor
        nextModel.revision = model.revision + 1
        nextModel.status = #ready
        nextModel.errorCode = #none
        nextModel.errorDetail = ""
        model = nextModel
        lastPublishedRevision = model.revision
        model.dirty = true
        true
    ),

    fn publishHover kindValue pointValue colorValue:(color 230 170 60) =
    (
        if not enabled then return false
        local resolvedKind = if kindValue == undefined then #none else kindValue
        local resolvedVisible = (pointValue != undefined and resolvedKind == #reference)
        local resolvedPoint = if resolvedVisible then pointValue else undefined
        local resolvedColor = colorValue
        if model.hoverKind == resolvedKind and model.hoverVisible == resolvedVisible and \
            _samePoint model.hoverPoint resolvedPoint and _sameColor model.hoverColor resolvedColor then
            return false
        model.hoverKind = resolvedKind
        model.hoverVisible = resolvedVisible
        model.hoverPoint = resolvedPoint
        model.hoverColor = resolvedColor
        model.revision += 1
        lastPublishedRevision = model.revision
        model.dirty = true
        true
    ),

    fn requestRedraw =
    (
        if not enabled then return false
        -- Uma mesma revision precisa de no máximo uma solicitação. O callback
        -- ainda pode ser chamado pelo próprio Max em redraws externos.
        if model.revision == lastRequestedRevision then return false
        lastRequestedRevision = model.revision
        redrawRequests += 1
        try (redrawViews()) catch ()
        true
    ),

    fn _drawPrimitive primitiveValue =
    (
        if primitiveValue == undefined then return true
        local drawSucceeded = true
        case primitiveValue.kind of
        (
            #marker:
                try (gw.marker primitiveValue.point #diamond color:primitiveValue.colorValue) catch (drawSucceeded = false)
            #polygon:
                try (gw.polygon primitiveValue.points color:primitiveValue.colorValue) catch
                (
                    try (gw.polyline primitiveValue.points true color:primitiveValue.colorValue) catch (drawSucceeded = false)
                )
            default:
                try (gw.polyline primitiveValue.points false color:primitiveValue.colorValue) catch (drawSucceeded = false)
        )
        if not drawSucceeded do
        (
            model.drawErrorCount += 1
            model.lastDrawError = "Falha ao desenhar primitiva " + (primitiveValue.kind as string)
        )
        drawSucceeded
    ),

    fn _drawMarker pointValue markerTypeValue colorValue =
    (
        try
        (
            gw.marker pointValue markerTypeValue color:colorValue
            true
        )
        catch
        (
            model.drawErrorCount += 1
            model.lastDrawError = "Falha ao desenhar marcador"
            false
        )
    ),

    fn drawCurrent =
    (
        if not enabled or model.sessionId != sessionId or not model.visible then return false
        try
        (
            gw.setTransform (matrix3 1)
            for pointValue in model.referencePoints where pointValue != undefined do
                _drawMarker pointValue #smallDiamond styleSnapshot.referenceColor

            for segmentValue in model.segments where segmentValue != undefined and segmentValue.valid do
            (
                _drawPrimitive (AmenoContinuousOverlayPrimitive kind:#polyline points:segmentValue.extensionA colorValue:styleSnapshot.lineColor)
                _drawPrimitive (AmenoContinuousOverlayPrimitive kind:#polyline points:segmentValue.extensionB colorValue:styleSnapshot.lineColor)
                _drawPrimitive (AmenoContinuousOverlayPrimitive kind:#polyline points:#(segmentValue.linePointA, segmentValue.linePointB) colorValue:styleSnapshot.lineColor)
                for primitiveValue in segmentValue.terminalA do _drawPrimitive primitiveValue
                for primitiveValue in segmentValue.terminalB do _drawPrimitive primitiveValue
                try (gw.text segmentValue.labelPoint segmentValue.labelText color:styleSnapshot.textColor) catch
                (
                    model.drawErrorCount += 1
                    model.lastDrawError = "Falha ao desenhar rótulo"
                )
            )

            if model.hoverVisible and model.hoverPoint != undefined do
                _drawMarker model.hoverPoint #diamond model.hoverColor
            if model.status == #invalid and model.offsetPoint != undefined do
                _drawMarker model.offsetPoint #diamond styleSnapshot.emptyColor
            gw.enlargeUpdateRect #whole
            model.lastDrawnRevision = model.revision
            model.dirty = false
            true
        )
        catch
        (
            model.drawErrorCount += 1
            model.lastDrawError = getCurrentException() as string
            false
        )
    )
)

AmenoContinuousOverlayService = AmenoContinuousOverlayServiceDefinition()
