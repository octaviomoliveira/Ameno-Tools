/*
    E5 — Custom Attributes e Persistência de Cotas.

    Define os Custom Attributes versionados para o controlador técnico da cota,
    permitindo que cenas salvas abram de forma confiável e independente do script.
    Mantém espelhamento com User Defined Properties para compatibilidade retroativa.
*/

global AmenoDimensionCADef
global AmenoDimensionCA

struct AmenoDimensionRecord
(
    schemaVersion = 1,
    dimensionId = "",
    dimensionRole = "user",
    pointA = [0, 0, 0],
    pointB = [0, 0, 0],
    offsetPoint = [0, 0, 0],
    outputUnit = "meters",
    precision = 2,
    displayMode = "measured",
    roundingIncrementMm = 0.0,
    manualValue = "",
    styleId = "default"
)

AmenoDimensionCADef = attributes AmenoDimensionData
attribID:#(0x414d454e, 0x44494d31) -- 'AMEN', 'DIM1'
version:1
(
    parameters main
    (
        schemaVersion type:#integer default:1
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
        styleId type:#string default:"default"
    )
)

struct AmenoDimensionCAService
(
    def = AmenoDimensionCADef,
    schemaVersion = 1,

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
