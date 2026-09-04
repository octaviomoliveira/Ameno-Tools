/*
    E4 — ferramenta interativa de três cliques.

    A prévia usa nós temporários identificados em Ameno_COTAS. Eles nunca
    recebem controlador e são removidos em cancelamento, erro, reset ou após
    o commit. A cota permanente continua sendo criada pelo construtor da E3.
*/

global AmenoDimensionTool
global AmenoDimensionMouseTool
global AmenoApp
global AmenoDimensionGraphics
global AmenoDimensionMath
global AmenoSceneSetup
global AmenoLog
global AmenoRefreshMainPanel

struct AmenoDimensionToolService
(
    stage = #idle,
    pointA = undefined,
    pointB = undefined,
    offsetPoint = undefined,
    preview = undefined,
    active = false,
    lastCommittedRecord = undefined,
    lastError = "",
    previewOutputUnit = #meters,
    previewPrecision = 2,
    activeStyleId = "default",

    fn flattenPoint pointValue =
    (
        if pointValue == undefined then return undefined
        [pointValue.x, pointValue.y, 0.0]
    ),

    fn panelStatus statusText =
    (
        try
        (
            if AmenoApp != undefined do AmenoApp.dimensionStatus = statusText
        )
        catch ()

        statusText
    ),

    fn replaceStagePrompt =
    (
        local promptText =
            case stage of
            (
                #pointA: "Ameno Dimensions: clique o ponto A (Esc/botão direito cancela)"
                #pointB: "Ameno Dimensions: clique o ponto B"
                #offset: "Ameno Dimensions: clique para posicionar a linha de cota"
                default: "Ameno Dimensions: pronto"
            )

        try (replacePrompt promptText) catch ()
        promptText
    ),

    fn setStage stageValue =
    (
        stage = stageValue

        local statusText =
            case stage of
            (
                #pointA: "E4: aguardando ponto A."
                #pointB: "E4: ponto A definido · aguardando ponto B."
                #offset: "E4: pontos A/B definidos · aguardando afastamento."
                default: "E4: ferramenta pronta."
            )

        panelStatus statusText
        replaceStagePrompt()
    ),

    fn defaultOffsetPoint pointAValue pointBValue =
    (
        local measurementVector = [pointBValue.x - pointAValue.x, pointBValue.y - pointAValue.y, 0.0]
        local measuredLength = length measurementVector

        if measuredLength <= 0.00001 then
        (
            pointAValue + [0, 100.0, 0]
        )
        else
        (
            local direction = normalize measurementVector
            local perpendicular = normalize (cross [0, 0, 1] direction)
            local offsetDistance = measuredLength * 0.2
            if offsetDistance < 10.0 do offsetDistance = 10.0
            pointAValue + (perpendicular * offsetDistance)
        )
    ),

    fn removePreview =
    (
        if preview != undefined do
        (
            try (AmenoDimensionGraphics.removePreviewDimension preview) catch ()
            preview = undefined
        )

        true
    ),

    fn updatePreview pointAValue pointBValue offsetPointValue =
    (
        local layout = undefined
        try (layout = AmenoDimensionMath.alignedLayout pointAValue pointBValue offsetPointValue) catch ()

        if layout == undefined or not layout.valid then
        (
            displayTempPrompt "Ameno Dimensions: os pontos A e B não podem coincidir." 1200
            return false
        )

        try
        (
            if preview == undefined then
            (
                preview = AmenoDimensionGraphics.createPreviewDimension pointAValue pointBValue offsetPointValue outputUnit:previewOutputUnit precision:previewPrecision styleId:activeStyleId
            )
            else
            (
                preview = AmenoDimensionGraphics.updatePreviewDimension preview pointAValue pointBValue offsetPointValue outputUnit:previewOutputUnit precision:previewPrecision styleId:activeStyleId
            )

            preview != undefined
        )
        catch
        (
            lastError = getCurrentException() as string
            displayTempPrompt ("Ameno Dimensions: falha na prévia — " + lastError) 1800
            false
        )
    ),

    fn begin =
    (
        if active then return false

        local sceneState = AmenoSceneSetup.inspect()
        if sceneState.status != #ready do sceneState = AmenoSceneSetup.prepare()

        if sceneState.status != #ready then
        (
            displayTempPrompt ("Ameno Dimensions: prepare a cena antes de cotar. " + sceneState.detail) 2200
            return false
        )

        pointA = undefined
        pointB = undefined
        offsetPoint = undefined
        preview = undefined
        lastCommittedRecord = undefined
        lastError = ""
        active = true
        setStage #pointA
        true
    ),

    fn handlePoint clickNumber pointValue =
    (
        if not active then return #stop

        local candidate = flattenPoint pointValue
        if candidate == undefined then return undefined

        case stage of
        (
            #pointA:
            (
                pointA = candidate
                setStage #pointB
                undefined
            )
            #pointB:
            (
                if pointA == undefined then return undefined

                if (length (candidate - pointA)) <= 0.00001 then
                (
                    displayTempPrompt "Ameno Dimensions: escolha um ponto B diferente do ponto A." 1400
                    return undefined
                )

                pointB = candidate
                offsetPoint = defaultOffsetPoint pointA pointB
                updatePreview pointA pointB offsetPoint
                setStage #offset
                undefined
            )
            #offset:
            (
                if pointA == undefined or pointB == undefined then return undefined

                offsetPoint = candidate
                if not updatePreview pointA pointB offsetPoint then return undefined

                local created = undefined
                try
                (
                    created = AmenoDimensionGraphics.createDimension pointA pointB offsetPoint role:"interactive" outputUnit:previewOutputUnit precision:previewPrecision styleId:activeStyleId
                    lastCommittedRecord = created
                    removePreview()
                    true
                )
                catch
                (
                    lastError = getCurrentException() as string
                    displayTempPrompt ("Ameno Dimensions: não foi possível criar a cota — " + lastError) 2200
                    false
                )

                if created != undefined then #stop else undefined
            )
            default: undefined
        )
    ),

    fn handleMove clickNumber pointValue =
    (
        if not active then return undefined

        local candidate = flattenPoint pointValue
        if candidate == undefined then return undefined

        case stage of
        (
            #pointA: undefined
            #pointB:
            (
                if pointA != undefined and (length (candidate - pointA)) > 0.00001 do
                (
                    local temporaryOffset = defaultOffsetPoint pointA candidate
                    updatePreview pointA candidate temporaryOffset
                )
            )
            #offset:
            (
                if pointA != undefined and pointB != undefined do updatePreview pointA pointB candidate
            )
            default: undefined
        )
    ),

    fn cancel =
    (
        removePreview()
        pointA = undefined
        pointB = undefined
        offsetPoint = undefined
        active = false
        stage = #idle
        panelStatus "E4: cota cancelada."
        true
    ),

    fn onStart =
    (
        if not active do active = true
        replaceStagePrompt()
        true
    ),

    fn onAbort clickNumber =
    (
        cancel()
        displayTempPrompt "Ameno Dimensions: cota cancelada." 1000
        undefined
    ),

    fn onStop =
    (
        removePreview()
        try (popPrompt()) catch ()
        active = false
        stage = #idle
        panelStatus "E4: ferramenta pronta."
        true
    ),

    fn start =
    (
        if not begin() then return undefined

        local toolResult = #abort
        try
        (
            toolResult = startTool AmenoDimensionMouseTool prompt:"Ameno Dimensions: clique A, B e o afastamento" snap:#3D
        )
        catch
        (
            lastError = getCurrentException() as string
            displayTempPrompt ("Ameno Dimensions: ferramenta interrompida — " + lastError) 2200
            cancel()
        )

        if toolResult == #abort then removePreview()
        lastCommittedRecord
    )
)

AmenoDimensionTool = AmenoDimensionToolService()

tool AmenoDimensionMouseTool prompt:"Ameno Dimensions: clique A, B e o afastamento"
(
    on start do
    (
        if AmenoDimensionTool != undefined do AmenoDimensionTool.onStart()
    )

    on freeMove do
    (
        if AmenoDimensionTool != undefined do AmenoDimensionTool.handleMove 1 worldPoint
    )

    on mousePoint clickNumber do
    (
        if AmenoDimensionTool != undefined then AmenoDimensionTool.handlePoint clickNumber worldPoint else #abort
    )

    on mouseMove clickNumber do
    (
        if AmenoDimensionTool != undefined do AmenoDimensionTool.handleMove clickNumber worldPoint
    )

    on mouseAbort clickNumber do
    (
        if AmenoDimensionTool != undefined do AmenoDimensionTool.onAbort clickNumber
    )

    on stop do
    (
        if AmenoDimensionTool != undefined do AmenoDimensionTool.onStop()
    )
)
