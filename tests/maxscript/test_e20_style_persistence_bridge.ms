/* E20: real Python/MAXScript style bridge and lossless style-library parsing. */

global AmenoApp
global AmenoDimensionCA
global AmenoDimensionGraphics
global AmenoStyleService

(
    local testFile = getSourceFileName()
    local testPath = getFilenamePath testFile
    local repositoryRoot = pathConfig.normalizePath (pathConfig.appendPath testPath @"..\..")
    local bootstrapPath = pathConfig.normalizePath (pathConfig.appendPath repositoryRoot @"Contents\scripts\startup\ameno_bootstrap.ms")
    resetMaxFile #noPrompt
    fileIn bootstrapPath quiet:true

    local baseStyle = AmenoStyleService.getStyle "default"
    baseStyle.textColor = ""
    baseStyle.terminalPlacement = #outside
    baseStyle.terminalAngle = 37.0
    baseStyle.previewScale = 1.5
    local serialized = AmenoStyleService.serializeStyleList #(baseStyle)
    local parsed = AmenoStyleService.parseStyleList serialized
    if parsed.count != 1 then throw "E20 estilos: round-trip perdeu o registro."
    if parsed[1].textColor != "" or parsed[1].terminalPlacement != #outside or parsed[1].terminalAngle != 37.0 or parsed[1].previewScale != 1.5 then
        throw "E20 estilos: campo vazio deslocou posição, ângulo ou escala."

    local legacy = "legacy|Legado|Arial|140.0|0|0|0.0|60.0|1.5|80.0|0.0|tick|100.0|1|245,245,245|auto|45.0|1.0|1.0"
    local recovered = AmenoStyleService.parseStyleList legacy
    if recovered.count != 1 or recovered[1].textColor != "" or recovered[1].terminalPlacement != #auto or recovered[1].terminalAngle != 45.0 then
        throw "E20 estilos: registro antigo com campos deslocados não foi recuperado."
    local resavedLegacy = "legacy-2|Legado 2|Arial|140.0|0|0|0.0|60.0|1.5|80.0|0.0|arrowClosed|100.0|1|0,85,0|auto|auto|1.0|1.0"
    local recoveredTwice = AmenoStyleService.parseStyleList resavedLegacy
    if recoveredTwice.count != 1 or recoveredTwice[1].textColor != "" or recoveredTwice[1].terminalPlacement != #auto or recoveredTwice[1].terminalAngle != 45.0 then
        throw "E20 estilos: registro salvo novamente após a corrupção não foi recuperado."

    local created = AmenoDimensionGraphics.createDimension [0,0,0] [100,0,0] [50,30,0] useUndo:false
    if created == undefined or not isValidNode created.controller then throw "E20 estilos: cota de teste não foi criada."
    select created.controller

    local pythonRoot = substituteString (pathConfig.normalizePath (pathConfig.appendPath repositoryRoot @"Contents\python")) "\\" "/"
    local pythonCall = "import sys; sys.path.insert(0, r'" + pythonRoot + "'); from ameno_ui.bridge import UiBridge, BridgeError; _ameno_style_bridge=UiBridge(); assert _ameno_style_bridge.apply_style('technical', False) == 1"
    if (python.Execute pythonCall) != #success then throw "E20 estilos: ponte real não aplicou à seleção com keyword MAXScript."
    local record = AmenoDimensionCA.readCA created.controller
    if record == undefined or record.styleId != "technical" then throw "E20 estilos: CA não recebeu o estilo selecionado."

    if (python.Execute "assert _ameno_style_bridge.apply_style('default', True) == 1") != #success then
        throw "E20 estilos: ponte real não aplicou a todas as cotas."
    record = AmenoDimensionCA.readCA created.controller
    if record == undefined or record.styleId != "default" then throw "E20 estilos: CA não recebeu o estilo global."

    clearSelection()
    if (python.Execute "try:\n _ameno_style_bridge.apply_style('technical', False)\n assert False, 'expected noSelection'\nexcept BridgeError as exc:\n assert exc.code == 'noSelection'") != #success then
        throw "E20 estilos: seleção vazia não retornou noSelection."

    format "[AMENO_TEST][PASS] E20 estilos: ponte real, seleção e biblioteca retrocompatível.\n"
)
