/* E19: legacy one-style libraries receive missing built-in presets safely. */

global AmenoStyleService
global AmenoStyleServiceDefinition

clearListener()

try
(
    local testPath = getFilenamePath (getSourceFileName())
    local worktreeRoot = pathConfig.normalizePath (pathConfig.appendPath testPath @"..\..")
    local servicePath = pathConfig.normalizePath (pathConfig.appendPath worktreeRoot @"Contents\scripts\ameno\core\ameno_style_service.ms")
    resetMaxFile #noPrompt
    if doesFileExist servicePath then fileIn servicePath quiet:true
    else throw ("E19: serviço de estilos não encontrado: " + servicePath)

    local service = AmenoStyleServiceDefinition()
    local presets = service.createDefaultPresets()
    if presets.count < 3 do throw "E19: catálogo interno precisa ter ao menos três estilos."

    local customized = service.cloneStyle presets[1]
    customized.name = "Arquitetônico personalizado"
    customized.fontSize = 276.0
    local ghost = service.cloneStyle presets[1]
    ghost.styleId = "style-legacy-ameno-01"
    ghost.name = "Ameno_01"
    service.styles = #(customized, ghost)
    service.globalStyles = #(service.cloneStyle ghost)

    local removed = service.removeLegacyGhostStyles persist:false
    if not removed do throw "E19: limpeza não detectou Ameno_01."
    if service.styles.count != 1 or service.globalStyles.count != 0 do throw "E19: Ameno_01 permaneceu na biblioteca."
    if service.styles[1].name != "Arquitetônico personalizado" do throw "E19: limpeza removeu um estilo legítimo."

    local changed = service.ensureBuiltInPresets persist:false
    if not changed do throw "E19: migração não detectou presets ausentes."
    if service.globalStyles.count != (presets.count - 1) do throw "E19: migração não adicionou somente os presets ausentes."
    if service.styles[1].name != "Arquitetônico personalizado" or service.styles[1].fontSize != 276.0 do
        throw "E19: migração sobrescreveu o estilo editado pelo usuário."

    local secondRun = service.ensureBuiltInPresets persist:false
    if secondRun do throw "E19: migração de presets não é idempotente."
    if service.globalStyles.count != (presets.count - 1) do throw "E19: segunda migração duplicou presets."

    format "[AMENO_TEST][PASS] E19_STYLE_PRESETS\n"
)
catch
(
    format "[AMENO_TEST][FAIL] E19_STYLE_PRESETS | %\n" (getCurrentException() as string)
    throw()
)
