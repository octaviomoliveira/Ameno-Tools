/* Integration smoke test executed by 3dsmaxbatch.exe. */

global AmenoApp
global AmenoVersion
global AmenoRendererProbe
global AmenoSceneSetup

(
    local testFile = getSourceFileName()
    local testPath = getFilenamePath testFile
    local repositoryRoot = pathConfig.normalizePath (pathConfig.appendPath testPath @"..\..")
    local bootstrapPath = pathConfig.normalizePath (pathConfig.appendPath repositoryRoot @"Contents\scripts\startup\ameno_bootstrap.ms")
    local macroPath = pathConfig.normalizePath (pathConfig.appendPath repositoryRoot @"Contents\macroscripts\AmenoTools.mcr")

    fileIn bootstrapPath quiet:true

    if AmenoApp == undefined then throw "AmenoApp não foi criada pelo bootstrap."
    if not AmenoApp.started then throw "AmenoApp não terminou o startup."
    if AmenoVersion.appVersion != "0.0.1" then throw "Versão inesperada no runtime."
    if AmenoApp.rendererInfo == undefined then throw "Renderer probe não retornou informação."
    if AmenoSceneSetup == undefined then throw "Scene setup não foi carregado pelo bootstrap."

    local coronaInfo = AmenoRendererProbe.classify "CoronaRenderer"
    local vrayCpuInfo = AmenoRendererProbe.classify "V_Ray_7_Hotfix_1"
    local vrayGpuInfo = AmenoRendererProbe.classify "V_Ray_GPU_Next"

    if coronaInfo.family != #corona or coronaInfo.supportState != #supported then throw "Classificação Corona inválida."
    if vrayCpuInfo.family != #vray or vrayCpuInfo.engine != #cpu or vrayCpuInfo.supportState != #supported then throw "Classificação V-Ray CPU inválida."
    if vrayGpuInfo.family != #vray or vrayGpuInfo.engine != #gpu or vrayGpuInfo.supportState != #experimental then throw "Classificação V-Ray GPU inválida."

    resetMaxFile #noPrompt

    local originalLayer = LayerManager.current
    local preparedState = AmenoApp.prepareScene()

    if preparedState.status != #ready then throw ("Preparar cena deveria terminar pronto: " + preparedState.detail)
    if preparedState.dimensionsLayer == undefined or preparedState.systemLayer == undefined then throw "Layers Ameno não foram criadas."
    if preparedState.dimensionsLayer.name != "AMENO_COTAS" then throw "Layer de cotas padrão inesperada."
    if preparedState.systemLayer.name != "AMENO_SYSTEM" then throw "Layer de sistema padrão inesperada."
    if preparedState.documentNode == undefined or not isValidNode preparedState.documentNode then throw "Registro de documento não foi criado."
    if preparedState.defaultStyleNode == undefined or not isValidNode preparedState.defaultStyleNode then throw "Estilo padrão não foi criado."
    if preparedState.documentNode.layer != preparedState.systemLayer then throw "Registro de documento não pertence à layer de sistema."
    if preparedState.defaultStyleNode.layer != preparedState.systemLayer then throw "Estilo padrão não pertence à layer de sistema."
    if preparedState.documentNode.renderable or preparedState.defaultStyleNode.renderable then throw "Infraestrutura Ameno não pode renderizar."
    if not preparedState.documentNode.isHidden or not preparedState.defaultStyleNode.isHidden then throw "Infraestrutura Ameno deve permanecer oculta."
    if (AmenoSceneSetup.readTextProperty preparedState.defaultStyleNode "Ameno.Unit") != "m" then throw "Unidade padrão do estilo não foi registrada."
    if LayerManager.current.name != originalLayer.name then throw "A layer corrente não foi restaurada após preparar a cena."

    local documentCountBefore = (AmenoSceneSetup.findManagedNodes "document").count
    local styleCountBefore = (AmenoSceneSetup.findDefaultStyleNodes()).count
    local layerCountBefore = LayerManager.count
    local preparedAgainState = AmenoApp.prepareScene()

    if preparedAgainState.status != #ready then throw "Preparar cena não é idempotente."
    if (AmenoSceneSetup.findManagedNodes "document").count != documentCountBefore then throw "Preparar cena duplicou o registro de documento."
    if (AmenoSceneSetup.findDefaultStyleNodes()).count != styleCountBefore then throw "Preparar cena duplicou o estilo padrão."
    if LayerManager.count != layerCountBefore then throw "Preparar cena duplicou layers."

    resetMaxFile #noPrompt
    local userLayer = LayerManager.newLayerFromName "AMENO_COTAS"
    local conflictState = AmenoApp.prepareScene()

    if conflictState.status != #ready then throw ("Preparar cena com conflito de layer falhou: " + conflictState.detail)
    if conflictState.dimensionsLayer.name == "AMENO_COTAS" then throw "Uma layer homônima do usuário foi apropriada."
    if userLayer.name != "AMENO_COTAS" then throw "A layer homônima do usuário foi modificada."

    fileIn macroPath quiet:true

    format "[AMENO_TEST][PASS] Bootstrap %, renderer %, preparação de cena aprovada.\n" AmenoVersion.appVersion AmenoApp.rendererInfo.displayName
)
