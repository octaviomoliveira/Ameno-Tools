/* E12-B — matemática pura de cadeia de cotas em uma linha compartilhada. */

global AmenoDimensionChainMath
global AmenoDimensionChainLayout
global AmenoDimensionChainReferenceLayout
global AmenoDimensionChainSegmentLayout
global AmenoUnitService
global AmenoDimensionPlane
global AmenoDimensionPlaneService

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
    segments               = #(),
    planeType              = #worldXY,
    planeOrigin            = [0,0,0],
    planeAxisU             = [1,0,0],
    planeAxisV             = [0,1,0],
    planeNormal            = [0,0,1],
    baselinePolicy         = "relative",
    baselineCoordinate     = 0.0
)

struct AmenoDimensionChainMathDefinition
(
    fn resolvePlane planeValue =
    (
        if planeValue != undefined then return planeValue
        if ::AmenoDimensionPlaneService != undefined then return ::AmenoDimensionPlaneService.worldXY()
        AmenoDimensionPlane planeType:#worldXY origin:[0,0,0] axisU:[1,0,0] axisV:[0,1,0] normal:[0,0,1] valid:true
    ),

    fn projectToWorld pointValue planeValue:undefined =
    (
        if pointValue == undefined then return undefined
        local resolvedPlane = resolvePlane planeValue
        if ::AmenoDimensionPlaneService != undefined then
            ::AmenoDimensionPlaneService.project resolvedPlane pointValue
        else
            [pointValue.x, pointValue.y, 0.0]
    ),

    fn coordinatesOf pointValue planeValue:undefined =
    (
        if pointValue == undefined then return undefined
        local resolvedPlane = resolvePlane planeValue
        if ::AmenoDimensionPlaneService != undefined then
            ::AmenoDimensionPlaneService.coordinatesOf resolvedPlane pointValue
        else
            [pointValue.x, pointValue.y, pointValue.z]
    ),

    fn invalidLayout errorCodeValue errorMessageValue modeValue =
    (
        AmenoDimensionChainLayout valid:false errorCode:errorCodeValue \
            errorMessage:errorMessageValue dimensionMode:modeValue
    ),

    fn resolveBasis points mode toleranceSceneUnits planeValue =
    (
        local resolvedPlane = resolvePlane planeValue
        case mode of
        (
            #horizontal: #(resolvedPlane.axisU, resolvedPlane.axisV)
            #vertical:   #(resolvedPlane.axisV, resolvedPlane.axisU)
            #aligned:
            (
                if points.count < 2 then return undefined
                local originPoint = projectToWorld points[1] planeValue:resolvedPlane
                local secondPoint = projectToWorld points[2] planeValue:resolvedPlane
                if originPoint == undefined or secondPoint == undefined then return undefined
                local axisVector = secondPoint - originPoint
                if length axisVector <= toleranceSceneUnits then return undefined
                local axisDirection = normalize axisVector
                #(axisDirection, normalize (cross resolvedPlane.normal axisDirection))
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

    fn layout points offsetPoint mode:#horizontal millimetersPerSceneUnit:undefined toleranceSceneUnits:0.00001 plane:undefined baselinePolicy:"relative" baselineCoordinate:undefined =
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

        local resolvedPlane = resolvePlane plane
        if resolvedPlane == undefined or not resolvedPlane.valid then
            return (invalidLayout #invalidPlane "O plano da cadeia é inválido." mode)

        local originPoint = projectToWorld points[1] planeValue:resolvedPlane
        local projectedOffset = projectToWorld offsetPoint planeValue:resolvedPlane
        if originPoint == undefined or projectedOffset == undefined then
            return (invalidLayout #invalidPoint "Referência ou afastamento inválido." mode)

        local basis = resolveBasis points mode toleranceSceneUnits resolvedPlane
        if basis == undefined then
        (
            local basisError = if mode == #aligned then #invalidAlignedAxis else #unsupportedMode
            return (invalidLayout basisError "Não foi possível resolver o eixo da cadeia." mode)
        )

        local axisDirection = basis[1]
        local perpendicularDirection = basis[2]
        local resolvedBaselinePolicy = if baselinePolicy == undefined then "relative" else (baselinePolicy as string)
        local firstCoords = coordinatesOf points[1] planeValue:resolvedPlane
        local offsetCoords = coordinatesOf offsetPoint planeValue:resolvedPlane
        if firstCoords == undefined or offsetCoords == undefined then
            return (invalidLayout #invalidPoint "Não foi possível resolver as coordenadas da linha comum." mode)

        local signedOffset = dot (projectedOffset - originPoint) perpendicularDirection
        local resolvedBaselineCoordinate = 0.0
        if mode == #horizontal then
            resolvedBaselineCoordinate = firstCoords.y + signedOffset
        else if mode == #vertical then
            resolvedBaselineCoordinate = firstCoords.x + signedOffset

        if resolvedBaselinePolicy == "fixedPlaneBaseline" then
        (
            -- A linha comum da fachada é uma coordenada absoluta no plano. O
            -- deslocamento relativo ao primeiro ponto é derivado só para
            -- manter o contrato de layout já consumido pelos gráficos.
            if baselineCoordinate != undefined do
            (
                local finiteBaseline = true
                try (finiteBaseline = ::AmenoDimensionPlaneService.isFiniteNumber baselineCoordinate) catch ()
                if finiteBaseline then resolvedBaselineCoordinate = baselineCoordinate as float
            )
            if mode == #horizontal then
                signedOffset = resolvedBaselineCoordinate - firstCoords.y
            else if mode == #vertical then
                signedOffset = resolvedBaselineCoordinate - firstCoords.x
            else
                return (invalidLayout #unsupportedBaseline "A linha fixa só é suportada nos modos Horizontal e Vertical." mode)
        )
        local sourceReferences = #()

        for sourceIndex = 1 to points.count do
        (
            local rawSourcePoint = points[sourceIndex]
            local sourcePointValue = projectToWorld rawSourcePoint planeValue:resolvedPlane
            if sourcePointValue == undefined then
                return (invalidLayout #invalidPoint ("Referência inválida no índice " + (sourceIndex as string) + ".") mode)
            local stationValue = dot (sourcePointValue - originPoint) axisDirection
            local projectedValue = originPoint + (axisDirection * stationValue) + (perpendicularDirection * signedOffset)
            append sourceReferences (AmenoDimensionChainReferenceLayout sourceIndex:sourceIndex \
                sourcePoint:rawSourcePoint station:stationValue projectedPoint:projectedValue)
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
            orderedReferences:ordered segments:segmentLayouts \
            planeType:resolvedPlane.planeType planeOrigin:resolvedPlane.origin planeAxisU:resolvedPlane.axisU \
            planeAxisV:resolvedPlane.axisV planeNormal:resolvedPlane.normal \
            baselinePolicy:resolvedBaselinePolicy baselineCoordinate:resolvedBaselineCoordinate
    )
)

AmenoDimensionChainMath = AmenoDimensionChainMathDefinition()
