/*
    Ameno Tools - Janela de login WPF
    Aparece quando nao ha sessao valida salva.
    Retorna true se o login foi bem-sucedido, false se o usuario cancelou.
*/

global AmenoLoginWindow

struct AmenoLoginWindowDef
(
    _result = false,

    fn show =
    (
        local xaml = "
<Window
    xmlns='http://schemas.microsoft.com/winfx/2006/xaml/presentation'
    xmlns:x='http://schemas.microsoft.com/winfx/2006/xaml'
    Title='Ameno Tools - Login'
    Width='340' Height='420'
    WindowStartupLocation='CenterScreen'
    ResizeMode='NoResize'
    Background='#1E1E1E'
    Foreground='#E0E0E0'
    FontFamily='Segoe UI'
    FontSize='13'>
  <Window.Resources>
    <Style TargetType='TextBox'>
      <Setter Property='Background' Value='#2D2D2D'/>
      <Setter Property='Foreground' Value='#E0E0E0'/>
      <Setter Property='BorderBrush' Value='#444'/>
      <Setter Property='Padding' Value='8,6'/>
      <Setter Property='Height' Value='34'/>
      <Setter Property='VerticalContentAlignment' Value='Center'/>
    </Style>
    <Style TargetType='PasswordBox'>
      <Setter Property='Background' Value='#2D2D2D'/>
      <Setter Property='Foreground' Value='#E0E0E0'/>
      <Setter Property='BorderBrush' Value='#444'/>
      <Setter Property='Padding' Value='8,6'/>
      <Setter Property='Height' Value='34'/>
      <Setter Property='VerticalContentAlignment' Value='Center'/>
    </Style>
  </Window.Resources>
  <Grid Margin='28'>
    <Grid.RowDefinitions>
      <RowDefinition Height='Auto'/>
      <RowDefinition Height='20'/>
      <RowDefinition Height='Auto'/>
      <RowDefinition Height='6'/>
      <RowDefinition Height='Auto'/>
      <RowDefinition Height='14'/>
      <RowDefinition Height='Auto'/>
      <RowDefinition Height='6'/>
      <RowDefinition Height='Auto'/>
      <RowDefinition Height='16'/>
      <RowDefinition Height='Auto'/>
      <RowDefinition Height='12'/>
      <RowDefinition Height='Auto'/>
      <RowDefinition Height='*'/>
      <RowDefinition Height='Auto'/>
    </Grid.RowDefinitions>

    <!-- Logo / titulo -->
    <StackPanel Grid.Row='0' HorizontalAlignment='Center'>
      <TextBlock Text='Ameno Tools' FontSize='20' FontWeight='Bold'
                 Foreground='#4CA3F5' HorizontalAlignment='Center'/>
      <TextBlock Text='v2.1' FontSize='11' Foreground='#666'
                 HorizontalAlignment='Center' Margin='0,2,0,0'/>
    </StackPanel>

    <!-- Label Email -->
    <TextBlock Grid.Row='2' Text='E-mail' Foreground='#AAA' FontSize='11'/>

    <!-- Campo Email -->
    <TextBox Grid.Row='4' x:Name='txtEmail'/>

    <!-- Label Senha -->
    <TextBlock Grid.Row='6' Text='Senha' Foreground='#AAA' FontSize='11'/>

    <!-- Campo Senha -->
    <PasswordBox Grid.Row='8' x:Name='txtSenha'/>

    <!-- Mensagem de erro -->
    <TextBlock Grid.Row='10' x:Name='lblErro'
               Foreground='#FF6B6B' FontSize='11'
               TextWrapping='Wrap' Text='' Visibility='Collapsed'/>

    <!-- Botao Entrar -->
    <Button Grid.Row='12' x:Name='btnEntrar'
            Content='Entrar'
            Height='38'
            Background='#4CA3F5' Foreground='White'
            FontWeight='SemiBold' FontSize='14'
            BorderThickness='0'
            Cursor='Hand'/>

    <!-- Link solicitar acesso -->
    <TextBlock Grid.Row='14' HorizontalAlignment='Center' VerticalAlignment='Bottom'>
      <Hyperlink x:Name='lnkSolicitar' Foreground='#666'>
        Nao tem conta? Solicitar acesso
      </Hyperlink>
    </TextBlock>
  </Grid>
</Window>"

        -- Carregar o XAML
        local reader   = dotNetObject "System.IO.StringReader" xaml
        local xmlReader = (dotNetClass "System.Xml.XmlReader").Create reader
        local window   = (dotNetClass "System.Windows.Markup.XamlReader").Load xmlReader

        local txtEmail  = window.FindName "txtEmail"
        local txtSenha  = window.FindName "txtSenha"
        local btnEntrar = window.FindName "btnEntrar"
        local lblErro   = window.FindName "lblErro"
        local lnkSol    = window.FindName "lnkSolicitar"

        -- Funcao para mostrar erro na UI
        local fnSetError = fn msg =
        (
            lblErro.Text       = msg
            lblErro.Visibility = if msg != "" \
                then (dotNetClass "System.Windows.Visibility").Visible \
                else (dotNetClass "System.Windows.Visibility").Collapsed
        )

        -- Funcao de login executada ao clicar
        local fnDoLogin = fn sender args =
        (
            local email = txtEmail.Text
            local senha = txtSenha.Password
            fnSetError ""
            btnEntrar.IsEnabled = false
            btnEntrar.Content   = "Entrando..."

            local r = AmenoAuthService.login email senha

            if r.ok then
            (
                window.DialogResult = true
                window.Close()
            )
            else
            (
                fnSetError r.error
                btnEntrar.IsEnabled = true
                btnEntrar.Content   = "Entrar"
            )
        )

        -- Abrir URL de solicitacao de acesso
        local fnSolicitar = fn sender args =
        (
            try
            (
                (dotNetClass "System.Diagnostics.Process").Start \
                    "https://ameno.tools/solicitar-acesso"
            )
            catch ()
        )

        -- Conectar eventos
        dotNet.addEventHandler btnEntrar "Click" fnDoLogin
        dotNet.addEventHandler lnkSol "Click" fnSolicitar

        -- Mostrar janela bloqueante
        local result = window.ShowDialog()
        result == true
    )
)

AmenoLoginWindow = AmenoLoginWindowDef()