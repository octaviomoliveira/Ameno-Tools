global AmenoRenderCotasService
global AmenoRenderCotasRequest
global AmenoRenderCotasResult

struct AmenoRenderCotasRequest
(
    outputPath = "",
    selectionMode = #all,
    overwrite = false,
    frame = #current,
    width = 0,
    height = 0,
    pixelAspect = 1.0,
    renderType = #normal
)

struct AmenoRenderCotasResult
(
    success = false,
    cancelled = false,
    outputPath = "",
    width = 0,
    height = 0,
    hasAlpha = false,
    nodeCount = 0,
    selectionMode = #all,
    elapsedSeconds = 0.0,
    errorMessage = ""
)

struct AmenoRenderNodeState
(
    node = undefined,
    renderable = true,
    isHidden = false,
    renderByLayer = true,
    primaryVisibility = true,
    hasMaterial = false,
    material = undefined
)

struct AmenoRenderLayerState
(
    layer = undefined,
    layerOn = true,
    isHidden = false,
    renderable = true,
    primaryVisibility = true,
    visibility = 1.0
)

struct AmenoRenderSceneState
(
    nodes = #(),
    layers = #(),
    currentLayer = undefined
)

struct AmenoRenderCotasServiceDefinition
(
    isRendering = false,
    lastOutputPath = "",

    fn frameNumberFromTime frameValue =
    (
        if frameValue == #current then
            ((currentTime as integer) / ticksPerFrame) as integer
        else
            ((frameValue as integer) / ticksPerFrame) as integer
    ),

    fn padNumber value digits =
    (
        local negative = value < 0
        local textValue = (abs value) as string
        while textValue.count < digits do textValue = "0" + textValue
        if negative then "-" + textValue else textValue
    ),

    fn defaultOutputDirectory =
    (
        local targetDirectory = maxFilePath
        if targetDirectory == undefined or targetDirectory == "" do
        (
            try (targetDirectory = getDir #renderoutput) catch ()
        )
        if targetDirectory == undefined or targetDirectory == "" do targetDirectory = getDir #temp
        pathConfig.normalizePath targetDirectory
    ),

    fn defaultOutputPath frameValue:#current =
    (
        local sceneBaseName = getFilenameFile maxFileName
        if sceneBaseName == undefined or sceneBaseName == "" do sceneBaseName = "Untitled"

        local frameText = padNumber (frameNumberFromTime frameValue) 4
        pathConfig.normalizePath (pathConfig.appendPath (defaultOutputDirectory()) (sceneBaseName + "_AMENO_COTAS_f" + frameText + ".png"))
    ),

    fn ensurePngExtension outputPath =
    (
        local resolved = outputPath
        if resolved == undefined or resolved == "" do resolved = defaultOutputPath()

        if (toLower (getFilenameType resolved)) != ".png" do
        (
            resolved = (getFilenamePath resolved) + (getFilenameFile resolved) + ".png"
        )

        pathConfig.normalizePath resolved
    ),

    fn resolveOutputPath outputPath overwrite:false =
    (
        local resolved = ensurePngExtension outputPath
        if overwrite or not (doesFileExist resolved) then return resolved

        local folder = getFilenamePath resolved
        local baseName = getFilenameFile resolved
        local suffix = 1
        local candidate = resolved

        while doesFileExist candidate do
        (
            candidate = folder + baseName + "_" + (padNumber suffix 3) + ".png"
            suffix += 1
        )

        pathConfig.normalizePath candidate
    ),

    fn normalizeRenderType sourceType =
    (
        case sourceType of
        (
            #region: #region
            #regionCrop: #regionCrop
            #crop: #regionCrop
            #blowUp: #blowUp
            default: #normal
        )
    ),

    fn createRequest outputPath:"" selectionMode:#all overwrite:false =
    (
        local inheritedRenderType = #normal
        try (inheritedRenderType = normalizeRenderType (getRenderType())) catch ()

        AmenoRenderCotasRequest \
            outputPath:(ensurePngExtension outputPath) \
            selectionMode:selectionMode \
            overwrite:overwrite \
            frame:currentTime \
            width:renderWidth \
            height:renderHeight \
            pixelAspect:renderPixelAspect \
            renderType:inheritedRenderType
    ),

    fn collectDimensionIds selectionMode =
    (
        local ids = #()

        if selectionMode == #selected then
        (
            for node in selection where isValidNode node do
            (
                local dimensionId = AmenoDimensionGraphics.getDimensionId node
                if dimensionId != "" and (findItem ids dimensionId) == 0 do append ids dimensionId
            )
        )
        else
        (
            for controller in (AmenoDimensionGraphics.findControllers()) where isValidNode controller do
            (
                local dimensionId = AmenoDimensionGraphics.getDimensionId controller
                if dimensionId != "" and (findItem ids dimensionId) == 0 do append ids dimensionId
            )
        )

        ids
    ),

    fn collectTargetNodes selectionMode =
    (
        local targetNodes = #()
        local dimensionIds = collectDimensionIds selectionMode

        for dimensionId in dimensionIds do
        (
            for node in (AmenoDimensionGraphics.findNodesForDimension dimensionId) where isValidNode node do
            (
                local graphicRole = AmenoDimensionGraphics.readTextProperty node "Ameno.GraphicRole"
                if (graphicRole == "lines" or graphicRole == "label") and (findItem targetNodes node) == 0 do append targetNodes node
            )
        )

        targetNodes
    ),

    fn captureSceneState targetNodes =
    (
        local state = AmenoRenderSceneState currentLayer:LayerManager.current
        local targetLayers = #()

        for targetNode in targetNodes where isValidNode targetNode do
        (
            local targetLayer = undefined
            try (targetLayer = targetNode.layer) catch ()
            if targetLayer != undefined and (findItem targetLayers targetLayer) == 0 do append targetLayers targetLayer
        )

        for node in objects where isValidNode node do
        (
            local nodeState = AmenoRenderNodeState node:node
            try (nodeState.renderable = node.renderable) catch ()
            try (nodeState.isHidden = node.isHidden) catch ()
            try (nodeState.renderByLayer = node.renderByLayer) catch ()
            try (nodeState.primaryVisibility = node.primaryVisibility) catch ()
            nodeState.hasMaterial = isProperty node #material
            if nodeState.hasMaterial do try (nodeState.material = node.material) catch ()
            append state.nodes nodeState
        )

        for layer in targetLayers do
        (
            local layerState = AmenoRenderLayerState layer:layer
            try (layerState.layerOn = layer.on) catch ()
            try (layerState.isHidden = layer.ishidden) catch ()
            try (layerState.renderable = layer.renderable) catch ()
            try (layerState.primaryVisibility = layer.primaryVisibility) catch ()
            try (layerState.visibility = layer.visibility) catch ()
            append state.layers layerState
        )

        state
    ),

    fn applyIsolation sceneState targetNodes annotationMaterial =
    (
        with undo off
        (
            for layerState in sceneState.layers where layerState.layer != undefined do
            (
                local layer = layerState.layer
                try (layer.on = true) catch ()
                try (layer.ishidden = false) catch ()
                try (layer.renderable = true) catch ()
                try (layer.primaryVisibility = true) catch ()
                try (layer.visibility = 1.0) catch ()
            )

            for nodeState in sceneState.nodes where nodeState.node != undefined and isValidNode nodeState.node do
            (
                local node = nodeState.node
                local isTarget = (findItem targetNodes node) > 0

                try (node.renderByLayer = false) catch ()
                try (node.renderable = isTarget) catch ()

                if isTarget do
                (
                    try (node.primaryVisibility = true) catch ()
                    try (node.isHidden = false) catch ()
                    if nodeState.hasMaterial do node.material = annotationMaterial
                )
            )
        )

        for targetNode in targetNodes where isValidNode targetNode do
        (
            if not targetNode.renderable then throw ("Não foi possível tornar a cota renderizável: " + targetNode.name)
        )

        true
    ),

    fn restoreSceneState sceneState =
    (
        if sceneState == undefined then return true

        with undo off
        (
            for nodeState in sceneState.nodes where nodeState.node != undefined and isValidNode nodeState.node do
            (
                local node = nodeState.node
                if nodeState.hasMaterial do try (node.material = nodeState.material) catch ()
                try (node.isHidden = nodeState.isHidden) catch ()
                try (node.primaryVisibility = nodeState.primaryVisibility) catch ()
                try (node.renderable = nodeState.renderable) catch ()
                try (node.renderByLayer = nodeState.renderByLayer) catch ()
            )

            for layerState in sceneState.layers where layerState.layer != undefined do
            (
                local layer = layerState.layer
                try (layer.visibility = layerState.visibility) catch ()
                try (layer.primaryVisibility = layerState.primaryVisibility) catch ()
                try (layer.renderable = layerState.renderable) catch ()
                try (layer.ishidden = layerState.isHidden) catch ()
                try (layer.on = layerState.layerOn) catch ()
            )

            try (if sceneState.currentLayer != undefined do sceneState.currentLayer.current = true) catch ()
        )

        true
    ),

    fn ensureOutputDirectory outputPath =
    (
        local outputDirectory = getFilenamePath outputPath
        local directoryApi = dotNetClass "System.IO.Directory"

        if outputDirectory == undefined or outputDirectory == "" then throw "Escolha uma pasta de saída para o PNG das cotas."
        if not (directoryApi.Exists outputDirectory) do directoryApi.CreateDirectory outputDirectory
        true
    ),

    fn resolveDefaultAdapter =
    (
        local info = if ::AmenoRendererProbe != undefined then ::AmenoRendererProbe.detect() else undefined
        if info != undefined then
        (
            case info.family of
            (
                #corona: (if ::AmenoCoronaRendererAdapter != undefined then ::AmenoCoronaRendererAdapter else undefined)
                #vray:   (if ::AmenoVRayRendererAdapter != undefined then ::AmenoVRayRendererAdapter else undefined)
                default: (if ::AmenoCoronaRendererAdapter != undefined then ::AmenoCoronaRendererAdapter else undefined)
            )
        )
        else
        (
            if ::AmenoCoronaRendererAdapter != undefined then ::AmenoCoronaRendererAdapter else undefined
        )
    ),

    fn renderDimensions request adapter:undefined =
    (
        if isRendering then
        (
            return AmenoRenderCotasResult errorMessage:"Já existe um passe de cotas em andamento."
        )

        if request == undefined do request = createRequest()
        if request.selectionMode != #all and request.selectionMode != #selected do request.selectionMode = #all

        local startedAt = timestamp()
        local result = AmenoRenderCotasResult selectionMode:request.selectionMode
        local sceneState = undefined
        local adapterState = undefined
        local outputExisted = false
        local resolvedAdapter = if adapter != undefined then adapter else (resolveDefaultAdapter())
        if resolvedAdapter == undefined do
        (
            return AmenoRenderCotasResult errorMessage:"Nenhum adapter de renderização compatível está disponível para o renderer ativo."
        )
        local targetNodes = #()
        local activeStage = "inicialização"

        isRendering = true

        try
        (
            activeStage = "sincronização das âncoras"
            if ::AmenoAnchorService != undefined do ::AmenoAnchorService.syncAll force:false

            activeStage = "coleta das cotas"
            targetNodes = collectTargetNodes request.selectionMode
            if targetNodes.count == 0 then
            (
                if request.selectionMode == #selected then
                    throw "Selecione ao menos uma linha ou texto de cota antes de renderizar somente as selecionadas."
                else
                    throw "A cena não possui cotas Ameno para renderizar."
            )

            activeStage = "preparação do arquivo de saída"
            request.outputPath = resolveOutputPath request.outputPath overwrite:request.overwrite
            result.outputPath = request.outputPath
            result.nodeCount = targetNodes.count
            outputExisted = doesFileExist request.outputPath

            ensureOutputDirectory request.outputPath
            activeStage = "validação do adapter"
            resolvedAdapter.validate request
            activeStage = "captura do estado do renderer"
            adapterState = resolvedAdapter.captureState()
            activeStage = "captura do estado da cena"
            sceneState = captureSceneState targetNodes

            activeStage = "configuração do PNG"
            resolvedAdapter.configureOutput request
            activeStage = "criação do material de anotação"
            local annotationMaterial = resolvedAdapter.createAnnotationMaterial()
            activeStage = "isolamento temporário da cena"
            applyIsolation sceneState targetNodes annotationMaterial

            activeStage = "render"
            local adapterResult = resolvedAdapter.renderOverlay request
            if adapterResult != undefined and adapterResult.cancelled then
            (
                result.cancelled = true
                result.errorMessage = "Render das cotas cancelado pelo usuário."
            )
            else
            (
                activeStage = "verificação do PNG"
                local verification = resolvedAdapter.verifyOutput request
                result.success = verification.valid
                result.width = verification.width
                result.height = verification.height
                result.hasAlpha = verification.hasAlpha
                result.errorMessage = verification.errorMessage
            )
        )
        catch
        (
            result.success = false
            result.errorMessage = activeStage + ": " + (getCurrentException() as string)
        )

        local restoreErrors = #()
        try (restoreSceneState sceneState) catch (append restoreErrors (getCurrentException() as string))
        try (resolvedAdapter.restore adapterState) catch (append restoreErrors (getCurrentException() as string))
        isRendering = false

        if restoreErrors.count > 0 do
        (
            result.success = false
            result.errorMessage += (if result.errorMessage == "" then "" else "\n") + "Falha de restauração: " + restoreErrors[1]
        )

        if not result.success and not outputExisted and result.outputPath != "" and doesFileExist result.outputPath do
        (
            try (deleteFile result.outputPath) catch ()
        )

        result.elapsedSeconds = ((timestamp() - startedAt) / 1000.0)
        if result.success then
        (
            lastOutputPath = result.outputPath
            if ::AmenoLog != undefined do ::AmenoLog.info ("Overlay de cotas criado: " + result.outputPath)
        )
        else if not result.cancelled then
        (
            if ::AmenoLog != undefined do ::AmenoLog.error ("Falha no overlay de cotas: " + result.errorMessage)
        )

        result
    )
)

AmenoRenderCotasService = AmenoRenderCotasServiceDefinition()
