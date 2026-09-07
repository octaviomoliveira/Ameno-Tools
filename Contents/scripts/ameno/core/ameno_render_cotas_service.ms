global AmenoRenderCotasService
global AmenoRenderCotasRequest
global AmenoRenderCotasResult
global AmenoStyleService
global AmenoDimensionCA
global AmenoRendererProbe

struct AmenoRenderCotasRequest
(
    outputPath = "",
    selectionMode = #all,
    overwrite = false,
    frame = #current,
    width = 0,
    height = 0,
    pixelAspect = 1.0,
    renderType = #normal,
    -- true: cria o overlay independente e torna a planta não renderizável
    -- apenas durante o passe. false: preserva a cena e adiciona as cotas.
    dimensionsOnly = true,
    -- Quando preenchida, a câmera é passada diretamente ao comando render;
    -- a viewport ativa não precisa ser trocada para executar o passe.
    cameraNode = undefined
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

    fn createRequest outputPath:"" selectionMode:#all overwrite:false cameraNode:undefined dimensionsOnly:true =
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
            renderType:inheritedRenderType \
            dimensionsOnly:dimensionsOnly \
            cameraNode:cameraNode
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
                if (graphicRole == "lines" or graphicRole == "label" or graphicRole == "terminal") and (findItem targetNodes node) == 0 do append targetNodes node
            )
        )

        targetNodes
    ),

    fn styleColorForDimension dimensionId =
    (
        local fallbackColor = color 245 245 245
        if dimensionId == undefined or dimensionId == "" then return fallbackColor
        if ::AmenoStyleService == undefined or ::AmenoDimensionGraphics == undefined then return fallbackColor

        local styleId = "default"
        for controller in (::AmenoDimensionGraphics.findControllers()) where isValidNode controller do
        (
            if (::AmenoDimensionGraphics.getDimensionId controller) == dimensionId do
            (
                if ::AmenoDimensionCA != undefined do
                (
                    local rec = ::AmenoDimensionCA.readCA controller
                    if rec != undefined and rec.styleId != undefined and rec.styleId != "" do styleId = rec.styleId
                )
                if styleId == "default" do
                (
                    local propStyleId = ::AmenoDimensionGraphics.readTextProperty controller "Ameno.StyleId"
                    if propStyleId != undefined and propStyleId != "" do styleId = propStyleId
                )
                exit
            )
        )

        local styleRecord = ::AmenoStyleService.getStyle styleId
        if styleRecord == undefined then fallbackColor
        else ::AmenoStyleService.colorFromString styleRecord.annotationColor defaultColor:fallbackColor
    ),

    fn materialColorForNode nodeValue fallbackColor:(color 245 245 245) =
    (
        if nodeValue == undefined or not isValidNode nodeValue then return fallbackColor
        local materialValue = undefined
        try (materialValue = nodeValue.material) catch ()
        if materialValue == undefined then return fallbackColor

        local materialColor = undefined
        try (if isProperty materialValue #diffuse do materialColor = materialValue.diffuse) catch ()
        if materialColor == undefined do try (if isProperty materialValue #color do materialColor = materialValue.color) catch ()
        if materialColor != undefined and (classOf materialColor == color) then materialColor else fallbackColor
    ),

    fn sourceColorForNode nodeValue =
    (
        local fallbackColor = color 245 245 245
        if nodeValue == undefined or not isValidNode nodeValue then return fallbackColor
        local dimensionId = AmenoDimensionGraphics.getDimensionId nodeValue
        if dimensionId != "" then return styleColorForDimension dimensionId
        materialColorForNode nodeValue fallbackColor:fallbackColor
    ),

    fn colorKey colorValue =
    (
        local rText = (colorValue.r as integer) as string
        local gText = (colorValue.g as integer) as string
        local bText = (colorValue.b as integer) as string
        rText + "," + gText + "," + bText
    ),

    fn createAnnotationMaterials targetNodes adapterValue =
    (
        local materials = #()
        for targetNode in targetNodes where isValidNode targetNode do
        (
            local colorValue = sourceColorForNode targetNode
            local keyValue = colorKey colorValue
            local found = 0
            for i = 1 to materials.count do
            (
                if materials[i][1] == keyValue do
                (
                    found = i
                    exit
                )
            )
            if found == 0 do
            (
                local materialValue = adapterValue.createAnnotationMaterial colorValue:colorValue
                if materialValue == undefined then throw ("O adapter não criou material para a cor " + keyValue)
                append materials #(keyValue, colorValue, materialValue)
            )
        )
        materials
    ),

    fn annotationMaterialForNode nodeValue materialEntries =
    (
        local keyValue = colorKey (sourceColorForNode nodeValue)
        for entry in materialEntries where entry[1] == keyValue do return entry[3]
        undefined
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

    fn applyIsolation sceneState targetNodes annotationMaterials dimensionsOnly:true =
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

                -- Manter o caminho histórico do overlay byte a byte na ordem das
                -- mutações: primeiro remover herança e definir renderabilidade de
                -- todos os nós; depois preparar material/visibilidade dos alvos.
                -- Alguns renderers avaliam notificações de cena entre setters.
                if dimensionsOnly do
                (
                    try (node.renderByLayer = false) catch ()
                    try (node.renderable = isTarget) catch ()
                )

                if isTarget do
                (
                    if not dimensionsOnly do
                    (
                        try (node.renderByLayer = false) catch ()
                        try (node.renderable = true) catch ()
                    )
                    try (node.primaryVisibility = true) catch ()
                    try (node.isHidden = false) catch ()
                    if nodeState.hasMaterial do
                    (
                        local annotationMaterial = annotationMaterialForNode node annotationMaterials
                        if annotationMaterial == undefined then throw ("Não foi possível associar material à cota: " + node.name)
                        node.material = annotationMaterial
                    )
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

        local restoreErrors = #()
        with undo off
        (
            for nodeState in sceneState.nodes where nodeState.node != undefined and isValidNode nodeState.node do
            (
                local node = nodeState.node
                if nodeState.hasMaterial do
                    try (node.material = nodeState.material) catch (append restoreErrors ("material " + node.name + ": " + (getCurrentException() as string)))
                try (node.isHidden = nodeState.isHidden) catch (append restoreErrors ("hidden " + node.name + ": " + (getCurrentException() as string)))
                try (node.primaryVisibility = nodeState.primaryVisibility) catch (append restoreErrors ("primaryVisibility " + node.name + ": " + (getCurrentException() as string)))
                try (node.renderable = nodeState.renderable) catch (append restoreErrors ("renderable " + node.name + ": " + (getCurrentException() as string)))
                try (node.renderByLayer = nodeState.renderByLayer) catch (append restoreErrors ("renderByLayer " + node.name + ": " + (getCurrentException() as string)))
            )

            for layerState in sceneState.layers where layerState.layer != undefined do
            (
                local layer = layerState.layer
                try (layer.visibility = layerState.visibility) catch (append restoreErrors ("visibility " + layer.name + ": " + (getCurrentException() as string)))
                try (layer.primaryVisibility = layerState.primaryVisibility) catch (append restoreErrors ("primaryVisibility layer " + layer.name + ": " + (getCurrentException() as string)))
                try (layer.renderable = layerState.renderable) catch (append restoreErrors ("renderable layer " + layer.name + ": " + (getCurrentException() as string)))
                try (layer.ishidden = layerState.isHidden) catch (append restoreErrors ("hidden layer " + layer.name + ": " + (getCurrentException() as string)))
                try (layer.on = layerState.layerOn) catch (append restoreErrors ("on layer " + layer.name + ": " + (getCurrentException() as string)))
            )

            try (if sceneState.currentLayer != undefined do sceneState.currentLayer.current = true) catch (append restoreErrors ("current layer: " + (getCurrentException() as string)))
        )

        if restoreErrors.count > 0 then
            throw ("A restauração da cena falhou em " + (restoreErrors[1]))
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

    fn detectRendererInfo =
    (
        if ::AmenoRendererProbe == undefined then undefined
        else try (::AmenoRendererProbe.detect()) catch (undefined)
    ),

    fn rendererInfoLabel infoValue =
    (
        if infoValue == undefined then return "Renderer não identificado"

        local displayText = "Renderer não identificado"
        local classText = ""
        try (displayText = infoValue.displayName as string) catch ()
        try (classText = infoValue.className as string) catch ()
        if displayText == "" then displayText = "Renderer não identificado"
        if classText != "" then displayText += " [" + classText + "]"
        displayText
    ),

    fn rendererCompatibilityError adapterValue =
    (
        if adapterValue == undefined then return "Nenhum adapter de renderização foi resolvido."

        local adapterId = ""
        try (adapterId = adapterValue.adapterId as string) catch ()
        -- Adapters injetados pelos testes não possuem identidade de renderer;
        -- nesse caso a validação continua sendo responsabilidade do teste.
        if adapterId == "" then return ""

        local info = detectRendererInfo()
        local compatible = false
        if adapterId == "corona-overlay-v1" then
            compatible = (info != undefined and info.family == #corona)
        else if adapterId == "vray-overlay-v1" then
            compatible = (info != undefined and info.family == #vray)
        else
            return ""

        if compatible then
            ""
        else
            "O adapter '" + adapterId + "' não é compatível com o renderer ativo: " + (rendererInfoLabel info) + ". Selecione o renderer correspondente e tente novamente."
    ),

    fn resolveDefaultAdapter =
    (
        local info = detectRendererInfo()
        if info == undefined then
            undefined
        else if info.family == #corona then
        (
            if ::AmenoCoronaRendererAdapter != undefined then ::AmenoCoronaRendererAdapter else undefined
        )
        else if info.family == #vray then
        (
            if ::AmenoVRayRendererAdapter != undefined then ::AmenoVRayRendererAdapter else undefined
        )
        else undefined
    ),

    fn isolateSelectionActive =
    (
        local active = false
        try (active = IsolateSelection.IsolateSelectionModeActive()) catch ()
        active == true
    ),

    fn renderRequestSummary request isolateActive:false =
    (
        if request == undefined then return "pedido=undefined"

        local cameraText = "Render Setup/viewport"
        if request.cameraNode != undefined and isValidNode request.cameraNode do
            try (cameraText = request.cameraNode.name as string) catch ()

        "camera=" + cameraText +
        " · renderType=" + (request.renderType as string) +
        " · resolução=" + (request.width as string) + "x" + (request.height as string) +
        " · pixelAspect=" + (request.pixelAspect as string) +
        " · somenteCotas=" + (request.dimensionsOnly as string) +
        " · isolateSelection=" + (isolateActive as string) +
        " · saída=" + (request.outputPath as string)
    ),

    fn renderDimensions request adapter:undefined =
    (
        if isRendering then
        (
            return AmenoRenderCotasResult errorMessage:"Já existe um passe de cotas em andamento."
        )

        if request == undefined do request = createRequest()
        if request.selectionMode != #all and request.selectionMode != #selected do request.selectionMode = #all

        -- O Isolate Selection mantém estado nativo próprio, além de esconder nós.
        -- O render comum pode usá-lo normalmente; o conflito aparece quando o Ameno
        -- tenta aplicar por cima seu próprio passe transacional (renderable, layers,
        -- visibilidade e materiais). No Corona 15 Hotfix 1 essa combinação já
        -- produziu EXCEPTION_ACCESS_VIOLATION dentro de render().
        -- Sair e reentrar automaticamente também não é seguro: descartaria o estado
        -- original que o Max usa quando o usuário executa End Isolate.
        local isolateActive = isolateSelectionActive()
        if ::AmenoLog != undefined do
            ::AmenoLog.info ("Render overlay preflight · " + (renderRequestSummary request isolateActive:isolateActive))
        if isolateActive do
        (
            local isolateMessage = "A cena está em Isolate Selection. O render comum pode usar esse modo, mas o Ameno precisa controlar visibilidade e materiais durante seu próprio passe. Finalize o isolamento (Alt+Q / End Isolate) e use 'Renderizar somente as cotas (sem a planta)'; o Ameno ocultará a planta temporariamente e restaurará a cena."
            if ::AmenoLog != undefined do ::AmenoLog.warn isolateMessage
            return AmenoRenderCotasResult selectionMode:request.selectionMode errorMessage:isolateMessage
        )

        local startedAt = timestamp()
        local result = AmenoRenderCotasResult selectionMode:request.selectionMode
        local sceneState = undefined
        local adapterState = undefined
        local outputExisted = false
        local resolvedAdapter = if adapter != undefined then adapter else (resolveDefaultAdapter())
        if resolvedAdapter == undefined do
        (
            local rendererMessage = "Nenhum adapter de renderização compatível está disponível para o renderer ativo: " + (rendererInfoLabel (detectRendererInfo())) + ". Selecione Corona ou V-Ray antes de renderizar."
            if ::AmenoLog != undefined do ::AmenoLog.warn rendererMessage
            return AmenoRenderCotasResult errorMessage:rendererMessage
        )
        local compatibilityError = rendererCompatibilityError resolvedAdapter
        if compatibilityError != "" do
        (
            if ::AmenoLog != undefined do ::AmenoLog.warn compatibilityError
            return AmenoRenderCotasResult errorMessage:compatibilityError
        )
        local resolvedRendererText = rendererInfoLabel (detectRendererInfo())
        local adapterText = try (resolvedAdapter.adapterId as string) catch ("adapter-injetado")
        if ::AmenoLog != undefined do
            ::AmenoLog.info ("Render overlay iniciado · renderer=" + resolvedRendererText + " · adapter=" + adapterText)
        local targetNodes = #()
        local annotationMaterials = #()
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
            annotationMaterials = createAnnotationMaterials targetNodes resolvedAdapter
            activeStage = "isolamento temporário da cena"
            applyIsolation sceneState targetNodes annotationMaterials dimensionsOnly:request.dimensionsOnly

            activeStage = "validação final do renderer"
            local finalCompatibilityError = rendererCompatibilityError resolvedAdapter
            if finalCompatibilityError != "" then throw finalCompatibilityError
            if ::AmenoLog != undefined do
                ::AmenoLog.info ("Render overlay autorizado · renderer=" + (rendererInfoLabel (detectRendererInfo())) + " · adapter=" + adapterText)

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
