macroScript AmenoTools_Open
category:"Ameno Tools"
internalCategory:"Ameno Tools"
toolTip:"Abrir Ameno Tools"
buttonText:"Ameno Tools"
(
    on execute do
    (
        global AmenoApp

        if AmenoApp == undefined then
        (
            messageBox "O núcleo do Ameno Tools não foi carregado. Reinicie o 3ds Max e confira o PackageContents.xml." title:"Ameno Tools"
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
