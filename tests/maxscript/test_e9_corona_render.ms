/* Real Corona smoke test for the E9 separate dimensions overlay. */

global AmenoApp
global AmenoDimensionGraphics
global AmenoRenderCotasService

(
    local testFile = getSourceFileName()
    local testPath = getFilenamePath testFile
    local repositoryRoot = pathConfig.normalizePath (pathConfig.appendPath testPath @"..\..")
    local bootstrapPath = pathConfig.normalizePath (pathConfig.appendPath repositoryRoot @"Contents\scripts\startup\ameno_bootstrap.ms")
    local outputDirectory = pathConfig.normalizePath (pathConfig.appendPath repositoryRoot @".test-output")
    local outputPath = pathConfig.normalizePath (pathConfig.appendPath outputDirectory "e9_corona_real.png")

    (dotNetClass "System.IO.Directory").CreateDirectory outputDirectory
    fileIn bootstrapPath quiet:true
    resetMaxFile #noPrompt
    deleteFile outputPath

    renderers.current = Corona()
    renderers.current.progressive_passLimit = 2
    renderers.current.progressive_timeLimit = 5
    renderWidth = 160
    renderHeight = 90
    renderPixelAspect = 1.0

    local dim = AmenoDimensionGraphics.createDimension [-10, 0, 0] [10, 0, 0] [-10, 3, 0]
    dim.lineNode.render_thickness = 1.0
    dim.textNode.size = 3.0

    local userBox = box name:"E9_REAL_USER_BOX" pos:[0, 0, -2] width:30 length:15 height:2
    local cameraTarget = targetObject name:"E9_CAMERA_TARGET" pos:[0, 1.5, 0]
    local cameraNode = targetCamera name:"E9_CAMERA" pos:[0, 1.5, 30] target:cameraTarget
    cameraNode.orthoProjection = true
    cameraNode.fov = 45.0

    local originalBoxRenderable = userBox.renderable
    local originalLineMaterial = dim.lineNode.material
    select #(dim.lineNode, dim.textNode)
    viewport.setCamera cameraNode

    local request = AmenoRenderCotasService.createRequest outputPath:outputPath selectionMode:#all overwrite:true
    request.renderType = #normal
    local result = AmenoRenderCotasService.renderDimensions request

    if not result.success then throw ("E9 Corona real: " + result.errorMessage)
    if not result.hasAlpha then throw "E9 Corona real: PNG sem alpha."
    if userBox.renderable != originalBoxRenderable then throw "E9 Corona real: geometria do usuário não foi restaurada."
    if dim.lineNode.material != originalLineMaterial then throw "E9 Corona real: material da cota não foi restaurado."

    local image = openBitmap outputPath
    local opaqueSamples = 0
    local transparentSamples = 0

    for y = 0 to (image.height - 1) do
    (
        local row = getPixels image [0, y] image.width
        for pixel in row do
        (
            if pixel.a > 1 then opaqueSamples += 1
            if pixel.a < 254 then transparentSamples += 1
        )
    )
    close image

    if opaqueSamples == 0 then throw "E9 Corona real: nenhuma cota apareceu no alpha."
    if transparentSamples == 0 then throw "E9 Corona real: fundo não ficou transparente."

    format "[AMENO_TEST][PASS] E9 Corona real: % (%x%, alpha opaco=% transparente=%).\n" outputPath result.width result.height opaqueSamples transparentSamples
)
