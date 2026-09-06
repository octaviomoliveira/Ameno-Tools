/* E12-B — matemática pura de cadeia de cotas em uma linha compartilhada. */

global AmenoDimensionChainMath
global AmenoDimensionChainLayout
global AmenoDimensionChainReferenceLayout
global AmenoDimensionChainSegmentLayout
global AmenoUnitService

struct AmenoDimensionChainReferenceLayout
(
    sourceIndex    = 0,
    sourcePoint    = [0,0,0],
    station        = 0.0,
    projectedPoint = [0,0,0]
)

struct AmenoDimensionChainSegmentLayout
(
    sourceIndexA       = 0,
    sourceIndexB       = 0,
    pointA             = [0,0,0],
    pointB             = [0,0,0],
    linePointA         = [0,0,0],
    linePointB         = [0,0,0],
    measuredSceneUnits = 0.0,
    measuredMillimeters = 0.0
)

struct AmenoDimensionChainLayout
(
    valid                  = false,
    errorCode              = #none,
    errorMessage           = "",
    dimensionMode          = #horizontal,
    origin                 = [0,0,0],
    direction              = [1,0,0],
    perpendicular          = [0,1,0],
    signedOffsetSceneUnits = 0.0,
    offsetPoint            = [0,0,0],
    orderedReferences      = #(),
    segments               = #()
)

struct AmenoDimensionChainMathDefinition
(
    fn projectToWorldXY pointValue =
    (
        if pointValue == undefined then undefined else [pointValue.x, pointValue.y, 0.0]
    ),

    fn invalidLayout errorCodeValue errorMessageValue modeValue =
    (
        AmenoDimensionChainLayout valid:false errorCode:errorCodeValue \
            errorMessage:errorMessageValue dimensionMode:modeValue
    ),

    fn resolveBasis points mode toleranceSceneUnits =
    (
        case mode of
        (
            #horizontal: #([1.0,0,0], [0,1.0,0])
            #vertical:   #([0,1.0,0], [1.0,0,0])
            #aligned:
            (
                if points.count < 2 then return undefined
                local originPoint = projectToWorldXY points[1]
                local secondPoint = projectToWorldXY points[2]
                if originPoint == undefined or secondPoint == undefined then return undefined
                local axisVector = secondPoint - originPoint
                if length axisVector <= toleranceSceneUnits then return undefined
                local axisDirection = normalize axisVector
                #(axisDirection, normalize (cross [0,0,1.0] axisDirection))
            )
            default: undefined
        )
    ),

    fn sortByStation references =
    (
        local ordered = #()
        for referenceValue in references do
        (
            append ordered referenceValue
            local cursorIndex = ordered.count
            while cursorIndex > 1 and ordered[cursorIndex].station < ordered[cursorIndex - 1].station do
            (
                local swapValue = ordered[cursorIndex - 1]
                ordered[cursorIndex - 1] = ordered[cursorIndex]
                ordered[cursorIndex] = swapValue
                cursorIndex -= 1
            )
        )
        ordered
    ),

    fn layout points offsetPoint mode:#horizontal millimetersPerSceneUnit:undefined toleranceSceneUnits:0.00001 =
    (
        if points == undefined or points.count < 2 then
            return (invalidLayout #insufficientReferences "A cadeia exige ao menos duas referências." mode)
        if offsetPoint == undefined then
            return (invalidLayout #missingOffset "O ponto de afastamento é obrigatório." mode)
        if toleranceSceneUnits <= 0.0 then
            return (invalidLayout #invalidTolerance "A tolerância deve ser maior que zero." mode)

        local resolvedScale = millimetersPerSceneUnit
        if resolvedScale == undefined do resolvedScale = AmenoUnitService.currentMillimetersPerSceneUnit()
        if resolvedScale == undefined or resolvedScale <= 0.0 then
            return (invalidLayout #invalidUnitScale "A escala de unidades deve ser maior que zero." mode)

        local originPoint = projectToWorldXY points[1]
        local projectedOffset = projectToWorldXY offsetPoint
        if originPoint == undefined or projectedOffset == undefined then
            return (invalidLayout #invalidPoint "Referência ou afastamento inválido." mode)

        local basis = resolveBasis points mode toleranceSceneUnits
        if basis == undefined then
        (
            local basisError = if mode == #aligned then #invalidAlignedAxis else #unsupportedMode
            return (invalidLayout basisError "Não foi possível resolver o eixo da cadeia." mode)
        )

        local axisDirection = basis[1]
        local perpendicularDirection = basis[2]
        local signedOffset = dot (projectedOffset - originPoint) perpendicularDirection
        local sourceReferences = #()

        for sourceIndex = 1 to points.count do
        (
            local sourcePointValue = projectToWorldXY points[sourceIndex]
            if sourcePointValue == undefined then
                return (invalidLayout #invalidPoint ("Referência inválida no índice " + (sourceIndex as string) + ".") mode)
            local stationValue = dot (sourcePointValue - originPoint) axisDirection
            local projectedValue = originPoint + (axisDirection * stationValue) + (perpendicularDirection * signedOffset)
            append sourceReferences (AmenoDimensionChainReferenceLayout sourceIndex:sourceIndex \
                sourcePoint:sourcePointValue station:stationValue projectedPoint:projectedValue)
        )

        local ordered = sortByStation sourceReferences
        for orderedIndex = 1 to (ordered.count - 1) do
        (
            if abs (ordered[orderedIndex + 1].station - ordered[orderedIndex].station) <= toleranceSceneUnits then
                return (invalidLayout #coincidentStations "Duas referências ocupam a mesma estação projetada." mode)
        )

        local segmentLayouts = #()
        for segmentIndex = 1 to (ordered.count - 1) do
        (
            local firstReference = ordered[segmentIndex]
            local secondReference = ordered[segmentIndex + 1]
            local measuredScene = abs (secondReference.station - firstReference.station)
            append segmentLayouts (AmenoDimensionChainSegmentLayout \
                sourceIndexA:firstReference.sourceIndex sourceIndexB:secondReference.sourceIndex \
                pointA:firstReference.sourcePoint pointB:secondReference.sourcePoint \
                linePointA:firstReference.projectedPoint linePointB:secondReference.projectedPoint \
                measuredSceneUnits:measuredScene measuredMillimeters:(measuredScene * resolvedScale))
        )

        AmenoDimensionChainLayout valid:true dimensionMode:mode origin:originPoint \
            direction:axisDirection perpendicular:perpendicularDirection \
            signedOffsetSceneUnits:signedOffset offsetPoint:projectedOffset \
            orderedReferences:ordered segments:segmentLayouts
    )
)

AmenoDimensionChainMath = AmenoDimensionChainMathDefinition()
