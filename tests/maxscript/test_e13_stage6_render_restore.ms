/*
    E13 etapa 6 — render explícito e restauração transacional.
    O adapter injetado evita depender de uma renderização real para testar
    sucesso, cancelamento, exceção, câmera e restauração do estado da cena.
*/

(
    global AmenoApp
    global AmenoDimensionGraphics
    global AmenoDimensionTerminalMesh
    global AmenoRenderCotasService
    global AmenoAdapterRenderResult
    global AmenoOutputVerification
    global AmenoSceneSetup
    global AmenoStyleService

    struct AmenoE13Stage6Adapter
    (
        mode = #success,
        seenCamera = undefined,
        watchNode = undefined,
        seenWatchRenderable = undefined,
        configureCount = 0,
        restoreCount = 0,

        fn validate request =
        (
            if mode == #validateFailure then throw "Falha simulada na validação do adapter."
            true
        ),

        fn captureState = #stage6AdapterState,

        fn configureOutput request =
        (
            configureCount += 1
            true
        ),

        fn createAnnotationMaterial colorValue:(color 245 245 245) =
        (
            local mtl = standardMaterial name:(uniqueName "AMENO_E13_STAGE6_MTL_")
            mtl.diffuse = colorValue
            mtl
        ),

        fn renderOverlay request =
        (
            seenCamera = request.cameraNode
            if watchNode != undefined and isValidNode watchNode do
                try (seenWatchRenderable = watchNode.renderable) catch ()
            if mode == #renderFailure then throw "Falha simulada durante o render."
            AmenoAdapterRenderResult cancelled:(mode == #cancel)
        ),

        fn verifyOutput request =
        (
            if mode == #verifyFailure then
                AmenoOutputVerification valid:false errorMessage:"Falha simulada na verificação do PNG."
            else
                AmenoOutputVerification valid:true width:request.width height:request.height hasAlpha:true
        ),

        fn restore state =
        (
            restoreCount += 1
            if mode == #restoreFailure then throw "Falha simulada ao restaurar o adapter."
            true
        )
    )

    local testFile = getSourceFileName()
    local testPath = getFilenamePath testFile
    local worktreeRoot = pathConfig.normalizePath (pathConfig.appendPath testPath @"..\..")
    local bootstrapPath = pathConfig.normalizePath (pathConfig.appendPath worktreeRoot @"Contents\scripts\startup\ameno_bootstrap.ms")

    resetMaxFile #noPrompt
    if doesFileExist bootstrapPath then
        fileIn bootstrapPath quiet:true
    else
        throw ("bootstrap nao encontrado: " + bootstrapPath)

    local passed = 0
    local failed = 0
    local errors = #()

    fn check label conditionValue =
    (
        if conditionValue == true then
        (
            passed += 1
            format "[AMENO_TEST][PASS] %\n" label
        )
        else
        (
            failed += 1
            append errors label
            format "[AMENO_TEST][FAIL] %\n" label
        )
    )

    fn validNode nodeValue =
    (
        nodeValue != undefined and (try (isValidNode nodeValue) catch false)
    )

    fn nodeStateMatches nodeValue renderableValue hiddenValue renderByLayerValue materialValue =
    (
        if not (validNode nodeValue) then false
        else
        (
            local materialMatches = try (nodeValue.material == materialValue) catch (materialValue == undefined)
            local renderableMatches = try (nodeValue.renderable == renderableValue) catch true
            local hiddenMatches = try (nodeValue.isHidden == hiddenValue) catch true
            local layerMatches = try (nodeValue.renderByLayer == renderByLayerValue) catch true
            materialMatches and renderableMatches and hiddenMatches and layerMatches
        )
    )

    fn terminalCount nodes =
    (
        local count = 0
        for nodeValue in nodes where (validNode nodeValue) do
            if (try (::AmenoDimensionTerminalMesh.isTerminal nodeValue) catch false) do count += 1
        count
    )

    fn restoreCheck userNode userRenderable userHidden userRenderByLayer userMaterial dimensionLayer layerOn layerHidden layerRenderable targetNodes targetMaterials =
    (
        local ok = nodeStateMatches userNode userRenderable userHidden userRenderByLayer userMaterial
        ok = ok and (dimensionLayer.on == layerOn and dimensionLayer.ishidden == layerHidden and dimensionLayer.renderable == layerRenderable)
        for indexValue = 1 to targetNodes.count while ok do
        (
            local targetNode = targetNodes[indexValue]
            local targetMaterial = targetMaterials[indexValue]
            if not (try (targetNode.material == targetMaterial) catch (targetMaterial == undefined)) do ok = false
        )
        ok
    )

    check "serviço de render e resultado carregados" (::AmenoRenderCotasService != undefined and AmenoAdapterRenderResult != undefined)
    ::AmenoApp.prepareScene()

    local style = ::AmenoStyleService.getStyle "technical"
    local dimension = ::AmenoDimensionGraphics.createDimension [0, 0, 0] [180, 0, 0] [90, 40, 0] role:"stage6" styleId:"technical" style:style useUndo:false
    local userNode = box name:"E13_STAGE6_USER_GEOMETRY" length:40 width:30 height:20 pos:[0, 0, -10]
    local cameraTarget = targetObject name:"E13_STAGE6_CAMERA_TARGET" pos:[90, 0, 0]
    local cameraNode = targetCamera name:"E13_STAGE6_CAMERA" pos:[90, -20, 250] target:cameraTarget
    cameraNode.orthoProjection = true

    local targetNodes = ::AmenoRenderCotasService.collectTargetNodes #all
    local targetMaterials = #()
    local targetRoles = #()
    local terminalRoleCount = 0
    for targetNode in targetNodes where (validNode targetNode) do
    (
        append targetMaterials (try (targetNode.material) catch (undefined))
        local roleValue = ::AmenoDimensionGraphics.readTextProperty targetNode "Ameno.GraphicRole"
        append targetRoles roleValue
        if roleValue == "terminal" do terminalRoleCount += 1
    )
    local terminalTargets = terminalCount targetNodes
    local targetRoleOk = ((findItem targetRoles "lines") > 0 and (findItem targetRoles "label") > 0 and terminalRoleCount == 2)
    check "escopo de render inclui linhas, texto e os dois terminais" (dimension != undefined and targetNodes.count == 4 and terminalTargets == 2 and targetRoleOk)

    local originalUserRenderable = userNode.renderable
    local originalUserHidden = userNode.isHidden
    local originalUserRenderByLayer = userNode.renderByLayer
    local originalUserMaterial = userNode.material
    local dimensionsLayer = (::AmenoSceneSetup.inspect()).dimensionsLayer
    local originalCurrentLayer = LayerManager.current
    local outputPath = pathConfig.normalizePath (pathConfig.appendPath (getDir #temp) "ameno_e13_stage6_render.png")
    deleteFile outputPath

    local request = ::AmenoRenderCotasService.createRequest outputPath:outputPath selectionMode:#all overwrite:true cameraNode:cameraNode
    request.width = 320
    request.height = 180
    request.pixelAspect = 1.0
    check "pedido usa somente cotas por padrão" (request.dimensionsOnly == true)

    -- Isolate Selection: o serviço deve bloquear antes de tocar no adapter ou
    -- na cena. Renderizar sobre esse estado causou acesso inválido no Corona 15.
    select userNode
    local enteredIsolate = try (IsolateSelection.EnterIsolateSelectionMode()) catch (false)
    local isolateAdapter = AmenoE13Stage6Adapter mode:#success
    local isolateResult = ::AmenoRenderCotasService.renderDimensions request adapter:isolateAdapter
    check "preflight reconhece Isolate Selection ativo" (enteredIsolate and ::AmenoRenderCotasService.isolateSelectionActive())
    check "Isolate Selection bloqueia render antes do adapter" (not isolateResult.success and (matchPattern isolateResult.errorMessage pattern:"*Isolate Selection*") and isolateAdapter.configureCount == 0 and isolateAdapter.restoreCount == 0 and not ::AmenoRenderCotasService.isRendering)
    check "bloqueio preserva Isolate Selection e estado da cena" (::AmenoRenderCotasService.isolateSelectionActive() and nodeStateMatches userNode originalUserRenderable originalUserHidden originalUserRenderByLayer originalUserMaterial)
    try (IsolateSelection.ExitIsolateSelectionMode()) catch ()
    check "teste encerra Isolate Selection antes dos demais cenários" (not ::AmenoRenderCotasService.isolateSelectionActive())

    -- Sucesso: a câmera explícita chega ao adapter e o isolamento é totalmente desfeito.
    dimensionsLayer.on = false
    dimensionsLayer.ishidden = true
    dimensionsLayer.renderable = false
    local successAdapter = AmenoE13Stage6Adapter mode:#success watchNode:userNode
    local successResult = ::AmenoRenderCotasService.renderDimensions request adapter:successAdapter
    check "render bem sucedido retorna alpha e resolução" (successResult.success and not successResult.cancelled and successResult.hasAlpha and successResult.width == 320 and successResult.height == 180)
    check "câmera explícita é encaminhada sem trocar viewport" (successAdapter.seenCamera == cameraNode)
    check "sucesso restaura geometria, materiais e layer" (restoreCheck userNode originalUserRenderable originalUserHidden originalUserRenderByLayer originalUserMaterial dimensionsLayer false true false targetNodes targetMaterials and LayerManager.current == originalCurrentLayer)
    check "adapter é restaurado uma vez após sucesso" (successAdapter.restoreCount == 1 and successAdapter.configureCount == 1 and not ::AmenoRenderCotasService.isRendering)
    check "modo somente cotas exclui a geometria comum durante o passe" (successAdapter.seenWatchRenderable == false)

    -- Caixa desmarcada: preserva a geometria comum e adiciona as cotas.
    request.dimensionsOnly = false
    dimensionsLayer.on = false
    dimensionsLayer.ishidden = true
    dimensionsLayer.renderable = false
    local sceneAdapter = AmenoE13Stage6Adapter mode:#success watchNode:userNode
    local sceneResult = ::AmenoRenderCotasService.renderDimensions request adapter:sceneAdapter
    check "modo cena mais cotas mantém geometria comum renderizável" (sceneResult.success and sceneAdapter.seenWatchRenderable == originalUserRenderable)
    check "modo cena mais cotas também restaura cena e adapter" (restoreCheck userNode originalUserRenderable originalUserHidden originalUserRenderByLayer originalUserMaterial dimensionsLayer false true false targetNodes targetMaterials and sceneAdapter.restoreCount == 1)
    request.dimensionsOnly = true

    -- Cancelamento: o resultado é explícito e também deixa a cena original.
    dimensionsLayer.on = false
    dimensionsLayer.ishidden = true
    dimensionsLayer.renderable = false
    local cancelAdapter = AmenoE13Stage6Adapter mode:#cancel
    local cancelResult = ::AmenoRenderCotasService.renderDimensions request adapter:cancelAdapter
    check "cancelamento retorna estado cancelado" (not cancelResult.success and cancelResult.cancelled and cancelResult.errorMessage != "")
    check "cancelamento restaura a cena antes de retornar" (restoreCheck userNode originalUserRenderable originalUserHidden originalUserRenderByLayer originalUserMaterial dimensionsLayer false true false targetNodes targetMaterials)
    check "cancelamento restaura o adapter e libera a trava" (cancelAdapter.restoreCount == 1 and not ::AmenoRenderCotasService.isRendering)

    -- Exceção durante render: não há sucesso falso e todo estado é recuperado.
    dimensionsLayer.on = false
    dimensionsLayer.ishidden = true
    dimensionsLayer.renderable = false
    local renderFailureAdapter = AmenoE13Stage6Adapter mode:#renderFailure
    local renderFailureResult = ::AmenoRenderCotasService.renderDimensions request adapter:renderFailureAdapter
    check "exceção do render é reportada" (not renderFailureResult.success and not renderFailureResult.cancelled and (matchPattern renderFailureResult.errorMessage pattern:"*render*") and renderFailureResult.errorMessage != "")
    check "exceção do render restaura a cena" (restoreCheck userNode originalUserRenderable originalUserHidden originalUserRenderByLayer originalUserMaterial dimensionsLayer false true false targetNodes targetMaterials)
    check "exceção do render restaura adapter e libera a trava" (renderFailureAdapter.restoreCount == 1 and not ::AmenoRenderCotasService.isRendering)

    -- Falha do adapter durante a restauração não é escondida.
    dimensionsLayer.on = false
    dimensionsLayer.ishidden = true
    dimensionsLayer.renderable = false
    local restoreFailureAdapter = AmenoE13Stage6Adapter mode:#restoreFailure
    local restoreFailureResult = ::AmenoRenderCotasService.renderDimensions request adapter:restoreFailureAdapter
    check "falha de restauração é anunciada" (not restoreFailureResult.success and (matchPattern restoreFailureResult.errorMessage pattern:"*Falha de restauração*") and (matchPattern restoreFailureResult.errorMessage pattern:"*adapter*"))
    check "falha de restauração não deixa a trava ativa" (restoreFailureAdapter.restoreCount == 1 and not ::AmenoRenderCotasService.isRendering)

    -- Verificação inválida também é transacional e não cria arquivo fantasma.
    dimensionsLayer.on = false
    dimensionsLayer.ishidden = true
    dimensionsLayer.renderable = false
    local verifyFailureAdapter = AmenoE13Stage6Adapter mode:#verifyFailure
    local verifyFailureResult = ::AmenoRenderCotasService.renderDimensions request adapter:verifyFailureAdapter
    check "PNG inválido retorna falha explícita" (not verifyFailureResult.success and not verifyFailureResult.cancelled and verifyFailureResult.errorMessage != "")
    check "PNG inválido restaura cena e adapter" (restoreCheck userNode originalUserRenderable originalUserHidden originalUserRenderByLayer originalUserMaterial dimensionsLayer false true false targetNodes targetMaterials and verifyFailureAdapter.restoreCount == 1 and not ::AmenoRenderCotasService.isRendering)

    -- Validação ocorre antes do isolamento e ainda libera a trava.
    local validateFailureAdapter = AmenoE13Stage6Adapter mode:#validateFailure
    local validateFailureResult = ::AmenoRenderCotasService.renderDimensions request adapter:validateFailureAdapter
    check "falha de validação não isola a cena" (not validateFailureResult.success and validateFailureResult.errorMessage != "" and restoreCheck userNode originalUserRenderable originalUserHidden originalUserRenderByLayer originalUserMaterial dimensionsLayer false true false targetNodes targetMaterials)
    check "falha de validação não chama restauração parcial nem prende o serviço" (validateFailureAdapter.restoreCount == 1 and not ::AmenoRenderCotasService.isRendering)

    -- O arquivo não deve ser criado pelos adapters simulados em nenhum caminho.
    check "adapters simulados não deixam PNG residual" (not doesFileExist outputPath)

    if validNode dimension.controller do ::AmenoDimensionGraphics.removeDimension dimension.dimensionId
    if validNode userNode do delete userNode
    if validNode cameraNode do delete cameraNode
    if validNode cameraTarget do delete cameraTarget
    deleteFile outputPath

    format "\n[AMENO_TEST] Resultado etapa 6: % passou(aram), % falhou(aram)\n" passed failed
    if failed == 0 then
        format "[AMENO_TEST][PASS] E13 etapa 6 passou.\n"
    else
    (
        format "[AMENO_TEST][FAIL] Falhas etapa 6: %\n" (errors as string)
        throw ("E13 etapa 6 falhou: " + (failed as string))
    )
)
