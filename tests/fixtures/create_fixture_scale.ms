-- =============================================================
-- Ameno Tools - Fixture: Gerador de Escala de Cotas (10, 100, 500, 1000)
-- =============================================================

global AmenoApp
global AmenoDimensionGraphics
global AmenoDimensionMath
global AmenoDimensionCA

fn generateScaleDimensions count:10 spacing:50 =
(
    if AmenoApp != undefined do AmenoApp.prepareScene()

    local created = 0
    local modes = #(#aligned, #horizontal, #vertical)

    for i = 1 to count do
    (
        local yOffset = (i - 1) * spacing
        local pA = [0, yOffset, 0]
        local pB = [100 + (mod i 5) * 20, yOffset + (mod i 3) * 10, 0]
        local pOff = [50, yOffset + 25, 0]
        local m = modes[((mod (i - 1) 3) as integer) + 1]

        local res = AmenoDimensionGraphics.createDimension pA pB pOff dimensionMode:m role:"benchmark"
        if res != undefined and res.controller != undefined do created += 1
    )

    format "[FIXTURE] Criadas % cotas de escala (solicitadas: %).\n" created count
    created
)
