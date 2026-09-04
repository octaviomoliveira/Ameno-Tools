/*
    E7 — Sistema de Estilos Visuais do Ameno Dimensions.
    Gerencia estilos tipográficos e geométricos (fontes, peso, espessuras, terminais).
*/

global AmenoStyleRecord
global AmenoStyleServiceDefinition
global AmenoStyleService
global AmenoDimensionGraphics
global AmenoDimensionCA

struct AmenoStyleRecord
(
    styleId = "default",
    name = "Arquitetônico",
    fontName = "Arial",
    fontSize = 20.0,
    bold = false,
    italic = false,
    tracking = 0.0,
    textGap = 12.0,
    lineThickness = 1.5,
    extensionOverhang = 8.0,
    extensionGap = 0.0,
    terminalType = #tick, -- #tick, #arrowClosed, #arrowOpen, #dot, #none
    terminalSize = 14.0
)

struct AmenoStyleServiceDefinition
(
    styles = #(),
    installedFontsCache = undefined,

    fn createDefaultPresets =
    (
        local presets = #()

        -- Preset 1: Arquitetônico (Padrão)
        local arch = AmenoStyleRecord styleId:"default" name:"Arquitetônico" fontName:"Arial" fontSize:20.0 bold:false italic:false tracking:0.0 textGap:12.0 lineThickness:1.5 extensionOverhang:8.0 terminalType:#tick terminalSize:14.0
        append presets arch

        -- Preset 2: Editorial
        local edit = AmenoStyleRecord styleId:"editorial" name:"Editorial" fontName:"Georgia" fontSize:22.0 bold:false italic:false tracking:10.0 textGap:10.0 lineThickness:1.0 extensionOverhang:5.0 terminalType:#dot terminalSize:8.0
        append presets edit

        -- Preset 3: Técnico
        local tech = AmenoStyleRecord styleId:"technical" name:"Técnico" fontName:"Arial" fontSize:16.0 bold:false italic:false tracking:0.0 textGap:8.0 lineThickness:1.2 extensionOverhang:6.0 terminalType:#arrowClosed terminalSize:16.0
        append presets tech

        presets
    ),

    fn cloneStyle style =
    (
        if style == undefined then return undefined
        AmenoStyleRecord styleId:style.styleId \
                         name:style.name \
                         fontName:style.fontName \
                         fontSize:style.fontSize \
                         bold:style.bold \
                         italic:style.italic \
                         tracking:style.tracking \
                         textGap:style.textGap \
                         lineThickness:style.lineThickness \
                         extensionOverhang:style.extensionOverhang \
                         extensionGap:style.extensionGap \
                         terminalType:style.terminalType \
                         terminalSize:style.terminalSize
    ),

    fn serializeStyles =
    (
        local lines = #()
        for s in styles do
        (
            local parts = #(
                s.styleId,
                s.name,
                s.fontName,
                (s.fontSize as string),
                (if s.bold then "1" else "0"),
                (if s.italic then "1" else "0"),
                (s.tracking as string),
                (s.textGap as string),
                (s.lineThickness as string),
                (s.extensionOverhang as string),
                (s.extensionGap as string),
                (s.terminalType as string),
                (s.terminalSize as string)
            )
            local lineStr = ""
            for i = 1 to parts.count do
            (
                lineStr += parts[i]
                if i < parts.count do lineStr += "|"
            )
            append lines lineStr
        )

        local result = ""
        for i = 1 to lines.count do
        (
            result += lines[i]
            if i < lines.count do result += ";;"
        )
        result
    ),

    fn deserializeStyles serializedStr =
    (
        if serializedStr == undefined or serializedStr == "" then return false
        local styleEntries = filterString serializedStr ";;"
        if styleEntries.count == 0 then return false

        local loadedStyles = #()
        for entry in styleEntries do
        (
            local tokens = filterString entry "|"
            if tokens.count >= 13 then
            (
                local s = AmenoStyleRecord()
                s.styleId = tokens[1]
                s.name = tokens[2]
                s.fontName = tokens[3]
                s.fontSize = tokens[4] as float
                s.bold = (tokens[5] == "1")
                s.italic = (tokens[6] == "1")
                s.tracking = tokens[7] as float
                s.textGap = tokens[8] as float
                s.lineThickness = tokens[9] as float
                s.extensionOverhang = tokens[10] as float
                s.extensionGap = tokens[11] as float
                s.terminalType = tokens[12] as name
                s.terminalSize = tokens[13] as float
                append loadedStyles s
            )
        )

        if loadedStyles.count > 0 do
        (
            styles = loadedStyles
            return true
        )
        false
    ),

    fn saveToScene =
    (
        try
        (
            local data = serializeStyles()
            setUserPropVal rootNode "Ameno.Styles" data
            true
        )
        catch
        (
            false
        )
    ),

    fn loadFromScene =
    (
        try
        (
            local data = getUserPropVal rootNode "Ameno.Styles"
            if data != undefined and data != "" then
            (
                deserializeStyles data
            )
            else
            (
                styles = createDefaultPresets()
            )
            true
        )
        catch
        (
            styles = createDefaultPresets()
            false
        )
    ),

    fn getInstalledFonts =
    (
        if installedFontsCache != undefined then return installedFontsCache

        local fontList = #("Arial", "Calibri", "Courier New", "Georgia", "Segoe UI", "Tahoma", "Times New Roman", "Verdana")
        try
        (
            local ffClass = dotnetclass "System.Drawing.FontFamily"
            local families = ffClass.Families
            local names = #()
            for f in families do
            (
                local fnName = f.Name as string
                if fnName != "" and (findItem names fnName == 0) do append names fnName
            )
            sort names
            if names.count > 0 do fontList = names
        )
        catch ()

        installedFontsCache = fontList
        fontList
    ),

    fn validateFont fontName =
    (
        local fonts = getInstalledFonts()
        if (findItem fonts fontName) > 0 then fontName else "Arial"
    ),

    fn getStyle styleId =
    (
        if styleId == undefined or styleId == "" do styleId = "default"
        for s in styles where s.styleId == styleId do return s
        -- Fallback para default
        for s in styles where s.styleId == "default" do return s
        if styles.count > 0 then styles[1] else (createDefaultPresets())[1]
    ),

    fn listStyles =
    (
        styles
    ),

    fn saveStyle styleRecord =
    (
        if styleRecord == undefined then return false

        local index = 0
        for i = 1 to styles.count do
        (
            if styles[i].styleId == styleRecord.styleId do
            (
                index = i
                exit
            )
        )

        if index > 0 then
        (
            styles[index] = cloneStyle styleRecord
        )
        else
        (
            append styles (cloneStyle styleRecord)
        )

        saveToScene()
        true
    ),

    fn saveAsNewStyle newName baseRecord =
    (
        if newName == undefined or newName == "" then newName = "Novo Estilo"
        local newId = "style-" + (timestamp() as string) + "-" + (random 100 999 as string)

        local newRecord = if baseRecord != undefined then cloneStyle baseRecord else AmenoStyleRecord()
        newRecord.styleId = newId
        newRecord.name = newName

        append styles newRecord
        saveToScene()
        newRecord
    ),

    fn countDimensionsUsingStyle styleId =
    (
        global AmenoDimensionGraphics
        global AmenoDimensionCA
        if styleId == undefined or styleId == "" then return 0
        if ::AmenoDimensionGraphics == undefined then return 0

        local count = 0
        local controllers = ::AmenoDimensionGraphics.findControllers()

        for c in controllers where isValidNode c do
        (
            local rec = undefined
            if ::AmenoDimensionCA != undefined do rec = ::AmenoDimensionCA.readCA c
            if rec != undefined and rec.styleId == styleId do count += 1
        )
        count
    ),

    fn applyStyleToDimension controller styleId =
    (
        global AmenoDimensionGraphics
        global AmenoDimensionCA
        if controller == undefined or not isValidNode controller then return false
        if ::AmenoDimensionCA == undefined or ::AmenoDimensionGraphics == undefined then return false

        local rec = ::AmenoDimensionCA.readCA controller
        if rec == undefined then return false

        undo "Ameno: aplicar estilo" on
        (
            rec.styleId = styleId
            ::AmenoDimensionCA.applyCA controller rec
            ::AmenoDimensionGraphics.rebuildDimension controller
        )
        true
    ),

    fn applyStyleToSelection styleId =
    (
        global AmenoDimensionGraphics
        global AmenoDimensionCA
        if selection.count == 0 then return 0
        if ::AmenoDimensionGraphics == undefined or ::AmenoDimensionCA == undefined then return 0

        local controllersToUpdate = #()

        for obj in selection where isValidNode obj do
        (
            local dimId = ::AmenoDimensionGraphics.getDimensionId obj
            if dimId != "" do
            (
                local nodes = ::AmenoDimensionGraphics.findNodesForDimension dimId
                for n in nodes where isValidNode n do
                (
                    if (::AmenoDimensionGraphics.readTextProperty n "Ameno.Kind") == "dimension" or (::AmenoDimensionCA.hasCA n) then
                    (
                        if (findItem controllersToUpdate n) == 0 do append controllersToUpdate n
                    )
                )
            )
        )

        if controllersToUpdate.count == 0 then return 0

        undo "Ameno: aplicar estilo às selecionadas" on
        (
            for c in controllersToUpdate do
            (
                local rec = ::AmenoDimensionCA.readCA c
                if rec != undefined do
                (
                    rec.styleId = styleId
                    ::AmenoDimensionCA.applyCA c rec
                    ::AmenoDimensionGraphics.rebuildDimension c
                )
            )
        )

        controllersToUpdate.count
    ),

    fn updateStyleAndRebuild styleRecord =
    (
        global AmenoDimensionGraphics
        global AmenoDimensionCA
        if styleRecord == undefined then return 0
        saveStyle styleRecord
        if ::AmenoDimensionGraphics == undefined then return 0

        local controllers = ::AmenoDimensionGraphics.findControllers()
        local updatedCount = 0

        undo "Ameno: atualizar estilo de cotas" on
        (
            for c in controllers where isValidNode c do
            (
                local rec = undefined
                if ::AmenoDimensionCA != undefined do rec = ::AmenoDimensionCA.readCA c
                if rec != undefined and rec.styleId == styleRecord.styleId do
                (
                    ::AmenoDimensionGraphics.rebuildDimension c
                    updatedCount += 1
                )
            )
        )

        updatedCount
    )
)

AmenoStyleService = AmenoStyleServiceDefinition()
AmenoStyleService.loadFromScene()