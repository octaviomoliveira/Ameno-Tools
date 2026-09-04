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

    fn validate request =
    (
        if request == undefined then throw "A solicitação de render das cotas está vazia."

        local info = AmenoRendererProbe.detect()
        if info.family != #corona then
        (
            throw ("Renderizar Cotas da E9 requer Corona ativo. Renderer atual: " + info.displayName + ".")
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

        try (pngio.setAlpha state.pngAlpha) catch ()
        try (pngio.setType state.pngType) catch ()
        try (pngio.setInterlaced state.pngInterlaced) catch ()
        try (renderOutputFilename = state.savedOutputPath) catch ()
        try (renderSaveFile = state.savedSaveFile) catch ()

        -- Restaurar critérios de parada originais do usuário.
        local r = renderers.current
        if state.savedPassesEntry[1] != "" do
            try (if isProperty r state.savedPassesEntry[1] do
                setProperty r state.savedPassesEntry[1] state.savedPassesEntry[2]) catch ()
        if state.savedNoiseEntry[1] != "" do
            try (if isProperty r state.savedNoiseEntry[1] do
                setProperty r state.savedNoiseEntry[1] state.savedNoiseEntry[2]) catch ()

        if state.renderer != renderers.current then
        (
            throw "O renderer ativo mudou durante o passe de cotas; a restauração foi interrompida para não sobrescrever a escolha do usuário."
        )

        true
    ),

    fn createAnnotationMaterial colorValue:(color 245 245 245) =
    (
        local annotationMaterial = undefined
        try (annotationMaterial = execute "CoronaLightMtl()") catch ()

        if annotationMaterial == undefined then
        (
            throw "CoronaLightMtl não está disponível nesta instalação do Corona."
        )

        annotationMaterial.name = uniqueName "AMENO_CORONA_OVERLAY_MTL_"
        annotationMaterial.color = colorValue
        annotationMaterial.intensity = 1.0
        annotationMaterial.emitLight = false
        annotationMaterial.visibleDirect = true
        annotationMaterial.affectAlpha = true
        annotationMaterial.visibleRefl = false
        annotationMaterial.visibleRefract = false
        annotationMaterial.occludeOther = false
        annotationMaterial.visibleInMasks = true
        try (annotationMaterial.twosidedEmission = true) catch ()

        annotationMaterial
    ),

    fn renderOverlay request =
    (
        local wasCancelled = false
        local renderedBitmap = undefined

        try
        (
            renderedBitmap = render \
                frame:request.frame \
                outputwidth:request.width \
                outputheight:request.height \
                pixelaspect:request.pixelAspect \
                outputfile:request.outputPath \
                outputHDRbitmap:false \
                outputColorConversion:#automatic \
                renderType:request.renderType \
                renderhiddenobjects:false \
                renderatmosphericeffects:false \
                renderMultiPassEffects:false \
                renderElements:false \
                force2sided:true \
                vfb:false \
                progressbar:true \
                quiet:true \
                missingExtFilesAction:#logmsg \
                cancelled:&wasCancelled
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
