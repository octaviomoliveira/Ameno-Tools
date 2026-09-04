-- =============================================================
-- E10.7: ancoras por vertice em Editable Poly / Editable Mesh
-- Executado por 3dsmaxbatch.exe via tools\test-maxscript.ps1
-- =============================================================

global AmenoLegacyDimensionCADefV4ForTest
global AmenoApp
global AmenoDimensionCA
global AmenoDimensionGraphics
global AmenoAnchorService
global AmenoDimensionTool

-- Cria uma instancia real do schema anterior ANTES de carregar o schema v5.
-- Como o attribID e global, avaliar o bootstrap v5 migra a instancia existente.
AmenoLegacyDimensionCADefV4ForTest = attributes AmenoDimensionData
attribID:#(0x414d454e, 0x44494d31)
version:4
(
    parameters main
    (
        schemaVersion type:#integer default:4
        dimensionId type:#string default:""
        dimensionRole type:#string default:"user"
        dimensionMode type:#string default:"aligned"
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
    )
)

(
local legacyAnchor = Box name:"AMENO_TEST_LEGACY_ANCHOR" length:100 width:100 height:20
convertToPoly legacyAnchor
legacyAnchor.position = [100, 50, 0]

local legacyController = Point name:"AMENO_TEST_LEGACY_CTRL"
custAttributes.add legacyController AmenoLegacyDimensionCADefV4ForTest
local legacyCA = custAttributes.get legacyController AmenoLegacyDimensionCADefV4ForTest
legacyCA.schemaVersion = 4
legacyCA.dimensionId = "legacy-v4"
legacyCA.anchorType = "nodeA"
legacyCA.nodeA = legacyAnchor
legacyCA.localPointA = [0, 0, 0]
legacyCA.pointA = [100, 50, 0]
legacyCA.pointB = [300, 50, 0]
legacyCA.offsetPoint = [100, 100, 0]

local testFile = getSourceFileName()
local testPath = getFilenamePath testFile
local repositoryRoot = pathConfig.normalizePath (pathConfig.appendPath testPath @"..\..")
local bootstrapPath = pathConfig.normalizePath (pathConfig.appendPath repositoryRoot @"Contents\scripts\startup\ameno_bootstrap.ms")
fileIn bootstrapPath quiet:true

local passed = 0
local failed = 0
local errors = #()

fn expectTrue label value =
(
    if value == true then
    (
        format "  [PASS] %\n" label
        passed += 1
    )
    else
    (
        format "  [FAIL] % | obtido: %\n" label value
        failed += 1
        append errors label
    )
)

fn expectEqual label actual expected =
(
    expectTrue (label + " | esperado: " + (expected as string) + " | obtido: " + (actual as string)) (actual == expected)
)

fn expectPointNear label actual expected tolerance:0.001 =
(
    local ok = actual != undefined and expected != undefined and (length (actual - expected)) <= tolerance
    expectTrue (label + " | esperado: " + (expected as string) + " | obtido: " + (actual as string)) ok
)

format "\n=== A1: migracao real CA v4 -> v5 ===\n"
local migrated = AmenoDimensionCA.readCA legacyController
expectTrue "registro v4 continua legivel" (migrated != undefined)
if migrated != undefined do
(
    expectEqual "vertex A recebe sentinela retrocompativel" migrated.anchorVertexIdA -1
    expectEqual "vertex B recebe sentinela retrocompativel" migrated.anchorVertexIdB -1
    expectEqual "edge A recebe sentinela retrocompativel" migrated.anchorEdgeIdA -1
    expectEqual "edge B recebe sentinela retrocompativel" migrated.anchorEdgeIdB -1
    expectEqual "edgeMid A permanece desligado" migrated.anchorEdgeMidA false
    expectEqual "edgeMid B permanece desligado" migrated.anchorEdgeMidB false

    legacyAnchor.position += [25, 10, 0]
    local legacyResolved = AmenoDimensionCA.resolvePoints migrated
    expectPointNear "v4 continua resolvendo por localPoint" legacyResolved.pointA ([0, 0, 0] * legacyAnchor.transform)
)

resetMaxFile #noPrompt
AmenoApp.prepareScene()

format "\n=== A2: captura e persistencia do vertice Editable Poly ===\n"
local polyNode = Box name:"AMENO_TEST_POLY" length:100 width:100 height:20
convertToPoly polyNode
polyNode.position = [50, 25, 0]
local polyVertexId = 1
local polyPointA = AmenoDimensionCA.resolveVertexWorld polyNode polyVertexId
local polyPointB = polyPointA + [240, 80, 0]
local polyOffset = polyPointA + [0, 60, 0]
local nearestPoly = AmenoDimensionCA.findNearestVertex polyNode polyPointA maxDistance:0.01
expectTrue "vertice mais proximo do Poly foi detectado" (nearestPoly != undefined and nearestPoly.vertexId == polyVertexId)
local toolHitPoly = AmenoDimensionTool.detectHitNode polyPointA
expectTrue "ferramenta captura vertice pelo ponto de snap" (toolHitPoly != undefined and toolHitPoly.node == polyNode and toolHitPoly.vertexId == polyVertexId)

local polyDim = AmenoDimensionGraphics.createDimension polyPointA polyPointB polyOffset role:"test-subobject" \
    nodeA:polyNode anchorVertexIdA:polyVertexId dimensionMode:#horizontal
local polyCtrl = polyDim.controller
local polyRecord = AmenoDimensionCA.readCA polyCtrl
expectEqual "nova cota usa schema v5" polyRecord.schemaVersion 5
expectEqual "vertex ID A persistido" polyRecord.anchorVertexIdA polyVertexId
expectEqual "modo horizontal preservado" polyRecord.dimensionMode "horizontal"

format "\n=== A3: geometryChanged atualiza ponto e respeita modo H/V ===\n"
AmenoAnchorService.rebuildIndex()
local polyBase = polyNode.baseObject
local oldPolyLocal = polyOp.getVert polyBase polyVertexId
local polyVertexSet = #{}
polyVertexSet[polyVertexId] = true
polyOp.setVert polyBase polyVertexSet (oldPolyLocal + [35, 20, 0])
update polyNode
local expectedPolyWorld = AmenoDimensionCA.resolveVertexWorld polyNode polyVertexId
AmenoAnchorService.handleNodesChanged #geometryChanged #((getHandleByAnim polyNode))
polyRecord = AmenoDimensionCA.readCA polyCtrl
expectPointNear "ponto A acompanha movimento do vertice Poly" polyRecord.pointA expectedPolyWorld
local expectedHorizontal = AmenoDimensionMath.layoutForMode polyRecord.pointA polyRecord.pointB polyRecord.offsetPoint mode:#horizontal
expectTrue "layout horizontal continua valido apos update rapido" expectedHorizontal.valid
expectTrue "auditoria usa medida horizontal" ((abs (polyRecord.lastMeasuredMm - expectedHorizontal.measuredMillimeters)) <= 0.001)

format "\n=== A4: Editable Mesh usa o mesmo contrato ===\n"
local meshNode = Box name:"AMENO_TEST_MESH" length:80 width:80 height:20
convertToMesh meshNode
meshNode.position = [500, 40, 0]
local meshVertexId = 2
local meshPointB = AmenoDimensionCA.resolveVertexWorld meshNode meshVertexId
local meshPointA = meshPointB - [180, 0, 0]
local meshDim = AmenoDimensionGraphics.createDimension meshPointA meshPointB (meshPointA + [0, 50, 0]) role:"test-subobject" \
    nodeB:meshNode anchorVertexIdB:meshVertexId dimensionMode:#aligned
local meshCtrl = meshDim.controller
AmenoAnchorService.rebuildIndex()
local meshBase = meshNode.baseObject
local oldMeshLocal = meshOp.getVert meshBase meshVertexId
local meshVertexSet = #{}
meshVertexSet[meshVertexId] = true
meshOp.setVert meshBase meshVertexSet (oldMeshLocal + [20, 0, 0])
update meshNode
local expectedMeshWorld = AmenoDimensionCA.resolveVertexWorld meshNode meshVertexId
AmenoAnchorService.handleNodesChanged #geometryChanged #((getHandleByAnim meshNode))
local meshRecord = AmenoDimensionCA.readCA meshCtrl
expectPointNear "ponto B acompanha movimento do vertice Mesh" meshRecord.pointB expectedMeshWorld
expectEqual "vertex ID B permanece persistido" meshRecord.anchorVertexIdB meshVertexId

format "\n=== A4b: leitura usa geometria avaliada no topo da modifier stack ===\n"
local stackedNode = Box name:"AMENO_TEST_STACK" length:120 width:80 height:200
convertToPoly stackedNode
stackedNode.position = [900, 100, 0]
local stackedVertexId = 1
local stackedBefore = AmenoDimensionCA.resolveVertexWorld stackedNode stackedVertexId
local bendModifier = Bend()
bendModifier.angle = 55
bendModifier.direction = 20
bendModifier.bendAxis = 2
addModifier stackedNode bendModifier
update stackedNode
local stackedAfter = AmenoDimensionCA.resolveVertexWorld stackedNode stackedVertexId
expectTrue "modifier altera a posicao avaliada do vertice" (stackedBefore != undefined and stackedAfter != undefined and (length (stackedAfter - stackedBefore)) > 0.001)
local stackedHit = AmenoDimensionCA.findNearestVertex stackedNode stackedAfter maxDistance:0.01
expectTrue "busca encontra vertice no topo da stack" (stackedHit != undefined and stackedHit.vertexId == stackedVertexId)

format "\n=== A5: topologia invalida preserva posicao e marca orfa ===\n"
polyRecord = AmenoDimensionCA.readCA polyCtrl
local lastValidPointA = polyRecord.pointA
polyRecord.anchorVertexIdA = 999999
AmenoDimensionCA.applyCA polyCtrl polyRecord
local invalidResolved = AmenoDimensionCA.resolvePoints polyRecord
expectTrue "ID removido marca cota como orfa" invalidResolved.isOrphan
expectPointNear "ID removido nao faz a cota saltar" invalidResolved.pointA lastValidPointA
expectTrue "motivo identifica vertice ausente" (findString invalidResolved.orphanReason "Vértice" != undefined)

format "\n=== A6: bake limpa referencias de subobjeto ===\n"
AmenoAnchorService.syncDimension polyCtrl
select polyCtrl
local bakedCount = AmenoApp.bakeSelected()
local bakedRecord = AmenoDimensionCA.readCA polyCtrl
expectEqual "bake processou a cota ancorada" bakedCount 1
expectEqual "bake converte para world" bakedRecord.anchorType "world"
expectEqual "bake limpa vertex A" bakedRecord.anchorVertexIdA -1
expectEqual "bake limpa edge A" bakedRecord.anchorEdgeIdA -1
expectEqual "bake limpa edgeMid A" bakedRecord.anchorEdgeMidA false

format "\n=== A7: callback geometrico unico esta ativo ===\n"
expectTrue "NodeEventCallback foi retido" (AmenoAnchorService.anchorCallback != undefined)
expectTrue "servico informa callback ativo" AmenoAnchorService.isCallbackActive

format "\n=== RESULTADO E10.7 ===\n"
format "PASS: %  FAIL: %\n" passed failed
if failed > 0 do for item in errors do format "  - %\n" item

if failed == 0 then
    format "[AMENO_TEST][PASS] E10.7 subobject vertex anchors passed\n"
else
    format "E10.7 FAIL\n"
)
