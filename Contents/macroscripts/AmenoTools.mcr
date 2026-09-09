/*
    Ameno Tools -- MacroScripts para Toolbar e Menus do 3ds Max
    Categoria: "Ameno Tools"
*/

macroScript AbrirCotasPanel
category:"Ameno Tools"
internalCategory:"Ameno Tools"
toolTip:"Abrir Painel Ameno · Cotas"
buttonText:"Cotas"
Icon:#("ameno/cotas_panel", 1)
(
    on execute do
    (
        global AmenoPythonUI
        global AmenoStartupError

        if AmenoPythonUI == undefined then
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
                AmenoPythonUI.show pageName:"login"
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
Icon:#("ameno/cota_individual", 1)
(
    on execute do
    (
        global AmenoApp
        global AmenoPythonUI
        if AmenoApp != undefined and AmenoPythonUI != undefined then
        (
            try
            (
                AmenoPythonUI.show pageName:"create"
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
Icon:#("ameno/cota_continua", 1)
(
    on execute do
    (
        global AmenoApp
        global AmenoPythonUI
        if AmenoApp != undefined and AmenoPythonUI != undefined then
        (
            try
            (
                AmenoPythonUI.show pageName:"create-continuous"
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
Icon:#("ameno/editor_estilos", 1)
(
    on execute do
    (
        global AmenoPythonUI
        if AmenoPythonUI != undefined then
        (
            try
            (
                AmenoPythonUI.show pageName:"styles"
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
Icon:#("ameno/render_cotas", 1)
(
    on execute do
    (
        global AmenoPythonUI
        if AmenoPythonUI != undefined then
        (
            try
            (
                AmenoPythonUI.show pageName:"render"
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
Icon:#("ameno/cotas_panel", 1)
(
    on execute do
    (
        global AmenoPythonUI
        global AmenoApp

        if AmenoPythonUI != undefined then
        (
            try (AmenoPythonUI.show pageName:"login") catch ()
        )
        else if AmenoApp != undefined then
        (
            try (AmenoApp.openMainPanel()) catch ()
        )
    )
)
