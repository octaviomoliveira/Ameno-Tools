/*
    E15 — Fachada MAXScript da interface Python/Qt do Ameno.

    Este arquivo não conhece WPF, XAML ou controles. Ele expõe somente valores
    primitivos e comandos explícitos para que o Python nunca retenha proxies de
    nós, structs ou objetos temporários do 3ds Max entre eventos.
*/

global AmenoUiBridge
global AmenoApp
global AmenoVersion
global AmenoRendererProbe
global AmenoSceneSetup
global AmenoDimensionGraphics
global AmenoDimensionCA
global AmenoDimensionTool
global AmenoDimensionContinuousTool
global AmenoStyleService
global AmenoAnchorService
global AmenoRenderCotasService

struct AmenoUiBridgeService
(
    commandBusy = false,

    fn okResult code:"ok" message:"" payload:undefined =
    (
        if payload == undefined then #(true, code, message)
        else #(true, code, message, payload)
    ),

    fn errorResult code message =
    (
        #(false, code, message)
    ),

    fn asText value defaultValue:"" =
    (
        if value == undefined then defaultValue else (value as string)
    ),

    fn enumText value defaultValue:"" =
    (
        local textValue = asText value defaultValue:defaultValue
        if textValue.count > 0 and textValue[1] == "#" do textValue = substring textValue 2 -1
        textValue
    ),

    fn sceneSnapshot =
    (
        local sceneState = if ::AmenoApp != undefined then ::AmenoApp.sceneInfo else undefined
        if sceneState == undefined and ::AmenoSceneSetup != undefined do
            try (sceneState = ::AmenoSceneSetup.inspect()) catch ()

        local sceneStatus = if sceneState == undefined then "notPrepared" else enumText sceneState.status defaultValue:"notPrepared"
        local sceneLabel = if sceneState == undefined then "Não preparada" else asText sceneState.statusLabel defaultValue:"Não preparada"
        local sceneDetail = if sceneState == undefined then "Clique em Preparar esta cena." else asText sceneState.detail
        local count = 0
        if ::AmenoDimensionGraphics != undefined do
            try (count = (::AmenoDimensionGraphics.findControllers()).count) catch (count = 0)

        local renderer = if ::AmenoApp != undefined then ::AmenoApp.rendererInfo else undefined
        local rendererLabel = if renderer == undefined then "Renderer desconhecido" else renderer.detailedLabel()
        local rendererState = if renderer == undefined then "sem adapter" else renderer.statusLabel()
        local rendererFamily = if renderer == undefined then "unknown" else enumText renderer.family defaultValue:"unknown"
        local rendererEngine = if renderer == undefined then "unknown" else enumText renderer.engine defaultValue:"unknown"
        local versionText = if ::AmenoVersion == undefined then "" else ::AmenoVersion.displayName()

        #(sceneStatus, sceneLabel, sceneDetail, count, rendererLabel, rendererState, rendererFamily, rendererEngine, versionText)
    ),

    fn createSnapshot =
    (
        local modeValue = #aligned
        local planeValue = #worldXY
        local styleValue = "default"
        local unitValue = #meters
        local precisionValue = 2
        local followsLine = true

        if ::AmenoDimensionTool != undefined do
        (
            try (modeValue = ::AmenoDimensionTool.activeMode) catch ()
            try (planeValue = ::AmenoDimensionTool.activePlaneMode) catch ()
            try (styleValue = ::AmenoDimensionTool.activeStyleId) catch ()
            try (unitValue = ::AmenoDimensionTool.previewOutputUnit) catch ()
            try (precisionValue = ::AmenoDimensionTool.previewPrecision) catch ()
        )
        if ::AmenoDimensionGraphics != undefined do
            try (followsLine = ::AmenoDimensionGraphics.textFollowsLine) catch ()

        #(enumText modeValue defaultValue:"aligned", enumText planeValue defaultValue:"worldXY", asText styleValue defaultValue:"default", enumText unitValue defaultValue:"meters", precisionValue as integer, followsLine)
    ),

    fn styleSnapshot styleRecord =
    (
        if styleRecord == undefined then return #()
        local inUse = 0
        if ::AmenoStyleService != undefined do
            try (inUse = ::AmenoStyleService.countDimensionsUsingStyle styleRecord.styleId) catch (inUse = 0)

        #(
            asText styleRecord.styleId,
            asText styleRecord.name,
            asText styleRecord.fontName defaultValue:"Arial",
            styleRecord.fontSize as float,
            (styleRecord.bold == true),
            (styleRecord.italic == true),
            styleRecord.tracking as float,
            styleRecord.textGap as float,
            styleRecord.lineThickness as float,
            styleRecord.extensionOverhang as float,
            styleRecord.extensionGap as float,
            enumText styleRecord.terminalType defaultValue:"tick",
            styleRecord.terminalSize as float,
            (styleRecord.textMaskEnabled == true),
            asText styleRecord.annotationColor defaultValue:"245,245,245",
            asText styleRecord.textColor,
            enumText styleRecord.terminalPlacement defaultValue:"auto",
            styleRecord.terminalAngle as float,
            styleRecord.previewScale as float,
            inUse
        )
    ),

    fn stylesSnapshot =
    (
        local result = #()
        if ::AmenoStyleService != undefined do
        (
            local records = try (::AmenoStyleService.listStyles()) catch (#())
            for record in records do append result (styleSnapshot record)
        )
        result
    ),

    fn auditSnapshot audit =
    (
        if audit == undefined then return #()
        #(
            asText audit.dimensionId,
            enumText audit.mode defaultValue:"measured",
            audit.measuredMillimeters as float,
            audit.displayMillimeters as float,
            audit.deltaMillimeters as float,
            asText audit.measuredText,
            asText audit.displayText,
            asText audit.deltaText,
            asText audit.manualReason,
            (audit.isManual == true),
            asText audit.anchorType defaultValue:"world",
            asText audit.anchorDesc defaultValue:"Mundial",
            (audit.isOrphan == true),
            asText audit.orphanReason
        )
    ),

    fn selectedAuditSnapshot =
    (
        if ::AmenoApp == undefined then #()
        else (auditSnapshot (::AmenoApp.getSelectedDimensionAudit()))
    ),

    fn refreshSnapshot =
    (
        if ::AmenoApp == undefined then return (errorResult "runtimeUnavailable" "O runtime Ameno não está disponível.")
        try
        (
            ::AmenoApp.refreshRenderer()
            ::AmenoApp.refreshScene()
            ::AmenoApp.refreshDimensions()
            okResult payload:(#(sceneSnapshot(), createSnapshot(), selectedAuditSnapshot(), stylesSnapshot()))
        )
        catch
        (
            errorResult "refreshFailed" (getCurrentException() as string)
        )
    ),

    fn prepareSceneCommand =
    (
        if ::AmenoApp == undefined then return (errorResult "runtimeUnavailable" "O runtime Ameno não está disponível.")
        try
        (
            local state = ::AmenoApp.prepareScene()
            okResult payload:(#(enumText state.status defaultValue:"unknown", asText state.statusLabel, asText state.detail, sceneSnapshot()))
        )
        catch (errorResult "prepareFailed" (getCurrentException() as string))
    ),

    fn setCreateSettings modeValue planeValue styleId unitValue precisionValue followLine =
    (
        if ::AmenoDimensionTool == undefined then return (errorResult "toolUnavailable" "A ferramenta de cota não está disponível.")
        if commandBusy then return (errorResult "busy" "Há uma operação do Ameno em andamento.")
        try
        (
            local modeName = (if modeValue == "horizontal" then #horizontal else if modeValue == "vertical" then #vertical else #aligned)
            local planeName = (if planeValue == "viewPlane" then #viewPlane else #worldXY)
            local unitName = (if unitValue == "millimeters" then #millimeters else if unitValue == "centimeters" then #centimeters else if unitValue == "inches" then #inches else #meters)
            ::AmenoDimensionTool.activeMode = modeName
            ::AmenoDimensionTool.activeStyleId = if styleId == undefined or styleId == "" then "default" else styleId
            ::AmenoDimensionTool.previewOutputUnit = unitName
            ::AmenoDimensionTool.previewPrecision = (amax 0 (amin 4 (precisionValue as integer)))
            try (::AmenoDimensionTool.setActivePlaneMode planeName) catch (::AmenoDimensionTool.activePlaneMode = planeName)
            if ::AmenoDimensionContinuousTool != undefined do
            (
                ::AmenoDimensionContinuousTool.activeMode = modeName
                ::AmenoDimensionContinuousTool.activeStyleId = ::AmenoDimensionTool.activeStyleId
                ::AmenoDimensionContinuousTool.previewOutputUnit = unitName
                ::AmenoDimensionContinuousTool.previewPrecision = ::AmenoDimensionTool.previewPrecision
                try (::AmenoDimensionContinuousTool.setActivePlaneMode planeName) catch (::AmenoDimensionContinuousTool.activePlaneMode = planeName)
            )
            if ::AmenoDimensionGraphics != undefined and isProperty ::AmenoDimensionGraphics #textFollowsLine do
                ::AmenoDimensionGraphics.textFollowsLine = (followLine == true)
            okResult payload:(createSnapshot())
        )
        catch (errorResult "settingsFailed" (getCurrentException() as string))
    ),

    fn runIndividual =
    (
        if ::AmenoApp == undefined then return (errorResult "runtimeUnavailable" "O runtime Ameno não está disponível.")
        if commandBusy then return (errorResult "busy" "Há uma operação do Ameno em andamento.")
        commandBusy = true
        local result = undefined
        try
        (
            ::AmenoApp.startDimensionTool()
            result = okResult payload:(#(sceneSnapshot(), createSnapshot(), selectedAuditSnapshot()))
        )
        catch (result = errorResult "toolFailed" (getCurrentException() as string))
        commandBusy = false
        result
    ),

    fn runContinuous =
    (
        if ::AmenoApp == undefined then return (errorResult "runtimeUnavailable" "O runtime Ameno não está disponível.")
        if commandBusy then return (errorResult "busy" "Há uma operação do Ameno em andamento.")
        commandBusy = true
        local result = undefined
        try
        (
            ::AmenoApp.startContinuousDimensionTool()
            result = okResult payload:(#(sceneSnapshot(), createSnapshot(), selectedAuditSnapshot()))
        )
        catch (result = errorResult "toolFailed" (getCurrentException() as string))
        commandBusy = false
        result
    ),

    fn cancelInteractiveCommand =
    (
        if ::AmenoApp == undefined then return (errorResult "runtimeUnavailable" "O runtime Ameno não está disponível.")
        try (okResult payload:(::AmenoApp.cancelInteractiveTools())) catch (errorResult "cancelFailed" (getCurrentException() as string))
    ),

    fn repairAllCommand =
    (
        if ::AmenoApp == undefined then return (errorResult "runtimeUnavailable" "O runtime Ameno não está disponível.")
        try (okResult payload:(::AmenoApp.repairDimensions())) catch (errorResult "repairFailed" (getCurrentException() as string))
    ),

    fn repairOrphansCommand =
    (
        if ::AmenoApp == undefined then return (errorResult "runtimeUnavailable" "O runtime Ameno não está disponível.")
        try (okResult payload:(::AmenoApp.repairOrphans())) catch (errorResult "orphanRepairFailed" (getCurrentException() as string))
    ),

    fn deleteSelectionCommand =
    (
        if ::AmenoApp == undefined then return (errorResult "runtimeUnavailable" "O runtime Ameno não está disponível.")
        try (okResult payload:(::AmenoApp.deletarSelecao())) catch (errorResult "deleteFailed" (getCurrentException() as string))
    ),

    fn clearOrphansCommand =
    (
        if ::AmenoApp == undefined then return (errorResult "runtimeUnavailable" "O runtime Ameno não está disponível.")
        try (okResult payload:(::AmenoApp.limparOrfas())) catch (errorResult "orphanDeleteFailed" (getCurrentException() as string))
    ),

    fn deleteAllCommand =
    (
        if ::AmenoApp == undefined then return (errorResult "runtimeUnavailable" "O runtime Ameno não está disponível.")
        try (okResult payload:(::AmenoApp.deletarTudo())) catch (errorResult "deleteAllFailed" (getCurrentException() as string))
    ),

    fn saveStyleCommand styleId nameValue fontName fontSizeValue boldValue italicValue trackingValue textGapValue lineThicknessValue overhangValue extensionGapValue terminalTypeValue terminalSizeValue maskValue annotationColorValue textColorValue terminalPlacementValue angleValue previewScaleValue =
    (
        if ::AmenoStyleService == undefined then return (errorResult "styleServiceUnavailable" "O serviço de estilos não está disponível.")
        try
        (
            local record = AmenoStyleRecord styleId:(asText styleId defaultValue:"default") name:(asText nameValue defaultValue:"Novo Estilo") fontName:(asText fontName defaultValue:"Arial") fontSize:(fontSizeValue as float) bold:(boldValue == true) italic:(italicValue == true) tracking:(trackingValue as float) textGap:(textGapValue as float) lineThickness:(lineThicknessValue as float) extensionOverhang:(overhangValue as float) extensionGap:(extensionGapValue as float) terminalType:((asText terminalTypeValue defaultValue:"tick") as name) terminalSize:(terminalSizeValue as float) textMaskEnabled:(maskValue == true) annotationColor:(asText annotationColorValue defaultValue:"245,245,245") textColor:(asText textColorValue) terminalPlacement:((asText terminalPlacementValue defaultValue:"auto") as name) terminalAngle:(angleValue as float) previewScale:(previewScaleValue as float)
            local updated = ::AmenoStyleService.updateStyleAndRebuild record
            okResult payload:updated
        )
        catch (errorResult "styleSaveFailed" (getCurrentException() as string))
    ),

    fn newStyleCommand baseStyleId newName =
    (
        if ::AmenoStyleService == undefined then return (errorResult "styleServiceUnavailable" "O serviço de estilos não está disponível.")
        try
        (
            local base = ::AmenoStyleService.getStyle baseStyleId
            local created = ::AmenoStyleService.saveAsNewStyle newName base
            okResult payload:(styleSnapshot created)
        )
        catch (errorResult "styleCreateFailed" (getCurrentException() as string))
    ),

    fn deleteStyleCommand styleId =
    (
        if styleId == undefined or styleId == "" or styleId == "default" then return (errorResult "styleProtected" "O estilo padrão não pode ser excluído.")
        if ::AmenoStyleService == undefined then return (errorResult "styleServiceUnavailable" "O serviço de estilos não está disponível.")
        try (okResult payload:(::AmenoStyleService.removeStyle styleId)) catch (errorResult "styleDeleteFailed" (getCurrentException() as string))
    ),

    fn applyStyleCommand styleId allDimensions:false =
    (
        if ::AmenoStyleService == undefined then return (errorResult "styleServiceUnavailable" "O serviço de estilos não está disponível.")
        try
        (
            local count = if allDimensions then (::AmenoStyleService.applyDraftToSelection (::AmenoStyleService.createDraftFromStyle styleId) allDimensions:true) else ::AmenoApp.applyStyleToSelection styleId
            okResult payload:count
        )
        catch (errorResult "styleApplyFailed" (getCurrentException() as string))
    ),

    fn selectedModeCommand modeValue roundingValue manualValue manualTextValue reasonValue =
    (
        if ::AmenoApp == undefined then return (errorResult "runtimeUnavailable" "O runtime Ameno não está disponível.")
        try
        (
            local controller = ::AmenoApp.getSelectedDimensionController()
            if controller == undefined then return (errorResult "noSelection" "Selecione uma cota Ameno.")
            local modeName = (if modeValue == "rounded" then #rounded else if modeValue == "manualNumeric" then #manualNumeric else if modeValue == "manualText" then #manualText else #measured)
            local inc = try (roundingValue as float) catch (0.0)
            local numeric = try (manualValue as float) catch (0.0)
            local result = ::AmenoApp.setDimensionMode controller modeName manualValueMm:numeric manualText:(asText manualTextValue) reason:(asText reasonValue) incrementMm:inc
            okResult payload:(auditSnapshot (::AmenoApp.getSelectedDimensionAudit()))
        )
        catch (errorResult "editFailed" (getCurrentException() as string))
    ),

    fn restoreSelectedCommand =
    (
        if ::AmenoApp == undefined then return (errorResult "runtimeUnavailable" "O runtime Ameno não está disponível.")
        try
        (
            local controller = ::AmenoApp.getSelectedDimensionController()
            if controller == undefined then return (errorResult "noSelection" "Selecione uma cota Ameno.")
            ::AmenoApp.resetDimensionToMeasured controller
            okResult payload:(auditSnapshot (::AmenoApp.getSelectedDimensionAudit()))
        )
        catch (errorResult "restoreFailed" (getCurrentException() as string))
    ),

    fn applySelectedStyleCommand styleId =
    (
        if ::AmenoApp == undefined then return (errorResult "runtimeUnavailable" "O runtime Ameno não está disponível.")
        try
        (
            local controller = ::AmenoApp.getSelectedDimensionController()
            if controller == undefined then return (errorResult "noSelection" "Selecione uma cota Ameno.")
            okResult payload:(::AmenoStyleService.applyStyleToDimension controller styleId)
        )
        catch (errorResult "styleApplyFailed" (getCurrentException() as string))
    ),

    fn selectAnchorsCommand =
    (
        if ::AmenoApp == undefined then return (errorResult "runtimeUnavailable" "O runtime Ameno não está disponível.")
        try
        (
            local controller = ::AmenoApp.getSelectedDimensionController()
            if controller == undefined then return (errorResult "noSelection" "Selecione uma cota Ameno.")
            okResult payload:(::AmenoApp.selectAnchors controller)
        )
        catch (errorResult "anchorSelectFailed" (getCurrentException() as string))
    ),

    fn defaultRenderPath =
    (
        if ::AmenoApp == undefined then ""
        else try (::AmenoApp.defaultRenderCotasPath()) catch ("")
    ),

    fn diagnosticCommand =
    (
        if ::AmenoApp == undefined then return (errorResult "runtimeUnavailable" "O runtime Ameno não está disponível.")
        try (okResult payload:(::AmenoApp.printDiagnosticReport())) catch (errorResult "diagnosticFailed" (getCurrentException() as string))
    ),

    fn renderCommand outputPath selectionValue dimensionsOnlyValue =
    (
        if ::AmenoApp == undefined then return (errorResult "runtimeUnavailable" "O runtime Ameno não está disponível.")
        try
        (
            local scope = if selectionValue == "selected" then #selection else #all
            local result = ::AmenoApp.renderCotas outputPath:outputPath selectionMode:scope dimensionsOnly:(dimensionsOnlyValue == true)
            local statusText = "erro"
            if result != undefined do
            (
                if result.cancelled then statusText = "cancelado"
                else if result.success then statusText = "sucesso"
            )
            local pathText = if result == undefined then outputPath else asText result.outputPath defaultValue:outputPath
            okResult payload:(#(statusText, pathText))
        )
        catch (errorResult "renderFailed" (getCurrentException() as string))
    )
)

AmenoUiBridge = AmenoUiBridgeService()
