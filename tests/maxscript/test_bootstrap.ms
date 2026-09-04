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
global AmenoStyleService
global AmenoStyleRecord
global AmenoAnchorService

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
    if AmenoAnchorService == undefined then throw "Serviço de âncoras E8 não foi carregado pelo bootstrap."

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

    -- E7 — Sistema de Estilos Visuais e Editor
    resetMaxFile #noPrompt
    AmenoApp.prepareScene()
    if AmenoStyleService == undefined then throw "E7: AmenoStyleService não foi carregado."

    local defaultStyles = AmenoStyleService.listStyles()
    if defaultStyles.count < 3 then throw "E7: Deveriam existir pelo menos 3 presets padrão de estilo."
    local archStyle = AmenoStyleService.getStyle "default"
    local editStyle = AmenoStyleService.getStyle "editorial"
    local techStyle = AmenoStyleService.getStyle "technical"

    if archStyle.name != "Arquitetônico" or archStyle.terminalType != #tick then throw "E7: Preset Arquitetônico incorreto."
    if editStyle.name != "Editorial" or editStyle.terminalType != #dot then throw "E7: Preset Editorial incorreto."
    if techStyle.name != "Técnico" or techStyle.terminalType != #arrowClosed then throw "E7: Preset Técnico incorreto."

    -- 1. Criação de cotas com os 5 tipos de terminais
    local dimTick = AmenoDimensionGraphics.createDimension [0, 0, 0] [100, 0, 0] [0, 20, 0] styleId:"default"
    if dimTick.lineNode.render_thickness != archStyle.lineThickness then throw "E7: Espessura da linha não corresponde ao estilo."

    local arrowClosedStyle = AmenoStyleRecord styleId:"t_arrowC" terminalType:#arrowClosed terminalSize:16.0 lineThickness:1.2
    local arrowOpenStyle = AmenoStyleRecord styleId:"t_arrowO" terminalType:#arrowOpen terminalSize:16.0 lineThickness:1.2
    local dotStyle = AmenoStyleRecord styleId:"t_dot" terminalType:#dot terminalSize:8.0 lineThickness:1.0
    local noneStyle = AmenoStyleRecord styleId:"t_none" terminalType:#none terminalSize:0.0 lineThickness:0.8

    AmenoStyleService.saveStyle arrowClosedStyle
    AmenoStyleService.saveStyle arrowOpenStyle
    AmenoStyleService.saveStyle dotStyle
    AmenoStyleService.saveStyle noneStyle

    local dimArrowC = AmenoDimensionGraphics.createDimension [0, 50, 0] [100, 50, 0] [0, 70, 0] styleId:"t_arrowC"
    local dimArrowO = AmenoDimensionGraphics.createDimension [0, 100, 0] [100, 100, 0] [0, 120, 0] styleId:"t_arrowO"
    local dimDot = AmenoDimensionGraphics.createDimension [0, 150, 0] [100, 150, 0] [0, 170, 0] styleId:"t_dot"
    local dimNone = AmenoDimensionGraphics.createDimension [0, 200, 0] [100, 200, 0] [0, 220, 0] styleId:"t_none"

    if (numSplines dimArrowC.lineNode) < 5 then throw "E7: Spline com setas fechadas deveria possuir as splines dos terminais."
    if (numSplines dimArrowO.lineNode) < 5 then throw "E7: Spline com setas abertas deveria possuir as splines dos terminais."
    if (numSplines dimDot.lineNode) < 5 then throw "E7: Spline com pontos em losango deveria possuir as splines dos terminais."
    if (numSplines dimNone.lineNode) != 3 then throw "E7: Cota sem terminais (#none) deveria possuir exatamente 3 splines (extA, extB, cota)."

    -- 2. Propriedades de tipografia no TextPlus
    if dimTick.textNode.size != archStyle.fontSize then throw "E7: Tamanho do TextPlus não corresponde ao estilo."

    -- 3. Atualização de estilo em lote com Undo atômico
    local batchStyle = AmenoStyleRecord styleId:"batch_test" name:"Batch Test" fontSize:18.0 lineThickness:1.0 terminalType:#tick terminalSize:10.0
    AmenoStyleService.saveStyle batchStyle

    local batchDim1 = AmenoDimensionGraphics.createDimension [0, 300, 0] [200, 300, 0] [0, 330, 0] styleId:"batch_test"
    local batchDim2 = AmenoDimensionGraphics.createDimension [0, 400, 0] [200, 400, 0] [0, 430, 0] styleId:"batch_test"

    if (AmenoStyleService.countDimensionsUsingStyle "batch_test") != 2 then throw "E7: Contagem de cotas usando o estilo incorreta."

    -- Modificar propriedades do estilo (espessura 1.0 -> 2.5, tamanho 18.0 -> 28.0)
    batchStyle.lineThickness = 2.5
    batchStyle.fontSize = 28.0
    local updatedBatchCount = AmenoStyleService.updateStyleAndRebuild batchStyle
    if updatedBatchCount != 2 then throw "E7: Atualização em lote deveria ter reconstruído 2 cotas."

    local reloadedNodes1 = AmenoDimensionGraphics.findNodesForDimension batchDim1.dimensionId
    local foundLine1 = undefined
    local foundText1 = undefined
    for n in reloadedNodes1 do
    (
        if (AmenoDimensionGraphics.readTextProperty n "Ameno.GraphicRole") == "lines" do foundLine1 = n
        if (AmenoDimensionGraphics.readTextProperty n "Ameno.GraphicRole") == "label" do foundText1 = n
    )
    if foundLine1 == undefined or foundLine1.render_thickness != 2.5 then throw "E7: Cota 1 não assumiu nova espessura após atualização em lote."
    if foundText1 == undefined or foundText1.size != 28.0 then throw "E7: Cota 1 não assumiu novo tamanho após atualização em lote."

    -- Testar Undo atômico da atualização em lote
    max undo
    local lineAfterUndo = undefined
    for n in (AmenoDimensionGraphics.findNodesForDimension batchDim1.dimensionId) do
    (
        if (AmenoDimensionGraphics.readTextProperty n "Ameno.GraphicRole") == "lines" do lineAfterUndo = n
    )
    if lineAfterUndo != undefined and lineAfterUndo.render_thickness != 1.0 then throw "E7: Undo atômico não reverteu a espessura para 1.0."

    -- 4. Persistência de Estilos de Cena no arquivo .max
    local customSavedStyle = AmenoStyleService.saveAsNewStyle "Persistido_Max" batchStyle
    local tempE7Scene = pathConfig.appendPath tempMaxDir "ameno_e7_test.max"
    deleteFile tempE7Scene
    saveMaxFile tempE7Scene clearNeedSaveFlag:true quiet:true

    resetMaxFile #noPrompt
    loadMaxFile tempE7Scene quiet:true
    deleteFile tempE7Scene
    AmenoStyleService.loadFromScene()

    local loadedCustom = AmenoStyleService.getStyle customSavedStyle.styleId
    if loadedCustom == undefined or loadedCustom.name != "Persistido_Max" then throw "E7: Estilo customizado não persistiu no arquivo .max."

    -- 5. Testar abertura do editor visual e sincronização de UI
    AmenoShowStyleEditor()
    if AmenoStyleEditorRollout == undefined or not AmenoStyleEditorRollout.open then throw "E7: Editor de Estilos não abriu corretamente."

    -- Testar sincronização automática de estilo pela seleção
    AmenoStyleEditorRollout.syncToStyleId "editorial"
    if AmenoStyleEditorRollout.ddlStyles.selection == 0 then throw "E7: syncToStyleId falhou."

    -- Testar aplicação de UI ao vivo
    AmenoStyleEditorRollout.spnFontSize.value = 32.0
    AmenoStyleEditorRollout.applyCurrentUIToScene autoRebuild:true
    local editedArch = AmenoStyleService.getStyle "editorial"
    if editedArch.fontSize != 32.0 then throw "E7: applyCurrentUIToScene não atualizou fontSize."

    destroyDialog AmenoStyleEditorRollout

    -- 6. Testar aplicação de estilo à seleção e diretamente ao controlador
    local dimSelTest = AmenoDimensionGraphics.createDimension [0, 0, 0] [150, 0, 0] [0, 30, 0] styleId:"default"
    if dimSelTest.lineNode.render_displayRenderMesh != true then throw "E7: render_displayRenderMesh deve ser true para espessura visível no viewport."
    if dimSelTest.lineNode.render_useViewportSettings != false then throw "E7: render_useViewportSettings deve ser false."

    select #(dimSelTest.lineNode, dimSelTest.textNode)
    local appliedSelCount = AmenoStyleService.applyStyleToSelection "editorial"
    if appliedSelCount != 1 then throw "E7: Aplicação de estilo à seleção falhou."
    local auditApplied = AmenoDimensionGraphics.getDimensionAudit dimSelTest.controller
    local recAfterSel = AmenoDimensionCA.readCA dimSelTest.controller
    if recAfterSel.styleId != "editorial" then throw "E7: Estilo após applyStyleToSelection não é editorial."

    -- Testar preservação de seleção ao reconstruir
    if selection.count == 0 then throw "E7: Seleção foi perdida durante o rebuild da cota."

    AmenoStyleService.applyStyleToDimension dimSelTest.controller "technical"
    local recAfterCtrl = AmenoDimensionCA.readCA dimSelTest.controller
    if recAfterCtrl.styleId != "technical" then throw "E7: Estilo após applyStyleToDimension não é technical."

    -- E8 — Âncoras Geométricas, Reatividade, Cotas Órfãs e Diagnóstico
    resetMaxFile #noPrompt
    AmenoApp.prepareScene()
    if AmenoAnchorService == undefined then throw "E8: AmenoAnchorService não está disponível."

    -- 1. Criação de nós e cota associativa
    local boxA = box name:"Wall_A" pos:[0, 0, 0] width:20 length:20 height:50
    local boxB = box name:"Wall_B" pos:[200, 0, 0] width:20 length:20 height:50
    local dimE8 = AmenoDimensionGraphics.createDimension [0, 0, 0] [200, 0, 0] [0, 40, 0] nodeA:boxA nodeB:boxB
    local ctrlE8 = dimE8.controller
    local dimE8Id = dimE8.dimensionId

    local caE8 = AmenoDimensionCA.readCA ctrlE8
    if caE8.anchorType != "both" then throw "E8: anchorType deveria ser both."
    if caE8.nodeA != boxA or caE8.nodeB != boxB then throw "E8: Referências aos nós de ancoragem incorretas."
    if caE8.isOrphan != false then throw "E8: Cota recém-criada não deve ser órfã."

    local auditE8 = AmenoDimensionGraphics.getDimensionAudit ctrlE8
    if auditE8.anchorDesc != "Wall_A · Wall_B" then throw ("E8: anchorDesc incorreto: " + auditE8.anchorDesc)
    if not (AmenoDimensionMath.nearlyEqual auditE8.measuredMillimeters (200.0 * AmenoUnitService.currentMillimetersPerSceneUnit())) then throw "E8: Medida inicial da cota ancorada incorreta."

    -- 2. Movimentação de nó e sincronização reativa
    boxB.pos = [300, 0, 0]
    local syncRes = AmenoAnchorService.syncDimension ctrlE8
    if not syncRes then throw "E8: syncDimension deveria ter retornado true após mover boxB."

    local auditMoved = AmenoDimensionGraphics.getDimensionAudit ctrlE8
    if not (AmenoDimensionMath.nearlyEqual auditMoved.measuredMillimeters (300.0 * AmenoUnitService.currentMillimetersPerSceneUnit())) then throw "E8: Cota não atualizou medida após mover o nó B."

    -- 3. Rotação de nó e integridade
    rotate boxA (angleaxis 90 [0, 0, 1])
    AmenoAnchorService.syncAll()
    if (AmenoDimensionGraphics.inspectDimension ctrlE8) != #healthy then throw "E8: Integridade da cota danificada após rotacionar nó A."

    -- 4. Selecionar nós âncoras
    local selOk = AmenoAnchorService.selectAnchors ctrlE8
    if not selOk or selection.count != 2 then throw "E8: selectAnchors falhou ao selecionar os 2 nós associados."

    -- 5. Deleção de nó (resiliência a cota órfã)
    delete boxB
    AmenoAnchorService.syncAll()

    local caOrphan = AmenoDimensionCA.readCA ctrlE8
    if caOrphan.isOrphan != true then throw "E8: Cota deveria ter sido marcada como órfã após deleção de nó."
    if (AmenoDimensionGraphics.findNodesForDimension dimE8Id).count != 3 then throw "E8: Cota sumiu da cena após exclusão de objeto de referência!"

    local auditOrphan = AmenoDimensionGraphics.getDimensionAudit ctrlE8
    if auditOrphan.isOrphan != true then throw "E8: Audit da cota órfã não marcou isOrphan."
    if (findString auditOrphan.anchorDesc "[ÓRFÃ]") == undefined then throw "E8: Descrição da âncora órfã deveria conter [ÓRFÃ]."

    local orphanLineNode = undefined
    for n in (AmenoDimensionGraphics.findNodesForDimension dimE8Id) do
    (
        if (AmenoDimensionGraphics.readTextProperty n "Ameno.GraphicRole") == "lines" do orphanLineNode = n
    )
    if orphanLineNode == undefined or orphanLineNode.wirecolor != (color 230 70 70) then throw "E8: Cota órfã deveria assumir wirecolor de alerta (230, 70, 70)."

    -- 6. Reancoragem manual para novo objeto
    local boxC = box name:"Wall_C" pos:[400, 0, 0] width:20 length:20 height:50
    AmenoAnchorService.reanchorDimension ctrlE8 #pointB boxC [400, 0, 0]

    local caRecovered = AmenoDimensionCA.readCA ctrlE8
    if caRecovered.isOrphan != false then throw "E8: Cota continuou órfã após reancorar ponto B."
    if caRecovered.nodeB != boxC then throw "E8: Nó B não foi atualizado para Wall_C."

    local auditRecovered = AmenoDimensionGraphics.getDimensionAudit ctrlE8
    if auditRecovered.anchorDesc != "Wall_A · Wall_C" then throw ("E8: anchorDesc após recuperação incorreto: " + auditRecovered.anchorDesc)
    if not (AmenoDimensionMath.nearlyEqual auditRecovered.measuredMillimeters (400.0 * AmenoUnitService.currentMillimetersPerSceneUnit())) then throw "E8: Medida após reancorar incorreta."

    -- 7. Reparo em lote de órfãs (repairOrphans)
    delete #(boxA, boxC)
    AmenoAnchorService.syncAll()
    if (AmenoDimensionCA.readCA ctrlE8).isOrphan != true then throw "E8: Cota deveria ser órfã após deletar todos os nós."

    local repairedOrphansCount = AmenoAnchorService.repairOrphans()
    if repairedOrphansCount != 1 then throw "E8: repairOrphans deveria ter reparado 1 cota."

    local caRepaired = AmenoDimensionCA.readCA ctrlE8
    if caRepaired.isOrphan != false or caRepaired.anchorType != "world" then throw "E8: Cota reparada não foi convertida para mundial."
    local auditRepaired = AmenoDimensionGraphics.getDimensionAudit ctrlE8
    if not (AmenoDimensionMath.nearlyEqual auditRepaired.measuredMillimeters (400.0 * AmenoUnitService.currentMillimetersPerSceneUnit())) then throw "E8: Medida mundial não foi preservada durante o reparo de órfãs."

    -- 8. Persistência de âncoras no arquivo .max
    local boxD = box name:"Wall_D" pos:[50, 50, 0]
    local boxE = box name:"Wall_E" pos:[250, 50, 0]
    local dimPersist = AmenoDimensionGraphics.createDimension [50, 50, 0] [250, 50, 0] [50, 80, 0] nodeA:boxD nodeB:boxE
    local persistId = dimPersist.dimensionId

    local tempE8Scene = pathConfig.appendPath tempMaxDir "ameno_e8_test.max"
    deleteFile tempE8Scene
    saveMaxFile tempE8Scene clearNeedSaveFlag:true quiet:true

    resetMaxFile #noPrompt
    loadMaxFile tempE8Scene quiet:true
    deleteFile tempE8Scene
    AmenoApp.refreshDimensions()

    local loadedE8Ctrl = undefined
    for c in (AmenoDimensionGraphics.findControllers()) do
    (
        if (AmenoDimensionGraphics.getDimensionId c) == persistId do loadedE8Ctrl = c
    )
    if loadedE8Ctrl == undefined then throw "E8: Cota ancorada persistida não foi encontrada após load."
    local caLoadedE8 = AmenoDimensionCA.readCA loadedE8Ctrl
    if caLoadedE8.anchorType != "both" then throw "E8: anchorType não persistiu como both no arquivo .max."
    if caLoadedE8.nodeA == undefined or caLoadedE8.nodeB == undefined then throw "E8: Referências aos nós foram perdidas após load."
    if caLoadedE8.nodeA.name != "Wall_D" or caLoadedE8.nodeB.name != "Wall_E" then throw "E8: Nomes dos nós carregados incorretos."
    if caLoadedE8.isOrphan != false then throw "E8: Cota válida foi incorretamente marcada como órfã no load."

    -- 9. Garantia Pré-Render (#preRender)
    caLoadedE8.nodeB.pos = [350, 50, 0]
    AmenoAnchorService.onPreRender()

    local auditPreRender = AmenoDimensionGraphics.getDimensionAudit loadedE8Ctrl
    if not (AmenoDimensionMath.nearlyEqual auditPreRender.measuredMillimeters (300.0 * AmenoUnitService.currentMillimetersPerSceneUnit())) then throw "E8: Hook #preRender não sincronizou a cota antes do render."

    -- 10. Teste de escalabilidade com 100 cotas ativas
    local benchmarkBoxes = #()
    for i = 1 to 101 do
    (
        append benchmarkBoxes (box pos:[(i * 10), 500, 0] width:5 length:5 height:5)
    )
    for i = 1 to 100 do
    (
        AmenoDimensionGraphics.createDimension [(i * 10), 500, 0] [((i + 1) * 10), 500, 0] [(i * 10), 520, 0] nodeA:benchmarkBoxes[i] nodeB:benchmarkBoxes[i+1]
    )

    for b in benchmarkBoxes do b.pos.y += 10.0
    local startTime = timestamp()
    local syncedBatch = AmenoAnchorService.syncAll()
    local elapsed = (timestamp() - startTime) / 1000.0
    format "E8: Sincronizadas % cotas em % segundos.\n" syncedBatch elapsed
    if syncedBatch < 100 then throw "E8: syncAll não sincronizou todas as 100 cotas em lote."

    fileIn macroPath quiet:true

    format "[AMENO_TEST][PASS] Bootstrap %, renderer %, preparação de cena, E2, E3, E4, E5, E6, E7 e E8 aprovadas.\n" AmenoVersion.appVersion AmenoApp.rendererInfo.displayName
)
