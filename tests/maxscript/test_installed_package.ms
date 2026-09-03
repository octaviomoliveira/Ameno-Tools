/* Verifies that 3ds Max loaded the installed ApplicationPlugins package. */

global AmenoApp
global AmenoVersion

(
    if AmenoApp == undefined then throw "O pacote instalado não criou AmenoApp."
    if not AmenoApp.started then throw "O pacote instalado não concluiu o startup."
    if AmenoVersion.appVersion != "0.0.1" then throw "A versão instalada não corresponde ao teste."

    format "[AMENO_INSTALLED_TEST][PASS] Pacote % carregado via ApplicationPlugins.\n" AmenoVersion.appVersion
)
