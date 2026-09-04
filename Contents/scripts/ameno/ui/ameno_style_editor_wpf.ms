/*
    E11.2 — Shell e Navegação do Editor Visual de Estilos (WPF .NET 8).
    Fornece a interface moderna e responsiva do editor baseada no mockup do usuário:
    - Modeless hosting vinculado ao HWND do 3ds Max via WindowInteropHelper;
    - Instância singleton por sessão;
    - Atalhos de teclado globais: Esc (Cancelar), Ctrl+S (Salvar Estilo), Ctrl+Enter (Aplicar às Selecionadas);
    - Layout de duas colunas com GridSplitter (Preview ao vivo à esquerda, Controles à direita);
    - Tooltips contextuais e ordem de tabulação coerente;
    - Persistência segura de preferências de interface (largura, altura, fundo claro/escuro) em arquivo INI;
    - Sincronização bidirecional e isolamento estrito via AmenoStyleDraft.
*/

global AmenoStyleEditorWPF
global AmenoStyleEditorWindow
global AmenoStyleService
global AmenoStyleDraft
global AmenoPreviewRenderer

struct AmenoStyleEditorWPFDefinition
(
    window = undefined,
    currentDraft = undefined,
    isSyncingUI = false,

    -- Controles nomeados da interface
    cbStyleSelect = undefined,
    txtInUseCount = undefined,
    txtDirtyMark = undefined,
    btnPresetArch = undefined,
    btnPresetEdit = undefined,
    btnPresetTech = undefined,
    btnSaveAsNew = undefined,

    btnZoom50 = undefined,
    btnZoom100 = undefined,
    btnZoom200 = undefined,
    btnToggleBg = undefined,
    pnlPreviewHost = undefined,
    previewCanvas = undefined,
    txtPreviewStatus = undefined,

    cbFontName = undefined,
    sliderFontSize = undefined,
    txtFontSize = undefined,
    chkBold = undefined,
    chkItalic = undefined,
    sliderTracking = undefined,
    txtTracking = undefined,
    sliderTextGap = undefined,
    txtTextGap = undefined,
    chkTextMask = undefined,
    txtAnnotationColor = undefined,

    btnThin = undefined,
    btnNorm = undefined,
    btnThick = undefined,
    sliderLineThickness = undefined,
    txtLineThickness = undefined,
    sliderOverhang = undefined,
    txtOverhang = undefined,
    sliderExtensionGap = undefined,
    txtExtensionGap = undefined,

    cbTerminalType = undefined,
    sliderTerminalSize = undefined,
    txtTerminalSize = undefined,
    cbTerminalPlacement = undefined,
    sliderTerminalAngle = undefined,
    txtTerminalAngle = undefined,

    btnCancel = undefined,
    btnApplySelection = undefined,
    btnSaveStyle = undefined,

    fn getPreferencesPath =
    (
        local baseDir = pathConfig.appendPath (getDir #plugcfg) "AmenoTools"
        makeDir baseDir all:true
        pathConfig.appendPath baseDir "style_editor.ini"
    ),

    fn loadPreferences =
    (
        local prefFile = getPreferencesPath()
        local w = getINISetting prefFile "Window" "Width"
        local h = getINISetting prefFile "Window" "Height"
        local dark = getINISetting prefFile "Preview" "DarkBackground"

        local wVal = if w != "" then (w as float) else 860.0
        local hVal = if h != "" then (h as float) else 560.0
        local darkVal = if dark != "" then (dark == "true") else true

        if wVal < 740.0 do wVal = 860.0
        if hVal < 480.0 do hVal = 560.0

        #(wVal, hVal, darkVal)
    ),

    fn savePreferences wVal hVal darkVal =
    (
        try
        (
            local prefFile = getPreferencesPath()
            setINISetting prefFile "Window" "Width" (wVal as string)
            setINISetting prefFile "Window" "Height" (hVal as string)
            setINISetting prefFile "Preview" "DarkBackground" (if darkVal then "true" else "false")
            true
        )
        catch (false)
    ),

    fn isOpen =
    (
        window != undefined and (try (window.IsLoaded) catch (false))
    ),

    fn getXAMLString initialWidth:880 initialHeight:640 =
    (
        local xaml = @"<Window xmlns='http://schemas.microsoft.com/winfx/2006/xaml/presentation'
        xmlns:x='http://schemas.microsoft.com/winfx/2006/xaml'
        Title='Ameno — Editor de Estilo'
        Width='" + (initialWidth as string) + @"' Height='" + (initialHeight as string) + @"'
        MinWidth='780' MinHeight='520'
        Background='#1E1E1E' Foreground='#CCCCCC'
        FontFamily='Segoe UI' FontSize='12'
        WindowStartupLocation='CenterOwner'>

    <Window.Resources>
        <!-- ToggleButton escuro para ComboBox -->
        <ControlTemplate x:Key='ComboBoxToggleButton' TargetType='ToggleButton'>
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition />
                    <ColumnDefinition Width='20' />
                </Grid.ColumnDefinitions>
                <Border x:Name='Border' Grid.ColumnSpan='2' CornerRadius='3'
                        Background='#2D2D30' BorderBrush='#3F3F46' BorderThickness='1' />
                <Border Grid.Column='0' Margin='1' Background='#2D2D30' CornerRadius='2,0,0,2' />
                <Path x:Name='Arrow' Grid.Column='1' HorizontalAlignment='Center' VerticalAlignment='Center'
                      Data='M 0 0 L 4 4 L 8 0 Z' Fill='#CCCCCC' />
            </Grid>
            <ControlTemplate.Triggers>
                <Trigger Property='IsMouseOver' Value='true'>
                    <Setter TargetName='Border' Property='BorderBrush' Value='#007ACC' />
                    <Setter TargetName='Arrow' Property='Fill' Value='#FFFFFF' />
                </Trigger>
                <Trigger Property='IsChecked' Value='true'>
                    <Setter TargetName='Border' Property='BorderBrush' Value='#007ACC' />
                </Trigger>
                <Trigger Property='IsEnabled' Value='false'>
                    <Setter TargetName='Border' Property='Background' Value='#222222' />
                    <Setter TargetName='Border' Property='BorderBrush' Value='#333333' />
                    <Setter TargetName='Arrow' Property='Fill' Value='#555555' />
                </Trigger>
            </ControlTemplate.Triggers>
        </ControlTemplate>

        <!-- Estilo de Item do ComboBox (fundo escuro, texto claro e legivel) -->
        <Style TargetType='ComboBoxItem'>
            <Setter Property='SnapsToDevicePixels' Value='true' />
            <Setter Property='OverridesDefaultStyle' Value='true' />
            <Setter Property='Template'>
                <Setter.Value>
                    <ControlTemplate TargetType='ComboBoxItem'>
                        <Border x:Name='Border' Padding='6,4' SnapsToDevicePixels='true' Background='#252526'>
                            <ContentPresenter TextElement.Foreground='#E0E0E0' />
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property='IsHighlighted' Value='true'>
                                <Setter TargetName='Border' Property='Background' Value='#0E639C' />
                                <Setter Property='TextElement.Foreground' Value='#FFFFFF' />
                            </Trigger>
                            <Trigger Property='IsSelected' Value='true'>
                                <Setter TargetName='Border' Property='Background' Value='#1177BB' />
                                <Setter Property='TextElement.Foreground' Value='#FFFFFF' />
                            </Trigger>
                            <Trigger Property='IsEnabled' Value='false'>
                                <Setter Property='TextElement.Foreground' Value='#666666' />
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- Estilo global de ComboBox escuro -->
        <Style TargetType='ComboBox'>
            <Setter Property='SnapsToDevicePixels' Value='true' />
            <Setter Property='OverridesDefaultStyle' Value='true' />
            <Setter Property='ScrollViewer.HorizontalScrollBarVisibility' Value='Auto' />
            <Setter Property='ScrollViewer.VerticalScrollBarVisibility' Value='Auto' />
            <Setter Property='ScrollViewer.CanContentScroll' Value='true' />
            <Setter Property='Foreground' Value='#FFFFFF' />
            <Setter Property='Template'>
                <Setter.Value>
                    <ControlTemplate TargetType='ComboBox'>
                        <Grid>
                            <ToggleButton Name='ToggleButton'
                                          Template='{StaticResource ComboBoxToggleButton}'
                                          Grid.Column='2'
                                          Focusable='false'
                                          IsChecked='{Binding Path=IsDropDownOpen,Mode=TwoWay,RelativeSource={RelativeSource TemplatedParent}}'
                                          ClickMode='Press' />
                            <ContentPresenter Name='ContentSite'
                                              IsHitTestVisible='false'
                                              Content='{TemplateBinding SelectionBoxItem}'
                                              ContentTemplate='{TemplateBinding SelectionBoxItemTemplate}'
                                              ContentTemplateSelector='{TemplateBinding ItemTemplateSelector}'
                                              Margin='8,3,23,3'
                                              VerticalAlignment='Center'
                                              HorizontalAlignment='Left'
                                              TextElement.Foreground='#FFFFFF' />
                            <Popup Name='Popup'
                                   Placement='Bottom'
                                   IsOpen='{TemplateBinding IsDropDownOpen}'
                                   AllowsTransparency='true'
                                   Focusable='false'
                                   PopupAnimation='Slide'>
                                <Grid Name='DropDown'
                                      SnapsToDevicePixels='true'
                                      MinWidth='{TemplateBinding ActualWidth}'
                                      MaxHeight='{TemplateBinding MaxDropDownHeight}'>
                                    <Border x:Name='DropDownBorder'
                                            Background='#252526'
                                            BorderThickness='1'
                                            BorderBrush='#3F3F46'
                                            CornerRadius='3'
                                            Margin='0,2,0,4' />
                                    <ScrollViewer Margin='2,4,2,6' SnapsToDevicePixels='true'>
                                        <StackPanel IsItemsHost='True' KeyboardNavigation.DirectionalNavigation='Contained' />
                                    </ScrollViewer>
                                </Grid>
                            </Popup>
                        </Grid>
                        <ControlTemplate.Triggers>
                            <Trigger Property='HasItems' Value='false'>
                                <Setter TargetName='DropDownBorder' Property='MinHeight' Value='95' />
                            </Trigger>
                            <Trigger Property='IsEnabled' Value='false'>
                                <Setter Property='Foreground' Value='#666666' />
                            </Trigger>
                            <Trigger Property='IsGrouping' Value='true'>
                                <Setter Property='ScrollViewer.CanContentScroll' Value='false' />
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
    </Window.Resources>

    <Grid Margin='12'>
        <Grid.RowDefinitions>
            <RowDefinition Height='Auto'/>
            <RowDefinition Height='*'/>
            <RowDefinition Height='Auto'/>
        </Grid.RowDefinitions>

        <!-- LINHA 0: CABEÇALHO -->
        <Border Grid.Row='0' Background='#252526' BorderBrush='#333333' BorderThickness='1' CornerRadius='4' Padding='10,8' Margin='0,0,0,10'>
            <DockPanel LastChildFill='True'>
                <!-- Direita: Presets e Salvar como Novo -->
                <StackPanel DockPanel.Dock='Right' Orientation='Horizontal' VerticalAlignment='Center'>
                    <TextBlock Text='Presets:' Foreground='#888888' VerticalAlignment='Center' Margin='0,0,8,0' />
                    <Button Name='btnPresetArch' Content='Arquitetônico' Height='24' Padding='8,2' Margin='0,0,4,0' Background='#333337' Foreground='#FFFFFF' BorderBrush='#444444' ToolTip='Carregar preset Arquitetônico (Arial, Traço 45°)' TabIndex='4'/>
                    <Button Name='btnPresetEdit' Content='Editorial' Height='24' Padding='8,2' Margin='0,0,4,0' Background='#333337' Foreground='#FFFFFF' BorderBrush='#444444' ToolTip='Carregar preset Editorial (Georgia, Ponto)' TabIndex='5'/>
                    <Button Name='btnPresetTech' Content='Técnico' Height='24' Padding='8,2' Margin='0,0,12,0' Background='#333337' Foreground='#FFFFFF' BorderBrush='#444444' ToolTip='Carregar preset Técnico (Consolas, Seta Fechada)' TabIndex='6'/>
                    <Button Name='btnSaveAsNew' Content='Salvar como Novo...' Height='24' Padding='10,2' Background='#3A3A3D' Foreground='#61AFEF' BorderBrush='#4B5263' ToolTip='Criar um novo estilo a partir das alterações atuais' TabIndex='7'/>
                </StackPanel>

                <!-- Esquerda: Seletor de Estilo e Status -->
                <StackPanel Orientation='Horizontal' VerticalAlignment='Center'>
                    <TextBlock Text='Estilo:' Foreground='#CCCCCC' FontWeight='SemiBold' VerticalAlignment='Center' Margin='0,0,8,0'/>
                    <ComboBox Name='cbStyleSelect' Width='180' Height='24' VerticalAlignment='Center' Background='#2D2D30' Foreground='#FFFFFF' BorderBrush='#3F3F46' ToolTip='Selecione o estilo da cena para edição' TabIndex='1'/>
                    <TextBlock Name='txtDirtyMark' Text='*' Foreground='#E06C75' FontWeight='Bold' FontSize='16' VerticalAlignment='Center' Margin='4,0,8,0' Visibility='Collapsed' ToolTip='Alterações não salvas no rascunho'/>
                    <TextBlock Name='txtInUseCount' Text='Em uso: 0 cota(s)' Foreground='#888888' VerticalAlignment='Center' Margin='6,0,0,0'/>
                </StackPanel>
            </DockPanel>
        </Border>

        <!-- LINHA 1: CORPO PRINCIPAL (PREVIEW E CONTROLES) -->
        <Grid Grid.Row='1'>
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width='1.1*' MinWidth='320'/>
                <ColumnDefinition Width='6'/>
                <ColumnDefinition Width='1.2*' MinWidth='360'/>
            </Grid.ColumnDefinitions>

            <!-- COLUNA ESQUERDA: PREVIEW AO VIVO -->
            <Border Grid.Column='0' Background='#181818' BorderBrush='#2A2A2A' BorderThickness='1' CornerRadius='4'>
                <Grid>
                    <Grid.RowDefinitions>
                        <RowDefinition Height='Auto'/>
                        <RowDefinition Height='*'/>
                        <RowDefinition Height='Auto'/>
                    </Grid.RowDefinitions>

                    <!-- Barra de ferramentas do preview -->
                    <Border Grid.Row='0' Background='#222222' BorderBrush='#2A2A2A' BorderThickness='0,0,0,1' Padding='8,4'>
                        <DockPanel LastChildFill='True'>
                            <StackPanel DockPanel.Dock='Right' Orientation='Horizontal'>
                                <TextBlock Text='Zoom:' Foreground='#888888' VerticalAlignment='Center' Margin='0,0,6,0' FontSize='11'/>
                                <Button Name='btnZoom50' Content='50%' Width='40' Height='20' Margin='0,0,2,0' FontSize='10' Background='#2D2D30' Foreground='#CCCCCC' BorderBrush='#3F3F46' ToolTip='Zoom do preview: 50%' TabIndex='8'/>
                                <Button Name='btnZoom100' Content='100%' Width='44' Height='20' Margin='0,0,2,0' FontSize='10' Background='#383838' Foreground='#FFFFFF' BorderBrush='#555555' ToolTip='Zoom do preview: 100% (escala real)' TabIndex='9'/>
                                <Button Name='btnZoom200' Content='200%' Width='40' Height='20' Margin='0,0,8,0' FontSize='10' Background='#2D2D30' Foreground='#CCCCCC' BorderBrush='#3F3F46' ToolTip='Zoom do preview: 200%' TabIndex='10'/>
                                <Button Name='btnToggleBg' Content='Fundo' Width='52' Height='20' FontSize='10' Background='#2D2D30' Foreground='#CCCCCC' BorderBrush='#3F3F46' ToolTip='Alternar fundo claro/escuro do preview' TabIndex='11'/>
                            </StackPanel>
                            <TextBlock Text='Preview ao vivo' Foreground='#9CDCFE' FontWeight='SemiBold' VerticalAlignment='Center' FontSize='11'/>
                        </DockPanel>
                    </Border>

                    <!-- Canvas do preview -->
                    <Border Name='pnlPreviewHost' Grid.Row='1' Background='#121212' ClipToBounds='True'>
                        <Canvas Name='previewCanvas' HorizontalAlignment='Stretch' VerticalAlignment='Stretch'>
                            <!-- Elementos desenhados programaticamente na E11.3 -->
                        </Canvas>
                    </Border>

                    <!-- Barra de status do preview -->
                    <Border Grid.Row='2' Background='#181818' BorderBrush='#2A2A2A' BorderThickness='0,1,0,0' Padding='8,4'>
                        <TextBlock Name='txtPreviewStatus' Text='Saída: PNG Alpha 1:1 · Escala 100%' Foreground='#777777' FontSize='10' VerticalAlignment='Center'/>
                    </Border>
                </Grid>
            </Border>

            <!-- SPLITTER -->
            <GridSplitter Grid.Column='1' Width='6' HorizontalAlignment='Center' Background='#252526' ToolTip='Arraste para redimensionar o painel de preview'/>

            <!-- COLUNA DIREITA: PAINEL DE CONTROLES -->
            <Border Grid.Column='2' Background='#252526' BorderBrush='#333333' BorderThickness='1' CornerRadius='4' Padding='10'>
                <ScrollViewer VerticalScrollBarVisibility='Auto' HorizontalScrollBarVisibility='Disabled'>
                    <StackPanel>
                        <!-- GRUPO 1: TEXTO / TIPOGRAFIA -->
                        <Border Background='#202022' BorderBrush='#303034' BorderThickness='1' CornerRadius='3' Padding='8' Margin='0,0,0,10'>
                            <StackPanel>
                                <TextBlock Text='TEXTO / TIPOGRAFIA' Foreground='#61AFEF' FontWeight='Bold' FontSize='11' Margin='0,0,0,8'/>

                                <!-- Família de Fonte -->
                                <Grid Margin='0,0,0,6'>
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition Width='75'/>
                                        <ColumnDefinition Width='*'/>
                                    </Grid.ColumnDefinitions>
                                    <TextBlock Text='Fonte:' Foreground='#CCCCCC' VerticalAlignment='Center'/>
                                    <ComboBox Name='cbFontName' Grid.Column='1' Height='24' Background='#2D2D30' Foreground='#FFFFFF' BorderBrush='#3F3F46' ToolTip='Família tipográfica da cota' TabIndex='20'/>
                                </Grid>

                                <!-- Tamanho e Estilo (B/I) -->
                                <Grid Margin='0,0,0,6'>
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition Width='75'/>
                                        <ColumnDefinition Width='*'/>
                                        <ColumnDefinition Width='50'/>
                                        <ColumnDefinition Width='Auto'/>
                                    </Grid.ColumnDefinitions>
                                    <TextBlock Text='Tamanho:' Foreground='#CCCCCC' VerticalAlignment='Center'/>
                                    <Slider Name='sliderFontSize' Grid.Column='1' Minimum='10' Maximum='500' Value='140' VerticalAlignment='Center' Margin='0,0,6,0' TabIndex='21' ToolTip='Tamanho da fonte em milímetros de cena'/>
                                    <TextBox Name='txtFontSize' Grid.Column='2' Text='140.0' Height='22' Background='#2D2D30' Foreground='#FFFFFF' BorderBrush='#3F3F46' HorizontalContentAlignment='Center' VerticalAlignment='Center' Margin='0,0,8,0' TabIndex='22'/>
                                    <StackPanel Grid.Column='3' Orientation='Horizontal' VerticalAlignment='Center'>
                                        <CheckBox Name='chkBold' Content='N' FontWeight='Bold' Foreground='#FFFFFF' Margin='0,0,6,0' ToolTip='Negrito' TabIndex='23'/>
                                        <CheckBox Name='chkItalic' Content='I' FontStyle='Italic' Foreground='#FFFFFF' ToolTip='Itálico' TabIndex='24'/>
                                    </StackPanel>
                                </Grid>

                                <!-- Tracking -->
                                <Grid Margin='0,0,0,6'>
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition Width='75'/>
                                        <ColumnDefinition Width='*'/>
                                        <ColumnDefinition Width='50'/>
                                    </Grid.ColumnDefinitions>
                                    <TextBlock Text='Tracking:' Foreground='#CCCCCC' VerticalAlignment='Center'/>
                                    <Slider Name='sliderTracking' Grid.Column='1' Minimum='-10' Maximum='50' Value='0' VerticalAlignment='Center' Margin='0,0,6,0' TabIndex='25' ToolTip='Espaçamento entre caracteres'/>
                                    <TextBox Name='txtTracking' Grid.Column='2' Text='0.0' Height='22' Background='#2D2D30' Foreground='#FFFFFF' BorderBrush='#3F3F46' HorizontalContentAlignment='Center' VerticalAlignment='Center' TabIndex='26'/>
                                </Grid>

                                <!-- Afastamento e Máscara -->
                                <Grid Margin='0,0,0,2'>
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition Width='75'/>
                                        <ColumnDefinition Width='*'/>
                                        <ColumnDefinition Width='50'/>
                                        <ColumnDefinition Width='Auto'/>
                                    </Grid.ColumnDefinitions>
                                    <TextBlock Text='Afastamento:' Foreground='#CCCCCC' VerticalAlignment='Center'/>
                                    <Slider Name='sliderTextGap' Grid.Column='1' Minimum='0' Maximum='250' Value='60' VerticalAlignment='Center' Margin='0,0,6,0' TabIndex='27' ToolTip='Distância do texto em relação à linha de cota'/>
                                    <TextBox Name='txtTextGap' Grid.Column='2' Text='60.0' Height='22' Background='#2D2D30' Foreground='#FFFFFF' BorderBrush='#3F3F46' HorizontalContentAlignment='Center' VerticalAlignment='Center' Margin='0,0,8,0' TabIndex='28'/>
                                    <CheckBox Name='chkTextMask' Grid.Column='3' Content='Máscara' Foreground='#FFFFFF' VerticalAlignment='Center' ToolTip='Ocultar linhas sob o texto da cota' TabIndex='29'/>
                                </Grid>
                            </StackPanel>
                        </Border>

                        <!-- GRUPO 2: LINHAS DE COTA -->
                        <Border Background='#202022' BorderBrush='#303034' BorderThickness='1' CornerRadius='3' Padding='8' Margin='0,0,0,6'>
                            <StackPanel>
                                <TextBlock Text='LINHAS DE COTA' Foreground='#61AFEF' FontWeight='Bold' FontSize='11' Margin='0,0,0,8'/>

                                <!-- Atalhos de Espessura -->
                                <Grid Margin='0,0,0,6'>
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition Width='75'/>
                                        <ColumnDefinition Width='*'/>
                                    </Grid.ColumnDefinitions>
                                    <TextBlock Text='Atalhos:' Foreground='#CCCCCC' VerticalAlignment='Center'/>
                                    <StackPanel Grid.Column='1' Orientation='Horizontal'>
                                        <Button Name='btnThin' Content='Fina (0.8)' Height='22' Padding='8,1' Margin='0,0,4,0' Background='#333337' Foreground='#FFFFFF' BorderBrush='#444444' ToolTip='Espessura fina (0.8 mm)' TabIndex='30'/>
                                        <Button Name='btnNorm' Content='Normal (1.5)' Height='22' Padding='8,1' Margin='0,0,4,0' Background='#333337' Foreground='#FFFFFF' BorderBrush='#444444' ToolTip='Espessura normal (1.5 mm)' TabIndex='31'/>
                                        <Button Name='btnThick' Content='Forte (2.5)' Height='22' Padding='8,1' Background='#333337' Foreground='#FFFFFF' BorderBrush='#444444' ToolTip='Espessura forte (2.5 mm)' TabIndex='32'/>
                                    </StackPanel>
                                </Grid>

                                <!-- Espessura Contínua -->
                                <Grid Margin='0,0,0,6'>
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition Width='75'/>
                                        <ColumnDefinition Width='*'/>
                                        <ColumnDefinition Width='50'/>
                                    </Grid.ColumnDefinitions>
                                    <TextBlock Text='Espessura:' Foreground='#CCCCCC' VerticalAlignment='Center'/>
                                    <Slider Name='sliderLineThickness' Grid.Column='1' Minimum='0.2' Maximum='10' Value='1.5' VerticalAlignment='Center' Margin='0,0,6,0' TabIndex='33' ToolTip='Espessura da linha em milímetros de cena'/>
                                    <TextBox Name='txtLineThickness' Grid.Column='2' Text='1.5' Height='22' Background='#2D2D30' Foreground='#FFFFFF' BorderBrush='#3F3F46' HorizontalContentAlignment='Center' VerticalAlignment='Center' TabIndex='34'/>
                                </Grid>

                                <!-- Prolongamento (Overhang) -->
                                <Grid Margin='0,0,0,6'>
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition Width='75'/>
                                        <ColumnDefinition Width='*'/>
                                        <ColumnDefinition Width='50'/>
                                    </Grid.ColumnDefinitions>
                                    <TextBlock Text='Prolongar:' Foreground='#CCCCCC' VerticalAlignment='Center'/>
                                    <Slider Name='sliderOverhang' Grid.Column='1' Minimum='0' Maximum='300' Value='80' VerticalAlignment='Center' Margin='0,0,6,0' TabIndex='35' ToolTip='Extensão da linha além dos pontos cotados'/>
                                    <TextBox Name='txtOverhang' Grid.Column='2' Text='80.0' Height='22' Background='#2D2D30' Foreground='#FFFFFF' BorderBrush='#3F3F46' HorizontalContentAlignment='Center' VerticalAlignment='Center' TabIndex='36'/>
                                </Grid>

                                <!-- Afastamento (Extension Gap) -->
                                <Grid Margin='0,0,0,2'>
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition Width='75'/>
                                        <ColumnDefinition Width='*'/>
                                        <ColumnDefinition Width='50'/>
                                    </Grid.ColumnDefinitions>
                                    <TextBlock Text='Recuo:' Foreground='#CCCCCC' VerticalAlignment='Center'/>
                                    <Slider Name='sliderExtensionGap' Grid.Column='1' Minimum='0' Maximum='200' Value='0' VerticalAlignment='Center' Margin='0,0,6,0' TabIndex='37' ToolTip='Espaço entre os pontos cotados e o início das extensões'/>
                                    <TextBox Name='txtExtensionGap' Grid.Column='2' Text='0.0' Height='22' Background='#2D2D30' Foreground='#FFFFFF' BorderBrush='#3F3F46' HorizontalContentAlignment='Center' VerticalAlignment='Center' TabIndex='38'/>
                                </Grid>
                            </StackPanel>
                        </Border>

                        <!-- GRUPO 3: SETAS E TERMINAIS -->
                        <Border Background='#202022' BorderBrush='#303034' BorderThickness='1' CornerRadius='3' Padding='8'>
                            <StackPanel>
                                <TextBlock Text='SETAS E TERMINAIS' Foreground='#61AFEF' FontWeight='Bold' FontSize='11' Margin='0,0,0,8'/>

                                <!-- Tipo de Terminal -->
                                <Grid Margin='0,0,0,6'>
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition Width='75'/>
                                        <ColumnDefinition Width='*'/>
                                    </Grid.ColumnDefinitions>
                                    <TextBlock Text='Terminal:' Foreground='#CCCCCC' VerticalAlignment='Center'/>
                                    <ComboBox Name='cbTerminalType' Grid.Column='1' Height='24' Background='#2D2D30' Foreground='#FFFFFF' BorderBrush='#3F3F46' ToolTip='Tipo gráfico dos terminais da cota' TabIndex='40'/>
                                </Grid>

                                <!-- Tamanho do Terminal -->
                                <Grid Margin='0,0,0,6'>
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition Width='75'/>
                                        <ColumnDefinition Width='*'/>
                                        <ColumnDefinition Width='50'/>
                                    </Grid.ColumnDefinitions>
                                    <TextBlock Text='Tamanho:' Foreground='#CCCCCC' VerticalAlignment='Center'/>
                                    <Slider Name='sliderTerminalSize' Grid.Column='1' Minimum='10' Maximum='300' Value='100' VerticalAlignment='Center' Margin='0,0,6,0' TabIndex='41' ToolTip='Tamanho do terminal em milímetros'/>
                                    <TextBox Name='txtTerminalSize' Grid.Column='2' Text='100.0' Height='22' Background='#2D2D30' Foreground='#FFFFFF' BorderBrush='#3F3F46' HorizontalContentAlignment='Center' VerticalAlignment='Center' TabIndex='42'/>
                                </Grid>

                                <!-- Posição e Ângulo -->
                                <Grid Margin='0,0,0,2'>
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition Width='75'/>
                                        <ColumnDefinition Width='*'/>
                                        <ColumnDefinition Width='50'/>
                                    </Grid.ColumnDefinitions>
                                    <TextBlock Text='Posição:' Foreground='#CCCCCC' VerticalAlignment='Center'/>
                                    <ComboBox Name='cbTerminalPlacement' Grid.Column='1' Height='24' Background='#2D2D30' Foreground='#FFFFFF' BorderBrush='#3F3F46' Margin='0,0,6,0' ToolTip='Posicionamento das setas (Automático, Interno ou Externo)' TabIndex='43'/>
                                    <TextBox Name='txtTerminalAngle' Grid.Column='2' Text='45°' Height='22' Background='#2D2D30' Foreground='#FFFFFF' BorderBrush='#3F3F46' HorizontalContentAlignment='Center' VerticalAlignment='Center' ToolTip='Ângulo do traço' TabIndex='44' IsReadOnly='True'/>
                                </Grid>
                            </StackPanel>
                        </Border>
                    </StackPanel>
                </ScrollViewer>
            </Border>
        </Grid>

        <!-- LINHA 2: RODAPÉ DE AÇÕES -->
        <Border Grid.Row='2' Margin='0,10,0,0'>
            <DockPanel LastChildFill='True'>
                <!-- Esquerda: Ajuda de Atalhos -->
                <StackPanel DockPanel.Dock='Left' Orientation='Horizontal' VerticalAlignment='Center'>
                    <TextBlock Text='Atalhos: ' Foreground='#777777' FontSize='11'/>
                    <TextBlock Text='Esc: Cancelar  ·  Ctrl+Enter: Aplicar  ·  Ctrl+S: Salvar' Foreground='#999999' FontSize='11'/>
                </StackPanel>

                <!-- Direita: Botões Principais -->
                <StackPanel Orientation='Horizontal' HorizontalAlignment='Right'>
                    <Button Name='btnCancel' Content='Cancelar' Width='80' Height='28' Margin='0,0,8,0' Background='#333337' Foreground='#CCCCCC' BorderBrush='#444444' ToolTip='Descartar rascunho e fechar o editor (Esc)' TabIndex='90'/>
                    <Button Name='btnApplySelection' Content='Aplicar às Selecionadas' Width='140' Height='28' Margin='0,0,8,0' Background='#333337' Foreground='#FFFFFF' BorderBrush='#444444' ToolTip='Aplicar o rascunho de estilo às cotas atualmente selecionadas (Ctrl+Enter)' TabIndex='91'/>
                    <Button Name='btnSaveStyle' Content='Salvar Estilo' Width='110' Height='28' Background='#0E639C' Foreground='#FFFFFF' BorderBrush='#1177BB' FontWeight='SemiBold' ToolTip='Salvar alterações no estilo e atualizar cotas vinculadas (Ctrl+S)' TabIndex='92'/>
                </StackPanel>
            </DockPanel>
        </Border>
    </Grid>
</Window>"
        xaml
    ),

    fn findControl controlName =
    (
        if window == undefined then undefined else window.FindName controlName
    ),

    fn updateDirtyUI =
    (
        if txtDirtyMark == undefined or currentDraft == undefined do return false
        if currentDraft.isDirty then
        (
            txtDirtyMark.Visibility = (dotNetClass "System.Windows.Visibility").Visible
        )
        else
        (
            txtDirtyMark.Visibility = (dotNetClass "System.Windows.Visibility").Collapsed
        )
    ),

    fn updateInUseCount =
    (
        if txtInUseCount == undefined or currentDraft == undefined or ::AmenoStyleService == undefined do return false
        local count = ::AmenoStyleService.countDimensionsUsingStyle currentDraft.sourceStyleId
        txtInUseCount.Text = "Em uso: " + (count as string) + " cota(s)"
    ),

    fn onSceneSelectionChanged =
    (
        if window == undefined do return false
        updateInUseCount()
        if txtPreviewStatus != undefined do
        (
            local selDimCount = 0
            if ::AmenoDimensionGraphics != undefined do
            (
                local dimIds = #()
                for obj in selection where isValidNode obj do
                (
                    local did = ::AmenoDimensionGraphics.getDimensionId obj
                    if did != "" and (findItem dimIds did) == 0 do
                    (
                        append dimIds did
                        selDimCount += 1
                    )
                )
            )
            if selDimCount > 0 then
                txtPreviewStatus.Text = (selDimCount as string) + " cota(s) selecionada(s) pronta(s) para aplicação"
            else if currentDraft != undefined and currentDraft.isDirty then
                txtPreviewStatus.Text = "Rascunho com alterações não salvas"
            else
                txtPreviewStatus.Text = "Pronto"
        )
        true
    ),

    fn onSceneReset =
    (
        if window == undefined do return false
        isSyncingUI = true
        try
        (
            populateStyleList()
            if ::AmenoStyleService != undefined do
            (
                currentDraft = ::AmenoStyleService.createDraftFromStyle "default"
                loadDraftToUI()
                updateInUseCount()
                updatePreview()
            )
        )
        catch ()
        isSyncingUI = false
        if txtPreviewStatus != undefined do
            txtPreviewStatus.Text = "Pronto"
        true
    ),

    fn populateStyleList =
    (
        if cbStyleSelect == undefined or ::AmenoStyleService == undefined do return false
        cbStyleSelect.Items.Clear()
        local styles = ::AmenoStyleService.listStyles()
        local selIdx = -1
        for i = 1 to styles.count do
        (
            cbStyleSelect.Items.Add styles[i].name
            if currentDraft != undefined and styles[i].styleId == currentDraft.sourceStyleId do
            (
                selIdx = (i - 1)
            )
        )
        if selIdx >= 0 then cbStyleSelect.SelectedIndex = selIdx
        else if cbStyleSelect.Items.Count > 0 do cbStyleSelect.SelectedIndex = 0
    ),

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
            if (stricmp fonts[i] curFont) == 0 do
            (
                selIdx = (i - 1)
            )
        )
        if selIdx >= 0 then cbFontName.SelectedIndex = selIdx
        else if cbFontName.Items.Count > 0 do cbFontName.SelectedIndex = 0
    ),

    fn populateTerminalOptions =
    (
        if cbTerminalType != undefined do
        (
            cbTerminalType.Items.Clear()
            cbTerminalType.Items.Add "Traço Arquitetônico (45°)"
            cbTerminalType.Items.Add "Seta Fechada"
            cbTerminalType.Items.Add "Seta Aberta"
            cbTerminalType.Items.Add "Ponto / Losango"
            cbTerminalType.Items.Add "Nenhum"
        )

        if cbTerminalPlacement != undefined do
        (
            cbTerminalPlacement.Items.Clear()
            cbTerminalPlacement.Items.Add "Automática"
            cbTerminalPlacement.Items.Add "Interna"
            cbTerminalPlacement.Items.Add "Externa"
        )
    ),

    fn loadDraftToUI =
    (
        if currentDraft == undefined or currentDraft.styleRecord == undefined do return false
        isSyncingUI = true
        try
        (
            local rec = currentDraft.styleRecord

            -- Sincronizar seletor de estilo no cabeçalho
            if cbStyleSelect != undefined and ::AmenoStyleService != undefined do
            (
                local styles = ::AmenoStyleService.listStyles()
                local sIdx = -1
                for i = 1 to styles.count do
                (
                    if styles[i].styleId == currentDraft.sourceStyleId or (stricmp styles[i].name rec.name) == 0 do
                    (
                        sIdx = (i - 1)
                        exit
                    )
                )
                if sIdx >= 0 and cbStyleSelect.SelectedIndex != sIdx do
                (
                    cbStyleSelect.SelectedIndex = sIdx
                )
            )

            -- Font (busca case-insensitive e coerção segura)
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

            if txtTerminalAngle != undefined do txtTerminalAngle.Text = ((rec.terminalAngle as integer) as string) + "°"

            updateDirtyUI()
            updateInUseCount()
            updatePreview()
        )
        catch ()
        isSyncingUI = false
        true
    ),

    fn updatePreview =
    (
        if previewCanvas == undefined or currentDraft == undefined do return false
        if ::AmenoPreviewRenderer != undefined do
        (
            local pm = currentDraft.toPreviewModel()
            ::AmenoPreviewRenderer.render pm previewCanvas
        )
    ),

    fn onCancel =
    (
        callbacks.removeScripts id:#amenoStyleEditorWpfSelection
        if currentDraft != undefined and ::AmenoStyleService != undefined do
        (
            ::AmenoStyleService.discardDraft currentDraft
        )
        currentDraft = undefined
        if window != undefined do window.Close()
    ),

    fn onSaveStyle =
    (
        if currentDraft == undefined or ::AmenoStyleService == undefined do return 0
        try
        (
            local count = ::AmenoStyleService.saveDraftAsStyle currentDraft
            updateDirtyUI()
            updateInUseCount()
            if txtPreviewStatus != undefined do
            (
                txtPreviewStatus.Text = "Estilo '" + currentDraft.styleRecord.name + "' salvo (" + (count as string) + " cotas sincronizadas)"
            )
            count
        )
        catch
        (
            local err = getCurrentException()
            if txtPreviewStatus != undefined do
            (
                txtPreviewStatus.Text = "Erro ao salvar estilo: " + (err as string)
            )
            0
        )
    ),

    fn onApplyToSelection =
    (
        if currentDraft == undefined or ::AmenoStyleService == undefined do return 0
        if selection.count == 0 do
        (
            if txtPreviewStatus != undefined do
            (
                txtPreviewStatus.Text = "Nenhuma cota selecionada na cena para aplicação"
            )
            return 0
        )
        try
        (
            local count = ::AmenoStyleService.applyDraftToSelection currentDraft
            updateInUseCount()
            if txtPreviewStatus != undefined do
            (
                txtPreviewStatus.Text = "Estilo aplicado a " + (count as string) + " cota(s) selecionada(s)"
            )
            count
        )
        catch
        (
            local err = getCurrentException()
            if txtPreviewStatus != undefined do
            (
                txtPreviewStatus.Text = "Erro ao aplicar estilo: " + (err as string)
            )
            0
        )
    ),

    fn onPresetClick presetId =
    (
        if ::AmenoStyleService == undefined do return false
        currentDraft = ::AmenoStyleService.createDraftFromPreset presetId
        loadDraftToUI()
        updateDirtyUI()
        updatePreview()
        true
    ),

    fn onSaveAsNew =
    (
        if currentDraft == undefined or ::AmenoStyleService == undefined do return undefined
        try
        (
            local baseName = currentDraft.styleRecord.name
            local newName = baseName + " (Cópia)"
            local created = ::AmenoStyleService.saveDraftAsNewStyle currentDraft newName:newName
            if created != undefined do
            (
                populateStyleList()
                loadDraftToUI()
                if txtPreviewStatus != undefined do
                (
                    txtPreviewStatus.Text = "Novo estilo criado: " + created.name
                )
            )
            created
        )
        catch
        (
            local err = getCurrentException()
            if txtPreviewStatus != undefined do
            (
                txtPreviewStatus.Text = "Erro ao salvar como novo: " + (err as string)
            )
            undefined
        )
    ),

    fn onFieldChanged propName newVal =
    (
        if isSyncingUI or currentDraft == undefined or currentDraft.styleRecord == undefined do return false
        setProperty currentDraft.styleRecord propName newVal
        currentDraft.markDirty()
        updateDirtyUI()
        updatePreview()
    ),

    fn bindEvents =
    (
        if window == undefined do return false

        -- Atalhos de teclado no Window PreviewKeyDown
        dotNet.addEventHandler window "PreviewKeyDown" (fn onKeyDown sender e =
        (
            local keyStr = e.Key.ToString()
            local isCtrl = (dotNetClass "System.Windows.Input.Keyboard").IsKeyDown (dotNetClass "System.Windows.Input.Key").LeftCtrl or \
                           (dotNetClass "System.Windows.Input.Keyboard").IsKeyDown (dotNetClass "System.Windows.Input.Key").RightCtrl

            if keyStr == "Escape" then
            (
                e.Handled = true
                AmenoStyleEditorWPF.onCancel()
            )
            else if isCtrl and (keyStr == "S") then
            (
                e.Handled = true
                AmenoStyleEditorWPF.onSaveStyle()
            )
            else if isCtrl and (keyStr == "Return" or keyStr == "Enter") then
            (
                e.Handled = true
                AmenoStyleEditorWPF.onApplyToSelection()
            )
        ))

        -- Closed event para cleanup e persistência de preferências
        dotNet.addEventHandler window "Closed" (fn onClosed sender e =
        (
            callbacks.removeScripts id:#amenoStyleEditorWpfSelection
            try
            (
                AmenoStyleEditorWPF.savePreferences (sender.ActualWidth) (sender.ActualHeight) (if AmenoStyleEditorWPF.currentDraft != undefined then AmenoStyleEditorWPF.currentDraft.previewDarkBg else true)
            ) catch ()
            AmenoStyleEditorWPF.window = undefined
            AmenoStyleEditorWindow = undefined
        ))

        -- Botoes de Acao
        if btnCancel != undefined do dotNet.addEventHandler btnCancel "Click" (fn onBtnCancel s e = (AmenoStyleEditorWPF.onCancel()))
        if btnSaveStyle != undefined do dotNet.addEventHandler btnSaveStyle "Click" (fn onBtnSave s e = (AmenoStyleEditorWPF.onSaveStyle()))
        if btnApplySelection != undefined do dotNet.addEventHandler btnApplySelection "Click" (fn onBtnApply s e = (AmenoStyleEditorWPF.onApplyToSelection()))

        -- Presets
        if btnPresetArch != undefined do dotNet.addEventHandler btnPresetArch "Click" (fn onP1 s e = (AmenoStyleEditorWPF.onPresetClick "default"))
        if btnPresetEdit != undefined do dotNet.addEventHandler btnPresetEdit "Click" (fn onP2 s e = (AmenoStyleEditorWPF.onPresetClick "editorial"))
        if btnPresetTech != undefined do dotNet.addEventHandler btnPresetTech "Click" (fn onP3 s e = (AmenoStyleEditorWPF.onPresetClick "technical"))
        if btnSaveAsNew != undefined do dotNet.addEventHandler btnSaveAsNew "Click" (fn onNew s e = (AmenoStyleEditorWPF.onSaveAsNew()))

        -- Atalhos de espessura
        if btnThin != undefined do dotNet.addEventHandler btnThin "Click" (fn onT1 s e = (
            if AmenoStyleEditorWPF.sliderLineThickness != undefined do AmenoStyleEditorWPF.sliderLineThickness.Value = 0.8
        ))
        if btnNorm != undefined do dotNet.addEventHandler btnNorm "Click" (fn onT2 s e = (
            if AmenoStyleEditorWPF.sliderLineThickness != undefined do AmenoStyleEditorWPF.sliderLineThickness.Value = 1.5
        ))
        if btnThick != undefined do dotNet.addEventHandler btnThick "Click" (fn onT3 s e = (
            if AmenoStyleEditorWPF.sliderLineThickness != undefined do AmenoStyleEditorWPF.sliderLineThickness.Value = 2.5
        ))

        -- Alternar Fundo do Preview
        if btnToggleBg != undefined do dotNet.addEventHandler btnToggleBg "Click" (fn onToggleTheme s e = (
            if AmenoStyleEditorWPF.currentDraft != undefined do
            (
                AmenoStyleEditorWPF.currentDraft.previewDarkBg = not AmenoStyleEditorWPF.currentDraft.previewDarkBg
                if AmenoStyleEditorWPF.pnlPreviewHost != undefined do
                (
                    local bgHex = if AmenoStyleEditorWPF.currentDraft.previewDarkBg then "#121212" else "#F5F5F5"
                    if ::AmenoPreviewRenderer != undefined then
                        AmenoStyleEditorWPF.pnlPreviewHost.Background = ::AmenoPreviewRenderer.createBrush bgHex
                )
                AmenoStyleEditorWPF.updatePreview()
            )
        ))

        -- Zoom do Preview
        if btnZoom50 != undefined do dotNet.addEventHandler btnZoom50 "Click" (fn onZ50 s e = (if AmenoStyleEditorWPF.currentDraft != undefined do (AmenoStyleEditorWPF.currentDraft.previewZoom = 0.5; AmenoStyleEditorWPF.updatePreview())))
        if btnZoom100 != undefined do dotNet.addEventHandler btnZoom100 "Click" (fn onZ100 s e = (if AmenoStyleEditorWPF.currentDraft != undefined do (AmenoStyleEditorWPF.currentDraft.previewZoom = 1.0; AmenoStyleEditorWPF.updatePreview())))
        if btnZoom200 != undefined do dotNet.addEventHandler btnZoom200 "Click" (fn onZ200 s e = (if AmenoStyleEditorWPF.currentDraft != undefined do (AmenoStyleEditorWPF.currentDraft.previewZoom = 2.0; AmenoStyleEditorWPF.updatePreview())))

        -- Seleção de Estilo no Topo
        if cbStyleSelect != undefined do dotNet.addEventHandler cbStyleSelect "SelectionChanged" (fn onStyleChange s e = (
            if not AmenoStyleEditorWPF.isSyncingUI and s.SelectedIndex >= 0 and ::AmenoStyleService != undefined do
            (
                local styles = ::AmenoStyleService.listStyles()
                local idx = s.SelectedIndex + 1
                if idx <= styles.count do
                (
                    AmenoStyleEditorWPF.currentDraft = ::AmenoStyleService.createDraftFromStyle styles[idx].styleId
                    AmenoStyleEditorWPF.loadDraftToUI()
                )
            )
        ))

        -- Mudanças nos Sliders e Checkboxes
        if sliderFontSize != undefined do dotNet.addEventHandler sliderFontSize "ValueChanged" (fn onFS s e = (
            local v = (e.NewValue as float)
            if AmenoStyleEditorWPF.txtFontSize != undefined and not AmenoStyleEditorWPF.isSyncingUI do AmenoStyleEditorWPF.txtFontSize.Text = (formattedPrint v format:".1f")
            AmenoStyleEditorWPF.onFieldChanged #fontSize v
        ))

        if sliderTracking != undefined do dotNet.addEventHandler sliderTracking "ValueChanged" (fn onTr s e = (
            local v = (e.NewValue as float)
            if AmenoStyleEditorWPF.txtTracking != undefined and not AmenoStyleEditorWPF.isSyncingUI do AmenoStyleEditorWPF.txtTracking.Text = (formattedPrint v format:".1f")
            AmenoStyleEditorWPF.onFieldChanged #tracking v
        ))

        if sliderTextGap != undefined do dotNet.addEventHandler sliderTextGap "ValueChanged" (fn onTG s e = (
            local v = (e.NewValue as float)
            if AmenoStyleEditorWPF.txtTextGap != undefined and not AmenoStyleEditorWPF.isSyncingUI do AmenoStyleEditorWPF.txtTextGap.Text = (formattedPrint v format:".1f")
            AmenoStyleEditorWPF.onFieldChanged #textGap v
        ))

        if sliderLineThickness != undefined do dotNet.addEventHandler sliderLineThickness "ValueChanged" (fn onLT s e = (
            local v = (e.NewValue as float)
            if AmenoStyleEditorWPF.txtLineThickness != undefined and not AmenoStyleEditorWPF.isSyncingUI do AmenoStyleEditorWPF.txtLineThickness.Text = (formattedPrint v format:".1f")
            AmenoStyleEditorWPF.onFieldChanged #lineThickness v
        ))

        if sliderOverhang != undefined do dotNet.addEventHandler sliderOverhang "ValueChanged" (fn onOH s e = (
            local v = (e.NewValue as float)
            if AmenoStyleEditorWPF.txtOverhang != undefined and not AmenoStyleEditorWPF.isSyncingUI do AmenoStyleEditorWPF.txtOverhang.Text = (formattedPrint v format:".1f")
            AmenoStyleEditorWPF.onFieldChanged #extensionOverhang v
        ))

        if sliderExtensionGap != undefined do dotNet.addEventHandler sliderExtensionGap "ValueChanged" (fn onEG s e = (
            local v = (e.NewValue as float)
            if AmenoStyleEditorWPF.txtExtensionGap != undefined and not AmenoStyleEditorWPF.isSyncingUI do AmenoStyleEditorWPF.txtExtensionGap.Text = (formattedPrint v format:".1f")
            AmenoStyleEditorWPF.onFieldChanged #extensionGap v
        ))

        if sliderTerminalSize != undefined do dotNet.addEventHandler sliderTerminalSize "ValueChanged" (fn onTS s e = (
            local v = (e.NewValue as float)
            if AmenoStyleEditorWPF.txtTerminalSize != undefined and not AmenoStyleEditorWPF.isSyncingUI do AmenoStyleEditorWPF.txtTerminalSize.Text = (formattedPrint v format:".1f")
            AmenoStyleEditorWPF.onFieldChanged #terminalSize v
        ))

        if chkBold != undefined do dotNet.addEventHandler chkBold "Click" (fn onB s e = (
            local v = (s.IsChecked == true)
            AmenoStyleEditorWPF.onFieldChanged #bold v
        ))

        if chkItalic != undefined do dotNet.addEventHandler chkItalic "Click" (fn onI s e = (
            local v = (s.IsChecked == true)
            AmenoStyleEditorWPF.onFieldChanged #italic v
        ))

        if chkTextMask != undefined do dotNet.addEventHandler chkTextMask "Click" (fn onTM s e = (
            local v = (s.IsChecked == true)
            AmenoStyleEditorWPF.onFieldChanged #textMaskEnabled v
        ))

        if cbFontName != undefined do dotNet.addEventHandler cbFontName "SelectionChanged" (fn onFontChange s e = (
            if not AmenoStyleEditorWPF.isSyncingUI and s.SelectedIndex >= 0 do
            (
                local fnName = s.SelectedItem as string
                AmenoStyleEditorWPF.onFieldChanged #fontName fnName
            )
        ))

        if cbTerminalType != undefined do dotNet.addEventHandler cbTerminalType "SelectionChanged" (fn onTermChange s e = (
            if not AmenoStyleEditorWPF.isSyncingUI and s.SelectedIndex >= 0 do
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
                AmenoStyleEditorWPF.onFieldChanged #terminalType tType
            )
        ))

        if cbTerminalPlacement != undefined do dotNet.addEventHandler cbTerminalPlacement "SelectionChanged" (fn onPlaceChange s e = (
            if not AmenoStyleEditorWPF.isSyncingUI and s.SelectedIndex >= 0 do
            (
                local pType = case s.SelectedIndex of
                (
                    0: #auto
                    1: #inside
                    2: #outside
                    default: #auto
                )
                AmenoStyleEditorWPF.onFieldChanged #terminalPlacement pType
            )
        ))
    ),

    fn buildWindow styleId:undefined =
    (
        local prefs = loadPreferences()
        local initW = prefs[1]
        local initH = prefs[2]
        local initDark = prefs[3]

        local targetStyle = if styleId != undefined and styleId != "" then styleId else "default"
        if ::AmenoStyleService != undefined then
        (
            currentDraft = ::AmenoStyleService.createDraftFromStyle targetStyle
        )
        else
        (
            currentDraft = AmenoStyleDraft()
            currentDraft.styleRecord = AmenoStyleRecord()
        )
        currentDraft.previewDarkBg = initDark

        local xamlStr = getXAMLString initialWidth:initW initialHeight:initH
        local xamlReader = dotNetClass "System.Windows.Markup.XamlReader"
        window = xamlReader.Parse xamlStr

        -- Encontrar todos os controles nomeados
        cbStyleSelect = findControl "cbStyleSelect"
        txtInUseCount = findControl "txtInUseCount"
        txtDirtyMark = findControl "txtDirtyMark"
        btnPresetArch = findControl "btnPresetArch"
        btnPresetEdit = findControl "btnPresetEdit"
        btnPresetTech = findControl "btnPresetTech"
        btnSaveAsNew = findControl "btnSaveAsNew"

        btnZoom50 = findControl "btnZoom50"
        btnZoom100 = findControl "btnZoom100"
        btnZoom200 = findControl "btnZoom200"
        btnToggleBg = findControl "btnToggleBg"
        pnlPreviewHost = findControl "pnlPreviewHost"
        previewCanvas = findControl "previewCanvas"
        txtPreviewStatus = findControl "txtPreviewStatus"

        cbFontName = findControl "cbFontName"
        sliderFontSize = findControl "sliderFontSize"
        txtFontSize = findControl "txtFontSize"
        chkBold = findControl "chkBold"
        chkItalic = findControl "chkItalic"
        sliderTracking = findControl "sliderTracking"
        txtTracking = findControl "txtTracking"
        sliderTextGap = findControl "sliderTextGap"
        txtTextGap = findControl "txtTextGap"
        chkTextMask = findControl "chkTextMask"

        btnThin = findControl "btnThin"
        btnNorm = findControl "btnNorm"
        btnThick = findControl "btnThick"
        sliderLineThickness = findControl "sliderLineThickness"
        txtLineThickness = findControl "txtLineThickness"
        sliderOverhang = findControl "sliderOverhang"
        txtOverhang = findControl "txtOverhang"
        sliderExtensionGap = findControl "sliderExtensionGap"
        txtExtensionGap = findControl "txtExtensionGap"

        cbTerminalType = findControl "cbTerminalType"
        sliderTerminalSize = findControl "sliderTerminalSize"
        txtTerminalSize = findControl "txtTerminalSize"
        cbTerminalPlacement = findControl "cbTerminalPlacement"
        sliderTerminalAngle = findControl "sliderTerminalAngle"
        txtTerminalAngle = findControl "txtTerminalAngle"

        btnCancel = findControl "btnCancel"
        btnApplySelection = findControl "btnApplySelection"
        btnSaveStyle = findControl "btnSaveStyle"

        -- Popular coleções iniciais
        populateTerminalOptions()
        populateFontList()
        populateStyleList()

        -- Carregar rascunho nos controles
        loadDraftToUI()

        -- Aplicar cor inicial de fundo do preview conforme preferência
        if pnlPreviewHost != undefined do
        (
            local bgHex = if initDark then "#121212" else "#F5F5F5"
            if ::AmenoPreviewRenderer != undefined then
                pnlPreviewHost.Background = ::AmenoPreviewRenderer.createBrush bgHex
        )

        -- Conectar eventos
        bindEvents()

        -- Registrar callback de seleção de cena para manter contadores sincronizados
        callbacks.removeScripts id:#amenoStyleEditorWpfSelection
        callbacks.addScript #selectionSetChanged "if ::AmenoStyleEditorWPF != undefined and ::AmenoStyleEditorWPF.isOpen() do ::AmenoStyleEditorWPF.onSceneSelectionChanged()" id:#amenoStyleEditorWpfSelection

        -- Renderizar preview inicial
        updatePreview()

        -- Vincular ao HWND do 3ds Max
        try
        (
            local maxHwnd = windows.getMAXHWND()
            local intPtrType = dotNetClass "System.IntPtr"
            local maxIntPtr = dotNetObject intPtrType maxHwnd
            local interopHelper = dotNetObject "System.Windows.Interop.WindowInteropHelper" window
            interopHelper.Owner = maxIntPtr
        )
        catch ()

        AmenoStyleEditorWindow = window
        window
    ),

    fn open styleId:undefined =
    (
        if isOpen() then
        (
            if styleId != undefined and styleId != "" and ::AmenoStyleService != undefined do
            (
                currentDraft = ::AmenoStyleService.createDraftFromStyle styleId
                loadDraftToUI()
            )
            if window.WindowState == (dotNetClass "System.Windows.WindowState").Minimized do
            (
                window.WindowState = (dotNetClass "System.Windows.WindowState").Normal
            )
            window.Activate()
            return window
        )

        buildWindow styleId:styleId
        window.Show()
        window
    ),

    fn close =
    (
        if isOpen() do
        (
            onCancel()
        )
    )
)

AmenoStyleEditorWPF = AmenoStyleEditorWPFDefinition()
