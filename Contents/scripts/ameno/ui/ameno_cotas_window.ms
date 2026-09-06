/*
    E13-A — Shell da Janela Unificada "Ameno · Cotas" (WPF .NET)
    Fornece o container principal da interface unificada.
    Modeless, vinculada ao HWND do Max via WindowInteropHelper. Singleton por sessão.
*/

global AmenoCotasWindow
global AmenoCotasCriarTab
global AmenoCotasEstilosTab
global AmenoCotasEditarTab
global AmenoCotasRenderTab

struct AmenoCotasWindowDefinition
(
    window        = undefined,
    btnClose      = undefined,
    activeSection = 0,

    -- -----------------------------------------------------------------
    -- Helpers
    -- -----------------------------------------------------------------
    fn isOpen =
    (
        window != undefined and (try (window.IsLoaded and window.IsVisible) catch (false))
    ),

    fn suspendForInteractiveTool =
    (
        if window == undefined then return false
        try
        (
            if window.IsLoaded and window.IsVisible then
            (
                window.Hide()
                try (windows.setFocus (windows.getMAXHWND())) catch ()
                true
            )
            else false
        )
        catch (false)
    ),

    fn resumeAfterInteractiveTool =
    (
        if window == undefined then return false
        try
        (
            if not window.IsLoaded then return false
            if not window.IsVisible do window.Show()
            try (window.Activate()) catch ()
            true
        )
        catch (false)
    ),

    fn registerSceneCountCallbacks =
    (
        try (callbacks.removeScripts id:#amenoCotasSceneCount) catch ()
        local callbackText = "if ::AmenoCotasWindow != undefined and ::AmenoCotasWindow.isOpen() and ::AmenoCotasWindow.activeSection == 1 and ::AmenoCotasCriarTab != undefined do (try (::AmenoCotasCriarTab.updateCotaCount()) catch ())"
        try (callbacks.addScript #sceneNodeAdded callbackText id:#amenoCotasSceneCount) catch ()
        try (callbacks.addScript #sceneNodeDeleted callbackText id:#amenoCotasSceneCount) catch ()
        true
    ),

    fn unregisterSceneCountCallbacks =
    (
        try (callbacks.removeScripts id:#amenoCotasSceneCount) catch ()
        true
    ),

    fn findControl ctrlName =
    (
        if window == undefined then undefined else window.FindName ctrlName
    ),

    -- -----------------------------------------------------------------
    -- XAML — construído por concatenação para compatibilidade MaxScript
    -- -----------------------------------------------------------------
    fn getXAMLString =
    (
        local x  = "<Window xmlns='http://schemas.microsoft.com/winfx/2006/xaml/presentation'"
        local x2 = " xmlns:x='http://schemas.microsoft.com/winfx/2006/xaml'"
        local x3 = " Title='Ameno - Cotas' Width='820' Height='560' MinWidth='600' MinHeight='420'"
        local x4 = " WindowStyle='None' AllowsTransparency='True' Background='Transparent'"
        local x5 = " FontFamily='Segoe UI' FontSize='12' WindowStartupLocation='CenterOwner'>"

        -- recursos de estilos
        local res = "<Window.Resources>"
        local resSideBtnStyle = \
            "<Style x:Key='SidebarBtnStyle' TargetType='Button'>" + \
            "<Setter Property='Background' Value='Transparent'/>" + \
            "<Setter Property='Foreground' Value='#AAAAAA'/>" + \
            "<Setter Property='BorderThickness' Value='0'/>" + \
            "<Setter Property='Cursor' Value='Hand'/>" + \
            "<Setter Property='Height' Value='52'/>" + \
            "<Setter Property='Width' Value='64'/>" + \
            "<Setter Property='Template'><Setter.Value>" + \
            "<ControlTemplate TargetType='Button'>" + \
            "<Border x:Name='BtnBorder' Background='{TemplateBinding Background}' BorderThickness='3,0,0,0' BorderBrush='Transparent'>" + \
            "<ContentPresenter HorizontalAlignment='Center' VerticalAlignment='Center'/>" + \
            "</Border>" + \
            "<ControlTemplate.Triggers>" + \
            "<Trigger Property='IsMouseOver' Value='True'>" + \
            "<Setter TargetName='BtnBorder' Property='Background' Value='#22FFFFFF'/>" + \
            "</Trigger>" + \
            "</ControlTemplate.Triggers>" + \
            "</ControlTemplate>" + \
            "</Setter.Value></Setter>" + \
            "</Style>"

        local resCloseStyle = \
            "<Style x:Key='CloseButtonStyle' TargetType='Button'>" + \
            "<Setter Property='Background' Value='Transparent'/>" + \
            "<Setter Property='Foreground' Value='#AAAAAA'/>" + \
            "<Setter Property='BorderThickness' Value='0'/>" + \
            "<Setter Property='Width' Value='46'/>" + \
            "<Setter Property='Height' Value='32'/>" + \
            "<Setter Property='Cursor' Value='Hand'/>" + \
            "<Setter Property='FontSize' Value='14'/>" + \
            "<Setter Property='Template'><Setter.Value>" + \
            "<ControlTemplate TargetType='Button'>" + \
            "<Border x:Name='CloseBorder' Background='{TemplateBinding Background}'>" + \
            "<ContentPresenter HorizontalAlignment='Center' VerticalAlignment='Center'/>" + \
            "</Border>" + \
            "<ControlTemplate.Triggers>" + \
            "<Trigger Property='IsMouseOver' Value='True'>" + \
            "<Setter TargetName='CloseBorder' Property='Background' Value='#E81123'/>" + \
            "<Setter Property='Foreground' Value='#FFFFFF'/>" + \
            "</Trigger>" + \
            "</ControlTemplate.Triggers>" + \
            "</ControlTemplate>" + \
            "</Setter.Value></Setter>" + \
            "</Style>"

        local resEnd = "</Window.Resources>"

        -- container raiz
        local rootBorderOpen = \
            "<Border Background='#1E1E1E' CornerRadius='6' BorderBrush='#3A3A3A' BorderThickness='1'>" + \
            "<Border.Effect><DropShadowEffect BlurRadius='18' ShadowDepth='4' Opacity='0.55' Color='#000000'/></Border.Effect>"

        -- grid principal
        local gridOpen = \
            "<Grid>" + \
            "<Grid.RowDefinitions>" + \
            "<RowDefinition Height='32'/>" + \
            "<RowDefinition Height='2'/>" + \
            "<RowDefinition Height='*'/>" + \
            "<RowDefinition Height='24'/>" + \
            "</Grid.RowDefinitions>"

        -- título bar
        local titleBar = \
            "<Border Grid.Row='0' Background='#252526' CornerRadius='6,6,0,0' x:Name='titleBar'>" + \
            "<Grid>" + \
            "<Grid.ColumnDefinitions>" + \
            "<ColumnDefinition Width='*'/>" + \
            "<ColumnDefinition Width='Auto'/>" + \
            "</Grid.ColumnDefinitions>" + \
            "<StackPanel Grid.Column='0' Orientation='Horizontal' VerticalAlignment='Center' Margin='12,0,0,0'>" + \
            "<Border Background='#4a9eff' CornerRadius='3' Width='20' Height='20' Margin='0,0,8,0'>" + \
            "<TextBlock Text='A' Foreground='#FFFFFF' FontWeight='Bold' FontSize='12'" + \
            " HorizontalAlignment='Center' VerticalAlignment='Center'/>" + \
            "</Border>" + \
            "<TextBlock Text='Ameno - Cotas' Foreground='#CCCCCC' FontWeight='SemiBold'" + \
            " FontSize='13' VerticalAlignment='Center'/>" + \
            "</StackPanel>" + \
            "<Button Grid.Column='1' x:Name='btnClose' Style='{StaticResource CloseButtonStyle}'" + \
            " Content='X' ToolTip='Fechar'/>" + \
            "</Grid>" + \
            "</Border>"

        -- linha accent
        local accentLine = "<Rectangle Grid.Row='1' Fill='#4a9eff'/>"

        -- corpo: sidebar + conteúdo
        local bodyGrid = \
            "<Grid Grid.Row='2'>" + \
            "<Grid.ColumnDefinitions>" + \
            "<ColumnDefinition Width='65'/>" + \
            "<ColumnDefinition Width='1'/>" + \
            "<ColumnDefinition Width='*'/>" + \
            "</Grid.ColumnDefinitions>"

        -- sidebar
        local sidebar = \
            "<Border Grid.Column='0' Background='#252526'>" + \
            "<StackPanel Orientation='Vertical' Margin='0,8,0,0'>" + \
            "<Button x:Name='btnSectionCriar' Style='{StaticResource SidebarBtnStyle}' ToolTip='Criar cotas'>" + \
            "<StackPanel HorizontalAlignment='Center'>" + \
            "<TextBlock Text='+' FontSize='18' HorizontalAlignment='Center' Foreground='#AAAAAA'/>" + \
            "<TextBlock Text='Criar' FontSize='9' HorizontalAlignment='Center' Foreground='#888888' Margin='0,2,0,0'/>" + \
            "</StackPanel></Button>" + \
            "<Button x:Name='btnSectionEstilos' Style='{StaticResource SidebarBtnStyle}' ToolTip='Gerenciar estilos'>" + \
            "<StackPanel HorizontalAlignment='Center'>" + \
            "<TextBlock Text='S' FontSize='16' FontWeight='Bold' HorizontalAlignment='Center' Foreground='#AAAAAA'/>" + \
            "<TextBlock Text='Estilos' FontSize='9' HorizontalAlignment='Center' Foreground='#888888' Margin='0,2,0,0'/>" + \
            "</StackPanel></Button>" + \
            "<Button x:Name='btnSectionEditar' Style='{StaticResource SidebarBtnStyle}' ToolTip='Editar cotas'>" + \
            "<StackPanel HorizontalAlignment='Center'>" + \
            "<TextBlock Text='E' FontSize='16' HorizontalAlignment='Center' Foreground='#AAAAAA'/>" + \
            "<TextBlock Text='Editar' FontSize='9' HorizontalAlignment='Center' Foreground='#888888' Margin='0,2,0,0'/>" + \
            "</StackPanel></Button>" + \
            "<Button x:Name='btnSectionRender' Style='{StaticResource SidebarBtnStyle}' ToolTip='Renderizar cotas'>" + \
            "<StackPanel HorizontalAlignment='Center'>" + \
            "<TextBlock Text='R' FontSize='16' HorizontalAlignment='Center' Foreground='#AAAAAA'/>" + \
            "<TextBlock Text='Render' FontSize='9' HorizontalAlignment='Center' Foreground='#888888' Margin='0,2,0,0'/>" + \
            "</StackPanel></Button>" + \
            "<Rectangle Height='1' Fill='#3A3A3A' Margin='8,8,8,8'/>" + \
            "<Button x:Name='btnSectionConfig' Style='{StaticResource SidebarBtnStyle}' ToolTip='Configuracoes'>" + \
            "<StackPanel HorizontalAlignment='Center'>" + \
            "<TextBlock Text='C' FontSize='16' HorizontalAlignment='Center' Foreground='#AAAAAA'/>" + \
            "<TextBlock Text='Config' FontSize='9' HorizontalAlignment='Center' Foreground='#888888' Margin='0,2,0,0'/>" + \
            "</StackPanel></Button>" + \
            "<Button x:Name='btnSectionLogin' Style='{StaticResource SidebarBtnStyle}' ToolTip='Login (em breve)' IsEnabled='False'>" + \
            "<StackPanel HorizontalAlignment='Center'>" + \
            "<TextBlock Text='L' FontSize='16' HorizontalAlignment='Center' Foreground='#555555'/>" + \
            "<TextBlock Text='Login' FontSize='9' HorizontalAlignment='Center' Foreground='#555555' Margin='0,2,0,0'/>" + \
            "</StackPanel></Button>" + \
            "</StackPanel>" + \
            "</Border>"

        -- separador e area de conteudo (recebe o UserControl da aba ativa)
        local separator  = "<Rectangle Grid.Column='1' Fill='#333333'/>"
        local contentArea = \
            "<Border x:Name='ContentArea' Grid.Column='2' Background='#1E1E1E'/>"

        local bodyGridEnd = "</Grid>"

        -- status bar
        local statusBar = \
            "<Border Grid.Row='3' Background='#252526' CornerRadius='0,0,6,6'>" + \
            "<DockPanel LastChildFill='False' Margin='10,0,10,0'>" + \
            "<TextBlock DockPanel.Dock='Left' Text='Ameno Tools - v2.1'" + \
            " Foreground='#666666' FontSize='10' VerticalAlignment='Center'/>" + \
            "<TextBlock DockPanel.Dock='Right' Text='3ds Max 2026'" + \
            " Foreground='#666666' FontSize='10' VerticalAlignment='Center'/>" + \
            "</DockPanel>" + \
            "</Border>"

        local gridEnd       = "</Grid>"
        local rootBorderEnd = "</Border>"
        local windowEnd     = "</Window>"

        local xaml = x + x2 + x3 + x4 + x5 + \
                     res + resSideBtnStyle + resCloseStyle + resEnd + \
                     rootBorderOpen + \
                     gridOpen + titleBar + accentLine + bodyGrid + \
                     sidebar + separator + contentArea + bodyGridEnd + \
                     statusBar + gridEnd + \
                     rootBorderEnd + windowEnd
        xaml
    ),

    -- -----------------------------------------------------------------
    -- Injectar conteudo da aba ativa na ContentArea
    -- -----------------------------------------------------------------
    fn setTabContent sectionIndex =
    (
        local contentBorder = findControl "ContentArea"
        if contentBorder == undefined do return false

        try
        (
            contentBorder.Child = undefined
        )
        catch ()

        try
        (
            case sectionIndex of
            (
                1: -- Aba Criar
                (
                    if ::AmenoCotasCriarTab != undefined do
                    (
                        local tabControl = ::AmenoCotasCriarTab.build()
                        if tabControl != undefined do
                        (
                            contentBorder.Child = tabControl
                            ::AmenoCotasCriarTab.updateCotaCount()
                        )
                    )
                )
                2: -- Aba Estilos (E13-C)
                (
                    if ::AmenoCotasEstilosTab != undefined do
                    (
                        local tabControl = ::AmenoCotasEstilosTab.build()
                        if tabControl != undefined do
                            contentBorder.Child = tabControl
                    )
                )
                3: -- Aba Editar (E13-D)
                (
                    if ::AmenoCotasEditarTab != undefined do
                    (
                        local tabControl = ::AmenoCotasEditarTab.build()
                        if tabControl != undefined do
                        (
                            contentBorder.Child = tabControl
                            ::AmenoCotasEditarTab.refresh()
                        )
                    )
                )
                4: -- Aba Render (E13-E)
                (
                    if ::AmenoCotasRenderTab != undefined do
                    (
                        local tabControl = ::AmenoCotasRenderTab.build()
                        if tabControl != undefined do
                        (
                            contentBorder.Child = tabControl
                            ::AmenoCotasRenderTab.refreshCameras()
                            ::AmenoCotasRenderTab.refreshRendererInfo()
                        )
                    )
                )
                default:
                (
                    -- Outras abas: placeholder
                    local xamlReader = dotNetClass "System.Windows.Markup.XamlReader"
                    local placeholder = xamlReader.Parse ("<Border xmlns='http://schemas.microsoft.com/winfx/2006/xaml/presentation'>" + \
                        "<StackPanel HorizontalAlignment='Center' VerticalAlignment='Center'>" + \
                        "<TextBlock Text='Em construcao' Foreground='#555555' FontSize='16' FontStyle='Italic' HorizontalAlignment='Center'/>" + \
                        "<TextBlock Text='(disponivel nas proximas fases)' Foreground='#3A3A3A' FontSize='11' HorizontalAlignment='Center' Margin='0,6,0,0'/>" + \
                        "</StackPanel>" + \
                        "</Border>")
                    contentBorder.Child = placeholder
                )
            )
        )
        catch ()

        true
    ),

    -- -----------------------------------------------------------------
    -- Realcar secao ativa na sidebar (borda azul a esquerda)
    -- -----------------------------------------------------------------
    fn setActiveSection sectionIndex =
    (
        local btnNames = #(
            "btnSectionCriar",
            "btnSectionEstilos",
            "btnSectionEditar",
            "btnSectionRender",
            "btnSectionConfig"
        )

        activeSection = sectionIndex

        local converter = try (dotNetObject "System.Windows.Media.BrushConverter") catch (undefined)
        if converter != undefined do
        (
            for i = 1 to btnNames.count do
            (
                local btn = findControl btnNames[i]
                if btn != undefined do
                (
                    try
                    (
                        local isActive = (i == sectionIndex)
                        if isActive then
                        (
                            btn.Background = converter.ConvertFromString "#1A4a9eff"
                            btn.Foreground = converter.ConvertFromString "#FFFFFF"
                        )
                        else
                        (
                            btn.Background = converter.ConvertFromString "Transparent"
                            btn.Foreground = converter.ConvertFromString "#AAAAAA"
                        )
                    )
                    catch ()
                )
            )
        )

        -- Injectar conteudo da aba selecionada
        setTabContent sectionIndex
        if sectionIndex == 3 and ::AmenoCotasEditarTab != undefined do
            try (::AmenoCotasEditarTab.refresh()) catch ()
        if sectionIndex == 4 and ::AmenoCotasRenderTab != undefined do
        (
            try (::AmenoCotasRenderTab.refreshCameras()) catch ()
            try (::AmenoCotasRenderTab.refreshRendererInfo()) catch ()
        )
    ),

    -- -----------------------------------------------------------------
    -- Arrastar pela title bar
    -- -----------------------------------------------------------------
    fn bindTitleBarDrag =
    (
        local titleBarCtrl = findControl "titleBar"
        if titleBarCtrl == undefined do return false

        dotNet.addEventHandler titleBarCtrl "MouseLeftButtonDown" \
            (fn onTitleDrag s e =
            (
                try (AmenoCotasWindow.window.DragMove()) catch ()
            ))
    ),

    -- -----------------------------------------------------------------
    -- Bind de eventos
    -- -----------------------------------------------------------------
    fn bindEvents =
    (
        if window == undefined do return false

        -- Fechar
        if btnClose != undefined do
            dotNet.addEventHandler btnClose "Click" \
                (fn onClose s e = (try (AmenoCotasWindow.close()) catch ()))

        -- Cleaned: limpar singleton
        dotNet.addEventHandler window "Closed" \
            (fn onWindowClosed s e =
            (
                try (callbacks.removeScripts id:#amenoCotasWindowSelection) catch ()
                try (AmenoCotasWindow.unregisterSceneCountCallbacks()) catch ()
                try (AmenoCotasWindow.window = undefined) catch ()
            ))

        -- Tecla Esc fecha a janela; Ctrl+S e Ctrl+Enter repassam para a aba Estilos
        dotNet.addEventHandler window "PreviewKeyDown" \
            (fn onKeyDown s e =
            (
                try
                (
                    local keyStr = e.Key.ToString()
                    if keyStr == "Escape" then
                    (
                        e.Handled = true
                        AmenoCotasWindow.close()
                    )
                    else
                    (
                        local modStr = (dotNetClass "System.Windows.Input.Keyboard").Modifiers.ToString()
                        local isCtrl = matchPattern modStr pattern:"*Control*"
                        if isCtrl and keyStr == "S" and ::AmenoCotasWindow.activeSection == 2 and ::AmenoCotasEstilosTab != undefined do
                        (
                            e.Handled = true
                            try (::AmenoCotasEstilosTab.onSaveStyle()) catch ()
                        )
                        if isCtrl and (keyStr == "Return" or keyStr == "Enter") and ::AmenoCotasWindow.activeSection == 2 and ::AmenoCotasEstilosTab != undefined do
                        (
                            e.Handled = true
                            try (::AmenoCotasEstilosTab.onApplyToSelection()) catch ()
                        )
                    )
                )
                catch ()
            ))

        -- Botões da sidebar
        local btnCriar   = findControl "btnSectionCriar"
        local btnEstilos = findControl "btnSectionEstilos"
        local btnEditar  = findControl "btnSectionEditar"
        local btnRender  = findControl "btnSectionRender"
        local btnConfig  = findControl "btnSectionConfig"

        if btnCriar != undefined do
            dotNet.addEventHandler btnCriar "Click" \
                (fn onCriar s e = (try (AmenoCotasWindow.setActiveSection 1) catch ()))

        if btnEstilos != undefined do
            dotNet.addEventHandler btnEstilos "Click" \
                (fn onEstilos s e = (try (AmenoCotasWindow.setActiveSection 2) catch ()))

        if btnEditar != undefined do
            dotNet.addEventHandler btnEditar "Click" \
                (fn onEditar s e = (try (AmenoCotasWindow.setActiveSection 3) catch ()))

        if btnRender != undefined do
            dotNet.addEventHandler btnRender "Click" \
                (fn onRender s e = (try (AmenoCotasWindow.setActiveSection 4) catch ()))

        if btnConfig != undefined do
            dotNet.addEventHandler btnConfig "Click" \
                (fn onConfig s e = (try (AmenoCotasWindow.setActiveSection 5) catch ()))

        -- Arrastar pelo title bar
        bindTitleBarDrag()

        true
    ),

    -- -----------------------------------------------------------------
    -- Construir e configurar a janela
    -- -----------------------------------------------------------------
    fn buildWindow =
    (
        local xamlStr    = getXAMLString()
        local xamlReader = dotNetClass "System.Windows.Markup.XamlReader"
        window = xamlReader.Parse xamlStr

        -- Referência ao botão fechar
        btnClose = findControl "btnClose"

        -- Vincular ao HWND do 3ds Max (modeless owner)
        try
        (
            local maxHwnd       = windows.getMAXHWND()
            local intPtrType    = dotNetClass "System.IntPtr"
            local maxIntPtr     = dotNetObject intPtrType maxHwnd
            local interopHelper = dotNetObject "System.Windows.Interop.WindowInteropHelper" window
            interopHelper.Owner = maxIntPtr
        )
        catch ()

        -- Conectar eventos
        bindEvents()

        -- Ativar primeira seção (Criar)
        setActiveSection 1

        window
    ),

    -- -----------------------------------------------------------------
    -- Abrir (singleton)
    -- -----------------------------------------------------------------
    fn show =
    (
        if isOpen() then
        (
            -- Já aberta: restaurar e ativar
            try
            (
                local minimized = dotNetClass "System.Windows.WindowState"
                if window.WindowState == minimized.Minimized do
                    window.WindowState = minimized.Normal
            )
            catch ()
            try (window.Activate()) catch ()
            return window
        )

        buildWindow()
        window.Show()
        try
        (
            callbacks.removeScripts id:#amenoCotasWindowSelection
            callbacks.addScript #selectionSetChanged "if ::AmenoCotasWindow != undefined and ::AmenoCotasWindow.isOpen() and ::AmenoCotasWindow.activeSection == 3 and ::AmenoCotasEditarTab != undefined do (try (::AmenoCotasEditarTab.refresh()) catch ())" id:#amenoCotasWindowSelection
        )
        catch ()
        try (AmenoCotasWindow.registerSceneCountCallbacks()) catch ()
        window
    ),

    -- -----------------------------------------------------------------
    -- Selecionar e exibir uma aba por indice (1..5) ou nome
    -- -----------------------------------------------------------------
    fn showTab tabIdentifier =
    (
        local tabIdx = 1
        if (isKindOf tabIdentifier Integer) then
        (
            tabIdx = tabIdentifier
        )
        else if (isKindOf tabIdentifier String) then
        (
            local lowerName = toLower tabIdentifier
            case lowerName of
            (
                "criar": tabIdx = 1
                "estilos": tabIdx = 2
                "estilo": tabIdx = 2
                "editar": tabIdx = 3
                "edicao": tabIdx = 3
                "render": tabIdx = 4
                "renderizar": tabIdx = 4
                "config": tabIdx = 5
                "configuracoes": tabIdx = 5
                default: tabIdx = 1
            )
        )
        if tabIdx < 1 or tabIdx > 5 do tabIdx = 1

        if not isOpen() do show()
        if isOpen() do setActiveSection tabIdx
    ),

    -- -----------------------------------------------------------------
    -- Fechar
    -- -----------------------------------------------------------------
    fn close =
    (
        try (callbacks.removeScripts id:#amenoCotasWindowSelection) catch ()
        try (unregisterSceneCountCallbacks()) catch ()
        local loaded = try (window != undefined and window.IsLoaded) catch (false)
        if loaded do
        (
            try (window.Close()) catch ()
        )
    )
)

AmenoCotasWindow = AmenoCotasWindowDefinition()
