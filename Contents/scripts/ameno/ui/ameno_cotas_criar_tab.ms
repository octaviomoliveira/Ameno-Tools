/*
    E13-B -- Aba "Criar" da Janela Unificada Ameno - Cotas
    Conteudo da aba Criar: seletor de modo, cards de acao (Cota Individual / Cota Continua),
    secao Estilo Ativo e secao Cena com gestao de cotas.
*/

global AmenoCotasCriarTab
global AmenoApp
global AmenoDimensionTool
global AmenoDimensionContinuousTool
global AmenoStyleService
global AmenoDimensionGraphics
global AmenoDimensionPlaneService

struct AmenoCotasCriarTabDefinition
(
    -- Controles cached
    hostControl   = undefined,
    isSyncing     = false,

    -- -----------------------------------------------------------------
    -- XAML do UserControl (construido por concatenacao)
    -- -----------------------------------------------------------------
    fn getXAMLString =
    (
        local resPillActive = \
            "<Style x:Key='PillActiveStyle' TargetType='Button'>" + \
            "<Setter Property='Background' Value='#4a9eff'/>" + \
            "<Setter Property='Foreground' Value='#FFFFFF'/>" + \
            "<Setter Property='BorderThickness' Value='0'/>" + \
            "<Setter Property='Padding' Value='14,5'/>" + \
            "<Setter Property='Height' Value='28'/>" + \
            "<Setter Property='Cursor' Value='Hand'/>" + \
            "<Setter Property='FontSize' Value='11'/>" + \
            "<Setter Property='FontWeight' Value='SemiBold'/>" + \
            "<Setter Property='Template'><Setter.Value>" + \
            "<ControlTemplate TargetType='Button'>" + \
            "<Border x:Name='bd' Background='{TemplateBinding Background}' CornerRadius='14'>" + \
            "<ContentPresenter HorizontalAlignment='Center' VerticalAlignment='Center'/>" + \
            "</Border>" + \
            "<ControlTemplate.Triggers>" + \
            "<Trigger Property='IsMouseOver' Value='True'>" + \
            "<Setter TargetName='bd' Property='Background' Value='#5aAEff'/>" + \
            "</Trigger>" + \
            "</ControlTemplate.Triggers>" + \
            "</ControlTemplate></Setter.Value></Setter>" + \
            "</Style>"

        local resPillInactive = \
            "<Style x:Key='PillInactiveStyle' TargetType='Button'>" + \
            "<Setter Property='Background' Value='#2D2D30'/>" + \
            "<Setter Property='Foreground' Value='#AAAAAA'/>" + \
            "<Setter Property='BorderThickness' Value='1'/>" + \
            "<Setter Property='BorderBrush' Value='#3A3A3A'/>" + \
            "<Setter Property='Padding' Value='14,5'/>" + \
            "<Setter Property='Height' Value='28'/>" + \
            "<Setter Property='Cursor' Value='Hand'/>" + \
            "<Setter Property='FontSize' Value='11'/>" + \
            "<Setter Property='Template'><Setter.Value>" + \
            "<ControlTemplate TargetType='Button'>" + \
            "<Border x:Name='bd' Background='{TemplateBinding Background}' CornerRadius='14'" + \
            " BorderBrush='{TemplateBinding BorderBrush}' BorderThickness='{TemplateBinding BorderThickness}'>" + \
            "<ContentPresenter HorizontalAlignment='Center' VerticalAlignment='Center'/>" + \
            "</Border>" + \
            "<ControlTemplate.Triggers>" + \
            "<Trigger Property='IsMouseOver' Value='True'>" + \
            "<Setter TargetName='bd' Property='Background' Value='#3A3A3F'/>" + \
            "</Trigger>" + \
            "</ControlTemplate.Triggers>" + \
            "</ControlTemplate></Setter.Value></Setter>" + \
            "</Style>"

        local resActionCard = \
            "<Style x:Key='ActionCardStyle' TargetType='Button'>" + \
            "<Setter Property='Background' Value='#252528'/>" + \
            "<Setter Property='Foreground' Value='#CCCCCC'/>" + \
            "<Setter Property='BorderBrush' Value='#3A3A3A'/>" + \
            "<Setter Property='BorderThickness' Value='1'/>" + \
            "<Setter Property='Cursor' Value='Hand'/>" + \
            "<Setter Property='Template'><Setter.Value>" + \
            "<ControlTemplate TargetType='Button'>" + \
            "<Border x:Name='bd' Background='{TemplateBinding Background}'" + \
            " BorderBrush='{TemplateBinding BorderBrush}' BorderThickness='{TemplateBinding BorderThickness}'" + \
            " CornerRadius='4'>" + \
            "<ContentPresenter HorizontalAlignment='Center' VerticalAlignment='Center'/>" + \
            "</Border>" + \
            "<ControlTemplate.Triggers>" + \
            "<Trigger Property='IsMouseOver' Value='True'>" + \
            "<Setter TargetName='bd' Property='Background' Value='#2E2E33'/>" + \
            "<Setter TargetName='bd' Property='BorderBrush' Value='#4a9eff'/>" + \
            "</Trigger>" + \
            "<Trigger Property='IsPressed' Value='True'>" + \
            "<Setter TargetName='bd' Property='Background' Value='#1A3A5C'/>" + \
            "</Trigger>" + \
            "</ControlTemplate.Triggers>" + \
            "</ControlTemplate></Setter.Value></Setter>" + \
            "</Style>"

        local resDangerCard = \
            "<Style x:Key='DangerCardStyle' TargetType='Button'>" + \
            "<Setter Property='Background' Value='#2D1A1A'/>" + \
            "<Setter Property='Foreground' Value='#E06C75'/>" + \
            "<Setter Property='BorderBrush' Value='#4A2222'/>" + \
            "<Setter Property='BorderThickness' Value='1'/>" + \
            "<Setter Property='Cursor' Value='Hand'/>" + \
            "<Setter Property='Template'><Setter.Value>" + \
            "<ControlTemplate TargetType='Button'>" + \
            "<Border x:Name='bd' Background='{TemplateBinding Background}'" + \
            " BorderBrush='{TemplateBinding BorderBrush}' BorderThickness='{TemplateBinding BorderThickness}'" + \
            " CornerRadius='4'>" + \
            "<ContentPresenter HorizontalAlignment='Center' VerticalAlignment='Center'/>" + \
            "</Border>" + \
            "<ControlTemplate.Triggers>" + \
            "<Trigger Property='IsMouseOver' Value='True'>" + \
            "<Setter TargetName='bd' Property='Background' Value='#3D2020'/>" + \
            "<Setter TargetName='bd' Property='BorderBrush' Value='#E06C75'/>" + \
            "</Trigger>" + \
            "</ControlTemplate.Triggers>" + \
            "</ControlTemplate></Setter.Value></Setter>" + \
            "</Style>"

        local resources = "<UserControl.Resources>" + \
            resPillActive + resPillInactive + resActionCard + resDangerCard + \
            "</UserControl.Resources>"

        local modoSection = \
            "<Border Background='#252526' CornerRadius='4' Padding='12,10' Margin='0,0,0,10'>" + \
            "<StackPanel>" + \
            "<TextBlock Text='MODO' Foreground='#61AFEF' FontWeight='Bold' FontSize='10'" + \
            " Margin='0,0,0,8'/>" + \
            "<StackPanel Orientation='Horizontal' HorizontalAlignment='Center'>" + \
            "<Button x:Name='btnModoAlinhada' Style='{StaticResource PillActiveStyle}'" + \
            " Content='Alinhada' Margin='0,0,4,0' ToolTip='Cota alinhada ao vetor A-B'/>" + \
            "<Button x:Name='btnModoHorizontal' Style='{StaticResource PillInactiveStyle}'" + \
            " Content='Horizontal' Margin='0,0,4,0' ToolTip='Cota projetada no eixo X'/>" + \
            "<Button x:Name='btnModoVertical' Style='{StaticResource PillInactiveStyle}'" + \
            " Content='Vertical' ToolTip='Cota projetada no eixo Y'/>" + \
            "</StackPanel>" + \
            "</StackPanel>" + \
            "</Border>"

        local planoSection = \
            "<Border Background='#252526' CornerRadius='4' Padding='12,10' Margin='0,0,0,10'>" + \
            "<StackPanel>" + \
            "<TextBlock Text='PLANO DE COTA' Foreground='#61AFEF' FontWeight='Bold' FontSize='10' Margin='0,0,0,8'/>" + \
            "<StackPanel Orientation='Horizontal' HorizontalAlignment='Center'>" + \
            "<Button x:Name='btnPlanoPlanta' Style='{StaticResource PillActiveStyle}' Content='Planta XY' Margin='0,0,4,0' ToolTip='Projeta no plano XY, comportamento legado'/>" + \
            "<Button x:Name='btnPlanoFachada' Style='{StaticResource PillInactiveStyle}' Content='Fachada / Vista' ToolTip='Usa a vista ortográfica ativa como plano U/V/N'/>" + \
            "</StackPanel>" + \
            "<TextBlock Text='Fachada exige vista ortografica nivelada; a orientacao e capturada ao iniciar.' Foreground='#888888' FontSize='9' Margin='0,7,0,0' TextWrapping='Wrap'/>" + \
            "</StackPanel>" + \
            "</Border>"

        local cardsSection = \
            "<Border Background='#252526' CornerRadius='4' Padding='12,10' Margin='0,0,0,10'>" + \
            "<StackPanel>" + \
            "<TextBlock Text='CRIAR COTA' Foreground='#61AFEF' FontWeight='Bold' FontSize='10'" + \
            " Margin='0,0,0,8'/>" + \
            "<Grid>" + \
            "<Grid.ColumnDefinitions>" + \
            "<ColumnDefinition Width='*'/>" + \
            "<ColumnDefinition Width='8'/>" + \
            "<ColumnDefinition Width='*'/>" + \
            "</Grid.ColumnDefinitions>" + \
            "<Button x:Name='btnCotaIndividual' Grid.Column='0'" + \
            " Style='{StaticResource ActionCardStyle}' Height='64'" + \
            " ToolTip='Iniciar ferramenta de 3 cliques (A, B, afastamento)'>" + \
            "<StackPanel HorizontalAlignment='Center'>" + \
            "<TextBlock Text='----' FontSize='18' HorizontalAlignment='Center' Foreground='#4a9eff'/>" + \
            "<TextBlock Text='Cota Individual' FontSize='11' Foreground='#CCCCCC'" + \
            " HorizontalAlignment='Center' Margin='0,2,0,0'/>" + \
            "<TextBlock Text='3 cliques' FontSize='9' Foreground='#888888' HorizontalAlignment='Center'/>" + \
            "</StackPanel>" + \
            "</Button>" + \
            "<Button x:Name='btnCotaContinua' Grid.Column='2'" + \
            " Style='{StaticResource ActionCardStyle}' Height='64'" + \
            " ToolTip='Cota continua Horizontal/Vertical (clique vazio confirma)'>" + \
            "<StackPanel HorizontalAlignment='Center'>" + \
            "<TextBlock Text='--------' FontSize='14' HorizontalAlignment='Center' Foreground='#888888'/>" + \
            "<TextBlock Text='Cota Continua' FontSize='11' Foreground='#888888'" + \
            " HorizontalAlignment='Center' Margin='0,2,0,0'/>" + \
            "<TextBlock Text='cadeia H/V' FontSize='9' Foreground='#888888' HorizontalAlignment='Center'/>" + \
            "</StackPanel>" + \
            "</Button>" + \
            "</Grid>" + \
            "</StackPanel>" + \
            "</Border>"

        local estiloSection = \
            "<Border Background='#252526' CornerRadius='4' Padding='12,10' Margin='0,0,0,10'>" + \
            "<StackPanel>" + \
            "<TextBlock Text='ESTILO ATIVO' Foreground='#61AFEF' FontWeight='Bold' FontSize='10'" + \
            " Margin='0,0,0,8'/>" + \
            "<Grid Margin='0,0,0,6'>" + \
            "<Grid.ColumnDefinitions>" + \
            "<ColumnDefinition Width='60'/>" + \
            "<ColumnDefinition Width='*'/>" + \
            "</Grid.ColumnDefinitions>" + \
            "<TextBlock Text='Estilo:' Foreground='#CCCCCC' VerticalAlignment='Center' FontSize='11'/>" + \
            "<ComboBox x:Name='cbEstiloAtivo' Grid.Column='1' Height='24'" + \
            " Background='#2D2D30' Foreground='#FFFFFF' BorderBrush='#3F3F46'/>" + \
            "</Grid>" + \
            "<Grid Margin='0,0,0,2'>" + \
            "<Grid.ColumnDefinitions>" + \
            "<ColumnDefinition Width='60'/>" + \
            "<ColumnDefinition Width='*'/>" + \
            "<ColumnDefinition Width='8'/>" + \
            "<ColumnDefinition Width='*'/>" + \
            "</Grid.ColumnDefinitions>" + \
            "<TextBlock Text='Unidade:' Foreground='#CCCCCC' VerticalAlignment='Center' FontSize='11'/>" + \
            "<ComboBox x:Name='cbUnidade' Grid.Column='1' Height='24'" + \
            " Background='#2D2D30' Foreground='#FFFFFF' BorderBrush='#3F3F46'>" + \
            "<ComboBoxItem Content='Metros (m)'/>" + \
            "<ComboBoxItem Content='Centimetros (cm)'/>" + \
            "<ComboBoxItem Content='Milimetros (mm)'/>" + \
            "</ComboBox>" + \
            "<TextBlock Grid.Column='2'/>" + \
            "<ComboBox x:Name='cbPrecisao' Grid.Column='3' Height='24'" + \
            " Background='#2D2D30' Foreground='#FFFFFF' BorderBrush='#3F3F46'>" + \
            "<ComboBoxItem Content='0 casas'/>" + \
            "<ComboBoxItem Content='1 casa'/>" + \
            "<ComboBoxItem Content='2 casas'/>" + \
            "<ComboBoxItem Content='3 casas'/>" + \
            "</ComboBox>" + \
            "</Grid>" + \
            "<CheckBox x:Name='chkTextFollowsLine' Content='Texto acompanha a orientacao da linha' Foreground='#EEEEEE' IsChecked='True' Margin='0,10,0,0'/>" + \
            "</StackPanel>" + \
            "</Border>"

        local cenaSection = \
            "<Border Background='#252526' CornerRadius='4' Padding='12,10'>" + \
            "<StackPanel>" + \
            "<DockPanel Margin='0,0,0,10'>" + \
            "<TextBlock DockPanel.Dock='Left' Text='CENA' Foreground='#61AFEF'" + \
            " FontWeight='Bold' FontSize='10' VerticalAlignment='Center'/>" + \
            "<TextBlock x:Name='txtCotaCount' DockPanel.Dock='Right'" + \
            " Text='0 cotas' Foreground='#888888' FontSize='10' VerticalAlignment='Center'/>" + \
            "</DockPanel>" + \
            "<Grid>" + \
            "<Grid.RowDefinitions>" + \
            "<RowDefinition Height='40'/>" + \
            "<RowDefinition Height='6'/>" + \
            "<RowDefinition Height='40'/>" + \
            "</Grid.RowDefinitions>" + \
            "<Grid.ColumnDefinitions>" + \
            "<ColumnDefinition Width='*'/>" + \
            "<ColumnDefinition Width='6'/>" + \
            "<ColumnDefinition Width='*'/>" + \
            "</Grid.ColumnDefinitions>" + \
            "<Button x:Name='btnRepararTudo' Grid.Row='0' Grid.Column='0'" + \
            " Style='{StaticResource ActionCardStyle}'" + \
            " Content='Reparar tudo' ToolTip='Reparar todas as cotas da cena'/>" + \
            "<Button x:Name='btnDeletarSelecao' Grid.Row='0' Grid.Column='2'" + \
            " Style='{StaticResource ActionCardStyle}'" + \
            " Content='Deletar selecao' ToolTip='Remover cotas selecionadas e seus Custom Attributes'/>" + \
            "<Button x:Name='btnLimparOrfas' Grid.Row='2' Grid.Column='0'" + \
            " Style='{StaticResource ActionCardStyle}'" + \
            " Content='Limpar orfas' ToolTip='Remover cotas cujas ancoras nao existem mais'/>" + \
            "<Button x:Name='btnDeletarTudo' Grid.Row='2' Grid.Column='2'" + \
            " Style='{StaticResource DangerCardStyle}'" + \
            " Content='Deletar tudo' ToolTip='Remover TODAS as cotas da cena (pede confirmacao)'/>" + \
            "</Grid>" + \
            "</StackPanel>" + \
            "</Border>"

        local xaml = \
            "<UserControl xmlns='http://schemas.microsoft.com/winfx/2006/xaml/presentation'" + \
            " xmlns:x='http://schemas.microsoft.com/winfx/2006/xaml'>" + \
            resources + \
            "<ScrollViewer VerticalScrollBarVisibility='Auto' HorizontalScrollBarVisibility='Disabled'>" + \
            "<StackPanel Margin='12'>" + \
            planoSection + \
            modoSection + \
            cardsSection + \
            estiloSection + \
            cenaSection + \
            "</StackPanel>" + \
            "</ScrollViewer>" + \
            "</UserControl>"

        xaml
    ),

    -- -----------------------------------------------------------------
    -- Helpers
    -- -----------------------------------------------------------------
    fn findControl ctrlName =
    (
        if hostControl == undefined then undefined else hostControl.FindName ctrlName
    ),

    fn normalizedMode modeValue =
    (
        if modeValue == #horizontal or modeValue == "horizontal" then #horizontal
        else if modeValue == #vertical or modeValue == "vertical" then #vertical
        else #aligned
    ),

    fn normalizedPlaneMode planeValue =
    (
        if planeValue == #viewPlane or planeValue == "viewPlane" or planeValue == "fachada" or planeValue == "Fachada" then #viewPlane
        else #worldXY
    ),

    fn normalizedUnit unitValue =
    (
        if unitValue == #centimeters or unitValue == "centimeters" or unitValue == "cm" then #centimeters
        else if unitValue == #millimeters or unitValue == "millimeters" or unitValue == "mm" then #millimeters
        else #meters
    ),

    fn normalizedPrecision precisionValue =
    (
        local result = try (precisionValue as integer) catch (2)
        if result < 0 then result = 0
        if result > 3 then result = 3
        result
    ),

    fn modeName modeValue =
    (
        local mode = normalizedMode modeValue
        if mode == #horizontal then "horizontal"
        else if mode == #vertical then "vertical"
        else "aligned"
    ),

    fn planeModeName planeValue =
    (
        if (normalizedPlaneMode planeValue) == #viewPlane then "viewPlane" else "worldXY"
    ),

    fn isInteractiveToolActive =
    (
        local individualActive = false
        local continuousActive = false
        if ::AmenoDimensionTool != undefined do
            individualActive = try (::AmenoDimensionTool.active == true) catch (false)
        if ::AmenoDimensionContinuousTool != undefined do
            continuousActive = try (::AmenoDimensionContinuousTool.active == true) catch (false)
        individualActive or continuousActive
    ),

    fn rejectConfigurationChange =
    (
        local message = "Finalize ou cancele a ferramenta ativa antes de alterar a configuração da cota."
        if ::AmenoApp != undefined do
            try (::AmenoApp.dimensionStatus = message) catch ()
        try (displayTempPrompt message 1600) catch ()
        try (this.syncFromServices()) catch ()
        false
    ),

    fn getStyleIndex styleId =
    (
        local result = 0
        if ::AmenoStyleService != undefined do
        (
            local styles = try (::AmenoStyleService.listStyles()) catch (#())
            for i = 1 to styles.count do
            (
                try
                (
                    if styles[i].styleId == styleId do
                    (
                        result = i
                        exit
                    )
                )
                catch ()
            )
        )
        result
    ),

    fn setActiveMode modeValue =
    (
        if isInteractiveToolActive() then return (rejectConfigurationChange())
        local mode = normalizedMode modeValue
        if ::AmenoDimensionTool != undefined do ::AmenoDimensionTool.activeMode = mode
        if ::AmenoDimensionContinuousTool != undefined do ::AmenoDimensionContinuousTool.activeMode = mode
        this.updateModoButtons mode
        mode
    ),

    fn setActivePlaneMode planeValue =
    (
        if isInteractiveToolActive() then return (rejectConfigurationChange())
        local planeMode = normalizedPlaneMode planeValue
        if ::AmenoDimensionTool != undefined do
            try (::AmenoDimensionTool.setActivePlaneMode planeMode) catch (::AmenoDimensionTool.activePlaneMode = planeMode)
        if ::AmenoDimensionContinuousTool != undefined do
            try (::AmenoDimensionContinuousTool.setActivePlaneMode planeMode) catch (::AmenoDimensionContinuousTool.activePlaneMode = planeMode)
        this.updatePlanoButtons planeMode
        planeMode
    ),

    fn setActiveStyle styleValue =
    (
        if isInteractiveToolActive() then return (rejectConfigurationChange())
        local styleId = if styleValue == undefined or styleValue == "" then "default" else styleValue
        if ::AmenoDimensionTool != undefined do ::AmenoDimensionTool.activeStyleId = styleId
        if ::AmenoDimensionContinuousTool != undefined do ::AmenoDimensionContinuousTool.activeStyleId = styleId
        styleId
    ),

    fn setOutputUnit unitValue =
    (
        if isInteractiveToolActive() then return (rejectConfigurationChange())
        local unit = normalizedUnit unitValue
        if ::AmenoDimensionTool != undefined do ::AmenoDimensionTool.previewOutputUnit = unit
        if ::AmenoDimensionContinuousTool != undefined do ::AmenoDimensionContinuousTool.previewOutputUnit = unit
        unit
    ),

    fn setPrecision precisionValue =
    (
        if isInteractiveToolActive() then return (rejectConfigurationChange())
        local precision = normalizedPrecision precisionValue
        if ::AmenoDimensionTool != undefined do ::AmenoDimensionTool.previewPrecision = precision
        if ::AmenoDimensionContinuousTool != undefined do ::AmenoDimensionContinuousTool.previewPrecision = precision
        precision
    ),

    fn getSettings =
    (
        local source = ::AmenoDimensionTool
        if source == undefined do source = ::AmenoDimensionContinuousTool

        local mode = #aligned
        local styleId = "default"
        local unit = #meters
        local precision = 2
        local planeMode = #worldXY
        if source != undefined do
        (
            mode = try (normalizedMode source.activeMode) catch (#aligned)
            styleId = try (source.activeStyleId) catch ("default")
            unit = try (normalizedUnit source.previewOutputUnit) catch (#meters)
            precision = try (normalizedPrecision source.previewPrecision) catch (2)
            planeMode = try (normalizedPlaneMode source.activePlaneMode) catch (#worldXY)
        )
        if styleId == undefined or styleId == "" do styleId = "default"
        #(mode, styleId, unit, precision, planeMode)
    ),

    fn syncFromServices =
    (
        local settings = getSettings()
        local mode = settings[1]
        local styleId = settings[2]
        local unit = settings[3]
        local precision = settings[4]
        local planeMode = if settings.count >= 5 then settings[5] else #worldXY

        -- O serviço individual é a fonte primária da aba. Em repouso, os dois
        -- serviços recebem a mesma configuração; a sessão contínua usa seu
        -- snapshot próprio e não é reinterpretada por esta sincronização.
        if not isInteractiveToolActive() do
        (
            if ::AmenoDimensionTool != undefined do
            (
                ::AmenoDimensionTool.activeMode = mode
                ::AmenoDimensionTool.activeStyleId = styleId
                ::AmenoDimensionTool.previewOutputUnit = unit
                ::AmenoDimensionTool.previewPrecision = precision
                try (::AmenoDimensionTool.setActivePlaneMode planeMode) catch (::AmenoDimensionTool.activePlaneMode = planeMode)
            )
            if ::AmenoDimensionContinuousTool != undefined do
            (
                ::AmenoDimensionContinuousTool.activeMode = mode
                ::AmenoDimensionContinuousTool.activeStyleId = styleId
                ::AmenoDimensionContinuousTool.previewOutputUnit = unit
                ::AmenoDimensionContinuousTool.previewPrecision = precision
                try (::AmenoDimensionContinuousTool.setActivePlaneMode planeMode) catch (::AmenoDimensionContinuousTool.activePlaneMode = planeMode)
            )
        )

        isSyncing = true
        try
        (
            this.populateEstilos selectedStyleId:styleId
            local orientationCheck = findControl "chkTextFollowsLine"
            if orientationCheck != undefined and ::AmenoDimensionGraphics != undefined and isProperty ::AmenoDimensionGraphics #textFollowsLine do
                orientationCheck.IsChecked = (dotNetObject "System.Nullable`1[System.Boolean]" ::AmenoDimensionGraphics.textFollowsLine)
            local cbUnd = findControl "cbUnidade"
            if cbUnd != undefined do
                cbUnd.SelectedIndex = case unit of
                (
                    #centimeters: 1
                    #millimeters: 2
                    default: 0
                )
            local cbPrec = findControl "cbPrecisao"
            if cbPrec != undefined do cbPrec.SelectedIndex = precision
            this.updateModoButtons mode
            this.updatePlanoButtons planeMode
        )
        catch (format "[Ameno][ERROR] Sincronizacao da aba Criar: %\n" (getCurrentException() as string))
        isSyncing = false
        true
    ),

    fn executeIndividualCommand =
    (
        this.syncFromServices()
        local result = undefined
        if ::AmenoApp != undefined do result = ::AmenoApp.startDimensionTool()
        this.syncFromServices()
        this.updateCotaCount()
        result
    ),

    fn executeContinuousCommand =
    (
        this.syncFromServices()
        local result = undefined
        if ::AmenoApp != undefined do result = ::AmenoApp.startContinuousDimensionTool()
        this.syncFromServices()
        this.updateCotaCount()
        result
    ),

    fn updateModoButtons activeMode =
    (
        try
        (
            local btnAl = findControl "btnModoAlinhada"
            local btnHz = findControl "btnModoHorizontal"
            local btnVt = findControl "btnModoVertical"

            if hostControl == undefined do return false

            local rDict = hostControl.Resources
            local styleActive   = try (rDict.Item "PillActiveStyle")   catch (undefined)
            local styleInactive = try (rDict.Item "PillInactiveStyle") catch (undefined)

            if styleActive == undefined or styleInactive == undefined do return false

            local modeNameValue = modeName activeMode

            if btnAl != undefined do
                btnAl.Style = (if modeNameValue == "aligned" then styleActive else styleInactive)
            if btnHz != undefined do
                btnHz.Style = (if modeNameValue == "horizontal" then styleActive else styleInactive)
            if btnVt != undefined do
                btnVt.Style = (if modeNameValue == "vertical" then styleActive else styleInactive)
        )
        catch ()
    ),

    fn updatePlanoButtons activePlaneMode =
    (
        try
        (
            local btnPlanta = findControl "btnPlanoPlanta"
            local btnFachada = findControl "btnPlanoFachada"
            if hostControl == undefined do return false
            local rDict = hostControl.Resources
            local styleActive = try (rDict.Item "PillActiveStyle") catch (undefined)
            local styleInactive = try (rDict.Item "PillInactiveStyle") catch (undefined)
            if styleActive == undefined or styleInactive == undefined do return false
            local planeModeValue = normalizedPlaneMode activePlaneMode
            if btnPlanta != undefined do btnPlanta.Style = (if planeModeValue == #worldXY then styleActive else styleInactive)
            if btnFachada != undefined do btnFachada.Style = (if planeModeValue == #viewPlane then styleActive else styleInactive)
        )
        catch ()
    ),

    fn populateEstilos selectedStyleId:undefined =
    (
        local cb = findControl "cbEstiloAtivo"
        if cb == undefined do return false
        cb.Items.Clear()
        local styles = #()
        if ::AmenoStyleService != undefined do
            styles = try (::AmenoStyleService.listStyles()) catch (#())
        if styles.count == 0 then
            cb.Items.Add "default"
        else
        (
            for st in styles do
                try (cb.Items.Add st.name) catch ()
        )
        local selectedIndex = 0
        if selectedStyleId != undefined do
        (
            local styleIndex = getStyleIndex selectedStyleId
            if styleIndex > 0 do selectedIndex = styleIndex - 1
        )
        if cb.Items.Count > 0 do cb.SelectedIndex = selectedIndex
        true
    ),

    fn updateCotaCount =
    (
        local txt = findControl "txtCotaCount"
        if txt == undefined do return false
        local count = 0
        if ::AmenoDimensionGraphics != undefined do
            count = try ((::AmenoDimensionGraphics.findControllers()).count) catch (0)
        txt.Text = (count as string) + (if count == 1 then " cota" else " cotas")
        true
    ),

    -- -----------------------------------------------------------------
    -- Bind de eventos (fn globais conforme regra MaxScript)
    -- -----------------------------------------------------------------
    fn bindEvents =
    (
        local btnAl    = findControl "btnModoAlinhada"
        local btnHz    = findControl "btnModoHorizontal"
        local btnVt    = findControl "btnModoVertical"
        local btnPlanta = findControl "btnPlanoPlanta"
        local btnFachada = findControl "btnPlanoFachada"
        local btnInd   = findControl "btnCotaIndividual"
        local btnCont  = findControl "btnCotaContinua"
        local btnRep   = findControl "btnRepararTudo"
        local btnDelSel = findControl "btnDeletarSelecao"
        local btnOrf   = findControl "btnLimparOrfas"
        local btnDelTd = findControl "btnDeletarTudo"
        local cbEstl   = findControl "cbEstiloAtivo"
        local cbUnd    = findControl "cbUnidade"
        local cbPrec   = findControl "cbPrecisao"

        if btnPlanta != undefined do
            dotNet.addEventHandler btnPlanta "Click" \
                (fn onPlanoPlanta s e =
                (
                    try (if ::AmenoCotasCriarTab != undefined do ::AmenoCotasCriarTab.setActivePlaneMode #worldXY) catch ()
                ))

        if btnFachada != undefined do
            dotNet.addEventHandler btnFachada "Click" \
                (fn onPlanoFachada s e =
                (
                    try (if ::AmenoCotasCriarTab != undefined do ::AmenoCotasCriarTab.setActivePlaneMode #viewPlane) catch ()
                ))

        if btnAl != undefined do
            dotNet.addEventHandler btnAl "Click" \
                (fn onModoAlinhada s e =
                (
                    try
                    (
                        if ::AmenoCotasCriarTab != undefined do
                            ::AmenoCotasCriarTab.setActiveMode #aligned
                    )
                    catch ()
                ))

        if btnHz != undefined do
            dotNet.addEventHandler btnHz "Click" \
                (fn onModoHorizontal s e =
                (
                    try
                    (
                        if ::AmenoCotasCriarTab != undefined do
                            ::AmenoCotasCriarTab.setActiveMode #horizontal
                    )
                    catch ()
                ))

        if btnVt != undefined do
            dotNet.addEventHandler btnVt "Click" \
                (fn onModoVertical s e =
                (
                    try
                    (
                        if ::AmenoCotasCriarTab != undefined do
                            ::AmenoCotasCriarTab.setActiveMode #vertical
                    )
                    catch ()
                ))

        if btnInd != undefined do
            dotNet.addEventHandler btnInd "Click" \
                (fn onCotaIndividual s e =
                (
                    try
                    (
                        if ::AmenoCotasCriarTab != undefined do
                            ::AmenoCotasCriarTab.executeIndividualCommand()
                    )
                    catch ()
                ))

        if btnCont != undefined do
            dotNet.addEventHandler btnCont "Click" \
                (fn onCotaContinua s e =
                (
                    try
                    (
                        if ::AmenoCotasCriarTab != undefined do
                            ::AmenoCotasCriarTab.executeContinuousCommand()
                    )
                    catch ()
                ))

        if btnRep != undefined do
            dotNet.addEventHandler btnRep "Click" \
                (fn onRepararTudo s e =
                (
                    try
                    (
                        if ::AmenoApp != undefined do
                        (
                            local count = ::AmenoApp.repairDimensions()
                            if ::AmenoCotasCriarTab != undefined do
                                ::AmenoCotasCriarTab.updateCotaCount()
                            format "[Ameno][INFO] Reparar tudo: % cotas reparadas.\n" count
                        )
                    )
                    catch ()
                ))

        if btnDelSel != undefined do
            dotNet.addEventHandler btnDelSel "Click" \
                (fn onDeletarSelecao s e =
                (
                    try
                    (
                        if ::AmenoApp != undefined do
                        (
                            local count = ::AmenoApp.deletarSelecao()
                            if ::AmenoCotasCriarTab != undefined do
                                ::AmenoCotasCriarTab.updateCotaCount()
                            format "[Ameno][INFO] Deletar selecao: % cotas removidas.\n" count
                        )
                    )
                    catch ()
                ))

        if btnOrf != undefined do
            dotNet.addEventHandler btnOrf "Click" \
                (fn onLimparOrfas s e =
                (
                    try
                    (
                        if ::AmenoApp != undefined do
                        (
                            local count = ::AmenoApp.limparOrfas()
                            if ::AmenoCotasCriarTab != undefined do
                                ::AmenoCotasCriarTab.updateCotaCount()
                            format "[Ameno][INFO] Limpar orfas: % cotas removidas.\n" count
                        )
                    )
                    catch ()
                ))

        if btnDelTd != undefined do
            dotNet.addEventHandler btnDelTd "Click" \
                (fn onDeletarTudo s e =
                (
                    try
                    (
                        if ::AmenoApp != undefined do
                        (
                            local count = 0
                            if ::AmenoDimensionGraphics != undefined do
                                count = try ((::AmenoDimensionGraphics.findControllers()).count) catch (0)

                            local msgBtnType  = dotNetClass "System.Windows.MessageBoxButton"
                            local msgIconType = dotNetClass "System.Windows.MessageBoxImage"
                            local msgResType  = dotNetClass "System.Windows.MessageBoxResult"

                            local msgText = "Deseja remover TODAS as " + (count as string) + " cota(s) da cena?\n\nEsta acao nao pode ser desfeita."
                            local dlgResult = (dotNetClass "System.Windows.MessageBox").Show \
                                msgText "Confirmar exclusao" msgBtnType.YesNo msgIconType.Warning

                            if dlgResult == msgResType.Yes do
                            (
                                local removed = ::AmenoApp.deletarTudo()
                                if ::AmenoCotasCriarTab != undefined do
                                    ::AmenoCotasCriarTab.updateCotaCount()
                                format "[Ameno][INFO] Deletar tudo: % cotas removidas.\n" removed
                            )
                        )
                    )
                    catch ()
                ))

        if cbEstl != undefined do
            dotNet.addEventHandler cbEstl "SelectionChanged" \
                (fn onEstiloChanged s e =
                (
                    try
                    (
                        if ::AmenoCotasCriarTab != undefined and not ::AmenoCotasCriarTab.isSyncing do
                        (
                            local idx = s.SelectedIndex
                            if idx >= 0 and ::AmenoStyleService != undefined do
                            (
                                local styles = try (::AmenoStyleService.listStyles()) catch (#())
                                if (idx + 1) <= styles.count do
                                    ::AmenoCotasCriarTab.setActiveStyle styles[idx + 1].styleId
                            )
                        )
                    )
                    catch ()
                ))

        if cbUnd != undefined do
            dotNet.addEventHandler cbUnd "SelectionChanged" \
                (fn onUnidadeChanged s e =
                (
                    try
                    (
                        if ::AmenoCotasCriarTab != undefined and not ::AmenoCotasCriarTab.isSyncing do
                        (
                            local idx = s.SelectedIndex
                            local units = #(#meters, #centimeters, #millimeters)
                            if idx >= 0 and idx < units.count do
                                ::AmenoCotasCriarTab.setOutputUnit units[idx + 1]
                        )
                    )
                    catch ()
                ))

        if cbPrec != undefined do
            dotNet.addEventHandler cbPrec "SelectionChanged" \
                (fn onPrecisaoChanged s e =
                (
                    try
                    (
                        if ::AmenoCotasCriarTab != undefined and not ::AmenoCotasCriarTab.isSyncing do
                        (
                            local idx = s.SelectedIndex
                            if idx >= 0 do
                                ::AmenoCotasCriarTab.setPrecision idx
                        )
                    )
                    catch ()
                ))

        true
    ),

    -- Libera a arvore WPF ao fechar o shell. O estado operacional (modo,
    -- unidade e precisao) continua nos servicos; somente referencias de
    -- controles visuais sao descartadas para evitar reparenting em reabertura.
    fn onPanelClosed =
    (
        hostControl = undefined
        isSyncing = false
        true
    ),

    -- -----------------------------------------------------------------
    -- Construir e retornar o UserControl WPF
    -- -----------------------------------------------------------------
    fn build =
    (
        if hostControl != undefined do
        (
            local cachedControlOk = try (hostControl.FindName "btnCotaContinua" != undefined) catch (false)
            if cachedControlOk do
            (
                syncFromServices()
                updateCotaCount()
                return hostControl
            )
            hostControl = undefined
        )

        local xamlStr    = getXAMLString()
        local xamlReader = dotNetClass "System.Windows.Markup.XamlReader"
        hostControl = xamlReader.Parse xamlStr
        local orientationCheck = findControl "chkTextFollowsLine"
        dotNet.addEventHandler orientationCheck "Click" (fn onOrientation s e =
        (
            if not ::AmenoCotasCriarTab.isSyncing do
            (
                if ::AmenoCotasCriarTab.isInteractiveToolActive() then
                    s.IsChecked = (dotNetObject "System.Nullable`1[System.Boolean]" ::AmenoDimensionGraphics.textFollowsLine)
                else ::AmenoDimensionGraphics.textFollowsLine = (s.IsChecked == true)
            )
        ))

        syncFromServices()
        updateCotaCount()
        bindEvents()

        hostControl
    )
)

AmenoCotasCriarTab = AmenoCotasCriarTabDefinition()
