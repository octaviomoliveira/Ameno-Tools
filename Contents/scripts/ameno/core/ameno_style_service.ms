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

global AmenoStyleRegistryCA = attributes AmenoStyleRegistryData
version:1
attribID:#(0x4a123bc4, 0x19283746)
(
    parameters main rollout:params
    (
        stylesData type:#string default:""
    )
    rollout params "Estilos Ameno"
    (
        label lblInfo "Armazenamento paramétrico de estilos"
    )
)

struct AmenoStyleServiceDefinition
(
    styles = #(),
    installedFontsCache = undefined,
    cachedSerialized = "",

    fn escapeStr strVal =
    (
        if strVal == undefined then return ""
        local s = strVal as string
        s = substituteString s "\\" "\\\\"
        s = substituteString s "|" "\\p"
        s = substituteString s ";" "\\s"
        s
    ),

    fn unescapeStr strVal =
    (
        if strVal == undefined then return ""
        local s = strVal as string
        s = substituteString s "\\p" "|"
        s = substituteString s "\\s" ";"
        s = substituteString s "\\\\" "\\"
        s
    ),

    fn hasRegistryCA node =
    (
        if node == undefined or not isValidNode node then return false
        (isProperty node #AmenoStyleRegistryData)
    ),

    fn getRegistryNode createIfMissing:false =
    (
        for obj in objects where isValidNode obj do
        (
            if (getUserPropVal obj "Ameno.Kind") == "styleRegistry" do return obj
        )

        if not createIfMissing then return undefined

        local regNode = Point name:(uniqueName "AMENO_STYLE_REGISTRY_") size:5.0
        try (regNode.isHidden = true) catch ()
        try (regNode.renderable = false) catch ()
        setUserPropVal regNode "Ameno.Kind" "styleRegistry"

        if ::AmenoSceneSetup != undefined do
        (
            local state = ::AmenoSceneSetup.inspect()
            if state.systemLayer != undefined do state.systemLayer.addNode regNode
        )

        custAttributes.add regNode AmenoStyleRegistryCA
        regNode
    ),

    fn ensureRegistryNode =
    (
        local regNode = getRegistryNode createIfMissing:true
        if regNode != undefined and not (hasRegistryCA regNode) do
        (
            custAttributes.add regNode AmenoStyleRegistryCA
        )
        regNode
    ),

    fn createDefaultPresets =
    (
        local presets = #()

        -- Preset 1: Arquitetônico (Padrão)
        local arch = AmenoStyleRecord styleId:"default" name:"Arquitetônico" fontName:"Arial" fontSize:20.0 bold:false italic:false tracking:0.0 textGap:12.0 lineThickness:1.5 extensionOverhang:8.0 extensionGap:0.0 terminalType:#tick terminalSize:14.0
        append presets arch

        -- Preset 2: Editorial
        local edit = AmenoStyleRecord styleId:"editorial" name:"Editorial" fontName:"Georgia" fontSize:22.0 bold:false italic:false tracking:10.0 textGap:10.0 lineThickness:1.0 extensionOverhang:5.0 extensionGap:0.0 terminalType:#dot terminalSize:8.0
        append presets edit

        -- Preset 3: Técnico
        local tech = AmenoStyleRecord styleId:"technical" name:"Técnico" fontName:"Arial" fontSize:16.0 bold:false italic:false tracking:0.0 textGap:8.0 lineThickness:1.2 extensionOverhang:6.0 extensionGap:0.0 terminalType:#arrowClosed terminalSize:16.0
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
                (escapeStr s.styleId),
                (escapeStr s.name),
                (escapeStr s.fontName),
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
                s.styleId = unescapeStr tokens[1]
                s.name = unescapeStr tokens[2]
                s.fontName = unescapeStr tokens[3]
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
            cachedSerialized = serializedStr
            return true
        )
        false
    ),

    fn saveToScene =
    (
        try
        (
            local data = serializeStyles()
            cachedSerialized = data
            local regNode = ensureRegistryNode()
            if regNode != undefined and (hasRegistryCA regNode) do
            (
                regNode.AmenoStyleRegistryData.stylesData = data
            )
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
            local data = undefined
            local regNode = getRegistryNode()
            if regNode != undefined and (hasRegistryCA regNode) do
            (
                data = regNode.AmenoStyleRegistryData.stylesData
            )
            if data == undefined or data == "" do
            (
                data = getUserPropVal rootNode "Ameno.Styles"
            )

            if data != undefined and data != "" then
            (
                deserializeStyles data
            )
            else
            (
                styles = createDefaultPresets()
                cachedSerialized = serializeStyles()
            )
            true
        )
        catch
        (
            styles = createDefaultPresets()
            cachedSerialized = serializeStyles()
            false
        )
    ),

    fn checkSyncWithRegistry =
    (
        local regNode = getRegistryNode()
        if regNode != undefined and isValidNode regNode and (hasRegistryCA regNode) do
        (
            local curData = regNode.AmenoStyleRegistryData.stylesData
            if curData != undefined and curData != "" and curData != cachedSerialized do
            (
                deserializeStyles curData
            )
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
        checkSyncWithRegistry()
        if styleId == undefined or styleId == "" do styleId = "default"
        for s in styles where s.styleId == styleId do return (cloneStyle s)
        -- Fallback para default
        for s in styles where s.styleId == "default" do return (cloneStyle s)
        if styles.count > 0 then (cloneStyle styles[1]) else (cloneStyle (createDefaultPresets())[1])
    ),

    fn listStyles =
    (
        checkSyncWithRegistry()
        for s in styles collect (cloneStyle s)
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
        cloneStyle newRecord
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
        if ::AmenoDimensionGraphics == undefined then return 0

        local updatedCount = 0

        undo "Ameno: atualizar estilo de cotas" on
        (
            local regNode = ensureRegistryNode()

            -- Atualiza no array em memória
            local found = false
            for i = 1 to styles.count do
            (
                if styles[i].styleId == styleRecord.styleId do
                (
                    styles[i] = cloneStyle styleRecord
                    found = true
                    exit
                )
            )
            if not found do append styles (cloneStyle styleRecord)

            local dataStr = serializeStyles()
            cachedSerialized = dataStr
            if regNode != undefined and isValidNode regNode and (hasRegistryCA regNode) do
            (
                regNode.AmenoStyleRegistryData.stylesData = dataStr
            )
            try (setUserPropVal rootNode "Ameno.Styles" dataStr) catch ()

            local controllers = ::AmenoDimensionGraphics.findControllers()
            for c in controllers where isValidNode c do
            (
                local rec = undefined
                if ::AmenoDimensionCA != undefined do rec = ::AmenoDimensionCA.readCA c
                if rec != undefined and rec.styleId == styleRecord.styleId do
                (
                    ::AmenoDimensionGraphics.rebuildDimension c style:(cloneStyle styleRecord)
                    updatedCount += 1
                )
            )
        )

        updatedCount
    )
)

AmenoStyleService = AmenoStyleServiceDefinition()
AmenoStyleService.loadFromScene()