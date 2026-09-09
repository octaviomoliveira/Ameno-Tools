/*
    E13-E -- Aba "Render" da Janela Unificada Ameno - Cotas
    Permite renderizar cotas como overlay PNG transparente com canal alpha
    para composição no Photoshop, After Effects ou apresentação.
*/

global AmenoCotasRenderTab
global AmenoApp
global AmenoRenderCotasService

-- ---------------------------------------------------------------------
-- Callbacks DotNet globais
-- ---------------------------------------------------------------------
fn onAmenoRenderBrowseClick s e =
(
    try (if ::AmenoCotasRenderTab != undefined do ::AmenoCotasRenderTab.browseOutput()) catch ()
)

fn onAmenoRenderResetClick s e =
(
    try (if ::AmenoCotasRenderTab != undefined do ::AmenoCotasRenderTab.resetOutput()) catch ()
)

fn onAmenoRenderCotasClick s e =
(
    try (if ::AmenoCotasRenderTab != undefined do ::AmenoCotasRenderTab.renderCotas()) catch ()
)

fn onAmenoRenderOpenFolderClick s e =
(
    try (if ::AmenoCotasRenderTab != undefined do ::AmenoCotasRenderTab.openOutputFolder()) catch ()
)

fn onAmenoRenderCopyPathClick s e =
(
    try (if ::AmenoCotasRenderTab != undefined do ::AmenoCotasRenderTab.copyOutputPath()) catch ()
)

fn onAmenoRenderDimensionsOnlyChanged s e =
(
    try (if ::AmenoCotasRenderTab != undefined do ::AmenoCotasRenderTab.refreshOutputMode()) catch ()
)

