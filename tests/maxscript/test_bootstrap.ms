/* Integration smoke test executed by 3dsmaxbatch.exe. */

global AmenoApp
global AmenoVersion
global AmenoRendererProbe
global AmenoSceneSetup
global AmenoUnitService
global AmenoDimensionMath
global AmenoDimensionGraphics

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
    if AmenoUnitService == undefined then throw "Serviço de unidades não foi carregado pelo bootstrap."
    if AmenoDimensionMath == undefined then throw "Núcleo de matemática de cotas não foi carregado pelo bootstrap."
    if AmenoDimensionGraphics == undefined then throw "Construtor gráfico de cotas não foi carregado pelo bootstrap."

    local coronaInfo = AmenoRendererProbe.classify "CoronaRenderer"
    local vrayCpuInfo = AmenoRendererProbe.classify "V_Ray_7_Hotfix_1"
    local vrayGpuInfo = AmenoRendererProbe.classify "V_Ray_GPU_Next"

    if coronaInfo.family != #corona or coronaInfo.supportState != #supported then throw "Classificação Corona inválida."
    if vrayCpuInfo.family != #vray or vrayCpuInfo.engine != #cpu or vrayCpuInfo.supportState != #supported then throw "Classificação V-Ray CPU inválida."
    if vrayGpuInfo.family != #vray or vrayGpuInfo.engine != #gpu or vrayGpuInfo.supportState != #experimental then throw "Classificação V-Ray GPU inválida."

    local objectCountBeforeMath = objects.count
    local layoutPositive = AmenoDimensionMath.alignedLayout [0, 0, 0] [100, 0, 0] [0, 20, 0] millimetersPerSceneUnit:10.0
    local layoutNegative = AmenoDimensionMath.alignedLayout [0, 0, 0] [100, 0, 0] [0, -20, 0] millimetersPerSceneUnit:10.0
    local layoutDiagonal = AmenoDimensionMath.alignedLayout [0, 0, 0] [-3, 4, 40] [-7, -5, 100] millimetersPerSceneUnit:1000.0
    local layoutInvalid = AmenoDimensionMath.alignedLayout [5, 5, 0] [5, 5, 10] [8, 8, 0] millimetersPerSceneUnit:1.0

    if not layoutPositive.valid then throw "Layout alinhado positivo deveria ser válido."
    if not (AmenoDimensionMath.nearlyEqual layoutPositive.measuredSceneUnits 100.0) then throw "Medida em unidades de cena incorreta."
    if not (AmenoDimensionMath.nearlyEqual layoutPositive.measuredMillimeters 1000.0) then throw "Medida em milímetros incorreta."
    if layoutPositive.side != #positive then throw "Lado positivo não foi identificado."
    if not (AmenoDimensionMath.nearlyEqualPoint layoutPositive.linePointA [0, 20, 0]) then throw "Ponto A da linha de cota incorreto."
    if not (AmenoDimensionMath.nearlyEqualPoint layoutPositive.linePointB [100, 20, 0]) then throw "Ponto B da linha de cota incorreto."
    if layoutNegative.side != #negative then throw "Lado negativo não foi identificado."
    if not layoutDiagonal.valid then throw "Layout diagonal deveria ser válido."
    if not (AmenoDimensionMath.nearlyEqual layoutDiagonal.measuredSceneUnits 5.0) then throw "Medida diagonal no plano XY incorreta."
    if not (AmenoDimensionMath.nearlyEqual layoutDiagonal.measuredMillimeters 5000.0) then throw "Conversão diagonal para milímetros incorreta."
    if layoutInvalid.valid or layoutInvalid.errorCode != #coincidentPoints then throw "Pontos coincidentes deveriam bloquear a cota."
    if objects.count != objectCountBeforeMath then throw "A matemática de cotas não deve criar objetos na cena."

    if not (AmenoDimensionMath.nearlyEqual (AmenoUnitService.sceneUnitsToMillimeters 10.0 systemScale:1.0 systemType:#centimeters) 100.0) then throw "Conversão de centímetros incorreta."
    if not (AmenoDimensionMath.nearlyEqual (AmenoUnitService.sceneUnitsToMillimeters 2.0 systemScale:1.0 systemType:#meters) 2000.0) then throw "Conversão de metros incorreta."
    if not (AmenoDimensionMath.nearlyEqual (AmenoUnitService.sceneUnitsToMillimeters 1.0 systemScale:1.0 systemType:#inches) 25.4) then throw "Conversão de polegadas incorreta."
    if not (AmenoDimensionMath.nearlyEqual (AmenoUnitService.roundToIncrement 19555.0 100.0) 19600.0) then throw "Arredondamento para incremento incorreto."

    local roundedMeters = AmenoUnitService.formatMillimeters 19555.0 outputUnit:#meters precision:2 decimalSeparator:#comma roundingIncrementMillimeters:100.0
    local trimmedMeters = AmenoUnitService.formatMillimeters 800.0 outputUnit:#meters precision:2 trimZeros:true decimalSeparator:#comma
    local centimeterValue = AmenoUnitService.formatMillimeters 3425.0 outputUnit:#centimeters precision:1 decimalSeparator:#dot

    if roundedMeters.text != "19,60 m" then throw ("Formatação arredondada incorreta: " + roundedMeters.text)
    if trimmedMeters.text != "0,8 m" then throw ("Formatação sem zeros incorreta: " + trimmedMeters.text)
    if centimeterValue.text != "342.5 cm" then throw ("Formatação em centímetros incorreta: " + centimeterValue.text)

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

    resetMaxFile #noPrompt
    local graphicSceneState = AmenoApp.prepareScene()
    local objectCountBeforeGraphics = objects.count
    local graphicRecord = AmenoDimensionGraphics.createDimension [0, 0, 0] [100, 0, 0] [0, 20, 0]

    if graphicRecord == undefined then throw "A cota gráfica não retornou registro."
    if graphicRecord.controller == undefined or not isValidNode graphicRecord.controller then throw "Controlador gráfico não foi criado."
    if graphicRecord.lineNode == undefined or not isValidNode graphicRecord.lineNode then throw "Linhas gráficas não foram criadas."
    if graphicRecord.textNode == undefined or not isValidNode graphicRecord.textNode then throw "Rótulo TextPlus não foi criado."
    if graphicRecord.lineNode.layer != graphicSceneState.dimensionsLayer or graphicRecord.textNode.layer != graphicSceneState.dimensionsLayer then throw "Nós visuais não pertencem à layer de cotas."
    if graphicRecord.controller.layer != graphicSceneState.systemLayer then throw "Controlador não pertence à layer de sistema."
    if not graphicRecord.controller.isHidden or graphicRecord.controller.renderable then throw "Controlador gráfico deve ficar oculto e fora do render."
    if graphicRecord.displayText == "" then throw "A cota gráfica não recebeu texto formatado."
    if (AmenoDimensionGraphics.findNodesForDimension graphicRecord.dimensionId).count != 3 then throw "A cota gráfica deveria registrar três nós."
    if objects.count != (objectCountBeforeGraphics + 3) then throw "A criação gráfica deveria adicionar exatamente três nós."

    local originalLineNode = graphicRecord.lineNode
    local rebuiltRecord = AmenoDimensionGraphics.rebuildDimension graphicRecord.controller

    if rebuiltRecord.controller != graphicRecord.controller then throw "Reconstrução não preservou o controlador."
    if isValidNode originalLineNode then throw "Reconstrução deixou a linha gráfica anterior na cena."
    if rebuiltRecord.lineNode == undefined or not isValidNode rebuiltRecord.lineNode then throw "Reconstrução não criou novas linhas."
    if rebuiltRecord.textNode == undefined or not isValidNode rebuiltRecord.textNode then throw "Reconstrução não criou novo rótulo TextPlus."
    if (AmenoDimensionGraphics.findNodesForDimension rebuiltRecord.dimensionId).count != 3 then throw "Reconstrução deixou resíduos gráficos."

    if not (AmenoDimensionGraphics.removeDimension rebuiltRecord.dimensionId) then throw "Remoção da cota gráfica falhou."
    if (AmenoDimensionGraphics.findNodesForDimension rebuiltRecord.dimensionId).count != 0 then throw "Remoção da cota gráfica deixou resíduos."
    if objects.count != objectCountBeforeGraphics then throw "Ciclo gráfico criar/reconstruir/remover não restaurou a contagem de nós."

    fileIn macroPath quiet:true

    format "[AMENO_TEST][PASS] Bootstrap %, renderer %, preparação de cena, E2 e E3 aprovadas.\n" AmenoVersion.appVersion AmenoApp.rendererInfo.displayName
)
