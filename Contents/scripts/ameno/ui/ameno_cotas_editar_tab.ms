/*
    E13-D -- Aba "Editar" da Janela Unificada Ameno - Cotas
    Permite inspecionar e editar propriedades da cota atualmente selecionada na cena.
    Suporta:
      - Card de metricas (medido, exibido, delta, badge EXATO/MANUAL)
      - Secao Modo de Valor (Medido, Arredondado, Numerico Manual, Texto Manual, Motivo)
      - Secao Estilo da cota com dropdown e botao aplicar
      - Secao Ancoras e Geometria com status e botoes de reancoragem
      - Acoes [Aplicar Alteracao] e [Restaurar Medido]
      - Painel de estado vazio quando nenhuma cota esta selecionada
*/

global AmenoCotasEditarTab
global AmenoApp
global AmenoDimensionCA
global AmenoDimensionGraphics
global AmenoStyleService
global AmenoAnchorService
global AmenoDimensionTool
global AmenoEditChangeRequest

struct AmenoEditChangeRequest
(
    valid = false,
    message = "",
    mode = #measured,
    manualValueMm = undefined,
    manualText = undefined,
    reason = undefined,
    incrementMm = undefined
)

fn AmenoEditarGeometryFilter nodeValue =
(
    if ::AmenoDimensionTool == undefined then false
    else try (::AmenoDimensionTool.isEligibleReferenceNode nodeValue) catch (false)
)

-- ---------------------------------------------------------------------
-- Callbacks DotNet globais (evita closures e erros de escopo)
-- ---------------------------------------------------------------------
fn onAmenoEditarModeChanged s e =
(
    try
    (
        if ::AmenoCotasEditarTab != undefined and not ::AmenoCotasEditarTab.isSyncing do
        (
            local rbRd = ::AmenoCotasEditarTab.findControl "rbModeRounded"
            local rbNum = ::AmenoCotasEditarTab.findControl "rbModeNumeric"
            local rbTxt = ::AmenoCotasEditarTab.findControl "rbModeText"

            local modeName = #measured
            if rbRd != undefined and rbRd.IsChecked == true then modeName = #rounded
            else if rbNum != undefined and rbNum.IsChecked == true then modeName = #manualNumeric
            else if rbTxt != undefined and rbTxt.IsChecked == true then modeName = #manualText

            ::AmenoCotasEditarTab.updateModeInputsState modeName
        )
    )
    catch ()
)

fn onAmenoEditarApplyClick s e =
(
    try
    (
        if ::AmenoCotasEditarTab != undefined do ::AmenoCotasEditarTab.applyChanges()
    )
    catch ()
)

fn onAmenoEditarResetClick s e =
(
    try
    (
        if ::AmenoCotasEditarTab != undefined do ::AmenoCotasEditarTab.restoreMeasured()
    )
    catch ()
)

fn onAmenoEditarApplyStyleClick s e =
(
    try
    (
        if ::AmenoCotasEditarTab != undefined do ::AmenoCotasEditarTab.applyStyle()
    )
    catch ()
)

fn onAmenoEditarReanchorAClick s e =
(
    try
    (
        if ::AmenoCotasEditarTab != undefined do ::AmenoCotasEditarTab.reanchor #pointA
    )
    catch ()
)

fn onAmenoEditarReanchorBClick s e =
(
    try
    (
        if ::AmenoCotasEditarTab != undefined do ::AmenoCotasEditarTab.reanchor #pointB
    )
    catch ()
)

fn onAmenoEditarSelectAnchorsClick s e =
(
    try
    (
        if ::AmenoCotasEditarTab != undefined do ::AmenoCotasEditarTab.selectAnchors()
    )
    catch ()
)

