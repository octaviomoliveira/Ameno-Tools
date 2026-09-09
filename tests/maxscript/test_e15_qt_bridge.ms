/* E15 — smoke test da fachada Python/Qt no host Max 2026 Batch. */

global AmenoApp
global AmenoUiBridge
global AmenoPythonUI

(
    local testFile = getSourceFileName()
    local testPath = getFilenamePath testFile
    local repositoryRoot = pathConfig.normalizePath (pathConfig.appendPath testPath @"..\..")
    local bootstrapPath = pathConfig.normalizePath (pathConfig.appendPath repositoryRoot @"Contents\scripts\startup\ameno_bootstrap.ms")
    fileIn bootstrapPath quiet:true

    if AmenoApp == undefined or not AmenoApp.started then throw "E15: runtime não iniciou."
    if AmenoUiBridge == undefined then throw "E15: AmenoUiBridge não foi carregado."
    if AmenoPythonUI == undefined then throw "E15: launcher Python/Qt não foi carregado."
    if AmenoPythonUI.scriptPath == undefined or AmenoPythonUI.scriptPath == "" then throw "E15: caminho do entrypoint Python vazio."
    if not doesFileExist AmenoPythonUI.scriptPath then throw ("E15: entrypoint ausente: " + AmenoPythonUI.scriptPath)

    local scene = AmenoUiBridge.sceneSnapshot()
    local create = AmenoUiBridge.createSnapshot()
    local styles = AmenoUiBridge.stylesSnapshot()
    local refreshed = AmenoUiBridge.refreshSnapshot()
    if scene == undefined or scene.count < 9 then throw "E15: snapshot de cena não primitivo/incompleto."
    if create == undefined or create.count < 6 then throw "E15: snapshot de criação incompleto."
    if styles == undefined then throw "E15: snapshot de estilos ausente."
    if refreshed == undefined or not refreshed[1] or refreshed.count < 4 then throw "E15: refreshSnapshot não retornou envelope válido."
    for item in styles do
        if item == undefined or item.count < 20 then throw "E15: item de estilo incompleto."

    local settings = AmenoUiBridge.setCreateSettings "vertical" "viewPlane" "default" "meters" 2 true
    if settings == undefined or not settings[1] then throw "E15: envelope de configuração inválido."
    if settings[4] == undefined or settings[4].count < 6 then throw "E15: configuração não retornou snapshot."
    local cancelled = AmenoUiBridge.cancelInteractiveCommand()
    if cancelled == undefined or not cancelled[1] then throw "E15: cancelamento seguro da coleta inválido."

    format "[AMENO_TEST][PASS] E15 bridge Qt/Max 2026: launcher, snapshots primitivos e configuração validados.\n"
)
