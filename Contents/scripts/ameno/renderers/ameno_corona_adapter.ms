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
    savedSaveFile = false
)

struct AmenoCoronaRendererAdapterService
(
    adapterId = "corona-overlay-v1",

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

    fn captureState =
    (
        local state = AmenoCoronaAdapterState renderer:renderers.current
        try (state.pngAlpha = pngio.getAlpha()) catch ()
        try (state.pngType = pngio.getType()) catch ()
        try (state.pngInterlaced = pngio.getInterlaced()) catch ()
        try (state.savedOutputPath = renderOutputFilename) catch (state.savedOutputPath = "")
        try (state.savedSaveFile = renderSaveFile) catch (state.savedSaveFile = false)
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
