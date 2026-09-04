global AmenoVRayRendererAdapter
global AmenoAdapterRenderResult
global AmenoOutputVerification

struct AmenoVRayAdapterState
(
    renderer = undefined,
    pngAlpha = true,
    pngType = #true24,
    pngInterlaced = false,
    savedOutputPath = "",
    savedSaveFile = false,
    savedGiEntry      = #("", undefined),
    savedNoiseEntry   = #("", undefined),
    savedTimeEntry    = #("", undefined),
    savedSamplesEntry = #("", undefined)
)

struct AmenoVRayRendererAdapterService
(
    adapterId = "vray-overlay-v1",

    OVERLAY_NOISE_THRESHOLD = 0.02,
    OVERLAY_MAX_RENDER_TIME = 1.0,

    GI_PROPS      = #("gi_on", "gi_enable", "indirect_illumination_on", "gi"),
    NOISE_PROPS   = #("progressive_noise_threshold", "dmc_earlyTermination_threshold", "color_threshold"),
    TIME_PROPS    = #("progressive_max_render_time", "progressive_max_time"),
    SAMPLES_PROPS = #("progressive_max_samples", "aa_max_subdivs"),

    fn validate request =
    (
        if request == undefined then throw "A solicitação de render das cotas está vazia."

        local info = AmenoRendererProbe.detect()
        if info.family != #vray then
        (
            throw ("O adapter V-Ray requer V-Ray ativo. Renderer atual: " + info.displayName + ".")
        )

        if (toLower (getFilenameType request.outputPath)) != ".png" then
        (
            throw "O adapter V-Ray gera PNG com alpha. Escolha um arquivo com extensão .png."
        )

        true
    ),

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
        local state = AmenoVRayAdapterState renderer:renderers.current
        try (state.pngAlpha = pngio.getAlpha()) catch ()
        try (state.pngType = pngio.getType()) catch ()
        try (state.pngInterlaced = pngio.getInterlaced()) catch ()
        try (state.savedOutputPath = renderOutputFilename) catch (state.savedOutputPath = "")
        try (state.savedSaveFile = renderSaveFile) catch (state.savedSaveFile = false)
        local r = renderers.current
        state.savedGiEntry      = readFirstRendererProp r GI_PROPS
        state.savedNoiseEntry   = readFirstRendererProp r NOISE_PROPS
        state.savedTimeEntry    = readFirstRendererProp r TIME_PROPS
        state.savedSamplesEntry = readFirstRendererProp r SAMPLES_PROPS
        state
    ),

    fn configureOutput request =
    (
        pngio.setAlpha true
        pngio.setType #true24
        pngio.setInterlaced false

        renderOutputFilename = request.outputPath
        renderSaveFile = true

        local r = renderers.current
        for propName in GI_PROPS    do try (if isProperty r propName do setProperty r propName false) catch ()
        for propName in NOISE_PROPS do try (if isProperty r propName do setProperty r propName OVERLAY_NOISE_THRESHOLD) catch ()
        for propName in TIME_PROPS  do try (if isProperty r propName do setProperty r propName OVERLAY_MAX_RENDER_TIME)  catch ()

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

        local r = renderers.current
        if state.savedGiEntry[1] != "" do
            try (if isProperty r state.savedGiEntry[1] do setProperty r state.savedGiEntry[1] state.savedGiEntry[2]) catch ()
        if state.savedNoiseEntry[1] != "" do
            try (if isProperty r state.savedNoiseEntry[1] do setProperty r state.savedNoiseEntry[1] state.savedNoiseEntry[2]) catch ()
        if state.savedTimeEntry[1] != "" do
            try (if isProperty r state.savedTimeEntry[1] do setProperty r state.savedTimeEntry[1] state.savedTimeEntry[2]) catch ()
        if state.savedSamplesEntry[1] != "" do
            try (if isProperty r state.savedSamplesEntry[1] do setProperty r state.savedSamplesEntry[1] state.savedSamplesEntry[2]) catch ()

        if state.renderer != renderers.current then
        (
            throw "O renderer ativo mudou durante o passe de cotas; a restauração foi interrompida para não sobrescrever a escolha do usuário."
        )

        true
    ),

    fn createAnnotationMaterial colorValue:(color 245 245 245) =
    (
        local annotationMaterial = undefined

        try (annotationMaterial = execute "VRayLightMtl()") catch ()

        if annotationMaterial != undefined then
        (
            annotationMaterial.name = uniqueName "AMENO_VRAY_OVERLAY_MTL_"
            try (annotationMaterial.color = colorValue) catch ()
            try (annotationMaterial.multiplier = 1.0) catch ()
            try (annotationMaterial.emitOnBackFaces = true) catch ()
            try (annotationMaterial.compensate_exposure = false) catch ()
            try (annotationMaterial.displace = false) catch ()
            try (annotationMaterial.directRenderable = true) catch ()
        )
        else
        (
            try (annotationMaterial = execute "VRayMtl()") catch ()
            if annotationMaterial != undefined then
            (
                annotationMaterial.name = uniqueName "AMENO_VRAY_OVERLAY_MTL_"
                annotationMaterial.diffuse = color 0 0 0
                try (annotationMaterial.selfIllumination = colorValue) catch ()
                try (annotationMaterial.selfIllumination_multiplier = 1.0) catch ()
                try (annotationMaterial.selfIllumination_gi = false) catch ()
            )
            else
            (
                throw "VRayLightMtl e VRayMtl não estão disponíveis nesta instalação do V-Ray."
            )
        )

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

        if wasCancelled and (doesFileExist request.outputPath) do
            try (deleteFile request.outputPath) catch ()

        AmenoAdapterRenderResult cancelled:wasCancelled
    ),

    fn verifyOutput request =
    (
        if not (doesFileExist request.outputPath) then
        (
            return AmenoOutputVerification errorMessage:"O V-Ray terminou sem criar o arquivo PNG."
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

AmenoVRayRendererAdapter = AmenoVRayRendererAdapterService()
