/*
    E16.9 — assistente de gate manual no 3ds Max 2026.

    Este arquivo somente observa o processo atual e imprime um roteiro. Não
    cria, remove ou altera nós, materiais, layers, seleção ou a cena. Execute
    em uma cópia descartável depois de reiniciar o Max; a interação humana
    continua necessária para confirmar clipping, DPI e fluidez.
*/
(
    global AmenoE16ManualGate
    global AmenoDimensionContinuousTool
    global AmenoContinuousOverlayService

    struct AmenoE16ManualGateDefinition
    (
        baseline = undefined,
        startedAt = 0,

        fn callbackCount =
        (
            local callbacks = #()
            try (callbacks = showregisteredRedrawViewsCallbacks asArray:true) catch (callbacks = #())
            if callbacks == undefined then 0 else callbacks.count
        ),

        fn sceneSnapshot =
        (
            local handles = for n in objects where isValidNode n collect n.handle
            local classes = for n in objects where isValidNode n collect ((classOf n) as string)
            local materialNames = for n in objects where isValidNode n collect
                (try (if n.material == undefined then "" else n.material.name) catch ("<error>"))
            local layers = #()
            try
            (
                for layerIndex = 0 to (LayerManager.count - 1) do
                    append layers (LayerManager.getLayer layerIndex).name
            )
            catch ()
            local selectionHandles = for n in selection where isValidNode n collect n.handle
            #(handles, classes, materialNames, layers, selectionHandles)
        ),

        fn arraysEqual leftValue rightValue =
        (
            if leftValue == undefined or rightValue == undefined then return (leftValue == rightValue)
            if leftValue.count != rightValue.count then return false
            for i = 1 to leftValue.count do
            (
                if leftValue[i] != rightValue[i] do return false
            )
            true
        ),

        fn snapshotEqual leftValue rightValue =
        (
            if leftValue == undefined or rightValue == undefined or leftValue.count != rightValue.count then return false
            for i = 1 to leftValue.count do
                if not (arraysEqual leftValue[i] rightValue[i]) do return false
            true
        ),

        fn capture =
        (
            baseline = sceneSnapshot()
            startedAt = timeStamp()
            format "[E16_MANUAL] baseline callbacks=% nodes=% layers=% selection=%\n" \
                (callbackCount()) baseline[1].count baseline[4].count baseline[5].count
            baseline
        ),

        fn verify labelValue =
        (
            local current = sceneSnapshot()
            local callbacksNow = callbackCount()
            local sceneOk = snapshotEqual baseline current
            local serviceState = "indisponível"
            local overlaySegments = 0
            local overlayErrors = 0
            if ::AmenoContinuousOverlayService != undefined do
            (
                serviceState = if ::AmenoContinuousOverlayService.enabled then "ativo" else "inativo"
                overlaySegments = ::AmenoContinuousOverlayService.model.segments.count
                overlayErrors = ::AmenoContinuousOverlayService.model.drawErrorCount
            )
            format "[E16_MANUAL] % callbacks=% nodes=% layers=% selection=% sceneDelta=% overlay=% segments=% drawErrors=%\n" \
                labelValue callbacksNow current[1].count current[4].count current[5].count (if sceneOk then "zero" else "ALTERADO") \
                serviceState overlaySegments overlayErrors
            sceneOk
        ),

        fn printChecklist =
        (
            format "\n=== E16.9 GATE MANUAL — 3ds Max 2026 ===\n"
            format "1) Feche qualquer Max antigo e abra um processo novo com uma cópia descartável da cena.\n"
            format "2) Login -> Criar; execute duas cadeias horizontais, duas verticais e quatro fachadas.\n"
            format "3) Durante cada preview, mova, orbite, aplique zoom e alterne viewport sem clicar em referências extras.\n"
            format "4) Repita sucesso, Esc/botão direito e uma falha de commit; confira que a navegação não congela.\n"
            format "5) Teste janela minimizar/maximizar/fechar e DPI 100, 125 e 150 por cento quando disponíveis.\n"
            format "6) Para soak: 20 sessões alternando 2, 10 e 50 referências; faça reset/new/open entre grupos.\n"
            format "7) Após cada grupo execute AmenoE16ManualGate.verify \"grupo-N\". No fim, use verify \"final\".\n"
            format "8) Esperado: callbacks 0 ocioso / 1 durante / 0 ao sair, nodes delta zero no preview, drawErrors=0.\n"
            format "Não salve a cena original. Preserve Listener, Max.log e qualquer dump se houver travamento.\n\n"
            true
        )
    )

    AmenoE16ManualGate = AmenoE16ManualGateDefinition()
    AmenoE16ManualGate.printChecklist()
    AmenoE16ManualGate.capture()
    true
)
