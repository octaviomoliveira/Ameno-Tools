/*
    E13-C -- Aba "Estilos" da Janela Unificada Ameno - Cotas
    Absorve o editor visual de estilos WPF (antes janela separada) como aba embutida.
    Toda a funcionalidade permanece: preview ao vivo, sliders, dropdowns, salvar/carregar.
    Botoes Novo / Duplicar / Deletar ficam no topo da aba.
*/

global AmenoCotasEstilosTab
global AmenoStyleService
global AmenoStyleDraft
global AmenoPreviewRenderer
global AmenoDimensionGraphics

struct AmenoCotasEstilosTabDefinition
(
    -- Controles cached
    hostControl  = undefined,
    currentDraft = undefined,
    isSyncing    = false,
    sceneGeneration = 0,
    draftSceneGeneration = -1,
    dirtyDecisionOverride = undefined,
    callbacksRegistered = false,

    -- Controles nomeados (preenchidos em build)
    cbStyleSelect     = undefined,
    txtInUseCount     = undefined,
    txtDirtyMark      = undefined,
    btnPresetArch     = undefined,
    btnPresetEdit     = undefined,
    btnPresetTech     = undefined,
    btnSaveAsNew      = undefined,
    btnNewStyle       = undefined,
    btnDuplicateStyle = undefined,
    btnDeleteStyle    = undefined,

    btnZoom50    = undefined,
    btnZoom100   = undefined,
    btnZoom200   = undefined,
    btnToggleBg  = undefined,
    pnlPreviewHost  = undefined,
    previewCanvas   = undefined,
    txtPreviewStatus = undefined,

    cbFontName       = undefined,
    sliderFontSize   = undefined,
    txtFontSize      = undefined,
    chkBold          = undefined,
    chkItalic        = undefined,
    sliderTracking   = undefined,
    txtTracking      = undefined,
    sliderTextGap    = undefined,
    txtTextGap       = undefined,
    chkTextMask      = undefined,

    btnThin             = undefined,
    btnNorm             = undefined,
    btnThick            = undefined,
    sliderLineThickness = undefined,
    txtLineThickness    = undefined,
    sliderOverhang      = undefined,
    txtOverhang         = undefined,
    sliderExtensionGap  = undefined,
    txtExtensionGap     = undefined,

    cbTerminalType      = undefined,
    sliderTerminalSize  = undefined,
    txtTerminalSize     = undefined,
    cbTerminalPlacement = undefined,
    txtTerminalAngle    = undefined,

    btnApplySelection = undefined,
    btnApplyAll = undefined,
    btnSaveStyle      = undefined,

    -- -----------------------------------------------------------------
    -- Estado do draft e contrato de transicao
    -- -----------------------------------------------------------------
    fn setCurrentDraft draftValue =
    (
        currentDraft = draftValue
        draftSceneGeneration = if draftValue != undefined then sceneGeneration else -1
        currentDraft
    ),

    fn ensureCurrentDraft styleId:"default" =
    (
        if currentDraft == undefined or draftSceneGeneration != sceneGeneration or currentDraft.styleRecord == undefined do
        (
            if ::AmenoStyleService != undefined then
                this.setCurrentDraft (::AmenoStyleService.createDraftFromStyle styleId)
            else
            (
                local fallbackDraft = AmenoStyleDraft()
                fallbackDraft.styleRecord = AmenoStyleRecord()
                this.setCurrentDraft fallbackDraft
            )
        )
        currentDraft
    ),

    fn discardCurrentDraft clearDraft:true =
    (
        if currentDraft != undefined and ::AmenoStyleService != undefined do
            try (::AmenoStyleService.discardDraft currentDraft) catch ()
        if clearDraft then
        (
            currentDraft = undefined
            draftSceneGeneration = -1
        )
        true
    ),

    fn setDirtyDecision decision =
    (
        dirtyDecisionOverride = decision
        decision
    ),

    fn resolveDirtyDecision contextLabel =
    (
        if dirtyDecisionOverride != undefined then
        (
            local decision = dirtyDecisionOverride
            dirtyDecisionOverride = undefined
            decision
        )
        else
        (
            local msgText = "O rascunho atual possui alteracoes nao salvas.\n\n" + \
                "Deseja salvar antes de " + contextLabel + "?"
            local result = (dotNetClass "System.Windows.MessageBox").Show \
                msgText "Rascunho de estilo" \
                (dotNetClass "System.Windows.MessageBoxButton").YesNoCancel \
                (dotNetClass "System.Windows.MessageBoxImage").Warning
            local resultType = dotNetClass "System.Windows.MessageBoxResult"
            if result == resultType.Yes then #save
            else if result == resultType.No then #discard
            else #cancel
        )
    ),

    fn saveDraftForTransition =
    (
        if currentDraft == undefined or not currentDraft.isDirty then return true
        if ::AmenoStyleService == undefined then return false
        try
        (
            ::AmenoStyleService.saveDraftAsStyle currentDraft
            true
        )
        catch
        (
            if txtPreviewStatus != undefined do
                txtPreviewStatus.Text = "Nao foi possivel salvar o rascunho"
            false
        )
    ),

    fn resolveDirtyDraft contextLabel =
    (
        if currentDraft == undefined or not currentDraft.isDirty then return true
        local decision = this.resolveDirtyDecision contextLabel
        case decision of
        (
            #save: this.saveDraftForTransition()
            #discard: (this.discardCurrentDraft(); true)
            default: false
        )
    ),

    fn findStyle styleId =
    (
        if ::AmenoStyleService == undefined then undefined
        else
        (
            local stylesList = ::AmenoStyleService.listStyles()
            for styleRecord in stylesList where styleRecord.styleId == styleId do return styleRecord
            undefined
        )
    ),

    fn requestStyleSwitch styleId =
    (
        if styleId == undefined or styleId == "" do return false
        if currentDraft != undefined and currentDraft.sourceStyleId == styleId and currentDraft.styleRecord != undefined do
        (
            this.loadDraftToUI()
            return true
        )
        if this.findStyle styleId == undefined do return false
        if not this.resolveDirtyDraft "trocar de estilo" do
        (
            this.loadDraftToUI()
            return false
        )
        if ::AmenoStyleService == undefined then return false
        this.setCurrentDraft (::AmenoStyleService.createDraftFromStyle styleId)
        this.loadDraftToUI()
        if txtPreviewStatus != undefined do
            txtPreviewStatus.Text = "Editando estilo '" + currentDraft.styleRecord.name + "'"
        true
    ),

    fn onSceneSelectionChanged =
    (
        if currentDraft == undefined do return false
        this.updateInUseCount()
        if txtPreviewStatus != undefined do
        (
            local selectedDimensionIds = #()
            if ::AmenoDimensionGraphics != undefined do
            (
                for obj in selection where isValidNode obj do
                (
                    local dimId = ::AmenoDimensionGraphics.getDimensionId obj
                    if dimId != "" and (findItem selectedDimensionIds dimId) == 0 do
                        append selectedDimensionIds dimId
                )
            )
            local selectedCount = selectedDimensionIds.count
            if selectedCount > 0 then
                txtPreviewStatus.Text = (selectedCount as string) + " elemento(s) selecionado(s) pronto(s) para aplicacao"
            else if currentDraft.isDirty then
                txtPreviewStatus.Text = "Rascunho com alteracoes nao salvas"
            else
                txtPreviewStatus.Text = "Pronto"
        )
        true
    ),

    fn registerCallbacks =
    (
        try (callbacks.removeScripts id:#amenoCotasStyleSelection) catch ()
        local callbackText = "if ::AmenoCotasWindow != undefined and ::AmenoCotasWindow.isOpen() and ::AmenoCotasWindow.activeSection == 2 and ::AmenoCotasEstilosTab != undefined do (try (::AmenoCotasEstilosTab.onSceneSelectionChanged()) catch ())"
        try (callbacks.addScript #selectionSetChanged callbackText id:#amenoCotasStyleSelection) catch ()
        callbacksRegistered = true
        true
    ),

    fn unregisterCallbacks =
    (
        try (callbacks.removeScripts id:#amenoCotasStyleSelection) catch ()
        callbacksRegistered = false
        true
    ),

    fn onSceneReset =
    (
        sceneGeneration += 1
        this.discardCurrentDraft()
        local wasSyncing = isSyncing
        isSyncing = true
        try
        (
            if hostControl != undefined do
            (
                this.ensureCurrentDraft()
                this.populateStyleList()
                this.populateFontList()
                this.loadDraftToUI()
                if txtPreviewStatus != undefined do txtPreviewStatus.Text = "Cena recarregada; rascunho anterior descartado"
            )
        )
        catch ()
        isSyncing = wasSyncing
        true
    ),

    fn refresh =
    (
        if currentDraft == undefined do this.ensureCurrentDraft()
        if hostControl == undefined then return true
        local wasSyncing = isSyncing
        isSyncing = true
        try
        (
            this.populateStyleList()
            this.populateFontList()
            this.loadDraftToUI()
        )
        catch ()
        isSyncing = wasSyncing
        this.updateDirtyUI()
        this.updateInUseCount()
        this.updatePreview()
        true
    ),

    fn prepareToClose =
    (
        if not this.resolveDirtyDraft "fechar a janela" do return false
        true
    ),

    fn onPanelClosed =
    (
        this.unregisterCallbacks()
        this.discardCurrentDraft()
        true
    ),

    -- -----------------------------------------------------------------
    -- XAML do UserControl (construido por concatenacao — sem @"..." verbatim)
    -- -----------------------------------------------------------------
    fn getXAMLString =
    (
        -- Estilos de ComboBoxToggleButton
        local resCbToggle = \
            "<ControlTemplate x:Key='ComboBoxToggleButton' TargetType='ToggleButton'>" + \
            "<Grid>" + \
            "<Grid.ColumnDefinitions>" + \
            "<ColumnDefinition />" + \
            "<ColumnDefinition Width='20' />" + \
            "</Grid.ColumnDefinitions>" + \
            "<Border x:Name='Border' Grid.ColumnSpan='2' CornerRadius='3' Background='#2D2D30' BorderBrush='#3F3F46' BorderThickness='1' />" + \
            "<Border Grid.Column='0' Margin='1' Background='#2D2D30' CornerRadius='2,0,0,2' />" + \
            "<Path x:Name='Arrow' Grid.Column='1' HorizontalAlignment='Center' VerticalAlignment='Center' Data='M 0 0 L 4 4 L 8 0 Z' Fill='#CCCCCC' />" + \
            "</Grid>" + \
            "<ControlTemplate.Triggers>" + \
            "<Trigger Property='IsMouseOver' Value='true'>" + \
            "<Setter TargetName='Border' Property='BorderBrush' Value='#007ACC' />" + \
            "<Setter TargetName='Arrow' Property='Fill' Value='#FFFFFF' />" + \
            "</Trigger>" + \
            "<Trigger Property='IsChecked' Value='true'>" + \
            "<Setter TargetName='Border' Property='BorderBrush' Value='#007ACC' />" + \
            "</Trigger>" + \
            "<Trigger Property='IsEnabled' Value='false'>" + \
            "<Setter TargetName='Border' Property='Background' Value='#222222' />" + \
            "<Setter TargetName='Border' Property='BorderBrush' Value='#333333' />" + \
            "<Setter TargetName='Arrow' Property='Fill' Value='#555555' />" + \
            "</Trigger>" + \
            "</ControlTemplate.Triggers>" + \
            "</ControlTemplate>"

        -- Estilo de Item do ComboBox
        local resCbItem = \
            "<Style TargetType='ComboBoxItem'>" + \
            "<Setter Property='SnapsToDevicePixels' Value='true' />" + \
            "<Setter Property='OverridesDefaultStyle' Value='true' />" + \
            "<Setter Property='Template'><Setter.Value>" + \
            "<ControlTemplate TargetType='ComboBoxItem'>" + \
            "<Border x:Name='Border' Padding='6,4' SnapsToDevicePixels='true' Background='#252526'>" + \
            "<ContentPresenter TextElement.Foreground='#E0E0E0' />" + \
            "</Border>" + \
            "<ControlTemplate.Triggers>" + \
            "<Trigger Property='IsHighlighted' Value='true'>" + \
            "<Setter TargetName='Border' Property='Background' Value='#0E639C' />" + \
            "<Setter Property='TextElement.Foreground' Value='#FFFFFF' />" + \
            "</Trigger>" + \
            "<Trigger Property='IsSelected' Value='true'>" + \
            "<Setter TargetName='Border' Property='Background' Value='#1177BB' />" + \
            "<Setter Property='TextElement.Foreground' Value='#FFFFFF' />" + \
            "</Trigger>" + \
            "<Trigger Property='IsEnabled' Value='false'>" + \
            "<Setter Property='TextElement.Foreground' Value='#666666' />" + \
            "</Trigger>" + \
            "</ControlTemplate.Triggers>" + \
            "</ControlTemplate></Setter.Value></Setter>" + \
            "</Style>"

        -- Estilo global de ComboBox escuro
        local resCb = \
            "<Style TargetType='ComboBox'>" + \
            "<Setter Property='SnapsToDevicePixels' Value='true' />" + \
            "<Setter Property='OverridesDefaultStyle' Value='true' />" + \
            "<Setter Property='ScrollViewer.HorizontalScrollBarVisibility' Value='Auto' />" + \
            "<Setter Property='ScrollViewer.VerticalScrollBarVisibility' Value='Auto' />" + \
            "<Setter Property='ScrollViewer.CanContentScroll' Value='true' />" + \
            "<Setter Property='Foreground' Value='#FFFFFF' />" + \
            "<Setter Property='Template'><Setter.Value>" + \
            "<ControlTemplate TargetType='ComboBox'>" + \
            "<Grid>" + \
            "<ToggleButton Name='ToggleButton' Template='{StaticResource ComboBoxToggleButton}' Grid.Column='2' Focusable='false'" + \
            " IsChecked='{Binding Path=IsDropDownOpen,Mode=TwoWay,RelativeSource={RelativeSource TemplatedParent}}' ClickMode='Press' />" + \
            "<ContentPresenter Name='ContentSite' IsHitTestVisible='false'" + \
            " Content='{TemplateBinding SelectionBoxItem}'" + \
            " ContentTemplate='{TemplateBinding SelectionBoxItemTemplate}'" + \
            " ContentTemplateSelector='{TemplateBinding ItemTemplateSelector}'" + \
            " Margin='8,3,23,3' VerticalAlignment='Center' HorizontalAlignment='Left'" + \
            " TextElement.Foreground='#FFFFFF' />" + \
            "<Popup Name='Popup' Placement='Bottom' IsOpen='{TemplateBinding IsDropDownOpen}' AllowsTransparency='true' Focusable='false' PopupAnimation='Slide'>" + \
            "<Grid Name='DropDown' SnapsToDevicePixels='true' MinWidth='{TemplateBinding ActualWidth}' MaxHeight='{TemplateBinding MaxDropDownHeight}'>" + \
            "<Border x:Name='DropDownBorder' Background='#252526' BorderThickness='1' BorderBrush='#3F3F46' CornerRadius='3' Margin='0,2,0,4' />" + \
            "<ScrollViewer Margin='2,4,2,6' SnapsToDevicePixels='true'>" + \
            "<StackPanel IsItemsHost='True' KeyboardNavigation.DirectionalNavigation='Contained' />" + \
            "</ScrollViewer>" + \
            "</Grid>" + \
            "</Popup>" + \
            "</Grid>" + \
            "<ControlTemplate.Triggers>" + \
            "<Trigger Property='HasItems' Value='false'>" + \
            "<Setter TargetName='DropDownBorder' Property='MinHeight' Value='95' />" + \
            "</Trigger>" + \
            "<Trigger Property='IsEnabled' Value='false'>" + \
            "<Setter Property='Foreground' Value='#666666' />" + \
            "</Trigger>" + \
            "<Trigger Property='IsGrouping' Value='true'>" + \
            "<Setter Property='ScrollViewer.CanContentScroll' Value='false' />" + \
            "</Trigger>" + \
            "</ControlTemplate.Triggers>" + \
            "</ControlTemplate></Setter.Value></Setter>" + \
            "</Style>"

        local resources = "<UserControl.Resources>" + resCbToggle + resCbItem + resCb + "</UserControl.Resources>"

        -- TOPO: Barra de gerenciamento de estilos (Novo / Duplicar / Deletar + seletor)
        local topBar = \
            "<Border Background='#252526' BorderBrush='#333333' BorderThickness='0,0,0,1' Padding='10,8'>" + \
            "<DockPanel LastChildFill='True'>" + \
            "<StackPanel DockPanel.Dock='Right' Orientation='Horizontal' VerticalAlignment='Center'>" + \
            "<Button x:Name='btnNewStyle' Content='+ Novo' Height='24' Padding='8,2' Margin='0,0,4,0'" + \
            " Background='#0E639C' Foreground='#FFFFFF' BorderBrush='#1177BB'" + \
            " ToolTip='Criar um novo estilo em branco' />" + \
            "<Button x:Name='btnDuplicateStyle' Content='Duplicar' Height='24' Padding='8,2' Margin='0,0,4,0'" + \
            " Background='#333337' Foreground='#FFFFFF' BorderBrush='#444444'" + \
            " ToolTip='Duplicar o estilo selecionado' />" + \
            "<Button x:Name='btnDeleteStyle' Content='Deletar' Height='24' Padding='8,2'" + \
            " Background='#5A1A1A' Foreground='#E06C75' BorderBrush='#7A2222'" + \
            " ToolTip='Deletar o estilo selecionado (nao pode ser desfeito)' />" + \
            "</StackPanel>" + \
            "<StackPanel Orientation='Horizontal' VerticalAlignment='Center'>" + \
            "<TextBlock Text='Estilo:' Foreground='#CCCCCC' FontWeight='SemiBold' VerticalAlignment='Center' Margin='0,0,8,0'/>" + \
            "<ComboBox x:Name='cbStyleSelect' Width='180' Height='24' VerticalAlignment='Center'" + \
            " Background='#2D2D30' Foreground='#FFFFFF' BorderBrush='#3F3F46'" + \
            " ToolTip='Selecione o estilo para edicao' />" + \
            "<TextBlock x:Name='txtDirtyMark' Text='*' Foreground='#E06C75' FontWeight='Bold' FontSize='16'" + \
            " VerticalAlignment='Center' Margin='4,0,8,0' Visibility='Collapsed'" + \
            " ToolTip='Alteracoes nao salvas no rascunho'/>" + \
            "<TextBlock x:Name='txtInUseCount' Text='Em uso: 0 cota(s)' Foreground='#888888' VerticalAlignment='Center' Margin='6,0,0,0'/>" + \
            "</StackPanel>" + \
            "</DockPanel>" + \
            "</Border>"

        -- CORPO: layout duas colunas (preview | controles)
        local previewToolbar = \
            "<Border Background='#222222' BorderBrush='#2A2A2A' BorderThickness='0,0,0,1' Padding='8,4'>" + \
            "<DockPanel LastChildFill='True'>" + \
            "<StackPanel DockPanel.Dock='Right' Orientation='Horizontal'>" + \
            "<TextBlock Text='Zoom:' Foreground='#888888' VerticalAlignment='Center' Margin='0,0,6,0' FontSize='11'/>" + \
            "<Button x:Name='btnZoom50' Content='50%' Width='40' Height='20' Margin='0,0,2,0' FontSize='10'" + \
            " Background='#2D2D30' Foreground='#CCCCCC' BorderBrush='#3F3F46' ToolTip='Zoom 50%' />" + \
            "<Button x:Name='btnZoom100' Content='100%' Width='44' Height='20' Margin='0,0,2,0' FontSize='10'" + \
            " Background='#383838' Foreground='#FFFFFF' BorderBrush='#555555' ToolTip='Zoom 100%' />" + \
            "<Button x:Name='btnZoom200' Content='200%' Width='40' Height='20' Margin='0,0,8,0' FontSize='10'" + \
            " Background='#2D2D30' Foreground='#CCCCCC' BorderBrush='#3F3F46' ToolTip='Zoom 200%' />" + \
            "<Button x:Name='btnToggleBg' Content='Fundo' Width='52' Height='20' FontSize='10'" + \
            " Background='#2D2D30' Foreground='#CCCCCC' BorderBrush='#3F3F46' ToolTip='Alternar fundo claro/escuro do preview' />" + \
            "</StackPanel>" + \
            "<TextBlock Text='Preview ao vivo' Foreground='#9CDCFE' FontWeight='SemiBold' VerticalAlignment='Center' FontSize='11'/>" + \
            "</DockPanel>" + \
            "</Border>"

        local previewCanvas = \
            "<Border x:Name='pnlPreviewHost' Grid.Row='1' Background='#121212' ClipToBounds='True'>" + \
            "<Canvas x:Name='previewCanvas' HorizontalAlignment='Stretch' VerticalAlignment='Stretch' />" + \
            "</Border>"

        local previewStatus = \
            "<Border Grid.Row='2' Background='#181818' BorderBrush='#2A2A2A' BorderThickness='0,1,0,0' Padding='8,4'>" + \
            "<TextBlock x:Name='txtPreviewStatus' Text='Pronto' Foreground='#777777' FontSize='10' VerticalAlignment='Center'/>" + \
            "</Border>"

        local previewCol = \
            "<Border Grid.Column='0' Background='#181818' BorderBrush='#2A2A2A' BorderThickness='1' CornerRadius='4'>" + \
            "<Grid>" + \
            "<Grid.RowDefinitions>" + \
            "<RowDefinition Height='Auto'/>" + \
            "<RowDefinition Height='*'/>" + \
            "<RowDefinition Height='Auto'/>" + \
            "</Grid.RowDefinitions>" + \
            "<Border Grid.Row='0'>" + previewToolbar + "</Border>" + \
            previewCanvas + \
            previewStatus + \
            "</Grid>" + \
            "</Border>"

        -- Controles direita: Tipografia
        local grpTypo = \
            "<Border Background='#202022' BorderBrush='#303034' BorderThickness='1' CornerRadius='3' Padding='8' Margin='0,0,0,10'>" + \
            "<StackPanel>" + \
            "<TextBlock Text='TEXTO / TIPOGRAFIA' Foreground='#61AFEF' FontWeight='Bold' FontSize='11' Margin='0,0,0,8'/>" + \
            "<Grid Margin='0,0,0,6'><Grid.ColumnDefinitions><ColumnDefinition Width='75'/><ColumnDefinition Width='*'/></Grid.ColumnDefinitions>" + \
            "<TextBlock Text='Fonte:' Foreground='#CCCCCC' VerticalAlignment='Center'/>" + \
            "<ComboBox x:Name='cbFontName' Grid.Column='1' Height='24' Background='#2D2D30' Foreground='#FFFFFF' BorderBrush='#3F3F46' ToolTip='Familia tipografica da cota' />" + \
            "</Grid>" + \
            "<Grid Margin='0,0,0,6'><Grid.ColumnDefinitions><ColumnDefinition Width='75'/><ColumnDefinition Width='*'/><ColumnDefinition Width='50'/><ColumnDefinition Width='Auto'/></Grid.ColumnDefinitions>" + \
            "<TextBlock Text='Tamanho:' Foreground='#CCCCCC' VerticalAlignment='Center'/>" + \
            "<Slider x:Name='sliderFontSize' Grid.Column='1' Minimum='10' Maximum='500' Value='140' VerticalAlignment='Center' Margin='0,0,6,0' ToolTip='Tamanho da fonte em mm de cena' />" + \
            "<TextBox x:Name='txtFontSize' Grid.Column='2' Text='140.0' Height='22' Background='#2D2D30' Foreground='#FFFFFF' BorderBrush='#3F3F46' HorizontalContentAlignment='Center' VerticalAlignment='Center' Margin='0,0,8,0' />" + \
            "<StackPanel Grid.Column='3' Orientation='Horizontal' VerticalAlignment='Center'>" + \
            "<CheckBox x:Name='chkBold' Content='N' FontWeight='Bold' Foreground='#FFFFFF' Margin='0,0,6,0' ToolTip='Negrito' />" + \
            "<CheckBox x:Name='chkItalic' Content='I' FontStyle='Italic' Foreground='#FFFFFF' ToolTip='Italico' />" + \
            "</StackPanel>" + \
            "</Grid>" + \
            "<Grid Margin='0,0,0,6'><Grid.ColumnDefinitions><ColumnDefinition Width='75'/><ColumnDefinition Width='*'/><ColumnDefinition Width='50'/></Grid.ColumnDefinitions>" + \
            "<TextBlock Text='Tracking:' Foreground='#CCCCCC' VerticalAlignment='Center'/>" + \
            "<Slider x:Name='sliderTracking' Grid.Column='1' Minimum='-10' Maximum='50' Value='0' VerticalAlignment='Center' Margin='0,0,6,0' ToolTip='Espacamento entre caracteres' />" + \
            "<TextBox x:Name='txtTracking' Grid.Column='2' Text='0.0' Height='22' Background='#2D2D30' Foreground='#FFFFFF' BorderBrush='#3F3F46' HorizontalContentAlignment='Center' VerticalAlignment='Center' />" + \
            "</Grid>" + \
            "<Grid Margin='0,0,0,2'><Grid.ColumnDefinitions><ColumnDefinition Width='75'/><ColumnDefinition Width='*'/><ColumnDefinition Width='50'/><ColumnDefinition Width='Auto'/></Grid.ColumnDefinitions>" + \
            "<TextBlock Text='Afastamento:' Foreground='#CCCCCC' VerticalAlignment='Center'/>" + \
            "<Slider x:Name='sliderTextGap' Grid.Column='1' Minimum='0' Maximum='250' Value='60' VerticalAlignment='Center' Margin='0,0,6,0' ToolTip='Distancia do texto em relacao a linha de cota' />" + \
            "<TextBox x:Name='txtTextGap' Grid.Column='2' Text='60.0' Height='22' Background='#2D2D30' Foreground='#FFFFFF' BorderBrush='#3F3F46' HorizontalContentAlignment='Center' VerticalAlignment='Center' Margin='0,0,8,0' />" + \
            "<CheckBox x:Name='chkTextMask' Grid.Column='3' Content='Mascara' Foreground='#FFFFFF' VerticalAlignment='Center' ToolTip='Ocultar linhas sob o texto' />" + \
            "</Grid>" + \
            "</StackPanel>" + \
            "</Border>"

        -- Linhas de cota
        local grpLines = \
            "<Border Background='#202022' BorderBrush='#303034' BorderThickness='1' CornerRadius='3' Padding='8' Margin='0,0,0,10'>" + \
            "<StackPanel>" + \
            "<TextBlock Text='LINHAS DE COTA' Foreground='#61AFEF' FontWeight='Bold' FontSize='11' Margin='0,0,0,8'/>" + \
            "<Grid Margin='0,0,0,6'><Grid.ColumnDefinitions><ColumnDefinition Width='75'/><ColumnDefinition Width='*'/></Grid.ColumnDefinitions>" + \
            "<TextBlock Text='Atalhos:' Foreground='#CCCCCC' VerticalAlignment='Center'/>" + \
            "<StackPanel Grid.Column='1' Orientation='Horizontal'>" + \
            "<Button x:Name='btnThin' Content='Fina (0.8)' Height='22' Padding='8,1' Margin='0,0,4,0' Background='#333337' Foreground='#FFFFFF' BorderBrush='#444444' ToolTip='Espessura 0.8 mm' />" + \
            "<Button x:Name='btnNorm' Content='Normal (1.5)' Height='22' Padding='8,1' Margin='0,0,4,0' Background='#333337' Foreground='#FFFFFF' BorderBrush='#444444' ToolTip='Espessura 1.5 mm' />" + \
            "<Button x:Name='btnThick' Content='Forte (2.5)' Height='22' Padding='8,1' Background='#333337' Foreground='#FFFFFF' BorderBrush='#444444' ToolTip='Espessura 2.5 mm' />" + \
            "</StackPanel>" + \
            "</Grid>" + \
            "<Grid Margin='0,0,0,6'><Grid.ColumnDefinitions><ColumnDefinition Width='75'/><ColumnDefinition Width='*'/><ColumnDefinition Width='50'/></Grid.ColumnDefinitions>" + \
            "<TextBlock Text='Espessura:' Foreground='#CCCCCC' VerticalAlignment='Center'/>" + \
            "<Slider x:Name='sliderLineThickness' Grid.Column='1' Minimum='0.2' Maximum='10' Value='1.5' VerticalAlignment='Center' Margin='0,0,6,0' ToolTip='Espessura da linha em mm' />" + \
            "<TextBox x:Name='txtLineThickness' Grid.Column='2' Text='1.5' Height='22' Background='#2D2D30' Foreground='#FFFFFF' BorderBrush='#3F3F46' HorizontalContentAlignment='Center' VerticalAlignment='Center' />" + \
            "</Grid>" + \
            "<Grid Margin='0,0,0,6'><Grid.ColumnDefinitions><ColumnDefinition Width='75'/><ColumnDefinition Width='*'/><ColumnDefinition Width='50'/></Grid.ColumnDefinitions>" + \
            "<TextBlock Text='Prolongar:' Foreground='#CCCCCC' VerticalAlignment='Center'/>" + \
            "<Slider x:Name='sliderOverhang' Grid.Column='1' Minimum='0' Maximum='300' Value='80' VerticalAlignment='Center' Margin='0,0,6,0' ToolTip='Extensao alem dos pontos cotados' />" + \
            "<TextBox x:Name='txtOverhang' Grid.Column='2' Text='80.0' Height='22' Background='#2D2D30' Foreground='#FFFFFF' BorderBrush='#3F3F46' HorizontalContentAlignment='Center' VerticalAlignment='Center' />" + \
            "</Grid>" + \
            "<Grid Margin='0,0,0,2'><Grid.ColumnDefinitions><ColumnDefinition Width='75'/><ColumnDefinition Width='*'/><ColumnDefinition Width='50'/></Grid.ColumnDefinitions>" + \
            "<TextBlock Text='Recuo:' Foreground='#CCCCCC' VerticalAlignment='Center'/>" + \
            "<Slider x:Name='sliderExtensionGap' Grid.Column='1' Minimum='0' Maximum='200' Value='0' VerticalAlignment='Center' Margin='0,0,6,0' ToolTip='Espaco entre pontos cotados e extensoes' />" + \
            "<TextBox x:Name='txtExtensionGap' Grid.Column='2' Text='0.0' Height='22' Background='#2D2D30' Foreground='#FFFFFF' BorderBrush='#3F3F46' HorizontalContentAlignment='Center' VerticalAlignment='Center' />" + \
            "</Grid>" + \
            "</StackPanel>" + \
            "</Border>"

        -- Setas e Terminais
        local grpTerminals = \
            "<Border Background='#202022' BorderBrush='#303034' BorderThickness='1' CornerRadius='3' Padding='8' Margin='0,0,0,10'>" + \
            "<StackPanel>" + \
            "<TextBlock Text='SETAS E TERMINAIS' Foreground='#61AFEF' FontWeight='Bold' FontSize='11' Margin='0,0,0,8'/>" + \
            "<Grid Margin='0,0,0,6'><Grid.ColumnDefinitions><ColumnDefinition Width='75'/><ColumnDefinition Width='*'/></Grid.ColumnDefinitions>" + \
            "<TextBlock Text='Terminal:' Foreground='#CCCCCC' VerticalAlignment='Center'/>" + \
            "<ComboBox x:Name='cbTerminalType' Grid.Column='1' Height='24' Background='#2D2D30' Foreground='#FFFFFF' BorderBrush='#3F3F46' ToolTip='Tipo grafico dos terminais' />" + \
            "</Grid>" + \
            "<Grid Margin='0,0,0,6'><Grid.ColumnDefinitions><ColumnDefinition Width='75'/><ColumnDefinition Width='*'/><ColumnDefinition Width='50'/></Grid.ColumnDefinitions>" + \
            "<TextBlock Text='Tamanho:' Foreground='#CCCCCC' VerticalAlignment='Center'/>" + \
            "<Slider x:Name='sliderTerminalSize' Grid.Column='1' Minimum='10' Maximum='300' Value='100' VerticalAlignment='Center' Margin='0,0,6,0' ToolTip='Tamanho do terminal em mm' />" + \
            "<TextBox x:Name='txtTerminalSize' Grid.Column='2' Text='100.0' Height='22' Background='#2D2D30' Foreground='#FFFFFF' BorderBrush='#3F3F46' HorizontalContentAlignment='Center' VerticalAlignment='Center' />" + \
            "</Grid>" + \
            "<Grid Margin='0,0,0,2'><Grid.ColumnDefinitions><ColumnDefinition Width='75'/><ColumnDefinition Width='*'/><ColumnDefinition Width='50'/></Grid.ColumnDefinitions>" + \
            "<TextBlock Text='Posicao:' Foreground='#CCCCCC' VerticalAlignment='Center'/>" + \
            "<ComboBox x:Name='cbTerminalPlacement' Grid.Column='1' Height='24' Background='#2D2D30' Foreground='#FFFFFF' BorderBrush='#3F3F46' Margin='0,0,6,0' ToolTip='Posicionamento das setas' />" + \
            "<TextBox x:Name='txtTerminalAngle' Grid.Column='2' Text='45' Height='22' Background='#2D2D30' Foreground='#FFFFFF' BorderBrush='#3F3F46' HorizontalContentAlignment='Center' VerticalAlignment='Center' IsReadOnly='True' />" + \
            "</Grid>" + \
            "</StackPanel>" + \
            "</Border>"

        -- Presets e acoes adicionais
        local grpPresets = \
            "<Border Background='#202022' BorderBrush='#303034' BorderThickness='1' CornerRadius='3' Padding='8' Margin='0,0,0,10'>" + \
            "<StackPanel>" + \
            "<TextBlock Text='PRESETS' Foreground='#61AFEF' FontWeight='Bold' FontSize='11' Margin='0,0,0,8'/>" + \
            "<StackPanel Orientation='Horizontal'>" + \
            "<Button x:Name='btnPresetArch' Content='Arquitetonico' Height='24' Padding='8,2' Margin='0,0,4,0' Background='#333337' Foreground='#FFFFFF' BorderBrush='#444444' ToolTip='Preset Arquitetonico (Arial, Traco 45)' />" + \
            "<Button x:Name='btnPresetEdit' Content='Editorial' Height='24' Padding='8,2' Margin='0,0,4,0' Background='#333337' Foreground='#FFFFFF' BorderBrush='#444444' ToolTip='Preset Editorial (Georgia, Ponto)' />" + \
            "<Button x:Name='btnPresetTech' Content='Tecnico' Height='24' Padding='8,2' Background='#333337' Foreground='#FFFFFF' BorderBrush='#444444' ToolTip='Preset Tecnico (Consolas, Seta Fechada)' />" + \
            "</StackPanel>" + \
            "</StackPanel>" + \
            "</Border>"

        -- Rodape de acoes
        local footer = \
            "<Border Margin='0,8,0,0'>" + \
            "<DockPanel LastChildFill='True'>" + \
            "<StackPanel DockPanel.Dock='Right' Orientation='Horizontal'>" + \
            "<Button x:Name='btnApplyAll' Content='Atualizar todas as cotas' Width='160' Height='28' Margin='0,0,8,0' Background='#333337' Foreground='#FFFFFF' BorderBrush='#444444' ToolTip='Aplicar este estilo a todas as cotas da cena' />" + \
            "<Button x:Name='btnApplySelection' Content='Aplicar as Selecionadas' Width='150' Height='28' Margin='0,0,8,0' Background='#333337' Foreground='#FFFFFF' BorderBrush='#444444' ToolTip='Aplicar rascunho de estilo as cotas selecionadas' />" + \
            "<Button x:Name='btnSaveStyle' Content='Salvar Estilo' Width='110' Height='28' Background='#0E639C' Foreground='#FFFFFF' BorderBrush='#1177BB' FontWeight='SemiBold' ToolTip='Salvar alteracoes no estilo e atualizar cotas vinculadas' />" + \
            "</StackPanel>" + \
            "<TextBlock Text='Atalhos: Ctrl+Enter: Aplicar  Ctrl+S: Salvar' Foreground='#777777' FontSize='10' VerticalAlignment='Center' />" + \
            "</DockPanel>" + \
            "</Border>"

        local controlsCol = \
            "<Border Grid.Column='2' Background='#252526' BorderBrush='#333333' BorderThickness='1' CornerRadius='4' Padding='10'>" + \
            "<ScrollViewer VerticalScrollBarVisibility='Auto' HorizontalScrollBarVisibility='Disabled'>" + \
            "<StackPanel>" + \
            grpTypo + \
            grpLines + \
            grpTerminals + \
            grpPresets + \
            footer + \
            "</StackPanel>" + \
            "</ScrollViewer>" + \
            "</Border>"

        local bodyGrid = \
            "<Grid Margin='10,10,10,0'>" + \
            "<Grid.ColumnDefinitions>" + \
            "<ColumnDefinition Width='1.1*' MinWidth='280'/>" + \
            "<ColumnDefinition Width='6'/>" + \
            "<ColumnDefinition Width='1.2*' MinWidth='320'/>" + \
            "</Grid.ColumnDefinitions>" + \
            previewCol + \
            "<GridSplitter Grid.Column='1' Width='6' HorizontalAlignment='Center' Background='#252526' ToolTip='Arraste para redimensionar'/>" + \
            controlsCol + \
            "</Grid>"

        local xaml = \
            "<UserControl xmlns='http://schemas.microsoft.com/winfx/2006/xaml/presentation'" + \
            " xmlns:x='http://schemas.microsoft.com/winfx/2006/xaml'" + \
            " Background='#1E1E1E' Foreground='#CCCCCC' FontFamily='Segoe UI' FontSize='12'>" + \
            resources + \
            "<Grid>" + \
            "<Grid.RowDefinitions>" + \
            "<RowDefinition Height='Auto'/>" + \
            "<RowDefinition Height='*'/>" + \
            "</Grid.RowDefinitions>" + \
            topBar + \
            "<Border Grid.Row='1' Margin='0,0,0,10'>" + bodyGrid + "</Border>" + \
            "</Grid>" + \
            "</UserControl>"

        xaml
    ),

    -- -----------------------------------------------------------------
    -- Helper para encontrar controles no UserControl
    -- -----------------------------------------------------------------
    fn findControl ctrlName =
    (
        if hostControl == undefined then undefined else hostControl.FindName ctrlName
    ),

    -- -----------------------------------------------------------------
    -- Atualizar indicador de "sujo" (alteracoes nao salvas)
    -- -----------------------------------------------------------------
    fn updateDirtyUI =
    (
        if txtDirtyMark == undefined or currentDraft == undefined do return false
        local visClass = dotNetClass "System.Windows.Visibility"
        if currentDraft.isDirty then
            txtDirtyMark.Visibility = visClass.Visible
        else
            txtDirtyMark.Visibility = visClass.Collapsed
    ),

    -- -----------------------------------------------------------------
    -- Atualizar contagem de cotas usando o estilo
    -- -----------------------------------------------------------------
    fn updateInUseCount =
    (
        if txtInUseCount == undefined or currentDraft == undefined or ::AmenoStyleService == undefined do return false
        local cnt = ::AmenoStyleService.countDimensionsUsingStyle currentDraft.sourceStyleId
        txtInUseCount.Text = "Em uso: " + (cnt as string) + " cota(s)"
    ),

    -- -----------------------------------------------------------------
    -- Renderizar preview ao vivo
    -- -----------------------------------------------------------------
    fn updatePreview =
    (
        if previewCanvas == undefined or currentDraft == undefined do return false
        if ::AmenoPreviewRenderer != undefined do
        (
            local pm = currentDraft.toPreviewModel()
            ::AmenoPreviewRenderer.render pm previewCanvas
        )
    ),

    -- -----------------------------------------------------------------
    -- Popular seletor de estilos
    -- -----------------------------------------------------------------
    fn populateStyleList =
    (
        if cbStyleSelect == undefined or ::AmenoStyleService == undefined do return false
        cbStyleSelect.Items.Clear()
        local stylesList = ::AmenoStyleService.listStyles()
        local selIdx = -1
        for i = 1 to stylesList.count do
        (
            cbStyleSelect.Items.Add stylesList[i].name
            if currentDraft != undefined and stylesList[i].styleId == currentDraft.sourceStyleId do
                selIdx = (i - 1)
        )
        if selIdx >= 0 then cbStyleSelect.SelectedIndex = selIdx
        else if cbStyleSelect.Items.Count > 0 do cbStyleSelect.SelectedIndex = 0
    ),

    -- -----------------------------------------------------------------
    -- Popular lista de fontes
    -- -----------------------------------------------------------------
    fn populateFontList =
    (
        if cbFontName == undefined or ::AmenoStyleService == undefined do return false
        cbFontName.Items.Clear()
        local fonts = ::AmenoStyleService.getInstalledFonts()
        local selIdx = -1
        local curFont = if currentDraft != undefined and currentDraft.styleRecord != undefined then (currentDraft.styleRecord.fontName as string) else "Arial"
        for i = 1 to fonts.count do
        (
            cbFontName.Items.Add fonts[i]
            if (stricmp fonts[i] curFont) == 0 do selIdx = (i - 1)
        )
        if selIdx >= 0 then cbFontName.SelectedIndex = selIdx
        else if cbFontName.Items.Count > 0 do cbFontName.SelectedIndex = 0
    ),

    -- -----------------------------------------------------------------
    -- Popular opcoes de terminal
    -- -----------------------------------------------------------------
    fn populateTerminalOptions =
    (
        if cbTerminalType != undefined do
        (
            cbTerminalType.Items.Clear()
            cbTerminalType.Items.Add "Traco Arquitetonico (45)"
            cbTerminalType.Items.Add "Seta Fechada"
            cbTerminalType.Items.Add "Seta Aberta"
            cbTerminalType.Items.Add "Ponto / Losango"
            cbTerminalType.Items.Add "Nenhum"
        )
        if cbTerminalPlacement != undefined do
        (
            cbTerminalPlacement.Items.Clear()
            cbTerminalPlacement.Items.Add "Automatica"
            cbTerminalPlacement.Items.Add "Interna"
            cbTerminalPlacement.Items.Add "Externa"
        )
    ),

    -- -----------------------------------------------------------------
    -- Carregar rascunho para os controles
    -- -----------------------------------------------------------------
    fn loadDraftToUI =
    (
        if currentDraft == undefined or currentDraft.styleRecord == undefined do return false
        isSyncing = true
        try
        (
            local rec = currentDraft.styleRecord

            -- Sincronizar seletor de estilo
            if cbStyleSelect != undefined and ::AmenoStyleService != undefined do
            (
                local stylesList = ::AmenoStyleService.listStyles()
                local sIdx = -1
                for i = 1 to stylesList.count do
                (
                    if stylesList[i].styleId == currentDraft.sourceStyleId or (stricmp stylesList[i].name rec.name) == 0 do
                    (
                        sIdx = (i - 1)
                        exit
                    )
                )
                if sIdx >= 0 and cbStyleSelect.SelectedIndex != sIdx do
                    cbStyleSelect.SelectedIndex = sIdx
            )

            -- Fonte
            if cbFontName != undefined do
            (
                local found = false
                local targetFont = rec.fontName as string
                for i = 0 to (cbFontName.Items.Count - 1) do
                (
                    local itemStr = (cbFontName.Items.GetItemAt i) as string
                    if (stricmp itemStr targetFont) == 0 do
                    (
                        cbFontName.SelectedIndex = i
                        found = true
                        exit
                    )
                )
                if not found and cbFontName.Items.Count > 0 do cbFontName.SelectedIndex = 0
            )

            if sliderFontSize != undefined do sliderFontSize.Value = rec.fontSize
            if txtFontSize != undefined do txtFontSize.Text = (rec.fontSize as string)
            if chkBold != undefined do chkBold.IsChecked = (dotNetObject "System.Nullable`1[System.Boolean]" rec.bold)
            if chkItalic != undefined do chkItalic.IsChecked = (dotNetObject "System.Nullable`1[System.Boolean]" rec.italic)
            if sliderTracking != undefined do sliderTracking.Value = rec.tracking
            if txtTracking != undefined do txtTracking.Text = (rec.tracking as string)
            if sliderTextGap != undefined do sliderTextGap.Value = rec.textGap
            if txtTextGap != undefined do txtTextGap.Text = (rec.textGap as string)
            if chkTextMask != undefined do chkTextMask.IsChecked = (dotNetObject "System.Nullable`1[System.Boolean]" rec.textMaskEnabled)

            if sliderLineThickness != undefined do sliderLineThickness.Value = rec.lineThickness
            if txtLineThickness != undefined do txtLineThickness.Text = (rec.lineThickness as string)
            if sliderOverhang != undefined do sliderOverhang.Value = rec.extensionOverhang
            if txtOverhang != undefined do txtOverhang.Text = (rec.extensionOverhang as string)
            if sliderExtensionGap != undefined do sliderExtensionGap.Value = rec.extensionGap
            if txtExtensionGap != undefined do txtExtensionGap.Text = (rec.extensionGap as string)

            if cbTerminalType != undefined do
            (
                local tIdx = case rec.terminalType of
                (
                    #tick: 0
                    #arrowClosed: 1
                    #arrowOpen: 2
                    #dot: 3
                    #none: 4
                    default: 0
                )
                cbTerminalType.SelectedIndex = tIdx
            )

            if sliderTerminalSize != undefined do sliderTerminalSize.Value = rec.terminalSize
            if txtTerminalSize != undefined do txtTerminalSize.Text = (rec.terminalSize as string)

            if cbTerminalPlacement != undefined do
            (
                local pIdx = case rec.terminalPlacement of
                (
                    #auto: 0
                    #inside: 1
                    #outside: 2
                    default: 0
                )
                cbTerminalPlacement.SelectedIndex = pIdx
            )

            if txtTerminalAngle != undefined do txtTerminalAngle.Text = ((rec.terminalAngle as integer) as string) + ""

            updateDirtyUI()
            updateInUseCount()
            updatePreview()
        )
        catch ()
        isSyncing = false
        true
    ),

    -- -----------------------------------------------------------------
    -- Notificar mudanca em campo do rascunho
    -- -----------------------------------------------------------------
    fn onFieldChanged propName newVal =
    (
        if isSyncing or currentDraft == undefined or currentDraft.styleRecord == undefined do return false
        setProperty currentDraft.styleRecord propName newVal
        currentDraft.markDirty()
        updateDirtyUI()
        updatePreview()
    ),

    -- -----------------------------------------------------------------
    -- Salvar estilo atual
    -- -----------------------------------------------------------------
    fn promptStyleName initialName =
    (
        dotNet.loadAssembly "System.Windows.Forms"
        local form = dotNetObject "System.Windows.Forms.Form"
        form.Text = "Nome do estilo"
        form.Width = 380
        form.Height = 150
        form.StartPosition = (dotNetClass "System.Windows.Forms.FormStartPosition").CenterScreen
        local input = dotNetObject "System.Windows.Forms.TextBox"
        input.Text = initialName
        input.SetBounds 16 16 330 24
        local ok = dotNetObject "System.Windows.Forms.Button"
        ok.Text = "Salvar"
        ok.SetBounds 170 55 85 28
        ok.DialogResult = (dotNetClass "System.Windows.Forms.DialogResult").OK
        local cancel = dotNetObject "System.Windows.Forms.Button"
        cancel.Text = "Cancelar"
        cancel.SetBounds 261 55 85 28
        cancel.DialogResult = (dotNetClass "System.Windows.Forms.DialogResult").Cancel
        form.Controls.Add input
        form.Controls.Add ok
        form.Controls.Add cancel
        form.AcceptButton = ok
        form.CancelButton = cancel
        local result = form.ShowDialog()
        local value = if result == ok.DialogResult then (trimRight (trimLeft (input.Text as string))) else undefined
        form.Dispose()
        value
    ),

    fn onSaveStyle nameValue:undefined =
    (
        if currentDraft == undefined or ::AmenoStyleService == undefined do return 0
        local chosenName = if nameValue != undefined then nameValue else this.promptStyleName currentDraft.styleRecord.name
        if chosenName == undefined do return 0
        chosenName = trimRight (trimLeft chosenName)
        if chosenName == "" do
        (
            if txtPreviewStatus != undefined do txtPreviewStatus.Text = "Informe um nome para o estilo."
            return 0
        )
        for existing in ::AmenoStyleService.listStyles() where existing.styleId != currentDraft.styleRecord.styleId and (stricmp existing.name chosenName) == 0 do
        (
            if txtPreviewStatus != undefined do txtPreviewStatus.Text = "Ja existe um estilo com esse nome."
            return 0
        )
        currentDraft.styleRecord.name = chosenName
        try
        (
            local cnt = ::AmenoStyleService.saveDraftAsStyle currentDraft
            this.populateStyleList()
            updateDirtyUI()
            updateInUseCount()
            if txtPreviewStatus != undefined do
                txtPreviewStatus.Text = "Estilo '" + currentDraft.styleRecord.name + "' salvo (" + (cnt as string) + " cotas sincronizadas)"
            cnt
        )
        catch
        (
            if txtPreviewStatus != undefined do
                txtPreviewStatus.Text = "Erro ao salvar estilo"
            0
        )
    ),

    -- Cancelar explicitamente descarta o draft sem tocar no estilo persistido.
    -- O fechamento da janela usa prepareToClose(), que oferece Save/Discard/Cancel.
    fn onCancel =
    (
        this.discardCurrentDraft()
        true
    ),

    -- -----------------------------------------------------------------
    -- Aplicar rascunho as cotas selecionadas
    -- -----------------------------------------------------------------
    fn onApplyToSelection allDimensions:false =
    (
        if currentDraft == undefined or ::AmenoStyleService == undefined do return 0
        if not allDimensions and selection.count == 0 do
        (
            if txtPreviewStatus != undefined do
                txtPreviewStatus.Text = "Nenhuma cota selecionada na cena"
            return 0
        )
        try
        (
            local cnt = ::AmenoStyleService.applyDraftToSelection currentDraft allDimensions:allDimensions
            updateInUseCount()
            if txtPreviewStatus != undefined do
                txtPreviewStatus.Text = "Estilo aplicado a " + (cnt as string) + " cota(s)"
            cnt
        )
        catch
        (
            if txtPreviewStatus != undefined do
                txtPreviewStatus.Text = "Erro ao aplicar estilo"
            0
        )
    ),

    -- -----------------------------------------------------------------
    -- Criar novo estilo em branco
    -- -----------------------------------------------------------------
    fn onNewStyle =
    (
        if ::AmenoStyleService == undefined do return false
        if not this.resolveDirtyDraft "criar um novo estilo" do return false
        local chosenName = this.promptStyleName ""
        if chosenName == undefined or chosenName == "" do return false
        try
        (
            local newRec = ::AmenoStyleService.saveAsNewStyle chosenName undefined
            this.setCurrentDraft (::AmenoStyleService.createDraftFromStyle newRec.styleId)
            this.populateStyleList()
            this.loadDraftToUI()
            if txtPreviewStatus != undefined do
                txtPreviewStatus.Text = "Novo estilo criado: " + newRec.name
            true
        )
        catch (false)
    ),

    -- -----------------------------------------------------------------
    -- Duplicar estilo atual
    -- -----------------------------------------------------------------
    fn onDuplicateStyle =
    (
        if currentDraft == undefined or ::AmenoStyleService == undefined do return undefined
        try
        (
            local baseName = currentDraft.styleRecord.name
            local created = ::AmenoStyleService.saveDraftAsNewStyle currentDraft newName:(baseName + " (Copia)")
            if created != undefined do
            (
                this.populateStyleList()
                this.loadDraftToUI()
                if txtPreviewStatus != undefined do
                    txtPreviewStatus.Text = "Estilo duplicado: " + created.name
            )
            created
        )
        catch (undefined)
    ),

    -- -----------------------------------------------------------------
    -- Deletar estilo atual (com confirmacao)
    -- -----------------------------------------------------------------
    fn onDeleteStyle =
    (
        if currentDraft == undefined or ::AmenoStyleService == undefined do return false
        try
        (
            local targetId = currentDraft.sourceStyleId
            local inUseCount = ::AmenoStyleService.countDimensionsUsingStyle targetId
            if inUseCount > 0 do
            (
                if txtPreviewStatus != undefined do
                    txtPreviewStatus.Text = "Nao e possivel excluir um estilo em uso (" + (inUseCount as string) + " cota(s))"
                return false
            )
            local existingStyles = ::AmenoStyleService.listStyles()
            if existingStyles.count <= 1 do
            (
                if txtPreviewStatus != undefined do
                    txtPreviewStatus.Text = "Nao e possivel excluir o ultimo estilo"
                return false
            )
            if not this.resolveDirtyDraft "excluir o estilo" do return false
            local msgBtnType  = dotNetClass "System.Windows.MessageBoxButton"
            local msgIconType = dotNetClass "System.Windows.MessageBoxImage"
            local msgResType  = dotNetClass "System.Windows.MessageBoxResult"
            local msgText = "Deseja remover o estilo '" + currentDraft.styleRecord.name + "'?\n\nEsta acao nao pode ser desfeita."
            local dlgResult = (dotNetClass "System.Windows.MessageBox").Show \
                msgText "Confirmar exclusao" msgBtnType.YesNo msgIconType.Warning
            if dlgResult == msgResType.Yes do
            (
                -- Remover o estilo do servico
                local allStyles = ::AmenoStyleService.listStyles()
                local remaining = #()
                local targetId = currentDraft.sourceStyleId
                for s in allStyles where s.styleId != targetId do append remaining s
                ::AmenoStyleService.styles = remaining
                ::AmenoStyleService.saveToScene()
                -- Selecionar primeiro estilo disponivel
                local newStyles = ::AmenoStyleService.listStyles()
                local newId = if newStyles.count > 0 then newStyles[1].styleId else "default"
                this.setCurrentDraft (::AmenoStyleService.createDraftFromStyle newId)
                this.populateStyleList()
                this.loadDraftToUI()
                if txtPreviewStatus != undefined do
                    txtPreviewStatus.Text = "Estilo removido"
            )
            true
        )
        catch (false)
    ),

    -- -----------------------------------------------------------------
    -- Carregar preset
    -- -----------------------------------------------------------------
    fn onPresetClick presetId =
    (
        if ::AmenoStyleService == undefined do return false
        if not this.resolveDirtyDraft "carregar um preset" do return false
        this.setCurrentDraft (::AmenoStyleService.createDraftFromPreset presetId)
        this.loadDraftToUI()
        this.updateDirtyUI()
        this.updatePreview()
        true
    ),

    -- -----------------------------------------------------------------
    -- Bind de eventos (fn globais, try..catch obrigatorio)
    -- -----------------------------------------------------------------
    fn bindEvents =
    (
        -- Seletor de estilo
        if cbStyleSelect != undefined do
            dotNet.addEventHandler cbStyleSelect "SelectionChanged" (fn onEstiloTabStyleChange s e =
            (
                try
                (
                    if not ::AmenoCotasEstilosTab.isSyncing and s.SelectedIndex >= 0 and ::AmenoStyleService != undefined do
                    (
                        local stylesList = ::AmenoStyleService.listStyles()
                        local idx = s.SelectedIndex + 1
                        if idx <= stylesList.count do
                        (
                            ::AmenoCotasEstilosTab.requestStyleSwitch stylesList[idx].styleId
                        )
                    )
                )
                catch ()
            ))

        -- Botoes de gerenciamento (Novo / Duplicar / Deletar)
        if btnNewStyle != undefined do
            dotNet.addEventHandler btnNewStyle "Click" (fn onEstiloTabNew s e =
            (
                try (if ::AmenoCotasEstilosTab != undefined do ::AmenoCotasEstilosTab.onNewStyle()) catch ()
            ))

        if btnDuplicateStyle != undefined do
            dotNet.addEventHandler btnDuplicateStyle "Click" (fn onEstiloTabDuplicate s e =
            (
                try (if ::AmenoCotasEstilosTab != undefined do ::AmenoCotasEstilosTab.onDuplicateStyle()) catch ()
            ))

        if btnDeleteStyle != undefined do
            dotNet.addEventHandler btnDeleteStyle "Click" (fn onEstiloTabDelete s e =
            (
                try (if ::AmenoCotasEstilosTab != undefined do ::AmenoCotasEstilosTab.onDeleteStyle()) catch ()
            ))

        -- Presets
        if btnPresetArch != undefined do
            dotNet.addEventHandler btnPresetArch "Click" (fn onEstiloTabP1 s e =
            (
                try (if ::AmenoCotasEstilosTab != undefined do ::AmenoCotasEstilosTab.onPresetClick "default") catch ()
            ))

        if btnPresetEdit != undefined do
            dotNet.addEventHandler btnPresetEdit "Click" (fn onEstiloTabP2 s e =
            (
                try (if ::AmenoCotasEstilosTab != undefined do ::AmenoCotasEstilosTab.onPresetClick "editorial") catch ()
            ))

        if btnPresetTech != undefined do
            dotNet.addEventHandler btnPresetTech "Click" (fn onEstiloTabP3 s e =
            (
                try (if ::AmenoCotasEstilosTab != undefined do ::AmenoCotasEstilosTab.onPresetClick "technical") catch ()
            ))

        -- Atalhos de espessura
        if btnThin != undefined do
            dotNet.addEventHandler btnThin "Click" (fn onEstiloTabT1 s e =
            (
                try (if ::AmenoCotasEstilosTab != undefined and ::AmenoCotasEstilosTab.sliderLineThickness != undefined do ::AmenoCotasEstilosTab.sliderLineThickness.Value = 0.8) catch ()
            ))

        if btnNorm != undefined do
            dotNet.addEventHandler btnNorm "Click" (fn onEstiloTabT2 s e =
            (
                try (if ::AmenoCotasEstilosTab != undefined and ::AmenoCotasEstilosTab.sliderLineThickness != undefined do ::AmenoCotasEstilosTab.sliderLineThickness.Value = 1.5) catch ()
            ))

        if btnThick != undefined do
            dotNet.addEventHandler btnThick "Click" (fn onEstiloTabT3 s e =
            (
                try (if ::AmenoCotasEstilosTab != undefined and ::AmenoCotasEstilosTab.sliderLineThickness != undefined do ::AmenoCotasEstilosTab.sliderLineThickness.Value = 2.5) catch ()
            ))

        -- Fundo preview
        if btnToggleBg != undefined do
            dotNet.addEventHandler btnToggleBg "Click" (fn onEstiloTabBg s e =
            (
                try
                (
                    if ::AmenoCotasEstilosTab != undefined and ::AmenoCotasEstilosTab.currentDraft != undefined do
                    (
                        ::AmenoCotasEstilosTab.currentDraft.previewDarkBg = not ::AmenoCotasEstilosTab.currentDraft.previewDarkBg
                        if ::AmenoCotasEstilosTab.pnlPreviewHost != undefined do
                        (
                            local bgHex = if ::AmenoCotasEstilosTab.currentDraft.previewDarkBg then "#121212" else "#F5F5F5"
                            if ::AmenoPreviewRenderer != undefined do
                                ::AmenoCotasEstilosTab.pnlPreviewHost.Background = ::AmenoPreviewRenderer.createBrush bgHex
                        )
                        ::AmenoCotasEstilosTab.updatePreview()
                    )
                )
                catch ()
            ))

        -- Zoom
        if btnZoom50 != undefined do
            dotNet.addEventHandler btnZoom50 "Click" (fn onEstiloTabZ50 s e =
            (
                try (if ::AmenoCotasEstilosTab != undefined and ::AmenoCotasEstilosTab.currentDraft != undefined do (::AmenoCotasEstilosTab.currentDraft.previewZoom = 0.5; ::AmenoCotasEstilosTab.updatePreview())) catch ()
            ))

        if btnZoom100 != undefined do
            dotNet.addEventHandler btnZoom100 "Click" (fn onEstiloTabZ100 s e =
            (
                try (if ::AmenoCotasEstilosTab != undefined and ::AmenoCotasEstilosTab.currentDraft != undefined do (::AmenoCotasEstilosTab.currentDraft.previewZoom = 1.0; ::AmenoCotasEstilosTab.updatePreview())) catch ()
            ))

        if btnZoom200 != undefined do
            dotNet.addEventHandler btnZoom200 "Click" (fn onEstiloTabZ200 s e =
            (
                try (if ::AmenoCotasEstilosTab != undefined and ::AmenoCotasEstilosTab.currentDraft != undefined do (::AmenoCotasEstilosTab.currentDraft.previewZoom = 2.0; ::AmenoCotasEstilosTab.updatePreview())) catch ()
            ))

        -- Sliders
        if sliderFontSize != undefined do
            dotNet.addEventHandler sliderFontSize "ValueChanged" (fn onEstiloTabFS s e =
            (
                try
                (
                    local v = (e.NewValue as float)
                    if ::AmenoCotasEstilosTab != undefined do
                    (
                        if ::AmenoCotasEstilosTab.txtFontSize != undefined and not ::AmenoCotasEstilosTab.isSyncing do
                            ::AmenoCotasEstilosTab.txtFontSize.Text = (formattedPrint v format:".1f")
                        ::AmenoCotasEstilosTab.onFieldChanged #fontSize v
                    )
                )
                catch ()
            ))

        if sliderTracking != undefined do
            dotNet.addEventHandler sliderTracking "ValueChanged" (fn onEstiloTabTr s e =
            (
                try
                (
                    local v = (e.NewValue as float)
                    if ::AmenoCotasEstilosTab != undefined do
                    (
                        if ::AmenoCotasEstilosTab.txtTracking != undefined and not ::AmenoCotasEstilosTab.isSyncing do
                            ::AmenoCotasEstilosTab.txtTracking.Text = (formattedPrint v format:".1f")
                        ::AmenoCotasEstilosTab.onFieldChanged #tracking v
                    )
                )
                catch ()
            ))

        if sliderTextGap != undefined do
            dotNet.addEventHandler sliderTextGap "ValueChanged" (fn onEstiloTabTG s e =
            (
                try
                (
                    local v = (e.NewValue as float)
                    if ::AmenoCotasEstilosTab != undefined do
                    (
                        if ::AmenoCotasEstilosTab.txtTextGap != undefined and not ::AmenoCotasEstilosTab.isSyncing do
                            ::AmenoCotasEstilosTab.txtTextGap.Text = (formattedPrint v format:".1f")
                        ::AmenoCotasEstilosTab.onFieldChanged #textGap v
                    )
                )
                catch ()
            ))

        if sliderLineThickness != undefined do
            dotNet.addEventHandler sliderLineThickness "ValueChanged" (fn onEstiloTabLT s e =
            (
                try
                (
                    local v = (e.NewValue as float)
                    if ::AmenoCotasEstilosTab != undefined do
                    (
                        if ::AmenoCotasEstilosTab.txtLineThickness != undefined and not ::AmenoCotasEstilosTab.isSyncing do
                            ::AmenoCotasEstilosTab.txtLineThickness.Text = (formattedPrint v format:".1f")
                        ::AmenoCotasEstilosTab.onFieldChanged #lineThickness v
                    )
                )
                catch ()
            ))

        if sliderOverhang != undefined do
            dotNet.addEventHandler sliderOverhang "ValueChanged" (fn onEstiloTabOH s e =
            (
                try
                (
                    local v = (e.NewValue as float)
                    if ::AmenoCotasEstilosTab != undefined do
                    (
                        if ::AmenoCotasEstilosTab.txtOverhang != undefined and not ::AmenoCotasEstilosTab.isSyncing do
                            ::AmenoCotasEstilosTab.txtOverhang.Text = (formattedPrint v format:".1f")
                        ::AmenoCotasEstilosTab.onFieldChanged #extensionOverhang v
                    )
                )
                catch ()
            ))

        if sliderExtensionGap != undefined do
            dotNet.addEventHandler sliderExtensionGap "ValueChanged" (fn onEstiloTabEG s e =
            (
                try
                (
                    local v = (e.NewValue as float)
                    if ::AmenoCotasEstilosTab != undefined do
                    (
                        if ::AmenoCotasEstilosTab.txtExtensionGap != undefined and not ::AmenoCotasEstilosTab.isSyncing do
                            ::AmenoCotasEstilosTab.txtExtensionGap.Text = (formattedPrint v format:".1f")
                        ::AmenoCotasEstilosTab.onFieldChanged #extensionGap v
                    )
                )
                catch ()
            ))

        if sliderTerminalSize != undefined do
            dotNet.addEventHandler sliderTerminalSize "ValueChanged" (fn onEstiloTabTS s e =
            (
                try
                (
                    local v = (e.NewValue as float)
                    if ::AmenoCotasEstilosTab != undefined do
                    (
                        if ::AmenoCotasEstilosTab.txtTerminalSize != undefined and not ::AmenoCotasEstilosTab.isSyncing do
                            ::AmenoCotasEstilosTab.txtTerminalSize.Text = (formattedPrint v format:".1f")
                        ::AmenoCotasEstilosTab.onFieldChanged #terminalSize v
                    )
                )
                catch ()
            ))

        -- Checkboxes
        if chkBold != undefined do
            dotNet.addEventHandler chkBold "Click" (fn onEstiloTabBold s e =
            (
                try (if ::AmenoCotasEstilosTab != undefined do ::AmenoCotasEstilosTab.onFieldChanged #bold (s.IsChecked == true)) catch ()
            ))

        if chkItalic != undefined do
            dotNet.addEventHandler chkItalic "Click" (fn onEstiloTabItalic s e =
            (
                try (if ::AmenoCotasEstilosTab != undefined do ::AmenoCotasEstilosTab.onFieldChanged #italic (s.IsChecked == true)) catch ()
            ))

        if chkTextMask != undefined do
            dotNet.addEventHandler chkTextMask "Click" (fn onEstiloTabMask s e =
            (
                try (if ::AmenoCotasEstilosTab != undefined do ::AmenoCotasEstilosTab.onFieldChanged #textMaskEnabled (s.IsChecked == true)) catch ()
            ))

        -- ComboBox de fonte
        if cbFontName != undefined do
            dotNet.addEventHandler cbFontName "SelectionChanged" (fn onEstiloTabFont s e =
            (
                try
                (
                    if ::AmenoCotasEstilosTab != undefined and not ::AmenoCotasEstilosTab.isSyncing and s.SelectedIndex >= 0 do
                        ::AmenoCotasEstilosTab.onFieldChanged #fontName (s.SelectedItem as string)
                )
                catch ()
            ))

        -- ComboBox de tipo de terminal
        if cbTerminalType != undefined do
            dotNet.addEventHandler cbTerminalType "SelectionChanged" (fn onEstiloTabTerm s e =
            (
                try
                (
                    if ::AmenoCotasEstilosTab != undefined and not ::AmenoCotasEstilosTab.isSyncing and s.SelectedIndex >= 0 do
                    (
                        local tType = case s.SelectedIndex of
                        (
                            0: #tick
                            1: #arrowClosed
                            2: #arrowOpen
                            3: #dot
                            4: #none
                            default: #tick
                        )
                        ::AmenoCotasEstilosTab.onFieldChanged #terminalType tType
                    )
                )
                catch ()
            ))

        -- ComboBox de posicao do terminal
        if cbTerminalPlacement != undefined do
            dotNet.addEventHandler cbTerminalPlacement "SelectionChanged" (fn onEstiloTabPlace s e =
            (
                try
                (
                    if ::AmenoCotasEstilosTab != undefined and not ::AmenoCotasEstilosTab.isSyncing and s.SelectedIndex >= 0 do
                    (
                        local pType = case s.SelectedIndex of
                        (
                            0: #auto
                            1: #inside
                            2: #outside
                            default: #auto
                        )
                        ::AmenoCotasEstilosTab.onFieldChanged #terminalPlacement pType
                    )
                )
                catch ()
            ))

        -- Botoes de acao
        if btnApplyAll != undefined do
            dotNet.addEventHandler btnApplyAll "Click" (fn onEstiloTabAll s e = (::AmenoCotasEstilosTab.onApplyToSelection allDimensions:true))
        if btnApplySelection != undefined do
            dotNet.addEventHandler btnApplySelection "Click" (fn onEstiloTabApply s e =
            (
                try (if ::AmenoCotasEstilosTab != undefined do ::AmenoCotasEstilosTab.onApplyToSelection()) catch ()
            ))

        if btnSaveStyle != undefined do
            dotNet.addEventHandler btnSaveStyle "Click" (fn onEstiloTabSave s e =
            (
                try (if ::AmenoCotasEstilosTab != undefined do ::AmenoCotasEstilosTab.onSaveStyle()) catch ()
            ))

        true
    ),

    -- -----------------------------------------------------------------
    -- Construir e retornar o UserControl WPF (interface publica)
    -- -----------------------------------------------------------------
    fn build =
    (
        -- O UserControl e o draft sao donos da aba, nao da visita. Isso evita
        -- perder edicoes quando AmenoCotasWindow troca de secao e volta.
        if hostControl != undefined do
        (
            local cachedControlOk = try (hostControl.FindName "cbStyleSelect" != undefined) catch (false)
            if cachedControlOk do
            (
                this.ensureCurrentDraft()
                this.refresh()
                return hostControl
            )
            hostControl = undefined
        )

        local xamlStr    = getXAMLString()
        local xamlReader = dotNetClass "System.Windows.Markup.XamlReader"
        hostControl = xamlReader.Parse xamlStr

        -- Cache de referencias a controles
        cbStyleSelect     = findControl "cbStyleSelect"
        txtInUseCount     = findControl "txtInUseCount"
        txtDirtyMark      = findControl "txtDirtyMark"
        btnPresetArch     = findControl "btnPresetArch"
        btnPresetEdit     = findControl "btnPresetEdit"
        btnPresetTech     = findControl "btnPresetTech"
        btnNewStyle       = findControl "btnNewStyle"
        btnDuplicateStyle = findControl "btnDuplicateStyle"
        btnDeleteStyle    = findControl "btnDeleteStyle"

        btnZoom50    = findControl "btnZoom50"
        btnZoom100   = findControl "btnZoom100"
        btnZoom200   = findControl "btnZoom200"
        btnToggleBg  = findControl "btnToggleBg"
        pnlPreviewHost  = findControl "pnlPreviewHost"
        previewCanvas   = findControl "previewCanvas"
        txtPreviewStatus = findControl "txtPreviewStatus"

        cbFontName       = findControl "cbFontName"
        sliderFontSize   = findControl "sliderFontSize"
        txtFontSize      = findControl "txtFontSize"
        chkBold          = findControl "chkBold"
        chkItalic        = findControl "chkItalic"
        sliderTracking   = findControl "sliderTracking"
        txtTracking      = findControl "txtTracking"
        sliderTextGap    = findControl "sliderTextGap"
        txtTextGap       = findControl "txtTextGap"
        chkTextMask      = findControl "chkTextMask"

        btnThin             = findControl "btnThin"
        btnNorm             = findControl "btnNorm"
        btnThick            = findControl "btnThick"
        sliderLineThickness = findControl "sliderLineThickness"
        txtLineThickness    = findControl "txtLineThickness"
        sliderOverhang      = findControl "sliderOverhang"
        txtOverhang         = findControl "txtOverhang"
        sliderExtensionGap  = findControl "sliderExtensionGap"
        txtExtensionGap     = findControl "txtExtensionGap"

        cbTerminalType      = findControl "cbTerminalType"
        sliderTerminalSize  = findControl "sliderTerminalSize"
        txtTerminalSize     = findControl "txtTerminalSize"
        cbTerminalPlacement = findControl "cbTerminalPlacement"
        txtTerminalAngle    = findControl "txtTerminalAngle"

        btnApplySelection = findControl "btnApplySelection"
        btnApplyAll = findControl "btnApplyAll"
        btnSaveStyle      = findControl "btnSaveStyle"

        -- Inicializar somente se ainda nao houver um draft valido para a cena.
        this.ensureCurrentDraft()

        -- Popular controles
        this.populateTerminalOptions()
        this.populateFontList()
        this.populateStyleList()
        this.loadDraftToUI()

        -- Fundo inicial do preview
        if pnlPreviewHost != undefined and ::AmenoPreviewRenderer != undefined do
            pnlPreviewHost.Background = ::AmenoPreviewRenderer.createBrush "#121212"

        -- Bind de eventos
        this.bindEvents()

        hostControl
    )
)

::AmenoCotasEstilosTab = AmenoCotasEstilosTabDefinition()
