/*
    E5/E6 — Custom Attributes e Persistência de Cotas.

    Define os Custom Attributes versionados para o controlador técnico da cota,
    permitindo que cenas salvas abram de forma confiável e independente do script.
    Na E6, expande para suportar modos de valor (medido, arredondado, manual),
    delta entre medido e exibido, e motivo da alteração.
*/

global AmenoDimensionCADef
global AmenoDimensionCA

struct AmenoDimensionRecord
(
    schemaVersion = 2,
    dimensionId = "",
    dimensionRole = "user",
    pointA = [0, 0, 0],
    pointB = [0, 0, 0],
    offsetPoint = [0, 0, 0],
    outputUnit = "meters",
    precision = 2,
    displayMode = "measured", -- measured, rounded, manualNumeric, manualText
    roundingIncrementMm = 0.0,
    manualValue = "",
    manualValueMm = 0.0,
    manualText = "",
    manualReason = "",
    lastMeasuredMm = 0.0,
    lastDeltaMm = 0.0,
    styleId = "default"
)

AmenoDimensionCADef = attributes AmenoDimensionData
attribID:#(0x414d454e, 0x44494d31) -- 'AMEN', 'DIM1'
version:2
(
    parameters main
    (
        schemaVersion type:#integer default:2
        dimensionId type:#string default:""
        dimensionRole type:#string default:"user"
        pointA type:#point3 default:[0, 0, 0]
        pointB type:#point3 default:[0, 0, 0]
        offsetPoint type:#point3 default:[0, 0, 0]
        outputUnit type:#string default:"meters"
        precision type:#integer default:2
        displayMode type:#string default:"measured"
        roundingIncrementMm type:#float default:0.0
        manualValue type:#string default:""
        manualValueMm type:#float default:0.0
        manualText type:#string default:""
        manualReason type:#string default:""
        lastMeasuredMm type:#float default:0.0
        lastDeltaMm type:#float default:0.0
        styleId type:#string default:"default"
    )
)

struct AmenoDimensionCAService
(
    def = AmenoDimensionCADef,
    schemaVersion = 2,

    fn hasCA node =
    (
        if node == undefined or not isValidNode node then return false
        (custAttributes.get node def) != undefined
    ),

    fn applyCA node record =
    (
        if node == undefined or not isValidNode node then return false

        local ca = custAttributes.get node def
        if ca == undefined do
        (
            custAttributes.add node def
            ca = custAttributes.get node def
        )

        if ca == undefined then return false

        ca.schemaVersion = record.schemaVersion
        ca.dimensionId = record.dimensionId
        ca.dimensionRole = (record.dimensionRole as string)
        ca.pointA = record.pointA
        ca.pointB = record.pointB
        ca.offsetPoint = record.offsetPoint
        ca.outputUnit = (record.outputUnit as string)
        ca.precision = record.precision
        ca.displayMode = (record.displayMode as string)
        ca.roundingIncrementMm = (record.roundingIncrementMm as float)
        ca.manualValue = (record.manualValue as string)
        if isProperty ca #manualValueMm do ca.manualValueMm = (record.manualValueMm as float)
        if isProperty ca #manualText do ca.manualText = (record.manualText as string)
        if isProperty ca #manualReason do ca.manualReason = (record.manualReason as string)
        if isProperty ca #lastMeasuredMm do ca.lastMeasuredMm = (record.lastMeasuredMm as float)
        if isProperty ca #lastDeltaMm do ca.lastDeltaMm = (record.lastDeltaMm as float)
        ca.styleId = (record.styleId as string)

        true
    ),

    fn readCA node =
    (
        if node == undefined or not isValidNode node then return undefined

        local ca = custAttributes.get node def
        if ca != undefined then
        (
            local rec = AmenoDimensionRecord()
            rec.schemaVersion = ca.schemaVersion
            rec.dimensionId = ca.dimensionId
            rec.dimensionRole = ca.dimensionRole
            rec.pointA = ca.pointA
            rec.pointB = ca.pointB
            rec.offsetPoint = ca.offsetPoint
            rec.outputUnit = ca.outputUnit
            rec.precision = ca.precision
            rec.displayMode = ca.displayMode
            rec.roundingIncrementMm = ca.roundingIncrementMm
            rec.manualValue = ca.manualValue
            if isProperty ca #manualValueMm do rec.manualValueMm = ca.manualValueMm
            if isProperty ca #manualText do rec.manualText = ca.manualText
            if isProperty ca #manualReason do rec.manualReason = ca.manualReason
            if isProperty ca #lastMeasuredMm do rec.lastMeasuredMm = ca.lastMeasuredMm
            if isProperty ca #lastDeltaMm do rec.lastDeltaMm = ca.lastDeltaMm
            rec.styleId = ca.styleId
            return rec
        )

        -- Fallback de migração para nós com dados apenas em User Properties (E3/E4)
        local dimId = getUserPropVal node "Ameno.DimensionId"
        if dimId != undefined and dimId != "" then
        (
            local rec = AmenoDimensionRecord()
            rec.dimensionId = dimId as string

            local roleVal = getUserPropVal node "Ameno.DimensionRole"
            if roleVal != undefined do rec.dimensionRole = roleVal as string

            local pA = getUserPropVal node "Ameno.PointA"
            local pB = getUserPropVal node "Ameno.PointB"
            local pOff = getUserPropVal node "Ameno.OffsetPoint"

            if (classof pA == Point3) do rec.pointA = pA
            if (classof pB == Point3) do rec.pointB = pB
            if (classof pOff == Point3) do rec.offsetPoint = pOff

            return rec
        )

        undefined
    ),

    fn ensureCA node =
    (
        if node == undefined or not isValidNode node then return false
        if hasCA node then return true

        local rec = readCA node
        if rec != undefined then
        (
            applyCA node rec
            return true
        )

        false
    )
)

AmenoDimensionCA = AmenoDimensionCAService()