struct AmenoCotasEditarTabDefinition
(
    hostControl = undefined,
    currentCtrl = undefined,
    styleIds    = #(),
    isSyncing   = false,
    callbacksRegistered = false,

    fn findControl ctrlName =
    (
        if hostControl == undefined then undefined else hostControl.FindName ctrlName
    ),

    fn trimText value =
    (
        local textValue = if value == undefined then "" else (value as string)
        try (((dotNetObject "System.String" textValue).Trim()) as string) catch (textValue)
    ),

    fn setStatus messageText isError:false =
    (
        local statusCtrl = findControl "txtEditStatus"
        if statusCtrl != undefined do
        (
            statusCtrl.Text = if messageText == undefined then "" else (messageText as string)
            local brushConv = try (dotNetObject "System.Windows.Media.BrushConverter") catch (undefined)
            if brushConv != undefined do
                statusCtrl.Foreground = brushConv.ConvertFromString (if isError then "#E06C75" else "#98C379")
        )
        not isError
    ),

    fn parsePositiveNumber textValue fieldLabel =
    (
        local raw = trimText textValue
        if raw == "" then return #(false, undefined, fieldLabel + " e obrigatorio.")

        local validCharacters = true
        local decimalCount = 0
        local digitCount = 0
        for i = 1 to raw.count do
        (
            local ch = substring raw i 1
            if findString "0123456789" ch != undefined then
                digitCount += 1
            else if ch == "." or ch == "," then
            (
                decimalCount += 1
                if decimalCount > 1 do validCharacters = false
            )
            else if (ch == "+" or ch == "-") and i == 1 then
            (
                -- sinal permitido apenas no inicio; positivos sao exigidos abaixo
            )
            else
                validCharacters = false
        )

        if not validCharacters or digitCount == 0 then
            return #(false, undefined, fieldLabel + " deve conter apenas um numero decimal.")

        local normalized = substituteString raw "," "."
        local parsed = try (normalized as float) catch (undefined)
        if parsed == undefined then return #(false, undefined, fieldLabel + " nao e um numero valido.")
        if parsed <= 0.0 then return #(false, undefined, fieldLabel + " deve ser maior que zero.")
        #(true, parsed, "")
    ),

    fn selectedValueMode =
    (
        local rbRd = findControl "rbModeRounded"
        local rbNum = findControl "rbModeNumeric"
        local rbTxt = findControl "rbModeText"
        if rbRd != undefined and rbRd.IsChecked == true then #rounded
        else if rbNum != undefined and rbNum.IsChecked == true then #manualNumeric
        else if rbTxt != undefined and rbTxt.IsChecked == true then #manualText
        else #measured
    ),

    fn validateChangeRequest modeName roundingText manualValueText manualText reasonText =
    (
        local request = AmenoEditChangeRequest mode:modeName
        if (findItem #(#measured, #rounded, #manualNumeric, #manualText) modeName) == 0 do
        (
            request.message = "Modo de valor invalido."
            return request
        )

        request.reason = if modeName == #measured then "" else trimText reasonText
        case modeName of
        (
            #rounded:
            (
                local parsed = parsePositiveNumber roundingText "Passo de arredondamento"
                if not parsed[1] do
                (
                    request.message = parsed[3]
                    return request
                )
                -- Campo rotulado em centimetros; persistencia canonica em milimetros.
                request.incrementMm = parsed[2] * 10.0
            )
            #manualNumeric:
            (
                local parsed = parsePositiveNumber manualValueText "Valor manual"
                if not parsed[1] do
                (
                    request.message = parsed[3]
                    return request
                )
                -- Campo rotulado em metros; persistencia canonica em milimetros.
                request.manualValueMm = parsed[2] * 1000.0
            )
            #manualText:
            (
                local cleanText = trimText manualText
                if cleanText == "" do
                (
                    request.message = "Texto manual e obrigatorio."
                    return request
                )
                request.manualText = cleanText
            )
            default: ()
        )
        request.valid = true
        request
    ),

    fn applyChangeToController ctrl modeName roundingText manualValueText manualText reasonText =
    (
        if ctrl == undefined or not isValidNode ctrl do
        (
            setStatus "Selecione uma cota valida para editar." isError:true
            return false
        )
        if ::AmenoApp == undefined do
        (
            setStatus "O servico de edicao Ameno nao esta disponivel." isError:true
            return false
        )

        local request = validateChangeRequest modeName roundingText manualValueText manualText reasonText
        if not request.valid do
        (
            setStatus request.message isError:true
            return false
        )

        local changed = false
        try
        (
            if request.mode == #measured then
                changed = ::AmenoApp.resetDimensionToMeasured ctrl
            else
                changed = ::AmenoApp.setDimensionMode ctrl request.mode manualValueMm:request.manualValueMm \
                    manualText:request.manualText reason:request.reason incrementMm:request.incrementMm
        )
        catch
        (
            setStatus ("Nao foi possivel aplicar a alteracao: " + (getCurrentException() as string)) isError:true
            return false
        )

        if changed != true do
        (
            setStatus "A alteracao nao foi aplicada." isError:true
            return false
        )
        this.refresh()
        setStatus "Alteracao aplicada."
        true
    ),

    -- -----------------------------------------------------------------
    -- XAML do UserControl
    -- -----------------------------------------------------------------
    fn getXAMLString =
    (
        local resBtnAction = \
            "<Style x:Key='EditActionBtnStyle' TargetType='Button'>" + \
            "<Setter Property='Background' Value='#252528'/>" + \
            "<Setter Property='Foreground' Value='#CCCCCC'/>" + \
            "<Setter Property='BorderBrush' Value='#3A3A3A'/>" + \
            "<Setter Property='BorderThickness' Value='1'/>" + \
            "<Setter Property='Cursor' Value='Hand'/>" + \
            "<Setter Property='FontSize' Value='11'/>" + \
            "<Setter Property='Height' Value='26'/>" + \
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

        local resBtnPrimary = \
            "<Style x:Key='EditPrimaryBtnStyle' TargetType='Button'>" + \
            "<Setter Property='Background' Value='#1B4B82'/>" + \
            "<Setter Property='Foreground' Value='#FFFFFF'/>" + \
            "<Setter Property='BorderBrush' Value='#4a9eff'/>" + \
            "<Setter Property='BorderThickness' Value='1'/>" + \
            "<Setter Property='Cursor' Value='Hand'/>" + \
            "<Setter Property='FontSize' Value='11'/>" + \
            "<Setter Property='FontWeight' Value='SemiBold'/>" + \
            "<Setter Property='Height' Value='28'/>" + \
            "<Setter Property='Template'><Setter.Value>" + \
            "<ControlTemplate TargetType='Button'>" + \
            "<Border x:Name='bd' Background='{TemplateBinding Background}'" + \
            " BorderBrush='{TemplateBinding BorderBrush}' BorderThickness='{TemplateBinding BorderThickness}'" + \
            " CornerRadius='3'>" + \
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

        local resBtnSecondary = \
            "<Style x:Key='EditSecondaryBtnStyle' TargetType='Button'>" + \
            "<Setter Property='Background' Value='#2D2D30'/>" + \
            "<Setter Property='Foreground' Value='#CCCCCC'/>" + \
            "<Setter Property='BorderBrush' Value='#3F3F46'/>" + \
            "<Setter Property='BorderThickness' Value='1'/>" + \
            "<Setter Property='Cursor' Value='Hand'/>" + \
            "<Setter Property='FontSize' Value='11'/>" + \
            "<Setter Property='Height' Value='28'/>" + \
            "<Setter Property='Template'><Setter.Value>" + \
            "<ControlTemplate TargetType='Button'>" + \
            "<Border x:Name='bd' Background='{TemplateBinding Background}'" + \
            " BorderBrush='{TemplateBinding BorderBrush}' BorderThickness='{TemplateBinding BorderThickness}'" + \
            " CornerRadius='3'>" + \
            "<ContentPresenter HorizontalAlignment='Center' VerticalAlignment='Center'/>" + \
            "</Border>" + \
            "<ControlTemplate.Triggers>" + \
            "<Trigger Property='IsMouseOver' Value='True'>" + \
            "<Setter TargetName='bd' Property='Background' Value='#3E3E42'/>" + \
            "</Trigger>" + \
            "<Trigger Property='IsEnabled' Value='False'>" + \
            "<Setter TargetName='bd' Property='Opacity' Value='0.4'/>" + \
            "</Trigger>" + \
            "</ControlTemplate.Triggers>" + \
            "</ControlTemplate></Setter.Value></Setter>" + \
            "</Style>"

        local resources = "<UserControl.Resources>" + \
            resBtnAction + resBtnPrimary + resBtnSecondary + \
            "</UserControl.Resources>"

        -- Painel de Estado Vazio (quando nenhuma cota selecionada)
        local emptyStateSection = \
            "<Border x:Name='panelEmpty' Background='#252526' CornerRadius='4' Padding='24' Margin='0,0,0,10' Visibility='Visible'>" + \
            "<StackPanel HorizontalAlignment='Center' VerticalAlignment='Center'>" + \
            "<Border Background='#2D2D30' CornerRadius='20' Width='40' Height='40' HorizontalAlignment='Center' Margin='0,0,0,10'>" + \
            "<TextBlock Text='i' Foreground='#61AFEF' FontWeight='Bold' FontSize='20' HorizontalAlignment='Center' VerticalAlignment='Center'/>" + \
            "</Border>" + \
            "<TextBlock Text='Nenhuma cota selecionada' Foreground='#CCCCCC' FontWeight='SemiBold' FontSize='13' HorizontalAlignment='Center'/>" + \
            "<TextBlock Text='Selecione uma cota no viewport para inspecionar e editar.' Foreground='#777777' FontSize='11' HorizontalAlignment='Center' Margin='0,6,0,0'/>" + \
            "</StackPanel>" + \
            "</Border>"

        -- Conteudo quando ha cota selecionada
        local cardInfoSection = \
            "<Border Background='#252526' CornerRadius='4' Padding='12,10' Margin='0,0,0,10'>" + \
            "<StackPanel>" + \
            "<DockPanel Margin='0,0,0,8'>" + \
            "<TextBlock x:Name='txtSelDimId' DockPanel.Dock='Left' Text='Cota: -' Foreground='#61AFEF' FontWeight='Bold' FontSize='11' VerticalAlignment='Center'/>" + \
            "<Border x:Name='bdBadge' DockPanel.Dock='Right' CornerRadius='3' Padding='6,2' Background='#3398C379' BorderBrush='#6698C379' BorderThickness='1' VerticalAlignment='Center'>" + \
            "<TextBlock x:Name='txtBadge' Text='EXATO' FontSize='9' FontWeight='Bold' Foreground='#98C379'/>" + \
            "</Border>" + \
            "</DockPanel>" + \
            "<Grid Margin='0,2,0,0'>" + \
            "<Grid.ColumnDefinitions>" + \
            "<ColumnDefinition Width='*'/>" + \
            "<ColumnDefinition Width='*'/>" + \
            "<ColumnDefinition Width='*'/>" + \
            "</Grid.ColumnDefinitions>" + \
            "<TextBlock x:Name='txtMeasured' Grid.Column='0' Text='Medido: -' Foreground='#AAAAAA' FontSize='11'/>" + \
            "<TextBlock x:Name='txtDisplay' Grid.Column='1' Text='Exibido: -' Foreground='#CCCCCC' FontWeight='SemiBold' FontSize='11'/>" + \
            "<TextBlock x:Name='txtDelta' Grid.Column='2' Text='Delta: -' Foreground='#E5C07B' FontSize='11'/>" + \
            "</Grid>" + \
            "</StackPanel>" + \
            "</Border>"

        -- Secao Modo de Valor
        local modoValorSection = \
            "<Border Background='#252526' CornerRadius='4' Padding='12,10' Margin='0,0,0,10'>" + \
            "<StackPanel>" + \
            "<TextBlock Text='MODO DE VALOR' Foreground='#61AFEF' FontWeight='Bold' FontSize='10' Margin='0,0,0,8'/>" + \
            "<Grid Margin='0,0,0,8'>" + \
            "<Grid.ColumnDefinitions>" + \
            "<ColumnDefinition Width='*'/>" + \
            "<ColumnDefinition Width='*'/>" + \
            "<ColumnDefinition Width='*'/>" + \
            "<ColumnDefinition Width='*'/>" + \
            "</Grid.ColumnDefinitions>" + \
            "<RadioButton x:Name='rbModeMeasured' Grid.Column='0' GroupName='modoValor' Content='Medido' Foreground='#CCCCCC' FontSize='11' Cursor='Hand'/>" + \
            "<RadioButton x:Name='rbModeRounded' Grid.Column='1' GroupName='modoValor' Content='Arredondado' Foreground='#CCCCCC' FontSize='11' Cursor='Hand'/>" + \
            "<RadioButton x:Name='rbModeNumeric' Grid.Column='2' GroupName='modoValor' Content='Numerico' Foreground='#CCCCCC' FontSize='11' Cursor='Hand'/>" + \
            "<RadioButton x:Name='rbModeText' Grid.Column='3' GroupName='modoValor' Content='Texto' Foreground='#CCCCCC' FontSize='11' Cursor='Hand'/>" + \
            "</Grid>" + \
            "<Grid Margin='0,0,0,6'>" + \
            "<Grid.ColumnDefinitions>" + \
            "<ColumnDefinition Width='110'/>" + \
            "<ColumnDefinition Width='*'/>" + \
            "</Grid.ColumnDefinitions>" + \
            "<TextBlock Text='Passo arred. (cm):' Foreground='#AAAAAA' VerticalAlignment='Center' FontSize='11'/>" + \
            "<TextBox x:Name='txtRounding' Grid.Column='1' Text='5' Height='22' Background='#2D2D30' Foreground='#FFFFFF' BorderBrush='#3F3F46' BorderThickness='1' Padding='4,2' FontSize='11'/>" + \
            "</Grid>" + \
            "<Grid Margin='0,0,0,6'>" + \
            "<Grid.ColumnDefinitions>" + \
            "<ColumnDefinition Width='110'/>" + \
            "<ColumnDefinition Width='*'/>" + \
            "</Grid.ColumnDefinitions>" + \
            "<TextBlock Text='Valor manual (m):' Foreground='#AAAAAA' VerticalAlignment='Center' FontSize='11'/>" + \
            "<TextBox x:Name='txtManualVal' Grid.Column='1' Text='1.00' Height='22' Background='#2D2D30' Foreground='#FFFFFF' BorderBrush='#3F3F46' BorderThickness='1' Padding='4,2' FontSize='11'/>" + \
            "</Grid>" + \
            "<Grid Margin='0,0,0,6'>" + \
            "<Grid.ColumnDefinitions>" + \
            "<ColumnDefinition Width='110'/>" + \
            "<ColumnDefinition Width='*'/>" + \
            "</Grid.ColumnDefinitions>" + \
            "<TextBlock Text='Texto manual:' Foreground='#AAAAAA' VerticalAlignment='Center' FontSize='11'/>" + \
            "<TextBox x:Name='txtManualText' Grid.Column='1' Text='' Height='22' Background='#2D2D30' Foreground='#FFFFFF' BorderBrush='#3F3F46' BorderThickness='1' Padding='4,2' FontSize='11'/>" + \
            "</Grid>" + \
            "<Grid Margin='0,0,0,2'>" + \
            "<Grid.ColumnDefinitions>" + \
            "<ColumnDefinition Width='110'/>" + \
            "<ColumnDefinition Width='*'/>" + \
            "</Grid.ColumnDefinitions>" + \
            "<TextBlock Text='Motivo:' Foreground='#AAAAAA' VerticalAlignment='Center' FontSize='11'/>" + \
            "<TextBox x:Name='txtReason' Grid.Column='1' Text='' Height='22' Background='#2D2D30' Foreground='#FFFFFF' BorderBrush='#3F3F46' BorderThickness='1' Padding='4,2' FontSize='11'/>" + \
            "</Grid>" + \
            "</StackPanel>" + \
            "</Border>"

        -- Secao Estilo
        local estiloSection = \
            "<Border Background='#252526' CornerRadius='4' Padding='12,10' Margin='0,0,0,10'>" + \
            "<StackPanel>" + \
            "<TextBlock Text='ESTILO DA COTA' Foreground='#61AFEF' FontWeight='Bold' FontSize='10' Margin='0,0,0,8'/>" + \
            "<Grid>" + \
            "<Grid.ColumnDefinitions>" + \
            "<ColumnDefinition Width='*'/>" + \
            "<ColumnDefinition Width='8'/>" + \
            "<ColumnDefinition Width='100'/>" + \
            "</Grid.ColumnDefinitions>" + \
            "<ComboBox x:Name='cbEstilo' Grid.Column='0' Height='24' Background='#2D2D30' Foreground='#FFFFFF' BorderBrush='#3F3F46'/>" + \
            "<Button x:Name='btnAplicarEstilo' Grid.Column='2' Style='{StaticResource EditActionBtnStyle}' Content='Aplicar Estilo'/>" + \
            "</Grid>" + \
            "</StackPanel>" + \
            "</Border>"

        -- Secao Ancoras
        local ancorasSection = \
            "<Border Background='#252526' CornerRadius='4' Padding='12,10' Margin='0,0,0,10'>" + \
            "<StackPanel>" + \
            "<TextBlock Text='ANCORAS E GEOMETRIA' Foreground='#61AFEF' FontWeight='Bold' FontSize='10' Margin='0,0,0,8'/>" + \
            "<TextBlock x:Name='txtAnchorsDesc' Text='Ancoras: -' Foreground='#CCCCCC' FontSize='11' Margin='0,0,0,4'/>" + \
            "<TextBlock x:Name='txtOrphanStatus' Text='Status: -' Foreground='#888888' FontSize='11' Margin='0,0,0,8'/>" + \
            "<Grid>" + \
            "<Grid.ColumnDefinitions>" + \
            "<ColumnDefinition Width='*'/>" + \
            "<ColumnDefinition Width='6'/>" + \
            "<ColumnDefinition Width='*'/>" + \
            "<ColumnDefinition Width='6'/>" + \
            "<ColumnDefinition Width='*'/>" + \
            "</Grid.ColumnDefinitions>" + \
            "<Button x:Name='btnReanchorA' Grid.Column='0' Style='{StaticResource EditActionBtnStyle}' Content='Reancorar A' ToolTip='Selecionar novo ponto para ancora A'/>" + \
            "<Button x:Name='btnReanchorB' Grid.Column='2' Style='{StaticResource EditActionBtnStyle}' Content='Reancorar B' ToolTip='Selecionar novo ponto para ancora B'/>" + \
            "<Button x:Name='btnSelectAnchors' Grid.Column='4' Style='{StaticResource EditActionBtnStyle}' Content='Sel. Nos' ToolTip='Selecionar na cena os objetos vinculados'/>" + \
            "</Grid>" + \
            "</StackPanel>" + \
            "</Border>"

        -- Botoes de Acao no Rodape
        local actionButtonsSection = \
            "<StackPanel>" + \
            "<Grid Margin='0,2,0,0'>" + \
            "<Grid.ColumnDefinitions>" + \
            "<ColumnDefinition Width='*'/>" + \
            "<ColumnDefinition Width='8'/>" + \
            "<ColumnDefinition Width='*'/>" + \
            "</Grid.ColumnDefinitions>" + \
            "<Button x:Name='btnAplicarModo' Grid.Column='0' Style='{StaticResource EditPrimaryBtnStyle}' Content='Aplicar Alteracao'/>" + \
            "<Button x:Name='btnRestaurarMedido' Grid.Column='2' Style='{StaticResource EditSecondaryBtnStyle}' Content='Restaurar Medido'/>" + \
            "</Grid>" + \
            "<TextBlock x:Name='txtEditStatus' Text='' Foreground='#98C379' FontSize='10' TextWrapping='Wrap' Margin='0,6,0,0'/>" + \
            "</StackPanel>"

        local panelSelected = \
            "<StackPanel x:Name='panelSelected' Visibility='Collapsed'>" + \
            cardInfoSection + \
            modoValorSection + \
            estiloSection + \
            ancorasSection + \
            actionButtonsSection + \
            "</StackPanel>"

        local xaml = \
            "<UserControl xmlns='http://schemas.microsoft.com/winfx/2006/xaml/presentation'" + \
            " xmlns:x='http://schemas.microsoft.com/winfx/2006/xaml'>" + \
            resources + \
            "<ScrollViewer VerticalScrollBarVisibility='Auto' HorizontalScrollBarVisibility='Disabled'>" + \
            "<StackPanel Margin='12'>" + \
            emptyStateSection + \
            panelSelected + \
            "</StackPanel>" + \
            "</ScrollViewer>" + \
            "</UserControl>"

        xaml
    ),

    -- -----------------------------------------------------------------
    -- Habilita/desabilita campos conforme o modo de valor
    -- -----------------------------------------------------------------
    fn updateModeInputsState modeName =
    (
        local txtRounding = findControl "txtRounding"
        local txtManualVal = findControl "txtManualVal"
        local txtManualText = findControl "txtManualText"
        local txtReason = findControl "txtReason"

        if txtRounding != undefined do txtRounding.IsEnabled = (modeName == #rounded)
        if txtManualVal != undefined do txtManualVal.IsEnabled = (modeName == #manualNumeric)
        if txtManualText != undefined do txtManualText.IsEnabled = (modeName == #manualText)
        if txtReason != undefined do txtReason.IsEnabled = (modeName != #measured)
    ),

    -- -----------------------------------------------------------------
    -- Popula dropdown de estilos
    -- -----------------------------------------------------------------
    fn populateEstilos ctrl:undefined =
    (
        local cb = findControl "cbEstilo"
        if cb == undefined do return false

        isSyncing = true
        cb.Items.Clear()
        styleIds = #()

        local allStyles = #()
        if ::AmenoStyleService != undefined do
            allStyles = try (::AmenoStyleService.listStyles()) catch (#())

        for s in allStyles do
        (
            cb.Items.Add s.name
            append styleIds s.styleId
        )

        if styleIds.count == 0 do
        (
            cb.Items.Add "Arquitetonico"
            append styleIds "default"
        )

        local targetStyleId = "default"
        if ctrl != undefined and isValidNode ctrl do
        (
            local rec = if ::AmenoDimensionCA != undefined then (::AmenoDimensionCA.readCA ctrl) else undefined
            if rec != undefined and rec.styleId != undefined and rec.styleId != "" then
                targetStyleId = rec.styleId
            else
            (
                local p = if ::AmenoDimensionGraphics != undefined then (::AmenoDimensionGraphics.readTextProperty ctrl "Ameno.StyleId") else undefined
                if p != undefined and p != "" do targetStyleId = p
            )
        )

        local sIdx = findItem styleIds targetStyleId
        if sIdx > 0 then cb.SelectedIndex = (sIdx - 1) else cb.SelectedIndex = 0

        isSyncing = false
        true
    ),

    -- -----------------------------------------------------------------
    -- Atualiza UI com a cota atualmente selecionada
    -- -----------------------------------------------------------------
    fn refresh =
    (
        if hostControl == undefined do return false
        setStatus ""

        local panelEmpty = findControl "panelEmpty"
        local panelSelected = findControl "panelSelected"
        local vis = dotNetClass "System.Windows.Visibility"

        local ctrl = if ::AmenoApp != undefined then ::AmenoApp.getSelectedDimensionController() else undefined
        currentCtrl = ctrl

        if ctrl == undefined or not isValidNode ctrl then
        (
            if panelEmpty != undefined do panelEmpty.Visibility = vis.Visible
            if panelSelected != undefined do panelSelected.Visibility = vis.Collapsed
            return false
        )

        if panelEmpty != undefined do panelEmpty.Visibility = vis.Collapsed
        if panelSelected != undefined do panelSelected.Visibility = vis.Visible

        local audit = if ::AmenoDimensionGraphics != undefined then (::AmenoDimensionGraphics.getDimensionAudit ctrl) else undefined
        if audit == undefined do return false

        -- Card Info
        local txtSelDimId = findControl "txtSelDimId"
        local txtMeasured = findControl "txtMeasured"
        local txtDisplay = findControl "txtDisplay"
        local txtDelta = findControl "txtDelta"
        local txtBadge = findControl "txtBadge"
        local bdBadge = findControl "bdBadge"

        if txtSelDimId != undefined do txtSelDimId.Text = "Cota: " + audit.dimensionId
        if txtMeasured != undefined do txtMeasured.Text = "Medido: " + audit.measuredText
        if txtDisplay != undefined do txtDisplay.Text = "Exibido: " + audit.displayText
        if txtDelta != undefined do txtDelta.Text = "Delta: " + audit.deltaText

        local brushConv = try (dotNetObject "System.Windows.Media.BrushConverter") catch (undefined)
        if txtBadge != undefined and bdBadge != undefined and brushConv != undefined do
        (
            try
            (
                if audit.isManual then
                (
                    txtBadge.Text = "MANUAL"
                    txtBadge.Foreground = brushConv.ConvertFromString "#E5C07B"
                    bdBadge.Background = brushConv.ConvertFromString "#33E5C07B"
                    bdBadge.BorderBrush = brushConv.ConvertFromString "#66E5C07B"
                )
                else
                (
                    txtBadge.Text = "EXATO"
                    txtBadge.Foreground = brushConv.ConvertFromString "#98C379"
                    bdBadge.Background = brushConv.ConvertFromString "#3398C379"
                    bdBadge.BorderBrush = brushConv.ConvertFromString "#6698C379"
                )
            )
            catch ()
        )

        -- Modo de Valor
        local rbMeas = findControl "rbModeMeasured"
        local rbRd = findControl "rbModeRounded"
        local rbNum = findControl "rbModeNumeric"
        local rbTxt = findControl "rbModeText"

        local txtRounding = findControl "txtRounding"
        local txtManualVal = findControl "txtManualVal"
        local txtManualText = findControl "txtManualText"
        local txtReason = findControl "txtReason"

        isSyncing = true
        local nullTrue = dotNetObject "System.Nullable`1[System.Boolean]" true
        case audit.mode of
        (
            #rounded: if rbRd != undefined do rbRd.IsChecked = nullTrue
            #manualNumeric: if rbNum != undefined do rbNum.IsChecked = nullTrue
            #manualText: if rbTxt != undefined do rbTxt.IsChecked = nullTrue
            default: if rbMeas != undefined do rbMeas.IsChecked = nullTrue
        )

        if txtManualVal != undefined do txtManualVal.Text = ((audit.displayMillimeters / 1000.0) as string)
        if txtManualText != undefined do txtManualText.Text = if audit.mode == #manualText then audit.displayText else ""
        if txtReason != undefined do txtReason.Text = audit.manualReason

        local rec = if ::AmenoDimensionCA != undefined then (::AmenoDimensionCA.readCA ctrl) else undefined
        if rec != undefined and txtRounding != undefined do
        (
            local incCm = if rec.roundingIncrementMm > 0.0 then (rec.roundingIncrementMm / 10.0) else 5.0
            txtRounding.Text = (incCm as string)
        )
        isSyncing = false

        updateModeInputsState audit.mode

        -- Estilos
        populateEstilos ctrl:ctrl

        -- Ancoras
        local txtAnchorsDesc = findControl "txtAnchorsDesc"
        local txtOrphanStatus = findControl "txtOrphanStatus"

        if txtAnchorsDesc != undefined do txtAnchorsDesc.Text = "Ancoras: " + audit.anchorDesc
        if txtOrphanStatus != undefined do
        (
            try
            (
                if audit.isOrphan then
                (
                    txtOrphanStatus.Text = "[ALERTA] " + audit.orphanReason
                    if brushConv != undefined do txtOrphanStatus.Foreground = brushConv.ConvertFromString "#E06C75"
                )
                else
                (
                    txtOrphanStatus.Text = "Status: Ancoras sincronizadas"
                    if brushConv != undefined do txtOrphanStatus.Foreground = brushConv.ConvertFromString "#98C379"
                )
            )
            catch ()
        )

        true
    ),

    -- -----------------------------------------------------------------
    -- Aplica alteracoes de modo de valor
    -- -----------------------------------------------------------------
    fn applyChanges =
    (
        if ::AmenoApp == undefined do return false
        local ctrl = ::AmenoApp.getSelectedDimensionController()
        if ctrl == undefined or not isValidNode ctrl do return false

        local rbRd = findControl "rbModeRounded"
        local rbNum = findControl "rbModeNumeric"
        local rbTxt = findControl "rbModeText"

        local modeName = selectedValueMode()

        local txtRounding = findControl "txtRounding"
        local txtManualVal = findControl "txtManualVal"
        local txtManualText = findControl "txtManualText"
        local txtReason = findControl "txtReason"

        local roundingText = if txtRounding != undefined then txtRounding.Text else ""
        local manualValueText = if txtManualVal != undefined then txtManualVal.Text else ""
        local manualText = if txtManualText != undefined then txtManualText.Text else ""
        local reasonText = if txtReason != undefined then txtReason.Text else ""

        applyChangeToController ctrl modeName roundingText manualValueText manualText reasonText
    ),

    -- -----------------------------------------------------------------
    -- Restaura para valor real medido
    -- -----------------------------------------------------------------
    fn restoreMeasured =
    (
        if ::AmenoApp == undefined do return false
        local ctrl = ::AmenoApp.getSelectedDimensionController()
        if ctrl == undefined or not isValidNode ctrl do return false

        try
        (
            local restored = ::AmenoApp.resetDimensionToMeasured ctrl
            if restored != true do
            (
                setStatus "O valor medido nao foi restaurado." isError:true
                return false
            )
            refresh()
            setStatus "Valor medido restaurado."
            true
        )
        catch
        (
            setStatus ("Nao foi possivel restaurar o valor medido: " + (getCurrentException() as string)) isError:true
            false
        )
    ),

    fn restoreMediated =
    (
        restoreMeasured()
    ),

    -- -----------------------------------------------------------------
    -- Aplica estilo selecionado
    -- -----------------------------------------------------------------
    fn applyStyleToController ctrl targetId =
    (
        if ctrl == undefined or not isValidNode ctrl do
        (
            setStatus "Selecione uma cota valida para aplicar o estilo." isError:true
            return false
        )
        if ::AmenoStyleService == undefined do
        (
            setStatus "O servico de estilos Ameno nao esta disponivel." isError:true
            return false
        )
        if targetId == undefined or targetId == "" or (::AmenoStyleService.getStyle targetId) == undefined do
        (
            setStatus "Selecione um estilo valido." isError:true
            return false
        )

        local applied = false
        try (applied = ::AmenoStyleService.applyStyleToDimension ctrl targetId) catch
        (
            setStatus ("Nao foi possivel aplicar o estilo: " + (getCurrentException() as string)) isError:true
            return false
        )
        if applied != true do
        (
            setStatus "O estilo nao foi aplicado." isError:true
            return false
        )
        refresh()
        setStatus "Estilo aplicado."
        true
    ),

    fn applyStyle =
    (
        if ::AmenoApp == undefined do return false
        local ctrl = ::AmenoApp.getSelectedDimensionController()

        local cb = findControl "cbEstilo"
        if cb != undefined and cb.SelectedIndex >= 0 and (cb.SelectedIndex + 1) <= styleIds.count do
        (
            local targetId = styleIds[cb.SelectedIndex + 1]
            return applyStyleToController ctrl targetId
        )
        setStatus "Selecione um estilo valido." isError:true
        false
    ),

    -- -----------------------------------------------------------------
    -- Reancoragem interativa
    -- -----------------------------------------------------------------
    fn applyReanchorTarget ctrl whichPoint targetNode targetWorldPoint vertexId:-1 =
    (
        if ctrl == undefined or not isValidNode ctrl do
        (
            setStatus "Selecione uma cota valida para reancorar." isError:true
            return false
        )
        if whichPoint != #pointA and whichPoint != #pointB do
        (
            setStatus "Ponto de ancora invalido." isError:true
            return false
        )
        if targetNode == undefined or not isValidNode targetNode do
        (
            setStatus "Reancoragem cancelada. Nenhuma ancora foi alterada." isError:true
            return false
        )
        if not (AmenoEditarGeometryFilter targetNode) do
        (
            setStatus "Escolha uma geometria valida; textos e graficos Ameno nao podem ser ancoras." isError:true
            return false
        )
        if targetWorldPoint == undefined or (classof targetWorldPoint) != Point3 do
        (
            setStatus "O ponto geometrico da nova ancora e invalido." isError:true
            return false
        )
        if ::AmenoApp == undefined do
        (
            setStatus "O servico de reancoragem Ameno nao esta disponivel." isError:true
            return false
        )

        local applied = false
        try
        (
            applied = ::AmenoApp.reanchorDimension ctrl whichPoint targetNode targetWorldPoint anchorVertexId:vertexId
        )
        catch
        (
            setStatus ("Nao foi possivel reancorar: " + (getCurrentException() as string)) isError:true
            return false
        )
        if applied != true do
        (
            setStatus "A reancoragem nao foi aplicada." isError:true
            return false
        )
        refresh()
        setStatus ("Ancora " + (if whichPoint == #pointA then "A" else "B") + " atualizada.")
        true
    ),

    fn reanchor whichPoint =
    (
        if ::AmenoApp == undefined do return false
        local ctrl = ::AmenoApp.getSelectedDimensionController()
        if ctrl == undefined or not isValidNode ctrl do
        (
            setStatus "Selecione uma cota na cena para reancorar." isError:true
            return false
        )

        local pointLabel = if whichPoint == #pointA then "A" else "B"
        local pt = pickPoint snap:#3D prompt:("Clique no novo ponto de ancoragem " + pointLabel + " no objeto (Esc cancela)")
        if pt != undefined and pt != #rightClick and (classof pt == Point3) then
        (
            local snapped = false
            local snappedNode = undefined
            local snappedWorldPoint = undefined
            try
            (
                snapped = (snapMode.hit == true)
                if snapped do
                (
                    snappedNode = snapMode.node
                    snappedWorldPoint = snapMode.worldHitpoint
                )
            )
            catch ()

            local hitResult = if ::AmenoDimensionTool != undefined then \
                (::AmenoDimensionTool.detectHitNode pt snapNode:snappedNode snapWorldPoint:snappedWorldPoint snapHit:snapped) \
                else undefined
            local foundNode = if hitResult != undefined then hitResult.node else undefined
            local resolvedPoint = if hitResult != undefined and hitResult.vertexWorldPoint != undefined then hitResult.vertexWorldPoint else pt
            local vertexId = if hitResult != undefined then hitResult.vertexId else -1

            if foundNode == undefined do
            (
                foundNode = pickObject prompt:("Objeto nao detectado. Clique em uma geometria para vincular o ponto " + pointLabel + " (Esc cancela):") filter:AmenoEditarGeometryFilter
                if foundNode == undefined or not isValidNode foundNode do
                (
                    setStatus "Reancoragem cancelada. Nenhuma ancora foi alterada."
                    return false
                )
                hitResult = ::AmenoDimensionTool.detectHitNode resolvedPoint snapNode:foundNode snapWorldPoint:resolvedPoint snapHit:true
                if hitResult != undefined do
                (
                    foundNode = hitResult.node
                    vertexId = hitResult.vertexId
                    if hitResult.vertexWorldPoint != undefined do resolvedPoint = hitResult.vertexWorldPoint
                )
            )

            applyReanchorTarget ctrl whichPoint foundNode resolvedPoint vertexId:vertexId
        )
        else
        (
            setStatus "Reancoragem cancelada. Nenhuma ancora foi alterada."
            false
        )
    ),

    -- -----------------------------------------------------------------
    -- Seleciona nos ancoras na cena
    -- -----------------------------------------------------------------
    fn selectAnchors =
    (
        if ::AmenoApp == undefined do return false
        local ctrl = ::AmenoApp.getSelectedDimensionController()
        if ctrl == undefined or not isValidNode ctrl do return false

        try
        (
            local selected = ::AmenoApp.selectAnchors ctrl
            if selected then setStatus "Nos ancora selecionados."
            else setStatus "A cota selecionada nao possui nos ancora validos." isError:true
            selected
        )
        catch
        (
            setStatus ("Nao foi possivel selecionar as ancoras: " + (getCurrentException() as string)) isError:true
            false
        )
    ),

    fn registerCallbacks =
    (
        try (callbacks.removeScripts id:#amenoCotasEditSync) catch ()
        local callbackText = "if ::AmenoCotasWindow != undefined and ::AmenoCotasWindow.isOpen() and ::AmenoCotasWindow.activeSection == 3 and ::AmenoCotasEditarTab != undefined do (try (::AmenoCotasEditarTab.refresh()) catch ())"
        try (callbacks.addScript #selectionSetChanged callbackText id:#amenoCotasEditSync) catch ()
        try (callbacks.addScript #sceneUndo callbackText id:#amenoCotasEditSync) catch ()
        try (callbacks.addScript #sceneRedo callbackText id:#amenoCotasEditSync) catch ()
        callbacksRegistered = true
        true
    ),

    fn unregisterCallbacks =
    (
        try (callbacks.removeScripts id:#amenoCotasEditSync) catch ()
        callbacksRegistered = false
        true
    ),

    fn onPanelClosed =
    (
        unregisterCallbacks()
        hostControl = undefined
        currentCtrl = undefined
        true
    ),

    -- -----------------------------------------------------------------
    -- Conecta eventos aos controles WPF
    -- -----------------------------------------------------------------
    fn bindEvents =
    (
        if hostControl == undefined do return false

        local rbMeas = findControl "rbModeMeasured"
        local rbRd = findControl "rbModeRounded"
        local rbNum = findControl "rbModeNumeric"
        local rbTxt = findControl "rbModeText"

        if rbMeas != undefined do dotNet.addEventHandler rbMeas "Checked" onAmenoEditarModeChanged
        if rbRd != undefined do dotNet.addEventHandler rbRd "Checked" onAmenoEditarModeChanged
        if rbNum != undefined do dotNet.addEventHandler rbNum "Checked" onAmenoEditarModeChanged
        if rbTxt != undefined do dotNet.addEventHandler rbTxt "Checked" onAmenoEditarModeChanged

        local btnAplicarModo = findControl "btnAplicarModo"
        local btnRestaurarMedido = findControl "btnRestaurarMedido"
        local btnAplicarEstilo = findControl "btnAplicarEstilo"
        local btnReanchorA = findControl "btnReanchorA"
        local btnReanchorB = findControl "btnReanchorB"
        local btnSelectAnchors = findControl "btnSelectAnchors"

        if btnAplicarModo != undefined do dotNet.addEventHandler btnAplicarModo "Click" onAmenoEditarApplyClick
        if btnRestaurarMedido != undefined do dotNet.addEventHandler btnRestaurarMedido "Click" onAmenoEditarResetClick
        if btnAplicarEstilo != undefined do dotNet.addEventHandler btnAplicarEstilo "Click" onAmenoEditarApplyStyleClick
        if btnReanchorA != undefined do dotNet.addEventHandler btnReanchorA "Click" onAmenoEditarReanchorAClick
        if btnReanchorB != undefined do dotNet.addEventHandler btnReanchorB "Click" onAmenoEditarReanchorBClick
        if btnSelectAnchors != undefined do dotNet.addEventHandler btnSelectAnchors "Click" onAmenoEditarSelectAnchorsClick

        true
    ),

    -- -----------------------------------------------------------------
    -- Constroi e retorna o UserControl WPF
    -- -----------------------------------------------------------------
    fn build =
    (
        if hostControl != undefined do
        (
            refresh()
            return hostControl
        )
        local xamlStr    = getXAMLString()
        local xamlReader = dotNetClass "System.Windows.Markup.XamlReader"
        hostControl = xamlReader.Parse xamlStr

        bindEvents()
        refresh()

        hostControl
    )
)

::AmenoCotasEditarTab = AmenoCotasEditarTabDefinition()
