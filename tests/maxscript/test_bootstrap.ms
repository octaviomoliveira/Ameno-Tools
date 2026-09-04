/* Integration smoke test executed by 3dsmaxbatch.exe. */

global AmenoApp
global AmenoVersion
global AmenoRendererProbe
global AmenoSceneSetup
global AmenoUnitService
global AmenoDimensionMath
global AmenoDimensionCA
global AmenoDimensionGraphics
global AmenoDimensionTool
global AmenoDimensionMouseTool

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
    if AmenoDimensionCA == undefined then throw "Serviço de Custom Attributes não foi carregado pelo bootstrap."
    if AmenoDimensionGraphics == undefined then throw "Construtor gráfico de cotas não foi carregado pelo bootstrap."
    if AmenoDimensionTool == undefined then throw "Ferramenta interativa E4 não foi carregada pelo bootstrap."
    if (classOf AmenoDimensionMouseTool) != MouseTool then throw "MouseTool E4 não foi registrado."

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
    if not (AmenoDimensionCA.hasCA graphicRecord.controller) then throw "Controlador gráfico não possui Custom Attributes Ameno."
    local caRecord = AmenoDimensionCA.readCA graphicRecord.controller
    if caRecord == undefined or caRecord.dimensionId != graphicRecord.dimensionId then throw "Custom Attributes do controlador inválidos."
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

    local previewRecord = AmenoDimensionGraphics.createPreviewDimension [0, 0, 0] [100, 0, 0] [0, 20, 0]
    if previewRecord == undefined then throw "Prévia E4 não retornou registro."
    if previewRecord.controller != undefined then throw "Prévia E4 não pode criar controlador permanente."
    if previewRecord.lineNode == undefined or previewRecord.textNode == undefined then throw "Prévia E4 não criou linhas e texto."
    if (AmenoDimensionGraphics.readTextProperty previewRecord.lineNode "Ameno.Kind") != "dimensionPreview" then throw "Prévia E4 não foi identificada como temporária."
    if objects.count != (objectCountBeforeGraphics + 2) then throw "Prévia E4 deveria adicionar apenas dois nós temporários."

    local updatedPreview = AmenoDimensionGraphics.updatePreviewDimension previewRecord [0, 0, 0] [120, 0, 0] [0, 30, 0]
    if updatedPreview == undefined then throw "Atualização da prévia E4 falhou."
    if not (AmenoDimensionMath.nearlyEqual updatedPreview.layout.measuredSceneUnits 120.0) then throw "Atualização da prévia E4 não atualizou a medida."
    if updatedPreview.displayText == "" then throw "Atualização da prévia E4 perdeu o texto."
    if not (AmenoDimensionGraphics.removePreviewDimension updatedPreview) then throw "Remoção da prévia E4 falhou."
    if objects.count != objectCountBeforeGraphics then throw "Remoção da prévia E4 deixou resíduos."

    resetMaxFile #noPrompt
    AmenoApp.prepareScene()
    local interactiveBaseline = objects.count
    if not AmenoDimensionTool.begin() then throw "AmenoDimensionTool não iniciou no teste de três cliques."
    AmenoDimensionTool.handlePoint 1 [0, 0, 0]
    AmenoDimensionTool.handlePoint 2 [100, 0, 0]
    if AmenoDimensionTool.preview == undefined then throw "E4 não criou prévia após o segundo ponto."
    local graphicsService = AmenoDimensionGraphics
    AmenoDimensionGraphics = undefined
    local failedCommitResult = AmenoDimensionTool.handlePoint 3 [50, 20, 0]
    AmenoDimensionGraphics = graphicsService
    if failedCommitResult == #stop then throw "E4 deveria manter a ferramenta ativa após afastamento inválido."
    if AmenoDimensionTool.preview == undefined then throw "E4 perdeu a prévia após afastamento inválido."
    if AmenoDimensionTool.stage != #offset then throw "E4 saiu da etapa de afastamento após falha de commit."
    local commitResult = AmenoDimensionTool.handlePoint 3 [0, 20, 0]
    if commitResult != #stop then throw "E4 não encerrou o fluxo após o terceiro ponto."
    if AmenoDimensionTool.lastCommittedRecord == undefined then throw "E4 não guardou a cota criada."
    if (AmenoDimensionGraphics.findControllers role:"interactive").count != 1 then throw "E4 não criou um controlador interativo."
    AmenoDimensionTool.cancel()
    if objects.count != (interactiveBaseline + 3) then throw "E4 deixou quantidade inesperada após commit."
    if not (AmenoDimensionGraphics.removeDimension AmenoDimensionTool.lastCommittedRecord.dimensionId) then throw "Limpeza da cota interativa de teste falhou."
    if objects.count != interactiveBaseline then throw "Limpeza da cota interativa deixou resíduos."

    resetMaxFile #noPrompt
    AmenoApp.prepareScene()
    local cancelBaseline = objects.count
    if not AmenoDimensionTool.begin() then throw "AmenoDimensionTool não iniciou no teste de cancelamento."
    AmenoDimensionTool.handlePoint 1 [0, 0, 0]
    AmenoDimensionTool.handlePoint 2 [100, 0, 0]
    if AmenoDimensionTool.preview == undefined then throw "E4 não criou prévia para o cancelamento."
    AmenoDimensionTool.cancel()
    if objects.count != cancelBaseline then throw "Cancelamento E4 deixou nós temporários."

    -- E5 — Persistência, Save/Load, Reabertura, Renomeação, Reparo e Undo
    resetMaxFile #noPrompt
    AmenoApp.prepareScene()
    local e5Baseline = objects.count
    local dimToPersist = AmenoDimensionGraphics.createDimension [10, 20, 0] [310, 20, 0] [10, 50, 0]
    local savedDimId = dimToPersist.dimensionId

    local tempMaxDir = getDir #temp
    local tempSceneFile = pathConfig.appendPath tempMaxDir "ameno_e5_test.max"
    deleteFile tempSceneFile
    saveMaxFile tempSceneFile clearNeedSaveFlag:true quiet:true

    resetMaxFile #noPrompt
    if (AmenoDimensionGraphics.findControllers()).count != 0 then throw "Reset da cena não limpou os controladores."

    loadMaxFile tempSceneFile quiet:true
    deleteFile tempSceneFile
    AmenoApp.refreshDimensions()

    local loadedControllers = AmenoDimensionGraphics.findControllers()
    if loadedControllers.count != 1 then throw "Cota persistida não foi encontrada após recarregar a cena."
    local loadedCtrl = loadedControllers[1]
    if not (AmenoDimensionCA.hasCA loadedCtrl) then throw "Controlador recarregado perdeu Custom Attributes."
    local loadedCa = AmenoDimensionCA.readCA loadedCtrl
    if loadedCa == undefined or loadedCa.dimensionId != savedDimId then throw "ID da cota recarregada não corresponde ao salvo."
    if loadedCa.pointA != [10, 20, 0] or loadedCa.pointB != [310, 20, 0] or loadedCa.offsetPoint != [10, 50, 0] then throw "Pontos geométricos divergentes após load."
    if (AmenoDimensionGraphics.inspectDimension loadedCtrl) != #healthy then throw "Cota recarregada não está com integridade saudável."

    -- Renomear nós e confirmar que identidade e integridade são preservadas
    local nodesToRename = AmenoDimensionGraphics.findNodesForDimension savedDimId
    for n in nodesToRename do n.name = "CustomRenamedNode_" + (random 1000 9999 as string)
    if (AmenoDimensionGraphics.findControllers()).count != 1 then throw "Cota perdeu identidade após renomear nós."
    if (AmenoDimensionGraphics.inspectDimension loadedCtrl) != #healthy then throw "Cota perdeu integridade após renomear nós."

    -- Simular exclusão acidental do filho gráfico e executar reparo
    local nodesBeforeDamage = AmenoDimensionGraphics.findNodesForDimension savedDimId
    for n in nodesBeforeDamage where (AmenoDimensionGraphics.readTextProperty n "Ameno.GraphicRole") == "label" do delete n
    if (AmenoDimensionGraphics.inspectDimension loadedCtrl) != #partial then throw "Inspeção deveria acusar estado parcial após exclusão de rótulo."
    local repairResult = AmenoApp.repairDimensions()
    if repairResult != 1 then throw "AmenoApp.repairDimensions deveria ter reparado 1 cota."
    if (AmenoDimensionGraphics.inspectDimension loadedCtrl) != #healthy then throw "Cota deveria estar saudável após o reparo."
    if (AmenoDimensionGraphics.findNodesForDimension savedDimId).count != 3 then throw "Reparo não restaurou a contagem de 3 nós."

    -- Validação de Undo atômico
    resetMaxFile #noPrompt
    AmenoApp.prepareScene()
    local undoBaseline = objects.count
    local undoDim = AmenoDimensionGraphics.createDimension [0, 0, 0] [200, 0, 0] [0, 40, 0]
    if objects.count != (undoBaseline + 3) then throw "Cota para teste de Undo deveria ter criado 3 nós."
    max undo
    if objects.count != undoBaseline then throw "Ctrl+Z não desfez a cota inteira em uma única entrada."

    -- E6 — Valores medidos, arredondados e manuais (Overrides auditáveis e marcador viewport-only)
    resetMaxFile #noPrompt
    AmenoApp.prepareScene()
    local e6Baseline = objects.count
    local dimE6 = AmenoDimensionGraphics.createDimension [0, 0, 0] [20000, 0, 0] [0, 500, 0]
    local ctrlE6 = dimE6.controller
    local dimE6Id = dimE6.dimensionId

    -- 1. Estado inicial medido
    local auditInit = AmenoDimensionGraphics.getDimensionAudit ctrlE6
    if auditInit == undefined then throw "E6: Não foi possível obter audit da cota recém-criada."
    if auditInit.mode != #measured then throw "E6: Modo inicial deveria ser #measured."
    if auditInit.isManual != false then throw "E6: isManual deveria ser false inicialmente."
    if not (AmenoDimensionMath.nearlyEqual auditInit.deltaMillimeters 0.0) then throw "E6: Delta inicial deveria ser 0.0."
    if dimE6.markerNode != undefined then throw "E6: Cota em modo medido não deve possuir markerNode."
    if (AmenoDimensionGraphics.findNodesForDimension dimE6Id).count != 3 then throw "E6: Contagem de nós medidos deveria ser 3."

    -- 2. Alteração para modo numérico manual (20,00m -> 19,60m, delta -0,40m)
    local targetValMm = auditInit.measuredMillimeters - 400.0 -- 19.600 mm
    AmenoDimensionGraphics.setDimensionMode ctrlE6 #manualNumeric manualValueMm:targetValMm reason:"Ajuste executivo"
    local auditManual = AmenoDimensionGraphics.getDimensionAudit ctrlE6
    if auditManual.mode != #manualNumeric then throw "E6: Modo deveria ser #manualNumeric."
    if auditManual.isManual != true then throw "E6: isManual deveria ser true em modo numérico manual."
    if not (AmenoDimensionMath.nearlyEqual auditManual.displayMillimeters targetValMm) then throw "E6: displayMillimeters incorreto após override."
    if not (AmenoDimensionMath.nearlyEqual auditManual.deltaMillimeters -400.0) then throw "E6: deltaMillimeters deveria ser -400.0."
    if auditManual.manualReason != "Ajuste executivo" then throw "E6: manualReason não foi preservado."

    -- Validação do marcador no viewport e isolamento do render
    local manualNodes = AmenoDimensionGraphics.findNodesForDimension dimE6Id
    if manualNodes.count != 4 then throw "E6: Cota manual deveria possuir 4 nós (controller, line, label, marker)."
    local foundMarker = undefined
    local foundLine = undefined
    local foundLabel = undefined
    for n in manualNodes do
    (
        local r = AmenoDimensionGraphics.readTextProperty n "Ameno.GraphicRole"
        if r == "marker" do foundMarker = n
        if r == "lines" do foundLine = n
        if r == "label" do foundLabel = n
    )
    if foundMarker == undefined or not isValidNode foundMarker then throw "E6: Marcador [M] não foi encontrado na cena."
    if foundMarker.renderable != false then throw "E6: CRÍTICO — Marcador [M] deve ter renderable = false para nunca aparecer no render."
    if foundMarker.wirecolor != (color 245 166 35) then throw "E6: Marcador [M] deve ter wirecolor âmbar (245, 166, 35)."
    if foundLine.wirecolor != (color 245 166 35) or foundLabel.wirecolor != (color 245 166 35) then throw "E6: Linha e rótulo devem ter wirecolor âmbar quando manual."
    if (AmenoDimensionGraphics.inspectDimension ctrlE6) != #healthy then throw "E6: Cota manual com marcador deve ser considerada saudável."

    -- 3. Mover geometria e confirmar recálculo de delta mantendo valor manual (regra de ouro)
    local mmPerUnit = AmenoUnitService.currentMillimetersPerSceneUnit()
    local caRec = AmenoDimensionCA.readCA ctrlE6
    caRec.pointB = [21000, 0, 0] -- física alterada para 21000 unidades de cena
    AmenoDimensionCA.applyCA ctrlE6 caRec
    AmenoDimensionGraphics.rebuildDimension ctrlE6

    local expectedMovedMm = 21000.0 * mmPerUnit
    local auditMoved = AmenoDimensionGraphics.getDimensionAudit ctrlE6
    if not (AmenoDimensionMath.nearlyEqual auditMoved.measuredMillimeters expectedMovedMm tolerance:1.0) then throw "E6: Medida física não atualizou após mover ponto."
    if not (AmenoDimensionMath.nearlyEqual auditMoved.displayMillimeters targetValMm) then throw "E6: Valor exibido manual deveria se manter inalterado após mover ponto."
    if not (AmenoDimensionMath.nearlyEqual auditMoved.deltaMillimeters (targetValMm - expectedMovedMm) tolerance:1.0) then throw "E6: Delta não recalculou corretamente após mover geometria."

    -- 4. Persistência de modo manual e audit em arquivo .max
    local tempE6Scene = pathConfig.appendPath tempMaxDir "ameno_e6_test.max"
    deleteFile tempE6Scene
    saveMaxFile tempE6Scene clearNeedSaveFlag:true quiet:true

    resetMaxFile #noPrompt
    loadMaxFile tempE6Scene quiet:true
    deleteFile tempE6Scene
    AmenoApp.refreshDimensions()

    local loadedE6Controllers = AmenoDimensionGraphics.findControllers()
    if loadedE6Controllers.count != 1 then throw "E6: Cota manual persistida não foi encontrada após recarregar cena."
    local loadedE6Ctrl = loadedE6Controllers[1]
    local auditReloaded = AmenoDimensionGraphics.getDimensionAudit loadedE6Ctrl
    if auditReloaded.mode != #manualNumeric then throw "E6: Modo não persistiu como #manualNumeric após load."
    if auditReloaded.isManual != true then throw "E6: isManual não persistiu como true após load."
    if auditReloaded.manualReason != "Ajuste executivo" then throw "E6: Motivo manual não persistiu após load."
    local reloadedNodes = AmenoDimensionGraphics.findNodesForDimension (AmenoDimensionGraphics.getDimensionId loadedE6Ctrl)
    if reloadedNodes.count != 4 then throw "E6: Cota recarregada deveria possuir 4 nós."
    for n in reloadedNodes where (AmenoDimensionGraphics.readTextProperty n "Ameno.GraphicRole") == "marker" do
    (
        if n.renderable != false then throw "E6: Marcador recarregado perdeu renderable = false."
    )

    -- 5. Restauração para valor medido (resetDimensionToMeasured)
    AmenoDimensionGraphics.resetDimensionToMeasured loadedE6Ctrl
    local auditReset = AmenoDimensionGraphics.getDimensionAudit loadedE6Ctrl
    if auditReset.mode != #measured then throw "E6: Modo após reset deveria ser #measured."
    if auditReset.isManual != false then throw "E6: isManual após reset deveria ser false."
    if not (AmenoDimensionMath.nearlyEqual auditReset.deltaMillimeters 0.0) then throw "E6: Delta após reset deveria ser 0.0."
    local nodesAfterReset = AmenoDimensionGraphics.findNodesForDimension (AmenoDimensionGraphics.getDimensionId loadedE6Ctrl)
    if nodesAfterReset.count != 3 then throw "E6: Nós após reset para medido deveriam ser 3 (marcador removido)."

    -- 6. Modo arredondado
    AmenoDimensionGraphics.setDimensionMode loadedE6Ctrl #rounded incrementMm:100.0 -- arredondar para cada 10 cm
    local auditRounded = AmenoDimensionGraphics.getDimensionAudit loadedE6Ctrl
    if auditRounded.mode != #rounded then throw "E6: Modo deveria ser #rounded."

    -- 7. Desfazer alteração com Undo do 3ds Max
    max undo
    local auditAfterUndo = AmenoDimensionGraphics.getDimensionAudit loadedE6Ctrl
    if auditAfterUndo.mode != #measured then throw "E6: Undo não reverteu a mudança de modo para #measured."

    fileIn macroPath quiet:true

    format "[AMENO_TEST][PASS] Bootstrap %, renderer %, preparação de cena, E2, E3, E4, E5 e E6 aprovadas.\n" AmenoVersion.appVersion AmenoApp.rendererInfo.displayName
)
