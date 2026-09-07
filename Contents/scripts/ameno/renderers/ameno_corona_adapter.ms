global AmenoCoronaRendererAdapter
global AmenoAdapterRenderResult
global AmenoOutputVerification

struct AmenoAdapterRenderResult
(
    cancelled = false,
    errorMessage = ""
)

struct AmenoOutputVerification
(
    valid = false,
    width = 0,
    height = 0,
    hasAlpha = false,
    errorMessage = ""
)

struct AmenoCoronaAdapterState
(
    renderer = undefined,
    pngAlpha = true,
    pngType = #true24,
    pngInterlaced = false,
    savedOutputPath = "",
    savedSaveFile = false,
    -- critérios de parada salvos como pares #(propName, value); "" = não encontrado
    savedPassesEntry = #("", undefined),
    savedNoiseEntry  = #("", undefined)
)

struct AmenoCoronaRendererAdapterService
(
    adapterId = "corona-overlay-v1",

    -- Limite seguro para o passe de overlay.
    -- CoronaLightMtl (emissivo puro, sem GI) converge em 1 passe;
    -- 20 passes é um teto conservador caso a detecção de convergência falhe.
    OVERLAY_MAX_PASSES = 20,
    -- 1 % de ruído: convergência rápida, imperceptível em linhas/texto.
    OVERLAY_NOISE_LEVEL = 0.01,

    -- Lista de nomes de propriedade de passes e noise em diferentes versões do Corona.
    PASSES_PROPS = #("imageSampler_passes", "rendererPasses", "maxPasses", "limit_passes"),
    NOISE_PROPS  = #("imageSampler_noiseLevel", "denoising_threshold", "noiseLevel", "limit_noise"),
    ALPHA_PROPS  = #("affectAlpha", "visibleToAlpha", "visibleToAlphaChannel"),
    DIRECT_PROPS = #("visibleDirect", "visibleInDirect"),
    REFLECTION_PROPS = #("visibleRefl", "visibleInReflections"),
    REFRACTION_PROPS = #("visibleRefract", "visibleInRefractions"),
    EMIT_PROPS = #("emitLight", "emitOnBackfaces"),

    fn setFirstProperty target propNames value required:false =
    (
        for propName in propNames do
        (
            if isProperty target propName do
            (
                try
                (
                    setProperty target propName value
                    return true
                )
                catch ()
            )
        )
        if required then throw ("Nenhuma propriedade compatível encontrada: " + (propNames as string))
        false
    ),

    fn validate request =
    (
        if request == undefined then throw "A solicitação de render das cotas está vazia."

        local info = AmenoRendererProbe.detect()
        if info == undefined or info.family != #corona then
        (
            local rendererName = if info == undefined then "desconhecido" else info.displayName
            throw ("Renderizar Cotas requer Corona ativo. Renderer atual: " + rendererName + ".")
        )

        if (toLower (getFilenameType request.outputPath)) != ".png" then
        (
            throw "A E9 gera PNG com alpha. Escolha um arquivo com extensão .png."
        )

        true
    ),

    -- Tenta ler o primeiro nome de propriedade disponível no renderer.
    -- Retorna #(propName, value) ou #("", undefined).
    fn readFirstRendererProp r propNames =
    (
        local found = #("", undefined)
        for propName in propNames while found[1] == "" do
        (
            if isProperty r propName then
            (
                local v = undefined
                try (v = getProperty r propName) catch ()
                if v != undefined do found = #(propName, v)
            )
        )
        found
    ),

    fn captureState =
    (
        local state = AmenoCoronaAdapterState renderer:renderers.current
        try (state.pngAlpha = pngio.getAlpha()) catch ()
        try (state.pngType = pngio.getType()) catch ()
        try (state.pngInterlaced = pngio.getInterlaced()) catch ()
        try (state.savedOutputPath = renderOutputFilename) catch (state.savedOutputPath = "")
        try (state.savedSaveFile = renderSaveFile) catch (state.savedSaveFile = false)
        local r = renderers.current
        state.savedPassesEntry = readFirstRendererProp r PASSES_PROPS
        state.savedNoiseEntry  = readFirstRendererProp r NOISE_PROPS
        state
    ),

    fn configureOutput request =
    (
        pngio.setAlpha true
        pngio.setType #true24
        pngio.setInterlaced false

        -- Corona ignora o parâmetro outputfile do comando render;
        -- a saída deve ser configurada via renderOutputFilename + renderSaveFile.
        renderOutputFilename = request.outputPath
        renderSaveFile = true

        -- Forçar critério de parada para o passe de overlay.
        -- CoronaLightMtl converge em 1 passe; estes limites garantem término
        -- mesmo se o usuário tiver 0 % de ruído (critério de parada infinito).
        local r = renderers.current
        for propName in NOISE_PROPS  do try (if isProperty r propName do setProperty r propName OVERLAY_NOISE_LEVEL) catch ()
        for propName in PASSES_PROPS do try (if isProperty r propName do setProperty r propName OVERLAY_MAX_PASSES)  catch ()

        true
    ),

    fn restore state =
    (
        if state == undefined then return true

        local restoreErrors = #()
        try (pngio.setAlpha state.pngAlpha) catch (append restoreErrors ("png alpha: " + (getCurrentException() as string)))
        try (pngio.setType state.pngType) catch (append restoreErrors ("png type: " + (getCurrentException() as string)))
        try (pngio.setInterlaced state.pngInterlaced) catch (append restoreErrors ("png interlaced: " + (getCurrentException() as string)))
        try (renderOutputFilename = state.savedOutputPath) catch (append restoreErrors ("output path: " + (getCurrentException() as string)))
        try (renderSaveFile = state.savedSaveFile) catch (append restoreErrors ("save file: " + (getCurrentException() as string)))

        -- Restaurar critérios de parada originais do usuário.
        local r = renderers.current
        if state.savedPassesEntry[1] != "" do
            try (if isProperty r state.savedPassesEntry[1] do
                setProperty r state.savedPassesEntry[1] state.savedPassesEntry[2]) catch (append restoreErrors ("passes: " + (getCurrentException() as string)))
        if state.savedNoiseEntry[1] != "" do
            try (if isProperty r state.savedNoiseEntry[1] do
                setProperty r state.savedNoiseEntry[1] state.savedNoiseEntry[2]) catch (append restoreErrors ("noise: " + (getCurrentException() as string)))

        if state.renderer != renderers.current then
        (
            append restoreErrors "O renderer ativo mudou durante o passe de cotas; os parâmetros do renderer atual não foram tocados."
        )

        if restoreErrors.count > 0 then throw ("Restauração do Corona falhou: " + restoreErrors[1])
        true
    ),

    fn createAnnotationMaterial colorValue:(color 245 245 245) =
    (
        local annotationMaterial = undefined
        local constructorNames = #("CoronaLightMtl()", "CoronaLegacyMtl()", "CoronaMtl()")
        for constructorName in constructorNames while annotationMaterial == undefined do
            try (annotationMaterial = execute constructorName) catch ()

        if annotationMaterial == undefined then
        (
            throw "Nenhum material de anotação Corona compatível está disponível nesta instalação."
        )

        annotationMaterial.name = uniqueName "AMENO_CORONA_OVERLAY_MTL_"
        if not (setFirstProperty annotationMaterial #(#color, #emissionColor) colorValue required:true) do
            throw "O material Corona não expõe uma propriedade de cor compatível."
        try (annotationMaterial.intensity = 1.0) catch ()
        setFirstProperty annotationMaterial EMIT_PROPS false
        setFirstProperty annotationMaterial DIRECT_PROPS true
        setFirstProperty annotationMaterial ALPHA_PROPS true
        setFirstProperty annotationMaterial REFLECTION_PROPS false
        setFirstProperty annotationMaterial REFRACTION_PROPS false
        try (annotationMaterial.occludeOther = false) catch ()
        try (annotationMaterial.visibleInMasks = true) catch ()
        try (annotationMaterial.twosidedEmission = true) catch ()

        if ::AmenoLog != undefined do
            try (::AmenoLog.info ("Material Corona de overlay criado: " + ((classOf annotationMaterial) as string))) catch ()

        annotationMaterial
    ),

    fn renderFrame request cameraNode:undefined =
    (
        local wasCancelled = false
        local renderedBitmap = undefined
        -- outputColorConversion removido: com camera:undefined passá-lo causa
        -- EXCEPTION_ACCESS_VIOLATION (leitura em 0x40) no Corona 15 HF1.
        -- vfb:true é necessário: com vfb:false o Corona 15 retorna undefined
        -- de render() e não aciona o save via renderSaveFile, deixando o PNG
        -- nunca criado. Com vfb:true o Corona usa seu pipeline normal de VFB
        -- e salva o arquivo via renderOutputFilename + renderSaveFile.
        if cameraNode != undefined and isValidNode cameraNode then
        (
            renderedBitmap = render \
                camera:cameraNode \
                frame:request.frame \
                outputwidth:request.width \
                outputheight:request.height \
                pixelaspect:request.pixelAspect \
                outputfile:request.outputPath \
                vfb:true \
                quiet:true \
                missingExtFilesAction:#logmsg \
                cancelled:&wasCancelled
        )
        else
        (
            renderedBitmap = render \
                frame:request.frame \
                outputwidth:request.width \
                outputheight:request.height \
                pixelaspect:request.pixelAspect \
                outputfile:request.outputPath \
                vfb:true \
                quiet:true \
                missingExtFilesAction:#logmsg \
                cancelled:&wasCancelled
        )

        -- Salvar manualmente como fallback caso o Corona não salve via VFB.
        -- Normalmente o renderSaveFile + renderOutputFilename já cobrem o save;
        -- este bloco só executa se a VFB retornou um bitmap acessível.
        if renderedBitmap != undefined and not wasCancelled and not (doesFileExist request.outputPath) then
        (
            local saveErr = ""
            try
            (
                pngio.setAlpha true
                pngio.setType #true24
                pngio.setInterlaced false
                renderedBitmap.filename = request.outputPath
                save renderedBitmap
            )
            catch (saveErr = getCurrentException() as string)
            if saveErr != "" then throw ("Falha ao salvar o PNG das cotas: " + saveErr)
        )

        #(renderedBitmap, wasCancelled)
    ),

    fn renderOverlay request =
    (
        local wasCancelled = false
        local renderedBitmap = undefined

        try
        (
            local renderData = renderFrame request cameraNode:request.cameraNode
            renderedBitmap = renderData[1]
            wasCancelled = renderData[2]
        )
        catch
        (
            try (if renderedBitmap != undefined do close renderedBitmap) catch ()
            throw
        )

        try (if renderedBitmap != undefined do close renderedBitmap) catch ()

        -- O Corona trata Esc como "parar e salvar" — arquivo parcial fica em disco.
        -- Removemos o arquivo para garantir "Cancelado · cena restaurada" consistente:
        -- sem arquivo em disco = sem ambiguidade sobre o que foi gerado.
        if wasCancelled and (doesFileExist request.outputPath) do
            try (deleteFile request.outputPath) catch ()

        AmenoAdapterRenderResult cancelled:wasCancelled
    ),

    fn verifyOutput request =
    (
        if not (doesFileExist request.outputPath) then
        (
            return AmenoOutputVerification errorMessage:"O Corona terminou sem criar o arquivo PNG."
        )

        local renderedImage = undefined
        local result = AmenoOutputVerification()

        try
        (
            renderedImage = openBitmap request.outputPath
            if renderedImage == undefined then throw "O PNG criado não pôde ser aberto para verificação."

            result.width = renderedImage.width
            result.height = renderedImage.height
            result.hasAlpha = renderedImage.hasAlpha

            local fullFrame = (request.renderType == #normal or request.renderType == #view)
            local dimensionsOk = (not fullFrame) or (result.width == request.width and result.height == request.height)
            result.valid = result.hasAlpha and dimensionsOk

            if not result.hasAlpha then result.errorMessage = "O arquivo foi criado sem canal alpha."
            else if not dimensionsOk then result.errorMessage = "O PNG não preservou a resolução do Render Setup."
        )
        catch
        (
            result.valid = false
            result.errorMessage = getCurrentException() as string
        )

        try (if renderedImage != undefined do close renderedImage) catch ()
        result
    )
)

AmenoCoronaRendererAdapter = AmenoCoronaRendererAdapterService()
