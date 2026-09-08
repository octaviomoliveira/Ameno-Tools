global AmenoUnitService
global AmenoDimensionMath
global AmenoDimensionPlane
global AmenoDimensionPlaneService

struct AmenoMeasurementFormat
(
    inputMillimeters = 0.0,
    roundedMillimeters = 0.0,
    outputUnit = #meters,
    outputValue = 0.0,
    text = ""
)

struct AmenoAlignedDimensionLayout
(
    valid = false,
    errorCode = #none,
    errorMessage = "",
    pointA = [0, 0, 0],
    pointB = [0, 0, 0],
    offsetPoint = [0, 0, 0],
    projectedA = [0, 0, 0],
    projectedB = [0, 0, 0],
    projectedOffsetPoint = [0, 0, 0],
    direction = [0, 0, 0],
    perpendicular = [0, 0, 0],
    linePointA = [0, 0, 0],
    linePointB = [0, 0, 0],
    signedOffsetSceneUnits = 0.0,
    side = #positive,
    measuredSceneUnits = 0.0,
    measuredMillimeters = 0.0,
    dimensionMode = #aligned,  -- E10.1: #aligned | #horizontal | #vertical
    planeType = #worldXY,
    planeOrigin = [0, 0, 0],
    planeAxisU = [1, 0, 0],
    planeAxisV = [0, 1, 0],
    planeNormal = [0, 0, 1]
)

struct AmenoUnitServiceDefinition
(
    fn unitToMillimeters unitType =
    (
        case unitType of
        (
            #millimeters: 1.0
            #centimeters: 10.0
            #meters: 1000.0
            #kilometers: 1000000.0
            #inches: 25.4
            #feet: 304.8
            #miles: 1609344.0
            default: undefined
        )
    ),

    fn outputUnitMultiplier outputUnit =
    (
        local multiplier = unitToMillimeters outputUnit

        if multiplier == undefined then throw ("Unidade Ameno não suportada: " + (outputUnit as string))
        multiplier
    ),

    fn outputUnitSuffix outputUnit =
    (
        case outputUnit of
        (
            #millimeters: "mm"
            #centimeters: "cm"
            #meters: "m"
            #kilometers: "km"
            #inches: "in"
            #feet: "ft"
            #miles: "mi"
            default: ""
        )
    ),

    fn currentMillimetersPerSceneUnit =
    (
        local multiplier = unitToMillimeters units.SystemType

        if multiplier == undefined then throw ("Unidade de sistema não suportada: " + (units.SystemType as string))
        units.SystemScale * multiplier
    ),

    fn sceneUnitsToMillimeters sceneValue systemScale:undefined systemType:undefined =
    (
        local resolvedScale = systemScale
        local resolvedType = systemType

        if resolvedScale == undefined do resolvedScale = units.SystemScale
        if resolvedType == undefined do resolvedType = units.SystemType

        local multiplier = unitToMillimeters resolvedType

        if multiplier == undefined then throw ("Unidade de sistema não suportada: " + (resolvedType as string))
        sceneValue * resolvedScale * multiplier
    ),

    fn millimetersToSceneUnits millimeters systemScale:undefined systemType:undefined =
    (
        local resolvedScale = systemScale
        local resolvedType = systemType

        if resolvedScale == undefined do resolvedScale = units.SystemScale
        if resolvedType == undefined do resolvedType = units.SystemType

        local multiplier = unitToMillimeters resolvedType

        if multiplier == undefined then throw ("Unidade de sistema não suportada: " + (resolvedType as string))
        millimeters / (resolvedScale * multiplier)
    ),

    fn roundHalfAwayFromZero value =
    (
        if value >= 0.0 then floor (value + 0.5) else ceil (value - 0.5)
    ),

    fn roundToIncrement millimeters incrementMillimeters =
    (
        if incrementMillimeters == undefined or incrementMillimeters <= 0.0 then return millimeters

        (roundHalfAwayFromZero (millimeters / incrementMillimeters)) * incrementMillimeters
    ),

    fn trimTrailingZeros numericText =
    (
        local decimalIndex = findString numericText "."
        local result = numericText

        if decimalIndex != undefined then
        (
            while result.count > decimalIndex and (substring result result.count 1) == "0" do
            (
                result = substring result 1 (result.count - 1)
            )

            if result.count == decimalIndex do result = substring result 1 (result.count - 1)
        )

        result
    ),

    fn formatMillimeters millimeters outputUnit:#meters precision:2 trimZeros:false decimalSeparator:#comma prefix:"" suffix:undefined roundingIncrementMillimeters:undefined =
    (
        local safePrecision = if precision < 0 then 0 else precision
        local roundedMillimeters = roundToIncrement millimeters roundingIncrementMillimeters
        local multiplier = outputUnitMultiplier outputUnit
        local outputValue = roundedMillimeters / multiplier
        local numericText = formattedPrint outputValue format:("0." + (safePrecision as string) + "f") userLocale:false

        if trimZeros do numericText = trimTrailingZeros numericText
        if decimalSeparator == #comma do numericText = substituteString numericText "." ","

        local resolvedSuffix = suffix

        if resolvedSuffix == undefined do resolvedSuffix = " " + (outputUnitSuffix outputUnit)

        AmenoMeasurementFormat inputMillimeters:millimeters roundedMillimeters:roundedMillimeters outputUnit:outputUnit outputValue:outputValue text:(prefix + numericText + resolvedSuffix)
    )
)

