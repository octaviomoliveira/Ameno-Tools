/*
    Ameno Tools -- MacroScripts para Toolbar e Menus do 3ds Max
    Categoria: "Ameno Tools"
*/

macroScript AbrirCotasPanel
category:"Ameno Tools"
internalCategory:"Ameno Tools"
toolTip:"Abrir Painel Ameno · Cotas"
buttonText:"Cotas"
(
    on execute do
    (
        global AmenoCotasWindow
        global AmenoStartupError

        if AmenoCotasWindow == undefined then
        (
            local startupDetail = ""
            try (startupDetail = AmenoStartupError) catch ()
            if startupDetail == undefined or startupDetail == "" do
                startupDetail = "Reinicie o 3ds Max e confira o PackageContents.xml."
            messageBox ("O painel Ameno · Cotas não foi carregado.\n\n" + startupDetail) title:"Ameno Tools"
        )
        else
        (
            try
            (
                AmenoCotasWindow.show()
            )
            catch
            (
                messageBox ("Não foi possível abrir o painel Cotas.\n\n" + (getCurrentException())) title:"Ameno Tools"
            )
        )
    )
)

macroScript CriarCotaIndividual
category:"Ameno Tools"
internalCategory:"Ameno Tools"
toolTip:"Criar Cota Individual (3 cliques)"
buttonText:"Cota Indiv."
(
    on execute do
    (
        global AmenoApp
        if AmenoApp != undefined then
        (
            try
            (
                AmenoApp.startDimensionTool()
            )
            catch
            (
                messageBox ("Não foi possível iniciar a ferramenta de cota:\n\n" + (getCurrentException())) title:"Ameno Tools"
            )
        )
        else
        (
            messageBox "O núcleo do Ameno Tools não está inicializado." title:"Ameno Tools"
        )
    )
)

macroScript CriarCotaContinua
category:"Ameno Tools"
internalCategory:"Ameno Tools"
toolTip:"Criar Cota Contínua"
buttonText:"Cota Cont."
(
    on execute do
    (
        global AmenoApp
        if AmenoApp != undefined then
        (
            try
            (
                if isProperty AmenoApp #startContinuousDimensionTool then
                    AmenoApp.startContinuousDimensionTool()
                else
                    messageBox "A ferramenta de cota contínua (E12) está em desenvolvimento." title:"Ameno Tools"
            )
            catch
            (
                messageBox ("Não foi possível iniciar cotação contínua:\n\n" + (getCurrentException())) title:"Ameno Tools"
            )
        )
        else
        (
            messageBox "O núcleo do Ameno Tools não está inicializado." title:"Ameno Tools"
        )
    )
)

macroScript AbrirEditorEstilos
category:"Ameno Tools"
internalCategory:"Ameno Tools"
toolTip:"Abrir Editor de Estilos Ameno"
buttonText:"Estilos"
(
    on execute do
    (
        global AmenoCotasWindow
        if AmenoCotasWindow != undefined then
        (
            try
            (
                AmenoCotasWindow.show()
                AmenoCotasWindow.setActiveSection 2
            )
            catch
            (
                messageBox ("Não foi possível abrir o editor de estilos:\n\n" + (getCurrentException())) title:"Ameno Tools"
            )
        )
        else
        (
            messageBox "O painel Ameno · Cotas não está inicializado." title:"Ameno Tools"
        )
    )
)

macroScript RenderizarCotas
category:"Ameno Tools"
internalCategory:"Ameno Tools"
toolTip:"Renderizar Cotas em PNG Transparente"
buttonText:"Render Cotas"
(
    on execute do
    (
        global AmenoCotasWindow
        if AmenoCotasWindow != undefined then
        (
            try
            (
                AmenoCotasWindow.show()
                AmenoCotasWindow.setActiveSection 4
            )
            catch
            (
                messageBox ("Não foi possível abrir a aba de render:\n\n" + (getCurrentException())) title:"Ameno Tools"
            )
        )
        else
        (
            messageBox "O painel Ameno · Cotas não está inicializado." title:"Ameno Tools"
        )
    )
)

macroScript AmenoTools_Open
category:"Ameno Tools"
internalCategory:"Ameno Tools"
toolTip:"Abrir Ameno Tools"
buttonText:"Ameno Tools"
(
    on execute do
    (
        global AmenoCotasWindow
        global AmenoApp

        if AmenoCotasWindow != undefined then
        (
            try (AmenoCotasWindow.show()) catch ()
        )
        else if AmenoApp != undefined then
        (
            try (AmenoApp.openMainPanel()) catch ()
        )
    )
)