struct AmenoCotasRenderTabDefinition
(
    hostControl = undefined,
    cameraList  = #(),

    fn findControl ctrlName =
    (
        if hostControl == undefined then undefined else hostControl.FindName ctrlName
    ),

    -- -----------------------------------------------------------------
    -- XAML do UserControl
    -- -----------------------------------------------------------------
    fn getXAMLString =
    (
        local resBtnAction = \
            "<Style x:Key='RenderActionBtnStyle' TargetType='Button'>" + \
            "<Setter Property='Background' Value='#252528'/>" + \
            "<Setter Property='Foreground' Value='#CCCCCC'/>" + \
            "<Setter Property='BorderBrush' Value='#3A3A3A'/>" + \
            "<Setter Property='BorderThickness' Value='1'/>" + \
            "<Setter Property='Cursor' Value='Hand'/>" + \
            "<Setter Property='FontSize' Value='11'/>" + \
            "<Setter Property='Height' Value='24'/>" + \
            "<Setter Property='Template'><Setter.Value>" + \
            "<ControlTemplate TargetType='Button'>" + \
            "<Border x:Name='bd' Background='{TemplateBinding Background}'" + \
            " BorderBrush='{TemplateBinding BorderBrush}' BorderThickness='{TemplateBinding BorderThickness}'" + \
            " CornerRadius='3'>" + \
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
            "<Trigger Property='IsEnabled' Value='False'>" + \
            "<Setter TargetName='bd' Property='Opacity' Value='0.4'/>" + \
            "</Trigger>" + \
            "</ControlTemplate.Triggers>" + \
            "</ControlTemplate></Setter.Value></Setter>" + \
            "</Style>"

        local resBtnBigPrimary = \
            "<Style x:Key='RenderBigPrimaryBtnStyle' TargetType='Button'>" + \
            "<Setter Property='Background' Value='#1B4B82'/>" + \
            "<Setter Property='Foreground' Value='#FFFFFF'/>" + \
            "<Setter Property='BorderBrush' Value='#4a9eff'/>" + \
            "<Setter Property='BorderThickness' Value='1'/>" + \
            "<Setter Property='Cursor' Value='Hand'/>" + \
            "<Setter Property='FontSize' Value='12'/>" + \
            "<Setter Property='FontWeight' Value='Bold'/>" + \
            "<Setter Property='Height' Value='36'/>" + \
            "<Setter Property='Template'><Setter.Value>" + \
            "<ControlTemplate TargetType='Button'>" + \
            "<Border x:Name='bd' Background='{TemplateBinding Background}'" + \
            " BorderBrush='{TemplateBinding BorderBrush}' BorderThickness='{TemplateBinding BorderThickness}'" + \
            " CornerRadius='4'>" + \
            "<ContentPresenter HorizontalAlignment='Center' VerticalAlignment='Center'/>" + \
            "</Border>" + \
            "<ControlTemplate.Triggers>" + \
            "<Trigger Property='IsMouseOver' Value='True'>" + \
            "<Setter TargetName='bd' Property='Background' Value='#2A62A6'/>" + \
            "</Trigger>" + \
            "<Trigger Property='IsPressed' Value='True'>" + \
            "<Setter TargetName='bd' Property='Background' Value='#153860'/>" + \
            "</Trigger>" + \
            "<Trigger Property='IsEnabled' Value='False'>" + \
            "<Setter TargetName='bd' Property='Opacity' Value='0.4'/>" + \
            "</Trigger>" + \
            "</ControlTemplate.Triggers>" + \
            "</ControlTemplate></Setter.Value></Setter>" + \
            "</Style>"

        local resources = "<UserControl.Resources>" + \
            resBtnAction + resBtnBigPrimary + \
            "</UserControl.Resources>"

        -- Banner de status do Renderer
        local bannerSection = \
            "<Border Background='#252526' CornerRadius='4' Padding='12,10' Margin='0,0,0,10'>" + \
            "<DockPanel>" + \
            "<Border DockPanel.Dock='Left' Background='#3398C379' BorderBrush='#6698C379' BorderThickness='1' CornerRadius='3' Padding='6,2' Margin='0,0,8,0'>" + \
            "<TextBlock Text='RENDERER' Foreground='#98C379' FontSize='9' FontWeight='Bold' VerticalAlignment='Center'/>" + \
            "</Border>" + \
            "<TextBlock x:Name='txtRendererInfo' Text='Verificando compatibilidade...' Foreground='#CCCCCC' FontSize='11' VerticalAlignment='Center'/>" + \
            "</DockPanel>" + \
            "</Border>"

        -- Seção Arquivo de Saída
        local outputSection = \
            "<Border Background='#252526' CornerRadius='4' Padding='12,10' Margin='0,0,0,10'>" + \
            "<StackPanel>" + \
            "<TextBlock Text='ARQUIVO DE SAÍDA' Foreground='#61AFEF' FontWeight='Bold' FontSize='10' Margin='0,0,0,8'/>" + \
            "<Grid Margin='0,0,0,6'>" + \
            "<Grid.ColumnDefinitions>" + \
            "<ColumnDefinition Width='*'/>" + \
            "<ColumnDefinition Width='6'/>" + \
            "<ColumnDefinition Width='32'/>" + \
            "<ColumnDefinition Width='6'/>" + \
            "<ColumnDefinition Width='46'/>" + \
            "</Grid.ColumnDefinitions>" + \
            "<TextBox x:Name='txtOutputPath' Grid.Column='0' Height='24' Background='#2D2D30' Foreground='#FFFFFF' BorderBrush='#3F3F46' BorderThickness='1' Padding='6,2' FontSize='11'/>" + \
            "<Button x:Name='btnBrowse' Grid.Column='2' Style='{StaticResource RenderActionBtnStyle}' Content='...' ToolTip='Escolher arquivo PNG'/>" + \
            "<Button x:Name='btnAuto' Grid.Column='4' Style='{StaticResource RenderActionBtnStyle}' Content='Auto' ToolTip='Gerar caminho automático'/>" + \
            "</Grid>" + \
            "<DockPanel Margin='0,2,0,0'>" + \
            "<Button x:Name='btnOpenFolder' DockPanel.Dock='Left' Style='{StaticResource RenderActionBtnStyle}' Content='Abrir Pasta' Width='80' Margin='0,0,6,0'/>" + \
            "<Button x:Name='btnCopyPath' DockPanel.Dock='Left' Style='{StaticResource RenderActionBtnStyle}' Content='Copiar Caminho' Width='100'/>" + \
            "<TextBlock/>" + \
            "</DockPanel>" + \
            "</StackPanel>" + \
            "</Border>"

        -- Seção Câmeras & Enquadramento
        local cameraSection = \
            "<Border Background='#252526' CornerRadius='4' Padding='12,10' Margin='0,0,0,10'>" + \
            "<StackPanel>" + \
            "<TextBlock Text='CÂMERA E VISTA' Foreground='#61AFEF' FontWeight='Bold' FontSize='10' Margin='0,0,0,8'/>" + \
            "<Grid Margin='0,0,0,4'>" + \
            "<Grid.ColumnDefinitions>" + \
            "<ColumnDefinition Width='65'/>" + \
            "<ColumnDefinition Width='*'/>" + \
            "</Grid.ColumnDefinitions>" + \
            "<TextBlock Text='Câmera:' Foreground='#AAAAAA' VerticalAlignment='Center' FontSize='11'/>" + \
            "<ComboBox x:Name='cbCameras' Grid.Column='1' Height='24' Background='#2D2D30' Foreground='#FFFFFF' BorderBrush='#3F3F46'/>" + \
            "</Grid>" + \
            "</StackPanel>" + \
            "</Border>"

        -- Seção Configurações de Render
        local configSection = \
            "<Border Background='#252526' CornerRadius='4' Padding='12,10' Margin='0,0,0,10'>" + \
            "<StackPanel>" + \
            "<TextBlock Text='CONFIGURAÇÕES DE RENDER' Foreground='#61AFEF' FontWeight='Bold' FontSize='10' Margin='0,0,0,8'/>" + \
            "<Grid Margin='0,0,0,8'>" + \
            "<Grid.ColumnDefinitions>" + \
            "<ColumnDefinition Width='65'/>" + \
            "<ColumnDefinition Width='*'/>" + \
            "<ColumnDefinition Width='*'/>" + \
            "</Grid.ColumnDefinitions>" + \
            "<TextBlock Text='Incluir:' Foreground='#AAAAAA' VerticalAlignment='Center' FontSize='11'/>" + \
            "<RadioButton x:Name='rbScopeAll' Grid.Column='1' GroupName='renderScope' Content='Todas as cotas' IsChecked='True' Foreground='#CCCCCC' FontSize='11' Cursor='Hand'/>" + \
            "<RadioButton x:Name='rbScopeSelected' Grid.Column='2' GroupName='renderScope' Content='Selecionadas' Foreground='#CCCCCC' FontSize='11' Cursor='Hand'/>" + \
            "</Grid>" + \
            "<CheckBox x:Name='chkDimensionsOnly' Content='Renderizar somente as cotas (sem a planta)' IsChecked='True' Foreground='#FFFFFF' FontSize='11' FontWeight='SemiBold' Cursor='Hand' Margin='65,0,0,7'/>" + \
            "<Grid Margin='0,0,0,4'>" + \
            "<Grid.ColumnDefinitions>" + \
            "<ColumnDefinition Width='65'/>" + \
            "<ColumnDefinition Width='*'/>" + \
            "</Grid.ColumnDefinitions>" + \
            "<TextBlock Text='Fundo:' Foreground='#AAAAAA' VerticalAlignment='Center' FontSize='11'/>" + \
            "<TextBlock x:Name='txtOutputMode' Grid.Column='1' Text='PNG transparente; a planta será ocultada temporariamente.' Foreground='#61AFEF' FontSize='11' VerticalAlignment='Center'/>" + \
            "</Grid>" + \
            "<TextBlock Text='Não é necessário usar o Isolate Selection do 3ds Max.' Foreground='#888888' FontSize='10' Margin='65,2,0,0'/>" + \
            "</StackPanel>" + \
            "</Border>"

        -- Seção Ação & Status
        local actionSection = \
            "<Border Background='#252526' CornerRadius='4' Padding='12,10'>" + \
            "<StackPanel>" + \
            "<Button x:Name='btnRenderCotas' Style='{StaticResource RenderBigPrimaryBtnStyle}' Content='Renderizar Cotas' Margin='0,0,0,8'/>" + \
            "<TextBlock x:Name='txtRenderStatus' Text='Pronto para renderizar overlay de cotas.' Foreground='#888888' FontSize='11' HorizontalAlignment='Center'/>" + \
            "</StackPanel>" + \
            "</Border>"

        local xaml = \
            "<UserControl xmlns='http://schemas.microsoft.com/winfx/2006/xaml/presentation'" + \
            " xmlns:x='http://schemas.microsoft.com/winfx/2006/xaml'>" + \
            resources + \
            "<ScrollViewer VerticalScrollBarVisibility='Auto' HorizontalScrollBarVisibility='Disabled'>" + \
            "<StackPanel Margin='12'>" + \
            bannerSection + \
            outputSection + \
            cameraSection + \
            configSection + \
            actionSection + \
            "</StackPanel>" + \
            "</ScrollViewer>" + \
            "</UserControl>"

        xaml
    ),

    -- -----------------------------------------------------------------
    -- Atualiza lista de câmeras disponíveis
    -- -----------------------------------------------------------------
    fn refreshCameras =
    (
        local cbCam = findControl "cbCameras"
        if cbCam == undefined do return false

        local previousCamera = undefined
        if cbCam.SelectedIndex > 0 and (cbCam.SelectedIndex + 1) <= cameraList.count do
            previousCamera = cameraList[cbCam.SelectedIndex + 1]

        cbCam.Items.Clear()
        cameraList = #()

        cbCam.Items.Add "Vista Atual (Viewport Ativo)"
        append cameraList undefined

        for c in cameras where isValidNode c and not (isKindOf c Targetobject) do
        (
            cbCam.Items.Add c.name
            append cameraList c
        )

        local selectedIndex = 0
        if previousCamera != undefined and isValidNode previousCamera do
        (
            if cameraList.count >= 2 do
                for cameraIndex = 2 to cameraList.count do
                    if cameraList[cameraIndex] == previousCamera do selectedIndex = cameraIndex - 1
        )
        cbCam.SelectedIndex = selectedIndex
        true
    ),

    fn isSupportedRendererInfo infoValue =
    (
        infoValue != undefined and (infoValue.family == #corona or infoValue.family == #vray)
    ),

    fn rendererLabel infoValue =
    (
        if infoValue == undefined then return "Renderer não identificado"

        local displayText = "Renderer não identificado"
        local classText = ""
        try (displayText = infoValue.displayName as string) catch ()
        try (classText = infoValue.className as string) catch ()
        if displayText == "" then displayText = "Renderer não identificado"
        if classText != "" then displayText += " [" + classText + "]"
        displayText
    ),

    fn updateRendererInfoUI infoValue =
    (
        local txtInfo = findControl "txtRendererInfo"
        local btnRender = findControl "btnRenderCotas"
        local canRender = isSupportedRendererInfo infoValue
        if btnRender != undefined do btnRender.IsEnabled = canRender
        if txtInfo == undefined then return canRender

        if canRender then
        (
            if infoValue.family == #corona then
                txtInfo.Text = (rendererLabel infoValue) + " · adapter pronto para PNG transparente"
            else if infoValue.engine == #gpu then
                txtInfo.Text = (rendererLabel infoValue) + " · experimental · adapter pronto para PNG transparente"
            else
                txtInfo.Text = (rendererLabel infoValue) + " · adapter pronto para PNG transparente"
        )
        else if infoValue != undefined then
            txtInfo.Text = (rendererLabel infoValue) + " · sem adapter de render compatível"
        else
            txtInfo.Text = "Renderer não identificado · render desabilitado"
        canRender
    ),

    -- -----------------------------------------------------------------
    -- Atualiza informações de suporte do renderer ativo
    -- -----------------------------------------------------------------
    fn refreshRendererInfo =
    (
        local info = if ::AmenoApp != undefined then (try (::AmenoApp.refreshRenderer()) catch (undefined)) else undefined
        updateRendererInfoUI info
    ),

    fn refreshOutputMode =
    (
        local chkOnly = findControl "chkDimensionsOnly"
        local txtMode = findControl "txtOutputMode"
        if txtMode == undefined then return false

        local dimensionsOnly = (chkOnly == undefined or chkOnly.IsChecked == true)
        if dimensionsOnly then
            txtMode.Text = "PNG transparente; a planta será ocultada temporariamente."
        else
            txtMode.Text = "Cena + cotas; fundo e alpha seguem o renderer."
        true
    ),

    -- -----------------------------------------------------------------
    -- Selecionar arquivo de saída
    -- -----------------------------------------------------------------
    fn browseOutput =
    (
        local txtOut = findControl "txtOutputPath"
        local cur = if txtOut != undefined then txtOut.Text else ""
        if cur == "" and ::AmenoApp != undefined do
            cur = try (::AmenoApp.defaultRenderCotasPath()) catch ("")

        local chosen = getSaveFileName caption:"Salvar overlay de cotas" filename:cur types:"PNG transparente (*.png)|*.png|"
        if chosen != undefined and txtOut != undefined do
            txtOut.Text = chosen
    ),

    -- -----------------------------------------------------------------
    -- Restaurar caminho padrão
    -- -----------------------------------------------------------------
    fn resetOutput =
    (
        local txtOut = findControl "txtOutputPath"
        if txtOut != undefined and ::AmenoApp != undefined do
            txtOut.Text = try (::AmenoApp.defaultRenderCotasPath()) catch ("")
    ),

    -- -----------------------------------------------------------------
    -- Executar render das cotas
    -- -----------------------------------------------------------------
    fn renderCotas =
    (
        if ::AmenoApp == undefined do return false
        local txtOut = findControl "txtOutputPath"
        local rbSel = findControl "rbScopeSelected"
        local chkOnly = findControl "chkDimensionsOnly"
        local txtStatus = findControl "txtRenderStatus"

        -- O renderer pode ter sido trocado no 3ds Max depois que a aba foi
        -- aberta. Revalidar aqui evita usar um adapter antigo (ou chamar
        -- render() com uma classe que o adapter não suporta).
        local liveRendererInfo = try (::AmenoApp.refreshRenderer()) catch (undefined)
        if not (updateRendererInfoUI liveRendererInfo) then
        (
            local rendererText = rendererLabel liveRendererInfo
            local guardMessage = rendererText + " não possui adapter de render compatível. Selecione Corona ou V-Ray antes de renderizar."
            if txtStatus != undefined do txtStatus.Text = "Falha: " + guardMessage
            try (messageBox guardMessage title:"Ameno - Render de Cotas") catch ()
            return false
        )

        local outPath = if txtOut != undefined then txtOut.Text else ""
        local scope = if (rbSel != undefined and rbSel.IsChecked == true) then #selected else #all
        local dimensionsOnly = (chkOnly == undefined or chkOnly.IsChecked == true)

        if txtStatus != undefined do txtStatus.Text = "Renderizando cotas... Por favor aguarde."

        -- A câmera escolhida é enviada diretamente ao serviço/adapter. Isso
        -- preserva a viewport ativa, incluindo vista livre, transform e zoom.
        local cbCam = findControl "cbCameras"
        local selectedCamera = undefined
        if cbCam != undefined and cbCam.SelectedIndex > 0 do
        (
            local cameraIndex = cbCam.SelectedIndex + 1
            if cameraIndex > cameraList.count then
            (
                if txtStatus != undefined do txtStatus.Text = "Falha: a câmera selecionada não existe mais."
                return false
            )
            selectedCamera = cameraList[cameraIndex]
            if selectedCamera == undefined or not isValidNode selectedCamera then
            (
                if txtStatus != undefined do txtStatus.Text = "Falha: a câmera selecionada não existe mais."
                return false
            )
        )

        local success = false
        try
        (
            local result = ::AmenoApp.renderCotas outputPath:outPath selectionMode:scope cameraNode:selectedCamera dimensionsOnly:dimensionsOnly
            if result != undefined and result.success then
            (
                if txtOut != undefined do txtOut.Text = result.outputPath
                if txtStatus != undefined do txtStatus.Text = "Concluido! Overlay salvo com sucesso."
                try (messageBox ("Overlay criado com sucesso:\n\n" + result.outputPath + "\n\nA cena foi restaurada.") title:"Ameno - Render de Cotas") catch ()
                success = true
            )
            else if result != undefined and result.cancelled then
            (
                if txtStatus != undefined do txtStatus.Text = "Cancelado pelo usuario. Cena restaurada."
                success = false
            )
            else
            (
                local err = if result != undefined then result.errorMessage else "Erro desconhecido"
                if txtStatus != undefined do txtStatus.Text = "Falha: " + err
                try (messageBox ("Nao foi possivel renderizar as cotas:\n\n" + err) title:"Ameno - Render de Cotas") catch ()
                success = false
            )
        )
        catch
        (
            local err = getCurrentException() as string
            if txtStatus != undefined do txtStatus.Text = "Falha: " + err
            try (messageBox ("Falha inesperada no render:\n\n" + err) title:"Ameno - Render de Cotas") catch ()
            success = false
        )

        success
    ),

    -- -----------------------------------------------------------------
    -- Abrir pasta de saída no Explorer
    -- -----------------------------------------------------------------
    fn openOutputFolder =
    (
        local txtOut = findControl "txtOutputPath"
        local p = if txtOut != undefined then txtOut.Text else ""
        if p != "" do
        (
            local dirPath = getFilenamePath p
            if dirPath != undefined and dirPath != "" and doesFileExist dirPath do
                try (shellLaunch "explorer.exe" ("/select,\"" + p + "\"")) catch ()
        )
    ),

    -- -----------------------------------------------------------------
    -- Copiar caminho de saída para clipboard
    -- -----------------------------------------------------------------
    fn copyOutputPath =
    (
        local txtOut = findControl "txtOutputPath"
        local p = if txtOut != undefined then txtOut.Text else ""
        if p != "" do
        (
            try
            (
                local clipboardClass = dotNetClass "System.Windows.Clipboard"
                clipboardClass.SetText p
            )
            catch ()
        )
    ),

    -- -----------------------------------------------------------------
    -- Conectar eventos DotNet
    -- -----------------------------------------------------------------
    fn bindEvents =
    (
        if hostControl == undefined do return false

        local btnBrowse = findControl "btnBrowse"
        local btnAuto = findControl "btnAuto"
        local btnRenderCotas = findControl "btnRenderCotas"
        local btnOpenFolder = findControl "btnOpenFolder"
        local btnCopyPath = findControl "btnCopyPath"
        local chkDimensionsOnly = findControl "chkDimensionsOnly"

        if btnBrowse != undefined do dotNet.addEventHandler btnBrowse "Click" onAmenoRenderBrowseClick
        if btnAuto != undefined do dotNet.addEventHandler btnAuto "Click" onAmenoRenderResetClick
        if btnRenderCotas != undefined do dotNet.addEventHandler btnRenderCotas "Click" onAmenoRenderCotasClick
        if btnOpenFolder != undefined do dotNet.addEventHandler btnOpenFolder "Click" onAmenoRenderOpenFolderClick
        if btnCopyPath != undefined do dotNet.addEventHandler btnCopyPath "Click" onAmenoRenderCopyPathClick
        if chkDimensionsOnly != undefined do
        (
            dotNet.addEventHandler chkDimensionsOnly "Checked" onAmenoRenderDimensionsOnlyChanged
            dotNet.addEventHandler chkDimensionsOnly "Unchecked" onAmenoRenderDimensionsOnlyChanged
        )

        true
    ),

    -- Libera referencias aos controles WPF quando o shell fecha. A lista de
    -- cameras sera reconstruida na proxima abertura.
    fn onPanelClosed =
    (
        hostControl = undefined
        cameraList = #()
        true
    ),

    -- -----------------------------------------------------------------
    -- Construir e retornar UserControl WPF
    -- -----------------------------------------------------------------
    fn build =
    (
        if hostControl != undefined do
        (
            local cachedControlOk = try (hostControl.FindName "btnRenderCotas" != undefined) catch (false)
            if cachedControlOk do
            (
                refreshCameras()
                refreshRendererInfo()
                return hostControl
            )
            hostControl = undefined
        )

        local xamlStr    = getXAMLString()
        local xamlReader = dotNetClass "System.Windows.Markup.XamlReader"
        hostControl = xamlReader.Parse xamlStr

        resetOutput()
        refreshCameras()
        refreshRendererInfo()
        refreshOutputMode()
        bindEvents()

        hostControl
    )
)

::AmenoCotasRenderTab = AmenoCotasRenderTabDefinition()
