/*
    E5/E6/E8 — Custom Attributes e Persistência de Cotas.

    Define os Custom Attributes versionados para o controlador técnico da cota,
    permitindo que cenas salvas abram de forma confiável e independente do script.
    Na E6: suporta modos de valor (medido, arredondado, manual), delta e motivo.
    Na E8: adiciona âncoras geométricas (nós A e B com pontos em espaço local),
    status de cota órfã (resiliência a nós deletados) e resolução de coordenadas.
*/

global AmenoDimensionCADef
global AmenoDimensionCA
global AmenoDimensionRecord
global AmenoResolvedAnchorPoints
global AmenoAnchorVertexHit

struct AmenoAnchorVertexHit
(
    vertexId = -1,
    worldPoint = [0, 0, 0],
    distance = 0.0
)

struct AmenoResolvedAnchorPoints
(
    pointA = [0, 0, 0],
    pointB = [0, 0, 0],
    offsetPoint = [0, 0, 0],
    isOrphan = false,
    orphanReason = "",
    changed = false
)

struct AmenoDimensionRecord
(
    schemaVersion = 5,
    dimensionId = "",
    dimensionRole = "user",
    dimensionMode = "aligned", -- E10.1: "aligned" | "horizontal" | "vertical"
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
    styleId = "default",
    anchorType = "world", -- world, nodeA, nodeB, both
    nodeA = undefined,
    localPointA = [0, 0, 0],
    anchorVertexIdA = -1,
    anchorEdgeIdA = -1,
    anchorEdgeMidA = false,
    nodeB = undefined,
    localPointB = [0, 0, 0],
    anchorVertexIdB = -1,
    anchorEdgeIdB = -1,
    anchorEdgeMidB = false,
    isOrphan = false,
    orphanReason = ""
)

AmenoDimensionCADef = attributes AmenoDimensionData
attribID:#(0x414d454e, 0x44494d31) -- 'AMEN', 'DIM1'
version:5
(
    parameters main
    (
        schemaVersion type:#integer default:5
        dimensionId type:#string default:""
        dimensionRole type:#string default:"user"
        dimensionMode type:#string default:"aligned"  -- E10.1: "aligned" | "horizontal" | "vertical"
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
        anchorType type:#string default:"world"
        nodeA type:#node
        localPointA type:#point3 default:[0, 0, 0]
        nodeB type:#node
        localPointB type:#point3 default:[0, 0, 0]
        isOrphan type:#boolean default:false
        orphanReason type:#string default:""
        -- Campos v5 sempre anexados ao fim para preservar os ParamIDs v4.
        anchorVertexIdA type:#integer default:-1
        anchorVertexIdB type:#integer default:-1
        anchorEdgeIdA type:#integer default:-1
        anchorEdgeIdB type:#integer default:-1
        anchorEdgeMidA type:#boolean default:false
        anchorEdgeMidB type:#boolean default:false
    )
)

