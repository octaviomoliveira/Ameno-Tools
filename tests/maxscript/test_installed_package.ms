/* Verifies that 3ds Max loaded the installed ApplicationPlugins package. */

global AmenoApp
global AmenoVersion
global AmenoSceneSetup
global AmenoUnitService
global AmenoDimensionMath

(
    if AmenoApp == undefined then throw "O pacote instalado não criou AmenoApp."
    if not AmenoApp.started then throw "O pacote instalado não concluiu o startup."
    if AmenoVersion.appVersion != "0.0.1" then throw "A versão instalada não corresponde ao teste."
    if AmenoSceneSetup == undefined then throw "O pacote instalado não carregou o serviço de preparação de cena."
    if AmenoApp.refreshScene() == undefined then throw "O pacote instalado não respondeu ao diagnóstico de cena."
    if AmenoUnitService == undefined or AmenoDimensionMath == undefined then throw "O pacote instalado não carregou o núcleo da E2."

    local installedE2Format = AmenoUnitService.formatMillimeters 19555.0 outputUnit:#meters precision:2 decimalSeparator:#comma roundingIncrementMillimeters:100.0
    if installedE2Format.text != "19,60 m" then throw "O núcleo E2 instalado formatou a medida incorretamente."

    format "[AMENO_INSTALLED_TEST][PASS] Pacote % carregado via ApplicationPlugins com E1 e E2.\n" AmenoVersion.appVersion
)
