/*
    E7 — Editor Visual de Estilos do Ameno Dimensions.
    Interface para controle tipográfico, espessuras e terminais com atualização em lote.
*/

global AmenoStyleEditorRollout
global AmenoShowStyleEditor
global AmenoStyleService
global AmenoApp
global AmenoRefreshMainPanel
global AmenoDimensionGraphics
global AmenoDimensionCA

rollout AmenoStyleEditorRollout "Ameno Dimensions — Editor de Estilos" width:400 height:520
(
    local currentStyles = #()
    local currentFonts = #()
    local activeStyle = undefined

    dropdownList ddlStyles "Estilo da Cena:" pos:[16,14] width:240 height:40
    button btnNewStyle "Novo..." pos:[266,32] width:120 height:22
    label lblInUse "Em uso: 0 cota(s) nesta cena." pos:[16,60] width:370 height:16

    groupBox grpTypo "Tipografia" pos:[12,82] width:376 height:140
    dropdownList ddlFonts "Fonte:" pos:[24,102] width:224 height:40
    checkbox chkBold "Negrito" pos:[258,122] width:62 height:18
    checkbox chkItalic "Itálico" pos:[324,122] width:58 height:18
    spinner spnFontSize "Tamanho:" pos:[24,152] width:160 height:18 range:[4.0, 500.0, 20.0] type:#float fieldWidth:50
    spinner spnTracking "Tracking:" pos:[200,152] width:170 height:18 range:[-100.0, 500.0, 0.0] type:#float fieldWidth:50
    spinner spnTextGap "Afastamento Texto:" pos:[24,182] width:200 height:18 range:[0.0, 200.0, 12.0] type:#float fieldWidth:50

    groupBox grpLines "Linhas de Cota" pos:[12,230] width:376 height:95
    spinner spnLineThickness "Espessura:" pos:[24,250] width:150 height:18 range:[0.1, 50.0, 1.5] type:#float scale:0.1 fieldWidth:45
    label lblPresets "Atalhos:" pos:[184,252] width:45 height:18
    button btnThin "Fina (0.8)" pos:[234,248] width:68 height:20
    button btnNorm "Norm (1.5)" pos:[306,248] width:70 height:20
    spinner spnOverhang "Prolongamento:" pos:[24,280] width:170 height:18 range:[0.0, 100.0, 8.0] type:#float fieldWidth:45
    button btnThick "Forte (2.5)" pos:[306,278] width:70 height:20

    groupBox grpTerminals "Terminais de Cota" pos:[12,333] width:376 height:95
    dropdownList ddlTerminalType "Tipo de Terminal:" pos:[24,353] width:210 height:40 items:#("Traço Arquitetônico (45°)", "Seta Fechada", "Seta Aberta", "Ponto / Losango", "Nenhum")
    spinner spnTerminalSize "Tamanho Terminal:" pos:[244,373] width:132 height:18 range:[1.0, 200.0, 14.0] type:#float fieldWidth:40

    button btnUpdateBatch "Atualizar Estilo (Em Lote)" pos:[12,438] width:184 height:30
    button btnApplySelection "Aplicar às Selecionadas" pos:[204,438] width:184 height:30
    button btnClose "Fechar" pos:[298,480] width:90 height:24

    fn terminalTypeToIndex tType =
    (
        case tType of
        (
            #tick: 1
            #arrowClosed: 2
            #arrowOpen: 3
            #dot: 4
            #none: 5
            default: 1
        )
    )

    fn indexToTerminalType idx =
    (
        case idx of
        (
            1: #tick
            2: #arrowClosed
            3: #arrowOpen
            4: #dot
            5: #none
            default: #tick
        )
    )

    fn loadActiveStyleToUI =
    (
        if activeStyle == undefined then return false

        -- Fonte
        local fIdx = findItem currentFonts activeStyle.fontName
        if fIdx > 0 then ddlFonts.selection = fIdx
        else
        (
            local aIdx = findItem currentFonts "Arial"
            if aIdx > 0 do ddlFonts.selection = aIdx
        )

        chkBold.checked = activeStyle.bold
        chkItalic.checked = activeStyle.italic
        spnFontSize.value = activeStyle.fontSize
        spnTracking.value = activeStyle.tracking
        spnTextGap.value = activeStyle.textGap

        spnLineThickness.value = activeStyle.lineThickness
        spnOverhang.value = activeStyle.extensionOverhang

        ddlTerminalType.selection = terminalTypeToIndex activeStyle.terminalType
        spnTerminalSize.value = activeStyle.terminalSize

        local count = if ::AmenoStyleService != undefined then ::AmenoStyleService.countDimensionsUsingStyle activeStyle.styleId else 0
        lblInUse.text = "Em uso: " + (count as string) + " cota(s) nesta cena."
        true
    )

    fn refreshStyleList selectedId:undefined =
    (
        if ::AmenoStyleService == undefined then return false
        currentStyles = ::AmenoStyleService.listStyles()

        local names = #()
        local selIdx = 1
        for i = 1 to currentStyles.count do
        (
            append names currentStyles[i].name
            if selectedId != undefined and currentStyles[i].styleId == selectedId do selIdx = i
        )

        ddlStyles.items = names
        if currentStyles.count > 0 then
        (
            ddlStyles.selection = selIdx
            activeStyle = currentStyles[selIdx]
            loadActiveStyleToUI()
        )
        true
    )

    fn readCurrentUIIntoActiveStyle =
    (
        if activeStyle == undefined then return undefined

        if ddlFonts.selection > 0 and ddlFonts.selection <= currentFonts.count do
        (
            activeStyle.fontName = currentFonts[ddlFonts.selection]
        )

        activeStyle.bold = chkBold.checked
        activeStyle.italic = chkItalic.checked
        activeStyle.fontSize = spnFontSize.value
        activeStyle.tracking = spnTracking.value
        activeStyle.textGap = spnTextGap.value

        activeStyle.lineThickness = spnLineThickness.value
        activeStyle.extensionOverhang = spnOverhang.value

        activeStyle.terminalType = indexToTerminalType ddlTerminalType.selection
        activeStyle.terminalSize = spnTerminalSize.value

        activeStyle
    )

    on AmenoStyleEditorRollout open do
    (
        if ::AmenoStyleService != undefined then
        (
            currentFonts = ::AmenoStyleService.getInstalledFonts()
            ddlFonts.items = currentFonts
            refreshStyleList()
        )
    )

    on ddlStyles selected idx do
    (
        if idx > 0 and idx <= currentStyles.count do
        (
            activeStyle = currentStyles[idx]
            loadActiveStyleToUI()
        )
    )

    on btnNewStyle pressed do
    (
        if ::AmenoStyleService != undefined then
        (
            local base = readCurrentUIIntoActiveStyle()
            local defName = if base != undefined then ("Novo " + base.name) else "Novo Estilo"
            local created = ::AmenoStyleService.saveAsNewStyle defName base
            if created != undefined do
            (
                refreshStyleList selectedId:created.styleId
                if AmenoRefreshMainPanel != undefined do AmenoRefreshMainPanel()
            )
        )
    )

    on btnThin pressed do
    (
        spnLineThickness.value = 0.8
    )

    on btnNorm pressed do
    (
        spnLineThickness.value = 1.5
    )

    on btnThick pressed do
    (
        spnLineThickness.value = 2.5
    )

    on btnUpdateBatch pressed do
    (
        if ::AmenoStyleService != undefined and activeStyle != undefined then
        (
            local updated = readCurrentUIIntoActiveStyle()
            if updated != undefined then
            (
                local count = ::AmenoStyleService.updateStyleAndRebuild updated
                loadActiveStyleToUI()
                if AmenoRefreshMainPanel != undefined do AmenoRefreshMainPanel()
                messageBox ("Estilo \"" + updated.name + "\" atualizado.\n\n" + (count as string) + " cota(s) reconstruída(s) na cena.") title:"Ameno Dimensions"
            )
        )
    )

    on btnApplySelection pressed do
    (
        if ::AmenoStyleService != undefined and activeStyle != undefined then
        (
            local count = ::AmenoStyleService.applyStyleToSelection activeStyle.styleId
            loadActiveStyleToUI()
            if AmenoRefreshMainPanel != undefined do AmenoRefreshMainPanel()
            messageBox ("Estilo \"" + activeStyle.name + "\" aplicado a " + (count as string) + " cota(s) selecionada(s).") title:"Ameno Dimensions"
        )
    )

    on btnClose pressed do
    (
        destroyDialog AmenoStyleEditorRollout
    )
)

fn AmenoShowStyleEditor =
(
    try (destroyDialog AmenoStyleEditorRollout) catch ()
    createDialog AmenoStyleEditorRollout width:400 height:520 style:#(#style_titlebar, #style_sysmenu, #style_toolwindow) lockWidth:true lockHeight:true
)