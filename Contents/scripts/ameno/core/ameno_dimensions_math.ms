global AmenoUnitService
global AmenoDimensionMath

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
    measuredMillimeters = 0.0
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
    fn projectToWorldXY point =
    (
        [point.x, point.y, 0.0]
    ),

    fn alignedLayout pointA pointB offsetPoint millimetersPerSceneUnit:undefined toleranceSceneUnits:0.00001 =
    (
        local projectedA = projectToWorldXY pointA
        local projectedB = projectToWorldXY pointB
        local projectedOffset = projectToWorldXY offsetPoint
        local measurementVector = projectedB - projectedA
        local measuredSceneUnits = length measurementVector

        if measuredSceneUnits <= toleranceSceneUnits then
        (
            return AmenoAlignedDimensionLayout pointA:pointA pointB:pointB offsetPoint:offsetPoint projectedA:projectedA projectedB:projectedB projectedOffsetPoint:projectedOffset errorCode:#coincidentPoints errorMessage:"Os pontos A e B coincidem no plano XY."
        )

        local resolvedMillimetersPerSceneUnit = millimetersPerSceneUnit

        if resolvedMillimetersPerSceneUnit == undefined do resolvedMillimetersPerSceneUnit = AmenoUnitService.currentMillimetersPerSceneUnit()

        if resolvedMillimetersPerSceneUnit <= 0.0 then
        (
            return AmenoAlignedDimensionLayout pointA:pointA pointB:pointB offsetPoint:offsetPoint projectedA:projectedA projectedB:projectedB projectedOffsetPoint:projectedOffset errorCode:#invalidUnitScale errorMessage:"A escala de unidades da cena deve ser maior que zero."
        )

        local direction = normalize measurementVector
        local perpendicular = normalize (cross [0, 0, 1] direction)
        local signedOffset = dot (projectedOffset - projectedA) perpendicular
        local linePointA = projectedA + (perpendicular * signedOffset)
        local linePointB = projectedB + (perpendicular * signedOffset)

        AmenoAlignedDimensionLayout valid:true pointA:pointA pointB:pointB offsetPoint:offsetPoint projectedA:projectedA projectedB:projectedB projectedOffsetPoint:projectedOffset direction:direction perpendicular:perpendicular linePointA:linePointA linePointB:linePointB signedOffsetSceneUnits:signedOffset side:(if signedOffset >= 0.0 then #positive else #negative) measuredSceneUnits:measuredSceneUnits measuredMillimeters:(measuredSceneUnits * resolvedMillimetersPerSceneUnit)
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
