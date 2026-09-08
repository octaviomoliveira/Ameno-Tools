/*
    E14.1 — Base ortonormal para cotas em planta e fachada.

    A cota armazena uma base no mundo (O, U, V, N). U é o eixo horizontal da
    vista, V o eixo vertical e N a normal voltada para o observador. O objeto
    original continua sendo a fonte do snap; este módulo só projeta pontos para
    calcular e desenhar a anotação.
*/

global AmenoDimensionPlane
global AmenoDimensionPlaneService

struct AmenoDimensionPlane
(
    planeType = #worldXY,
    origin = [0, 0, 0],
    axisU = [1, 0, 0],
    axisV = [0, 1, 0],
    normal = [0, 0, 1],
    valid = true,
    errorCode = #none,
    errorMessage = "",
    sourceViewport = undefined,
    sourceCamera = undefined,
    orientationLabel = "Planta XY"
)

struct AmenoDimensionPlaneServiceDefinition
(
    finiteNumberEpsilon = 1e30,
    basisTolerance = 0.0001,
    axisTolerance = 0.00001,
    viewLevelTolerance = 0.001,

    fn isFiniteNumber value =
    (
        if value == undefined then return false
        try ((value == value) and ((abs (value as float)) < finiteNumberEpsilon)) catch false
    ),

    fn isFinitePoint pointValue =
    (
        if pointValue == undefined then return false
        (isFiniteNumber pointValue.x) and (isFiniteNumber pointValue.y) and (isFiniteNumber pointValue.z)
    ),

    fn safeNormalize vectorValue =
    (
        if vectorValue == undefined then return undefined
        local vectorLength = 0.0
        try (vectorLength = length vectorValue) catch (return undefined)
        if not (isFiniteNumber vectorLength) or vectorLength <= axisTolerance then return undefined
        local result = undefined
        try (result = normalize vectorValue) catch (return undefined)
        if result == undefined then return undefined
        if not (isFinitePoint result) then return undefined
        result
    ),

    fn invalidPlane codeValue messageValue planeTypeValue:#viewPlane =
    (
        AmenoDimensionPlane planeType:planeTypeValue valid:false errorCode:codeValue errorMessage:messageValue orientationLabel:"Plano inválido"
    ),

    fn make originValue axisUValue axisVValue normalValue planeTypeValue:#viewPlane orientationLabelValue:"Plano de vista" sourceViewportValue:undefined sourceCameraValue:undefined =
    (
        -- O tipo faz parte do contrato persistido. Não aceitar um nome
        -- arbitrário aqui evita que uma cena corrompida seja interpretada
        -- como um plano válido e depois caia silenciosamente em Planta.
        if planeTypeValue != #worldXY and planeTypeValue != #viewPlane then
            return (invalidPlane #unsupportedPlaneType "O tipo de plano persistido não é suportado." planeTypeValue:planeTypeValue)
        if not (isFinitePoint originValue) then return (invalidPlane #invalidOrigin "A origem do plano não é finita." planeTypeValue:planeTypeValue)
        local u = safeNormalize axisUValue
        local v = safeNormalize axisVValue
        local n = safeNormalize normalValue
        if u == undefined or v == undefined or n == undefined then
            return (invalidPlane #invalidBasis "Os eixos do plano devem ter comprimento maior que zero." planeTypeValue:planeTypeValue)

        local uvDot = 0.0
        local unDot = 0.0
        local vnDot = 0.0
        try
        (
            uvDot = abs (dot u v)
            unDot = abs (dot u n)
            vnDot = abs (dot v n)
        )
        catch (return (invalidPlane #invalidBasis "Não foi possível validar a base do plano." planeTypeValue:planeTypeValue))
        if uvDot > basisTolerance or unDot > basisTolerance or vnDot > basisTolerance then
            return (invalidPlane #nonOrthonormalBasis "Os eixos do plano precisam ser ortogonais." planeTypeValue:planeTypeValue)

        local handedNormal = undefined
        try (handedNormal = safeNormalize (cross u v)) catch ()
        if handedNormal == undefined then return (invalidPlane #invalidBasis "A base do plano é degenerada." planeTypeValue:planeTypeValue)
        if (dot handedNormal n) < 0.999 then
            return (invalidPlane #invalidHandedness "A normal não corresponde a U × V." planeTypeValue:planeTypeValue)

        AmenoDimensionPlane planeType:planeTypeValue origin:originValue axisU:u axisV:v normal:n valid:true errorCode:#none errorMessage:"" \
            sourceViewport:sourceViewportValue sourceCamera:sourceCameraValue orientationLabel:orientationLabelValue
    ),

    fn worldXY =
    (
        make [0, 0, 0] [1, 0, 0] [0, 1, 0] [0, 0, 1] planeTypeValue:#worldXY orientationLabelValue:"Planta XY"
    ),

    fn copy planeValue =
    (
        if planeValue == undefined then return (worldXY())
        make planeValue.origin planeValue.axisU planeValue.axisV planeValue.normal \
            planeTypeValue:planeValue.planeType orientationLabelValue:planeValue.orientationLabel \
            sourceViewportValue:planeValue.sourceViewport sourceCameraValue:planeValue.sourceCamera
    ),

    fn coordinatesOf planeValue worldPoint =
    (
        if planeValue == undefined or not planeValue.valid or not (isFinitePoint worldPoint) then return undefined
        local delta = worldPoint - planeValue.origin
        local uValue = 0.0
        local vValue = 0.0
        local nValue = 0.0
        try
        (
            uValue = dot delta planeValue.axisU
            vValue = dot delta planeValue.axisV
            nValue = dot delta planeValue.normal
        )
        catch (return undefined)
        if not (isFiniteNumber uValue) or not (isFiniteNumber vValue) or not (isFiniteNumber nValue) then return undefined
        [uValue, vValue, nValue]
    ),

    fn pointAt planeValue uValue vValue depthValue:0.0 =
    (
        if planeValue == undefined or not planeValue.valid then return undefined
        if not (isFiniteNumber uValue) or not (isFiniteNumber vValue) or not (isFiniteNumber depthValue) then return undefined
        local result = planeValue.origin + (planeValue.axisU * uValue) + (planeValue.axisV * vValue) + (planeValue.normal * depthValue)
        if isFinitePoint result then result else undefined
    ),

    fn project planeValue worldPoint =
    (
        local coords = coordinatesOf planeValue worldPoint
        if coords == undefined then return undefined
        pointAt planeValue coords.x coords.y depthValue:0.0
    ),

    fn vectorToPlane planeValue worldVector =
    (
        if planeValue == undefined or not planeValue.valid or worldVector == undefined then return undefined
        local uValue = dot worldVector planeValue.axisU
        local vValue = dot worldVector planeValue.axisV
        if not (isFiniteNumber uValue) or not (isFiniteNumber vValue) then return undefined
        (planeValue.axisU * uValue) + (planeValue.axisV * vValue)
    ),

    fn signature planeValue =
    (
        if planeValue == undefined then return "worldXY"
        ((planeValue.planeType as string) + "|O=" + (planeValue.origin as string) + "|U=" + (planeValue.axisU as string) + \
            "|V=" + (planeValue.axisV as string) + "|N=" + (planeValue.normal as string))
    ),

    fn isSameBasis planeA planeB tolerance:0.0001 =
    (
        if planeA == undefined or planeB == undefined or not planeA.valid or not planeB.valid then return false
        (length (planeA.axisU - planeB.axisU)) <= tolerance and \
            (length (planeA.axisV - planeB.axisV)) <= tolerance and \
            (length (planeA.normal - planeB.normal)) <= tolerance
    ),

    fn standardForViewType viewType =
    (
        case viewType of
        (
            #view_front:  make [0,0,0] [1,0,0] [0,0,1] [0,-1,0] planeTypeValue:#viewPlane orientationLabelValue:"Fachada frontal"
            #view_back:   make [0,0,0] [-1,0,0] [0,0,1] [0,1,0] planeTypeValue:#viewPlane orientationLabelValue:"Fachada posterior"
            #view_right:  make [0,0,0] [0,1,0] [0,0,1] [1,0,0] planeTypeValue:#viewPlane orientationLabelValue:"Fachada direita"
            #view_left:   make [0,0,0] [0,-1,0] [0,0,1] [-1,0,0] planeTypeValue:#viewPlane orientationLabelValue:"Fachada esquerda"
            default: invalidPlane #unsupportedViewport "A vista ativa não é uma vista ortográfica nivelada suportada."
        )
    ),

    fn cameraPlane cameraNode =
    (
        if cameraNode == undefined or not isValidNode cameraNode then return (invalidPlane #missingCamera "A câmera da vista não está disponível.")
        local ortho = false
        try (ortho = cameraNode.orthoProjection) catch (return (invalidPlane #cameraProperty "Não foi possível consultar a projeção da câmera."))
        if not ortho then return (invalidPlane #perspectiveNotSupported "A E14 exige câmera ortográfica; perspectiva não é suportada no MVP.")

        local tm = undefined
        try (tm = cameraNode.transform) catch (return (invalidPlane #cameraTransform "Não foi possível ler a transformação da câmera."))
        local u = undefined
        local v = undefined
        local n = undefined
        try
        (
            u = tm.row1
            v = tm.row2
            n = tm.row3
        )
        catch (return (invalidPlane #cameraTransform "A transformação da câmera não possui uma base válida."))

        local uu = safeNormalize u
        local vv = safeNormalize v
        local nn = safeNormalize n
        if uu == undefined or vv == undefined or nn == undefined then return (invalidPlane #cameraBasis "A base da câmera é degenerada.")
        -- O eixo V precisa apontar para o Z mundial positivo. Usar abs aqui
        -- aceitaria a câmera invertida (roll de 180 graus) como se estivesse
        -- nivelada, invertendo a leitura do texto e a ordem vertical.
        if (dot vv [0,0,1]) < (1.0 - viewLevelTolerance) then
            return (invalidPlane #cameraTilt "A câmera deve estar nivelada, com o eixo vertical alinhado ao Z mundial.")
        if (abs (dot uu [0,0,1])) > viewLevelTolerance or (abs (dot nn [0,0,1])) > viewLevelTolerance then
            return (invalidPlane #cameraRoll "A câmera não pode ter roll no MVP da fachada.")
        local cameraOrigin = undefined
        try (cameraOrigin = cameraNode.position) catch (cameraOrigin = [0,0,0])
        make cameraOrigin uu vv nn planeTypeValue:#viewPlane orientationLabelValue:("Câmera ortográfica / " + cameraNode.name as string) sourceCameraValue:cameraNode
    ),

    fn captureActive allowPerspective:false =
    (
        local cameraNode = undefined
        try (cameraNode = viewport.getCamera()) catch ()
        if cameraNode != undefined and isValidNode cameraNode then
        (
            local cameraResult = cameraPlane cameraNode
            try (cameraResult.sourceViewport = viewport.activeViewport) catch ()
            if cameraResult.valid or not allowPerspective then return cameraResult
        )

        local perspective = false
        try (perspective = viewport.isPerspView()) catch ()
        if perspective and not allowPerspective then
            return (invalidPlane #perspectiveNotSupported "A vista em perspectiva não pode iniciar uma cota de fachada.")

        local viewType = undefined
        try (viewType = viewport.getType()) catch ()
        local result = standardForViewType viewType
        try (result.sourceViewport = viewport.activeViewport) catch ()
        result
    )
)

AmenoDimensionPlaneService = AmenoDimensionPlaneServiceDefinition()
