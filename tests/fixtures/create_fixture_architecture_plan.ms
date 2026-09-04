-- =============================================================
-- Ameno Tools - Fixture: Planta Arquitetônica com Cotas Mistas
-- Cria geometria de paredes e cotas (alinhadas, horizontais, verticais, ancoradas e override)
-- =============================================================

global AmenoApp
global AmenoDimensionGraphics
global AmenoDimensionTool
global AmenoDimensionCA
global AmenoStyleService

fn createArchitecturePlanFixture =
(
    resetMaxFile #noPrompt

    -- Prepara layers e servicos
    if AmenoApp != undefined do AmenoApp.prepareScene()

    -- 1. Cria paredes de uma sala retangular (comprimento 6m, largura 4m, altura 2.8m)
    -- Sistema de coordenadas em cm: 600 x 400 x 280
    local wallSouth = box name:"WALL_SOUTH" length:20 width:600 height:280 pos:[300, 0, 140]
    local wallNorth = box name:"WALL_NORTH" length:20 width:600 height:280 pos:[300, 400, 140]
    local wallWest  = box name:"WALL_WEST"  length:400 width:20 height:280 pos:[0, 200, 140]
    local wallEast  = box name:"WALL_EAST"  length:400 width:20 height:280 pos:[600, 200, 140]

    -- Pilar central
    local pillar = box name:"PILLAR_CENTER" length:40 width:40 height:280 pos:[300, 200, 140]

    -- 2. Cria Cotas usando AmenoDimensionGraphics
    -- Cota 1: Alinhada parede Sul (6.00 m) - ancorada no wallSouth
    local dimSouth = AmenoDimensionGraphics.createDimension [0, 0, 0] [600, 0, 0] [300, -60, 0] dimensionMode:#aligned
    if dimSouth != undefined and dimSouth.controller != undefined do
    (
        if AmenoDimensionCA != undefined do
        (
            local rec = AmenoDimensionCA.readCA dimSouth.controller
            if rec != undefined do
            (
                rec.anchorType = "nodeA"
                rec.nodeA = wallSouth
                rec.localPointA = [0, 0, 0] * (inverse wallSouth.transform)
                AmenoDimensionCA.applyCA dimSouth.controller rec
            )
        )
    )

    -- Cota 2: Alinhada parede Oeste (4.00 m) - ancorada no wallWest
    local dimWest = AmenoDimensionGraphics.createDimension [0, 0, 0] [0, 400, 0] [-60, 200, 0] dimensionMode:#aligned
    if dimWest != undefined and dimWest.controller != undefined do
    (
        if AmenoDimensionCA != undefined do
        (
            local rec = AmenoDimensionCA.readCA dimWest.controller
            if rec != undefined do
            (
                rec.anchorType = "nodeA"
                rec.nodeA = wallWest
                rec.localPointA = [0, 0, 0] * (inverse wallWest.transform)
                AmenoDimensionCA.applyCA dimWest.controller rec
            )
        )
    )

    -- Cota 3: Horizontal vão interno Norte (6.00 m)
    local dimNorthH = AmenoDimensionGraphics.createDimension [0, 400, 0] [600, 400, 0] [300, 460, 0] dimensionMode:#horizontal

    -- Cota 4: Vertical vão interno Leste (4.00 m)
    local dimEastV = AmenoDimensionGraphics.createDimension [600, 0, 0] [600, 400, 0] [660, 200, 0] dimensionMode:#vertical

    -- Cota 5: Diagonal até pilar com cota alinhada (ancorada em ambos)
    local dimPillar = AmenoDimensionGraphics.createDimension [0, 0, 0] [300, 200, 0] [150, 160, 0] dimensionMode:#aligned
    if dimPillar != undefined and dimPillar.controller != undefined do
    (
        if AmenoDimensionCA != undefined do
        (
            local rec = AmenoDimensionCA.readCA dimPillar.controller
            if rec != undefined do
            (
                rec.anchorType = "both"
                rec.nodeA = wallWest
                rec.localPointA = [0, 0, 0] * (inverse wallWest.transform)
                rec.nodeB = pillar
                rec.localPointB = [300, 200, 0] * (inverse pillar.transform)
                AmenoDimensionCA.applyCA dimPillar.controller rec
            )
        )
    )

    -- Cota 6: Cota com valor manual (Override) de 2.50 m
    local dimManual = AmenoDimensionGraphics.createDimension [300, 0, 0] [300, 200, 0] [350, 100, 0] dimensionMode:#vertical
    if dimManual != undefined and dimManual.controller != undefined do
    (
        if AmenoApp != undefined do
        (
            AmenoApp.setDimensionMode dimManual.controller #manualNumeric manualValueMm:2500 reason:"Cota de projeto executivo"
        )
    )

    format "[FIXTURE] Planta Arquitetônica criada com 6 cotas e 5 objetos.\n"
    #(wallSouth, wallNorth, wallWest, wallEast, pillar)
)

createArchitecturePlanFixture()
