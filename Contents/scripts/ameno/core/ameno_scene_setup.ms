global AmenoSceneSetup

struct AmenoSceneState
(
    status = #notPrepared,
    statusLabel = "Não preparada",
    detail = "Clique em Preparar esta cena para criar a infraestrutura Ameno.",
    documentNode = undefined,
    defaultStyleNode = undefined,
    systemLayer = undefined,
    dimensionsLayer = undefined,
    warnings = #()
)

struct AmenoSceneSetupService
(
    schemaVersion = 1,
    dimensionsLayerBaseName = "AMENO_COTAS",
    systemLayerBaseName = "AMENO_SYSTEM",

    fn readTextProperty node propertyName =
    (
        if node == undefined or not isValidNode node then return ""

        local value = undefined
        try (value = getUserPropVal node propertyName) catch ()

        if value == undefined then return ""

        local textValue = ""
        try (textValue = value as string) catch ()
        textValue
    ),

    fn setTextProperty node propertyName value =
    (
        if node == undefined or not isValidNode node then return false

        try
        (
            setUserPropVal node propertyName value
            true
        )
        catch
        (
            false
        )
    ),

    fn ensureTextProperty node propertyName defaultValue =
    (
        if (readTextProperty node propertyName) == "" then
        (
            setTextProperty node propertyName defaultValue
        )
        else
        (
            true
        )
    ),

    fn layerFromName layerName =
    (
        if layerName == undefined or layerName == "" then return undefined

        try
        (
            LayerManager.getLayerFromName layerName
        )
        catch
        (
            undefined
        )
    ),

    fn nextAvailableLayerName baseName =
    (
        if (layerFromName baseName) == undefined then return baseName

        local suffix = 1
        local candidateName = baseName + "_AMENO"

        while (layerFromName candidateName) != undefined do
        (
            suffix += 1
            candidateName = baseName + "_AMENO_" + (suffix as string)
        )

        candidateName
    ),

    fn createManagedLayer requestedName wireColorValue =
    (
        local layerName = nextAvailableLayerName requestedName
        local layer = LayerManager.newLayerFromName layerName

        try (layer.wireColor = wireColorValue) catch ()
        layer
    ),

    fn resolveRecordedLayer documentNode propertyName fallbackName wireColorValue =
    (
        local recordedName = readTextProperty documentNode propertyName
        local layer = layerFromName recordedName

        if layer == undefined then
        (
            if recordedName == "" then
            (
                layer = createManagedLayer fallbackName wireColorValue
            )
            else
            (
                layer = createManagedLayer recordedName wireColorValue
            )
        )

        layer
    ),

    fn findManagedNodes kind =
    (
        local matches = #()

        for node in objects where isValidNode node do
        (
            if (readTextProperty node "Ameno.Kind") == kind do append matches node
        )

        matches
    ),

    fn findDefaultStyleNodes =
    (
        local matches = #()

        for node in (findManagedNodes "style") do
        (
            if (readTextProperty node "Ameno.StyleRole") == "default" do append matches node
        )

        matches
    ),

    fn createHiddenPoint nodeNamePrefix =
    (
        local node = Point name:(uniqueName nodeNamePrefix) size:5.0

        try (node.isHidden = true) catch ()
        try (node.renderable = false) catch ()
        node
    ),

    fn prepareManagedNode node =
    (
        if node == undefined or not isValidNode node then return false

        try (node.isHidden = true) catch ()
        try (node.renderable = false) catch ()
        true
    ),

    fn createDocumentNode =
    (
        local documentNode = createHiddenPoint "AMENO_DOC_"

        setTextProperty documentNode "Ameno.Kind" "document"
        setTextProperty documentNode "Ameno.SchemaVersion" (schemaVersion as string)
        setTextProperty documentNode "Ameno.DocumentId" ("document-" + (documentNode.handle as string))
        setTextProperty documentNode "Ameno.CreatedWith" AmenoVersion.appVersion

        documentNode
    ),

    fn prepareDocumentNode documentNode systemLayer dimensionsLayer defaultStyleNode =
    (
        prepareManagedNode documentNode
        systemLayer.addNode documentNode

        ensureTextProperty documentNode "Ameno.Kind" "document"
        ensureTextProperty documentNode "Ameno.SchemaVersion" (schemaVersion as string)
        ensureTextProperty documentNode "Ameno.DocumentId" ("document-" + (documentNode.handle as string))
        ensureTextProperty documentNode "Ameno.CreatedWith" AmenoVersion.appVersion

        setTextProperty documentNode "Ameno.LastPreparedWith" AmenoVersion.appVersion
        setTextProperty documentNode "Ameno.SystemLayerName" systemLayer.name
        setTextProperty documentNode "Ameno.DimensionLayerName" dimensionsLayer.name
        setTextProperty documentNode "Ameno.DefaultStyleId" (readTextProperty defaultStyleNode "Ameno.StyleId")

        true
    ),

    fn createDefaultStyleNode =
    (
        local styleNode = createHiddenPoint "AMENO_STYLE_DEFAULT_"

        setTextProperty styleNode "Ameno.Kind" "style"
        setTextProperty styleNode "Ameno.StyleRole" "default"
        setTextProperty styleNode "Ameno.StyleId" ("style-default-" + (styleNode.handle as string))

        styleNode
    ),

    fn prepareDefaultStyleNode styleNode systemLayer =
    (
        prepareManagedNode styleNode
        systemLayer.addNode styleNode

        ensureTextProperty styleNode "Ameno.Kind" "style"
        ensureTextProperty styleNode "Ameno.StyleRole" "default"
        ensureTextProperty styleNode "Ameno.StyleId" ("style-default-" + (styleNode.handle as string))
        ensureTextProperty styleNode "Ameno.StyleName" "Padrão"
        ensureTextProperty styleNode "Ameno.Unit" "m"
        ensureTextProperty styleNode "Ameno.Precision" "2"
        ensureTextProperty styleNode "Ameno.FontName" "Arial"
        ensureTextProperty styleNode "Ameno.LineThickness" "1.0"
        ensureTextProperty styleNode "Ameno.TerminalType" "tick"

        true
    ),

    fn inspect =
    (
        local documentNodes = findManagedNodes "document"

        if documentNodes.count > 1 then
        (
            AmenoSceneState status:#requiresRepair statusLabel:"Requer reparo" detail:"Foram encontrados múltiplos registros Ameno nesta cena." documentNode:documentNodes[1]
        )
        else if documentNodes.count == 0 then
        (
            AmenoSceneState()
        )
        else
        (
            local documentNode = documentNodes[1]
            local styleNodes = findDefaultStyleNodes()
            local systemLayer = undefined
            local dimensionsLayer = layerFromName (readTextProperty documentNode "Ameno.DimensionLayerName")

            try (systemLayer = documentNode.layer) catch ()

            if styleNodes.count > 1 then
            (
                AmenoSceneState status:#requiresRepair statusLabel:"Requer reparo" detail:"Foram encontrados múltiplos estilos padrão Ameno." documentNode:documentNode systemLayer:systemLayer dimensionsLayer:dimensionsLayer defaultStyleNode:styleNodes[1]
            )
            else if systemLayer == undefined or dimensionsLayer == undefined or styleNodes.count == 0 then
            (
                AmenoSceneState status:#requiresRepair statusLabel:"Requer reparo" detail:"A infraestrutura Ameno está incompleta e pode ser reparada." documentNode:documentNode systemLayer:systemLayer dimensionsLayer:dimensionsLayer
            )
            else
            (
                AmenoSceneState status:#ready statusLabel:"Cena preparada" detail:("Layers: " + dimensionsLayer.name + " · " + systemLayer.name) documentNode:documentNode defaultStyleNode:styleNodes[1] systemLayer:systemLayer dimensionsLayer:dimensionsLayer
            )
        )
    ),

    fn prepare =
    (
        local currentState = inspect()

        if currentState.status == #ready then return currentState
        if currentState.status == #requiresRepair and (findManagedNodes "document").count > 1 then return currentState

        local previousLayer = LayerManager.current
        local succeeded = false
        local failureMessage = ""

        try
        (
            undo "Ameno: preparar cena" on
            (
                local documentNodes = findManagedNodes "document"
                local documentNode = undefined
                local systemLayer = undefined
                local dimensionsLayer = undefined
                local defaultStyleNodes = findDefaultStyleNodes()
                local defaultStyleNode = undefined

                if documentNodes.count == 0 then
                (
                    systemLayer = createManagedLayer systemLayerBaseName (color 80 150 220)
                    systemLayer.current = true
                    documentNode = createDocumentNode()
                    systemLayer.addNode documentNode
                )
                else
                (
                    documentNode = documentNodes[1]
                    systemLayer = resolveRecordedLayer documentNode "Ameno.SystemLayerName" systemLayerBaseName (color 80 150 220)
                    systemLayer.current = true
                    systemLayer.addNode documentNode
                )

                dimensionsLayer = resolveRecordedLayer documentNode "Ameno.DimensionLayerName" dimensionsLayerBaseName (color 220 170 70)

                if defaultStyleNodes.count == 0 then
                (
                    defaultStyleNode = createDefaultStyleNode()
                )
                else
                (
                    defaultStyleNode = defaultStyleNodes[1]
                )

                prepareDefaultStyleNode defaultStyleNode systemLayer
                prepareDocumentNode documentNode systemLayer dimensionsLayer defaultStyleNode
            )

            succeeded = true
        )
        catch
        (
            failureMessage = getCurrentException() as string
            if AmenoLog != undefined do AmenoLog.error ("Falha ao preparar a cena: " + failureMessage)
        )

        try
        (
            if previousLayer != undefined do previousLayer.current = true
        )
        catch ()

        if not succeeded then
        (
            AmenoSceneState status:#error statusLabel:"Erro ao preparar" detail:failureMessage
        )
        else
        (
            inspect()
        )
    )
)

AmenoSceneSetup = AmenoSceneSetupService()
