macroScript AmenoTools_Open
category:"Ameno Tools"
internalCategory:"Ameno Tools"
toolTip:"Abrir Ameno Tools"
buttonText:"Ameno Tools"
(
    on execute do
    (
        global AmenoApp
        global AmenoStartupError

        if AmenoApp == undefined then
        (
            local startupDetail = ""
            try (startupDetail = AmenoStartupError) catch ()

            if startupDetail == undefined or startupDetail == "" do startupDetail = "Reinicie o 3ds Max e confira o PackageContents.xml."

            messageBox ("O núcleo do Ameno Tools não foi carregado.\n\n" + startupDetail) title:"Ameno Tools"
        )
        else
        (
            try
            (
                AmenoApp.openMainPanel()
            )
            catch
            (
                messageBox ("Não foi possível abrir o Ameno Tools.\n\n" + (getCurrentException())) title:"Ameno Tools"
            )
        )
    )
)

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