struct AmenoDimensionCAService
(
    def = AmenoDimensionCADef,
    schemaVersion = 5,

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

        -- Qualquer gravação pelo código atual materializa o schema v5. A leitura
        -- continua aceitando v4 e só migra quando houver uma alteração real.
        ca.schemaVersion = schemaVersion
        ca.dimensionId = record.dimensionId
        ca.dimensionRole = (record.dimensionRole as string)
        if isProperty ca #dimensionMode do ca.dimensionMode = (record.dimensionMode as string)
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
        if isProperty ca #anchorType do ca.anchorType = (record.anchorType as string)
        if isProperty ca #nodeA do (if record.nodeA != undefined and isValidNode record.nodeA then ca.nodeA = record.nodeA else ca.nodeA = undefined)
        if isProperty ca #localPointA do ca.localPointA = record.localPointA
        if isProperty ca #anchorVertexIdA and isProperty record #anchorVertexIdA do ca.anchorVertexIdA = record.anchorVertexIdA
        if isProperty ca #anchorEdgeIdA and isProperty record #anchorEdgeIdA do ca.anchorEdgeIdA = record.anchorEdgeIdA
        if isProperty ca #anchorEdgeMidA and isProperty record #anchorEdgeMidA do ca.anchorEdgeMidA = record.anchorEdgeMidA
        if isProperty ca #nodeB do (if record.nodeB != undefined and isValidNode record.nodeB then ca.nodeB = record.nodeB else ca.nodeB = undefined)
        if isProperty ca #localPointB do ca.localPointB = record.localPointB
        if isProperty ca #anchorVertexIdB and isProperty record #anchorVertexIdB do ca.anchorVertexIdB = record.anchorVertexIdB
        if isProperty ca #anchorEdgeIdB and isProperty record #anchorEdgeIdB do ca.anchorEdgeIdB = record.anchorEdgeIdB
        if isProperty ca #anchorEdgeMidB and isProperty record #anchorEdgeMidB do ca.anchorEdgeMidB = record.anchorEdgeMidB
        if isProperty ca #isOrphan do ca.isOrphan = record.isOrphan
        if isProperty ca #orphanReason do ca.orphanReason = (record.orphanReason as string)

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
            -- E10.1: campo dimensionMode lido com guard para compatibilidade com CA v3
            if isProperty ca #dimensionMode then rec.dimensionMode = ca.dimensionMode else rec.dimensionMode = "aligned"
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
            if isProperty ca #anchorType do rec.anchorType = ca.anchorType
            if isProperty ca #nodeA do (if ca.nodeA != undefined and isValidNode ca.nodeA then rec.nodeA = ca.nodeA else rec.nodeA = undefined)
            if isProperty ca #localPointA do rec.localPointA = ca.localPointA
            if isProperty ca #anchorVertexIdA do rec.anchorVertexIdA = ca.anchorVertexIdA
            if isProperty ca #anchorEdgeIdA do rec.anchorEdgeIdA = ca.anchorEdgeIdA
            if isProperty ca #anchorEdgeMidA do rec.anchorEdgeMidA = ca.anchorEdgeMidA
            if isProperty ca #nodeB do (if ca.nodeB != undefined and isValidNode ca.nodeB then rec.nodeB = ca.nodeB else rec.nodeB = undefined)
            if isProperty ca #localPointB do rec.localPointB = ca.localPointB
            if isProperty ca #anchorVertexIdB do rec.anchorVertexIdB = ca.anchorVertexIdB
            if isProperty ca #anchorEdgeIdB do rec.anchorEdgeIdB = ca.anchorEdgeIdB
            if isProperty ca #anchorEdgeMidB do rec.anchorEdgeMidB = ca.anchorEdgeMidB
            if isProperty ca #isOrphan do rec.isOrphan = (ca.isOrphan as booleanClass)
            if isProperty ca #orphanReason do rec.orphanReason = ca.orphanReason
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
    ),

    fn getVertexCount anchorNode =
    (
        if anchorNode == undefined or not isValidNode anchorNode then return 0

        local baseObject = undefined
        try (baseObject = anchorNode.baseObject) catch ()
        if baseObject == undefined then return 0

        local count = 0
        try (count = polyOp.getNumVerts baseObject) catch ()
        if count < 1 do try (count = meshOp.getNumVerts baseObject) catch ()
        count
    ),

    fn getVertexLocal anchorNode vertexId =
    (
        if anchorNode == undefined or not isValidNode anchorNode then return undefined
        if vertexId < 1 then return undefined

        local baseObject = undefined
        try (baseObject = anchorNode.baseObject) catch ()
        if baseObject == undefined then return undefined

        local vertexCount = getVertexCount anchorNode
        if vertexId > vertexCount then return undefined

        local localPoint = undefined
        try (localPoint = polyOp.getVert baseObject vertexId) catch ()
        if localPoint == undefined do try (localPoint = meshOp.getVert baseObject vertexId) catch ()
        localPoint
    ),

    fn getVertexWorldUnchecked anchorNode vertexId =
    (
        -- Com o nó como argumento, polyOp/meshOp devolvem no sistema de
        -- coordenadas corrente. Pedir #world evita aplicar o transform duas vezes
        -- e inclui corretamente object offsets/pivôs.
        local worldPoint = undefined
        try (in coordsys world (worldPoint = polyOp.getVert anchorNode vertexId)) catch ()
        if worldPoint == undefined do try (in coordsys world (worldPoint = meshOp.getVert anchorNode vertexId)) catch ()

        -- Fallback defensivo para classes que aceitam somente o baseObject.
        if worldPoint == undefined do
        (
            local localPoint = getVertexLocal anchorNode vertexId
            if localPoint != undefined do
            (
                local objectTM = anchorNode.transform
                try (objectTM = anchorNode.objectTransform) catch ()
                worldPoint = localPoint * objectTM
            )
        )
        worldPoint
    ),

    fn resolveVertexWorld anchorNode vertexId =
    (
        if anchorNode == undefined or not isValidNode anchorNode then return undefined
        if vertexId < 1 or vertexId > (getVertexCount anchorNode) then return undefined
        getVertexWorldUnchecked anchorNode vertexId
    ),

    fn findNearestVertex anchorNode worldPoint maxDistance:undefined =
    (
        if anchorNode == undefined or not isValidNode anchorNode then return undefined
        if worldPoint == undefined then return undefined

        local vertexCount = getVertexCount anchorNode
        if vertexCount < 1 then return undefined

        local bestId = -1
        local bestPoint = undefined
        local bestDistance = 1e30

        for vertexId = 1 to vertexCount do
        (
            local candidatePoint = getVertexWorldUnchecked anchorNode vertexId
            if candidatePoint != undefined do
            (
                local candidateDistance = length (candidatePoint - worldPoint)
                if candidateDistance < bestDistance do
                (
                    bestId = vertexId
                    bestPoint = candidatePoint
                    bestDistance = candidateDistance
                )
            )
        )

        if bestId < 1 then return undefined
        if maxDistance != undefined and bestDistance > maxDistance then return undefined
        AmenoAnchorVertexHit vertexId:bestId worldPoint:bestPoint distance:bestDistance
    ),

    fn resolvePoints record =
    (
        if record == undefined then return undefined

        local resolved = AmenoResolvedAnchorPoints()
        resolved.pointA = record.pointA
        resolved.pointB = record.pointB
        resolved.offsetPoint = record.offsetPoint
        resolved.isOrphan = record.isOrphan
        resolved.orphanReason = record.orphanReason

        local checkA = (record.anchorType == "nodeA" or record.anchorType == "both")
        local checkB = (record.anchorType == "nodeB" or record.anchorType == "both")
        local orphanFound = false
        local reasons = #()

        local worldA = record.pointA
        if checkA then
        (
            if record.nodeA != undefined and isValidNode record.nodeA then
            (
                if record.anchorVertexIdA == -1 then
                (
                    -- Migração implícita: CAs v4 e anteriores continuam usando localPoint.
                    worldA = record.localPointA * record.nodeA.transform
                )
                else if record.anchorVertexIdA > 0 then
                (
                    local vertexWorldA = resolveVertexWorld record.nodeA record.anchorVertexIdA
                    if vertexWorldA != undefined then
                        worldA = vertexWorldA
                    else
                    (
                        orphanFound = true
                        append reasons "Vértice da âncora A não existe mais"
                    )
                )
                else
                (
                    orphanFound = true
                    append reasons "ID de vértice inválido na âncora A"
                )
            )
            else
            (
                orphanFound = true
                append reasons "Âncora A excluída"
            )
        )

        local worldB = record.pointB
        if checkB then
        (
            if record.nodeB != undefined and isValidNode record.nodeB then
            (
                if record.anchorVertexIdB == -1 then
                (
                    -- Migração implícita: CAs v4 e anteriores continuam usando localPoint.
                    worldB = record.localPointB * record.nodeB.transform
                )
                else if record.anchorVertexIdB > 0 then
                (
                    local vertexWorldB = resolveVertexWorld record.nodeB record.anchorVertexIdB
                    if vertexWorldB != undefined then
                        worldB = vertexWorldB
                    else
                    (
                        orphanFound = true
                        append reasons "Vértice da âncora B não existe mais"
                    )
                )
                else
                (
                    orphanFound = true
                    append reasons "ID de vértice inválido na âncora B"
                )
            )
            else
            (
                orphanFound = true
                append reasons "Âncora B excluída"
            )
        )

        if orphanFound then
        (
            resolved.isOrphan = true
            local reasonStr = ""
            for i = 1 to reasons.count do
            (
                if i > 1 do reasonStr += " · "
                reasonStr += reasons[i]
            )
            resolved.orphanReason = reasonStr
        )
        else
        (
            resolved.isOrphan = false
            resolved.orphanReason = ""
        )

        -- Verificar se as coordenadas mudaram
        local changedA = (length (worldA - record.pointA)) > 0.0001
        local changedB = (length (worldB - record.pointB)) > 0.0001

        resolved.pointA = worldA
        resolved.pointB = worldB

        if changedA or changedB then
        (
            resolved.changed = true
            -- Manter o afastamento perpendicular no modo correto da cota
            local mode = #aligned
            try (mode = record.dimensionMode as name) catch ()
            local oldLayout = AmenoDimensionMath.layoutForMode record.pointA record.pointB record.offsetPoint mode:mode
            local offsetDist = if oldLayout.valid then oldLayout.signedOffsetSceneUnits else 20.0

            -- Para horizontal: perpendicular fixo = Y; afastamento = deslocamento em Y
            -- Para vertical:   perpendicular fixo = X; afastamento = deslocamento em X
            -- Para aligned:    perpendicular derivado do novo vetor AB
            case mode of
            (
                #horizontal:
                (
                    -- Y do offset em relação ao Y de A
                    resolved.offsetPoint = [worldA.x, worldA.y + offsetDist, 0.0]
                )
                #vertical:
                (
                    -- X do offset em relação ao X de A
                    resolved.offsetPoint = [worldA.x + offsetDist, worldA.y, 0.0]
                )
                default:
                (
                    local newVec = [worldB.x - worldA.x, worldB.y - worldA.y, 0.0]
                    if (length newVec) > 0.00001 then
                    (
                        local newDir = normalize newVec
                        local newPerp = normalize (cross [0, 0, 1] newDir)
                        resolved.offsetPoint = [worldA.x, worldA.y, 0.0] + (newPerp * offsetDist)
                    )
                    else
                    (
                        resolved.offsetPoint = record.offsetPoint
                    )
                )
            )
        )
        else
        (
            resolved.offsetPoint = record.offsetPoint
        )

        resolved
    )
)

AmenoDimensionCA = AmenoDimensionCAService()
