/* Verifies that 3ds Max loaded the installed ApplicationPlugins package. */

global AmenoApp
global AmenoVersion
global AmenoSceneSetup

(
    if AmenoApp == undefined then throw "O pacote instalado não criou AmenoApp."
    if not AmenoApp.started then throw "O pacote instalado não concluiu o startup."
    if AmenoVersion.appVersion != "0.0.1" then throw "A versão instalada não corresponde ao teste."
    if AmenoSceneSetup == undefined then throw "O pacote instalado não carregou o serviço de preparação de cena."
    if AmenoApp.refreshScene() == undefined then throw "O pacote instalado não respondeu ao diagnóstico de cena."

    format "[AMENO_INSTALLED_TEST][PASS] Pacote % carregado via ApplicationPlugins com a E1.\n" AmenoVersion.appVersion
)
