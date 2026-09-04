/* Verifies that 3ds Max loaded the installed ApplicationPlugins package. */

global AmenoApp
global AmenoVersion
global AmenoSceneSetup
global AmenoUnitService
global AmenoDimensionMath
global AmenoDimensionCA
global AmenoDimensionGraphics
global AmenoDimensionTool

(
    if AmenoApp == undefined then throw "O pacote instalado não criou AmenoApp."
    if not AmenoApp.started then throw "O pacote instalado não concluiu o startup."
    if AmenoVersion.appVersion != "0.0.1" then throw "A versão instalada não corresponde ao teste."
    if AmenoSceneSetup == undefined then throw "O pacote instalado não carregou o serviço de preparação de cena."
    if AmenoApp.refreshScene() == undefined then throw "O pacote instalado não respondeu ao diagnóstico de cena."
    if AmenoUnitService == undefined or AmenoDimensionMath == undefined then throw "O pacote instalado não carregou o núcleo da E2."
    if AmenoDimensionCA == undefined then throw "O pacote instalado não carregou o serviço de Custom Attributes da E5."
    if AmenoDimensionGraphics == undefined then throw "O pacote instalado não carregou o construtor gráfico da E3."
    if AmenoDimensionTool == undefined then throw "O pacote instalado não carregou a ferramenta interativa da E4."

    local installedE2Format = AmenoUnitService.formatMillimeters 19555.0 outputUnit:#meters precision:2 decimalSeparator:#comma roundingIncrementMillimeters:100.0
    if installedE2Format.text != "19,60 m" then throw "O núcleo E2 instalado formatou a medida incorretamente."

    -- E6: Teste de override e auditoria no pacote instalado
    local testDim = AmenoDimensionGraphics.createDimension [0, 0, 0] [1000, 0, 0] [0, 100, 0]
    local testAudit = AmenoDimensionGraphics.getDimensionAudit testDim.controller
    if testAudit == undefined or testAudit.isManual then throw "E6 instalado: Cota inicial deveria ser medido."
    AmenoDimensionGraphics.setDimensionMode testDim.controller #manualNumeric manualValueMm:950.0 reason:"Ajuste pacote instalado"
    local manualAudit = AmenoDimensionGraphics.getDimensionAudit testDim.controller
    if manualAudit == undefined or not manualAudit.isManual then throw "E6 instalado: Cota não assumiu modo manual."
    local markerFound = false
    for n in (AmenoDimensionGraphics.findNodesForDimension testDim.dimensionId) do
    (
        if (AmenoDimensionGraphics.readTextProperty n "Ameno.GraphicRole") == "marker" do
        (
            markerFound = true
            if n.renderable != false then throw "E6 instalado: Marcador deve ter renderable = false."
        )
    )
    if not markerFound then throw "E6 instalado: Marcador [M] não encontrado."
    AmenoDimensionGraphics.removeDimension testDim.dimensionId

    format "[AMENO_INSTALLED_TEST][PASS] Pacote % carregado via ApplicationPlugins com E1, E2, E3, E4, E5 e E6.\n" AmenoVersion.appVersion
)