struct AmenoDimensionMathDefinition
(
    fn resolvePlane planeValue =
    (
        if planeValue == undefined then
        (
            if ::AmenoDimensionPlaneService != undefined then return ::AmenoDimensionPlaneService.worldXY()
            return AmenoDimensionPlane planeType:#worldXY origin:[0,0,0] axisU:[1,0,0] axisV:[0,1,0] normal:[0,0,1] valid:true
        )
        planeValue
    ),

    fn projectToWorld point plane:undefined =
    (
        local resolvedPlane = resolvePlane plane
        if ::AmenoDimensionPlaneService != undefined then
            ::AmenoDimensionPlaneService.project resolvedPlane point
        else
            [point.x, point.y, 0.0]
    ),

    fn coordinatesOf point plane:undefined =
    (
        local resolvedPlane = resolvePlane plane
        if ::AmenoDimensionPlaneService != undefined then
            ::AmenoDimensionPlaneService.coordinatesOf resolvedPlane point
        else
            [point.x, point.y, point.z]
    ),

    fn projectToWorldXY point =
    (
        projectToWorld point plane:(resolvePlane undefined)
    ),

    -- Cota alinhada: mede e segue o vetor AB projetado no plano XY.
    fn alignedLayout pointA pointB offsetPoint millimetersPerSceneUnit:undefined toleranceSceneUnits:0.00001 plane:undefined =
    (
        local resolvedPlane = resolvePlane plane
        local projectedA = projectToWorld pointA plane:resolvedPlane
        local projectedB = projectToWorld pointB plane:resolvedPlane
        local projectedOffset = projectToWorld offsetPoint plane:resolvedPlane
        if projectedA == undefined or projectedB == undefined or projectedOffset == undefined then
            return AmenoAlignedDimensionLayout pointA:pointA pointB:pointB offsetPoint:offsetPoint errorCode:#invalidPlane errorMessage:"O plano da cota é inválido." dimensionMode:#aligned
        local measurementVector = projectedB - projectedA
        local measuredSceneUnits = length measurementVector

        if measuredSceneUnits <= toleranceSceneUnits then
        (
            return AmenoAlignedDimensionLayout pointA:pointA pointB:pointB offsetPoint:offsetPoint projectedA:projectedA projectedB:projectedB projectedOffsetPoint:projectedOffset \
                planeType:resolvedPlane.planeType planeOrigin:resolvedPlane.origin planeAxisU:resolvedPlane.axisU planeAxisV:resolvedPlane.axisV planeNormal:resolvedPlane.normal \
                errorCode:#coincidentPoints errorMessage:"Os pontos A e B coincidem no plano da cota." dimensionMode:#aligned
        )

        local resolvedMillimetersPerSceneUnit = millimetersPerSceneUnit

        if resolvedMillimetersPerSceneUnit == undefined do resolvedMillimetersPerSceneUnit = AmenoUnitService.currentMillimetersPerSceneUnit()

        if resolvedMillimetersPerSceneUnit <= 0.0 then
        (
            return AmenoAlignedDimensionLayout pointA:pointA pointB:pointB offsetPoint:offsetPoint projectedA:projectedA projectedB:projectedB projectedOffsetPoint:projectedOffset \
                planeType:resolvedPlane.planeType planeOrigin:resolvedPlane.origin planeAxisU:resolvedPlane.axisU planeAxisV:resolvedPlane.axisV planeNormal:resolvedPlane.normal \
                errorCode:#invalidUnitScale errorMessage:"A escala de unidades da cena deve ser maior que zero." dimensionMode:#aligned
        )

        local direction = normalize measurementVector
        local perpendicular = normalize (cross resolvedPlane.normal direction)
        local signedOffset = dot (projectedOffset - projectedA) perpendicular
        local linePointA = projectedA + (perpendicular * signedOffset)
        local linePointB = projectedB + (perpendicular * signedOffset)

        AmenoAlignedDimensionLayout valid:true pointA:pointA pointB:pointB offsetPoint:offsetPoint projectedA:projectedA projectedB:projectedB projectedOffsetPoint:projectedOffset direction:direction perpendicular:perpendicular \
            planeType:resolvedPlane.planeType planeOrigin:resolvedPlane.origin planeAxisU:resolvedPlane.axisU planeAxisV:resolvedPlane.axisV planeNormal:resolvedPlane.normal \
            linePointA:linePointA linePointB:linePointB signedOffsetSceneUnits:signedOffset side:(if signedOffset >= 0.0 then #positive else #negative) measuredSceneUnits:measuredSceneUnits measuredMillimeters:(measuredSceneUnits * resolvedMillimetersPerSceneUnit) dimensionMode:#aligned
    ),

    -- Cota horizontal: mede somente a componente X de A para B.
    -- A linha principal é horizontal; linhas de extensão sobem/descem até o afastamento.
    fn horizontalLayout pointA pointB offsetPoint millimetersPerSceneUnit:undefined toleranceSceneUnits:0.00001 plane:undefined =
    (
        local resolvedPlane = resolvePlane plane
        local projectedA = projectToWorld pointA plane:resolvedPlane
        local projectedB = projectToWorld pointB plane:resolvedPlane
        local projectedOffset = projectToWorld offsetPoint plane:resolvedPlane
        if projectedA == undefined or projectedB == undefined or projectedOffset == undefined then
            return AmenoAlignedDimensionLayout pointA:pointA pointB:pointB offsetPoint:offsetPoint errorCode:#invalidPlane errorMessage:"O plano da cota é inválido." dimensionMode:#horizontal
        local coordsA = coordinatesOf pointA plane:resolvedPlane
        local coordsB = coordinatesOf pointB plane:resolvedPlane
        local coordsOffset = coordinatesOf offsetPoint plane:resolvedPlane
        if coordsA == undefined or coordsB == undefined or coordsOffset == undefined then
            return AmenoAlignedDimensionLayout pointA:pointA pointB:pointB offsetPoint:offsetPoint errorCode:#invalidPlane errorMessage:"As coordenadas do plano são inválidas." dimensionMode:#horizontal

        local dx = coordsB.x - coordsA.x
        local measuredSceneUnits = abs dx

        if measuredSceneUnits <= toleranceSceneUnits then
        (
            return AmenoAlignedDimensionLayout pointA:pointA pointB:pointB offsetPoint:offsetPoint projectedA:projectedA projectedB:projectedB projectedOffsetPoint:projectedOffset \
                planeType:resolvedPlane.planeType planeOrigin:resolvedPlane.origin planeAxisU:resolvedPlane.axisU planeAxisV:resolvedPlane.axisV planeNormal:resolvedPlane.normal \
                errorCode:#zeroProjection errorMessage:"A projeção horizontal entre A e B é zero." dimensionMode:#horizontal
        )

        local resolvedMillimetersPerSceneUnit = millimetersPerSceneUnit
        if resolvedMillimetersPerSceneUnit == undefined do resolvedMillimetersPerSceneUnit = AmenoUnitService.currentMillimetersPerSceneUnit()
        if resolvedMillimetersPerSceneUnit <= 0.0 then
        (
            return AmenoAlignedDimensionLayout pointA:pointA pointB:pointB offsetPoint:offsetPoint projectedA:projectedA projectedB:projectedB projectedOffsetPoint:projectedOffset errorCode:#invalidUnitScale errorMessage:"A escala de unidades da cena deve ser maior que zero." dimensionMode:#horizontal
        )

        -- Direção sempre horizontal (X), perpendicular sempre vertical (Y)
        local direction = if dx >= 0.0 then resolvedPlane.axisU else -resolvedPlane.axisU
        local perpendicular = resolvedPlane.axisV

        -- Afastamento: componente Y do ponto de offset em relação a A
        local signedOffset = coordsOffset.y - coordsA.y

        -- A linha principal usa a coordenada V absoluta do ponto de afastamento.
        -- Isso mantém a cota horizontal realmente horizontal mesmo quando A e B
        -- estão em alturas diferentes na fachada.
        local linePointA = resolvedPlane.origin + (resolvedPlane.axisU * coordsA.x) + (resolvedPlane.axisV * coordsOffset.y)
        local linePointB = resolvedPlane.origin + (resolvedPlane.axisU * coordsB.x) + (resolvedPlane.axisV * coordsOffset.y)

        AmenoAlignedDimensionLayout valid:true pointA:pointA pointB:pointB offsetPoint:offsetPoint projectedA:projectedA projectedB:projectedB projectedOffsetPoint:projectedOffset direction:direction perpendicular:perpendicular \
            planeType:resolvedPlane.planeType planeOrigin:resolvedPlane.origin planeAxisU:resolvedPlane.axisU planeAxisV:resolvedPlane.axisV planeNormal:resolvedPlane.normal \
            linePointA:linePointA linePointB:linePointB signedOffsetSceneUnits:signedOffset side:(if signedOffset >= 0.0 then #positive else #negative) measuredSceneUnits:measuredSceneUnits measuredMillimeters:(measuredSceneUnits * resolvedMillimetersPerSceneUnit) dimensionMode:#horizontal
    ),

    -- Cota vertical: mede somente a componente Y de A para B.
    -- A linha principal é vertical; linhas de extensão vão à esquerda/direita até o afastamento.
    fn verticalLayout pointA pointB offsetPoint millimetersPerSceneUnit:undefined toleranceSceneUnits:0.00001 plane:undefined =
    (
        local resolvedPlane = resolvePlane plane
        local projectedA = projectToWorld pointA plane:resolvedPlane
        local projectedB = projectToWorld pointB plane:resolvedPlane
        local projectedOffset = projectToWorld offsetPoint plane:resolvedPlane
        if projectedA == undefined or projectedB == undefined or projectedOffset == undefined then
            return AmenoAlignedDimensionLayout pointA:pointA pointB:pointB offsetPoint:offsetPoint errorCode:#invalidPlane errorMessage:"O plano da cota é inválido." dimensionMode:#vertical
        local coordsA = coordinatesOf pointA plane:resolvedPlane
        local coordsB = coordinatesOf pointB plane:resolvedPlane
        local coordsOffset = coordinatesOf offsetPoint plane:resolvedPlane
        if coordsA == undefined or coordsB == undefined or coordsOffset == undefined then
            return AmenoAlignedDimensionLayout pointA:pointA pointB:pointB offsetPoint:offsetPoint errorCode:#invalidPlane errorMessage:"As coordenadas do plano são inválidas." dimensionMode:#vertical

        local dy = coordsB.y - coordsA.y
        local measuredSceneUnits = abs dy

        if measuredSceneUnits <= toleranceSceneUnits then
        (
            return AmenoAlignedDimensionLayout pointA:pointA pointB:pointB offsetPoint:offsetPoint projectedA:projectedA projectedB:projectedB projectedOffsetPoint:projectedOffset \
                planeType:resolvedPlane.planeType planeOrigin:resolvedPlane.origin planeAxisU:resolvedPlane.axisU planeAxisV:resolvedPlane.axisV planeNormal:resolvedPlane.normal \
                errorCode:#zeroProjection errorMessage:"A projeção vertical entre A e B é zero." dimensionMode:#vertical
        )

        local resolvedMillimetersPerSceneUnit = millimetersPerSceneUnit
        if resolvedMillimetersPerSceneUnit == undefined do resolvedMillimetersPerSceneUnit = AmenoUnitService.currentMillimetersPerSceneUnit()
        if resolvedMillimetersPerSceneUnit <= 0.0 then
        (
            return AmenoAlignedDimensionLayout pointA:pointA pointB:pointB offsetPoint:offsetPoint projectedA:projectedA projectedB:projectedB projectedOffsetPoint:projectedOffset errorCode:#invalidUnitScale errorMessage:"A escala de unidades da cena deve ser maior que zero." dimensionMode:#vertical
        )

        -- Direção sempre vertical (Y), perpendicular sempre horizontal (X)
        local direction = if dy >= 0.0 then resolvedPlane.axisV else -resolvedPlane.axisV
        local perpendicular = resolvedPlane.axisU

        -- Afastamento: componente X do ponto de offset em relação a A
        local signedOffset = coordsOffset.x - coordsA.x

        -- A linha principal usa a coordenada U absoluta do ponto de afastamento.
        -- Assim, a cota vertical permanece em uma única prumada.
        local linePointA = resolvedPlane.origin + (resolvedPlane.axisU * coordsOffset.x) + (resolvedPlane.axisV * coordsA.y)
        local linePointB = resolvedPlane.origin + (resolvedPlane.axisU * coordsOffset.x) + (resolvedPlane.axisV * coordsB.y)

        AmenoAlignedDimensionLayout valid:true pointA:pointA pointB:pointB offsetPoint:offsetPoint projectedA:projectedA projectedB:projectedB projectedOffsetPoint:projectedOffset direction:direction perpendicular:perpendicular \
            planeType:resolvedPlane.planeType planeOrigin:resolvedPlane.origin planeAxisU:resolvedPlane.axisU planeAxisV:resolvedPlane.axisV planeNormal:resolvedPlane.normal \
            linePointA:linePointA linePointB:linePointB signedOffsetSceneUnits:signedOffset side:(if signedOffset >= 0.0 then #positive else #negative) measuredSceneUnits:measuredSceneUnits measuredMillimeters:(measuredSceneUnits * resolvedMillimetersPerSceneUnit) dimensionMode:#vertical
    ),

    -- Dispatcher público: escolhe o layout correto pelo modo.
    -- mode: #aligned (default), #horizontal, #vertical
    -- Cenas antigas sem modo assumem #aligned.
    fn layoutForMode pointA pointB offsetPoint mode:#aligned millimetersPerSceneUnit:undefined toleranceSceneUnits:0.00001 plane:undefined =
    (
        case mode of
        (
            #horizontal: horizontalLayout pointA pointB offsetPoint millimetersPerSceneUnit:millimetersPerSceneUnit toleranceSceneUnits:toleranceSceneUnits plane:plane
            #vertical:   verticalLayout   pointA pointB offsetPoint millimetersPerSceneUnit:millimetersPerSceneUnit toleranceSceneUnits:toleranceSceneUnits plane:plane
            default:     alignedLayout    pointA pointB offsetPoint millimetersPerSceneUnit:millimetersPerSceneUnit toleranceSceneUnits:toleranceSceneUnits plane:plane
        )
    ),

    fn nearlyEqual valueA valueB tolerance:0.0001 =
    (
        abs (valueA - valueB) <= tolerance
    ),

    fn nearlyEqualPoint pointA pointB tolerance:0.0001 =
    (
        (length (pointA - pointB)) <= tolerance
    )
)

AmenoUnitService = AmenoUnitServiceDefinition()
AmenoDimensionMath = AmenoDimensionMathDefinition()
