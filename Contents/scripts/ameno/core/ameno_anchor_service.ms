/*
    E8 — Serviço de Âncoras, Reatividade e Diagnóstico de Cotas.

    Gerencia o vínculo paramétrico entre cotas e nós da cena:
    - Rastreia transformações de geometria via NodeEventCallback.
    - Mantém a fila dirtyQueue para atualização com debounce.
    - Garante flush síncrono e mandatório antes de qualquer render (#preRender).
    - Preserva cotas órfãs intactas na cena caso seus nós sejam excluídos.
    - Provê ferramentas de reancoragem, seleção de âncoras e reparo de órfãs.
*/

global AmenoAnchorService
global AmenoAnchorServiceDefinition
global AmenoDimensionCA
global AmenoDimensionGraphics
global AmenoRefreshMainPanel

struct AmenoAnchorServiceDefinition
(
    dirtyQueue = #(),
    anchorCallback = undefined,
    isCallbackActive = false,

    fn markDirty controller =
    (
        if controller == undefined or not isValidNode controller then return false
        if (findItem dirtyQueue controller) == 0 do append dirtyQueue controller
        true
    ),

    fn syncDimension controller =
    (
        if controller == undefined or not isValidNode controller then return false
        if ::AmenoDimensionCA == undefined or ::AmenoDimensionGraphics == undefined then return false

        local rec = ::AmenoDimensionCA.readCA controller
        if rec == undefined then return false

        local resolved = ::AmenoDimensionCA.resolvePoints rec
        if resolved == undefined then return false

        if resolved.changed or (resolved.isOrphan != rec.isOrphan) then
        (
            rec.pointA = resolved.pointA
            rec.pointB = resolved.pointB
            rec.offsetPoint = resolved.offsetPoint
            rec.isOrphan = resolved.isOrphan
            rec.orphanReason = resolved.orphanReason

            ::AmenoDimensionCA.applyCA controller rec
            ::AmenoDimensionGraphics.rebuildDimension controller
            true
        )
        else
        (
            false
        )
    ),

    fn flushQueue =
    (
        if dirtyQueue.count == 0 then return 0

        local currentQueue = for c in dirtyQueue where isValidNode c collect c
        dirtyQueue = #()
        local updatedCount = 0

        for ctrl in currentQueue do
        (
            if syncDimension ctrl do updatedCount += 1
        )

        if updatedCount > 0 and ::AmenoRefreshMainPanel != undefined do
        (
            try (::AmenoRefreshMainPanel()) catch ()
        )

        updatedCount
    ),

    fn syncAll force:false =
    (
        if ::AmenoDimensionGraphics == undefined then return 0

        local controllers = ::AmenoDimensionGraphics.findControllers()
        local updatedCount = 0

        for ctrl in controllers where isValidNode ctrl do
        (
            if force then
            (
                local rec = ::AmenoDimensionCA.readCA ctrl
                if rec != undefined do
                (
                    local res = ::AmenoDimensionCA.resolvePoints rec
                    if res != undefined do
                    (
                        rec.pointA = res.pointA
                        rec.pointB = res.pointB
                        rec.offsetPoint = res.offsetPoint
                        rec.isOrphan = res.isOrphan
                        rec.orphanReason = res.orphanReason
                        ::AmenoDimensionCA.applyCA ctrl rec
                    )
                )
                ::AmenoDimensionGraphics.rebuildDimension ctrl
                updatedCount += 1
            )
            else
            (
                if syncDimension ctrl do updatedCount += 1
            )
        )

        if updatedCount > 0 and ::AmenoRefreshMainPanel != undefined do
        (
            try (::AmenoRefreshMainPanel()) catch ()
        )

        updatedCount
    ),

    fn handleNodesChanged ev nd =
    (
        if nd == undefined or nd.count == 0 then return ()
        if ::AmenoDimensionGraphics == undefined or ::AmenoDimensionCA == undefined then return ()

        local controllers = ::AmenoDimensionGraphics.findControllers()
        for ctrl in controllers where isValidNode ctrl do
        (
            local rec = ::AmenoDimensionCA.readCA ctrl
            if rec != undefined do
            (
                local matchFound = false
                if (rec.anchorType == "nodeA" or rec.anchorType == "both") and rec.nodeA != undefined and isValidNode rec.nodeA do
                (
                    local hA = getHandleByAnim rec.nodeA
                    if (findItem nd hA) > 0 do matchFound = true
                )
                if not matchFound and (rec.anchorType == "nodeB" or rec.anchorType == "both") and rec.nodeB != undefined and isValidNode rec.nodeB do
                (
                    local hB = getHandleByAnim rec.nodeB
                    if (findItem nd hB) > 0 do matchFound = true
                )
                if matchFound do markDirty ctrl
            )
        )

        flushQueue()
    ),

    fn handleNodesDeleted ev nd =
    (
        if ::AmenoDimensionGraphics == undefined or ::AmenoDimensionCA == undefined then return ()

        local controllers = ::AmenoDimensionGraphics.findControllers()
        for ctrl in controllers where isValidNode ctrl do
        (
            local rec = ::AmenoDimensionCA.readCA ctrl
            if rec != undefined and (rec.anchorType == "nodeA" or rec.anchorType == "nodeB" or rec.anchorType == "both") do
            (
                local aLost = (rec.anchorType == "nodeA" or rec.anchorType == "both") and (rec.nodeA == undefined or not (isValidNode rec.nodeA))
                local bLost = (rec.anchorType == "nodeB" or rec.anchorType == "both") and (rec.nodeB == undefined or not (isValidNode rec.nodeB))
                if aLost or bLost do markDirty ctrl
            )
        )

        flushQueue()
    ),

    fn onPreRender =
    (
        flushQueue()
        syncAll force:false
    ),

    fn reanchorDimension controller whichPoint targetNode targetWorldPoint =
    (
        if controller == undefined or not isValidNode controller then return false
        if ::AmenoDimensionCA == undefined or ::AmenoDimensionGraphics == undefined then return false

        local rec = ::AmenoDimensionCA.readCA controller
        if rec == undefined then return false

        undo "Ameno: reancorar cota" on
        (
            if whichPoint == #pointA then
            (
                if targetNode != undefined and isValidNode targetNode then
                (
                    rec.nodeA = targetNode
                    rec.localPointA = targetWorldPoint * (inverse targetNode.transform)
                    rec.pointA = targetWorldPoint
                    rec.anchorType = if (rec.anchorType == "nodeB" or rec.anchorType == "both") then "both" else "nodeA"
                )
                else
                (
                    rec.nodeA = undefined
                    rec.pointA = targetWorldPoint
                    rec.anchorType = if (rec.anchorType == "nodeB" or rec.anchorType == "both") then "nodeB" else "world"
                )
            )
            else if whichPoint == #pointB then
            (
                if targetNode != undefined and isValidNode targetNode then
                (
                    rec.nodeB = targetNode
                    rec.localPointB = targetWorldPoint * (inverse targetNode.transform)
                    rec.pointB = targetWorldPoint
                    rec.anchorType = if (rec.anchorType == "nodeA" or rec.anchorType == "both") then "both" else "nodeB"
                )
                else
                (
                    rec.nodeB = undefined
                    rec.pointB = targetWorldPoint
                    rec.anchorType = if (rec.anchorType == "nodeA" or rec.anchorType == "both") then "nodeA" else "world"
                )
            )

            local resolved = ::AmenoDimensionCA.resolvePoints rec
            if resolved != undefined do
            (
                rec.isOrphan = resolved.isOrphan
                rec.orphanReason = resolved.orphanReason
                rec.offsetPoint = resolved.offsetPoint
            )

            ::AmenoDimensionCA.applyCA controller rec
            ::AmenoDimensionGraphics.rebuildDimension controller
            if ::AmenoRefreshMainPanel != undefined do try (::AmenoRefreshMainPanel()) catch ()
        )
        true
    ),

    fn getAnchoredNodes controller =
    (
        if controller == undefined or not isValidNode controller then return #()
        if ::AmenoDimensionCA == undefined then return #()

        local rec = ::AmenoDimensionCA.readCA controller
        if rec == undefined then return #()

        local result = #()
        if rec.nodeA != undefined and isValidNode rec.nodeA do append result rec.nodeA
        if rec.nodeB != undefined and isValidNode rec.nodeB do append result rec.nodeB
        result
    ),

    fn selectAnchors controller =
    (
        local nodes = getAnchoredNodes controller
        if nodes.count > 0 then
        (
            select nodes
            true
        )
        else
        (
            false
        )
    ),

    fn repairOrphans =
    (
        if ::AmenoDimensionGraphics == undefined or ::AmenoDimensionCA == undefined then return 0

        local controllers = ::AmenoDimensionGraphics.findControllers()
        local repairedCount = 0

        undo "Ameno: reparar cotas órfãs" on
        (
            for ctrl in controllers where isValidNode ctrl do
            (
                local rec = ::AmenoDimensionCA.readCA ctrl
                if rec != undefined and rec.isOrphan do
                (
                    -- Converte referências perdidas em coordenadas mundiais estáticas
                    if rec.nodeA == undefined or not (isValidNode rec.nodeA) do
                    (
                        rec.nodeA = undefined
                        rec.localPointA = [0, 0, 0]
                    )
                    if rec.nodeB == undefined or not (isValidNode rec.nodeB) do
                    (
                        rec.nodeB = undefined
                        rec.localPointB = [0, 0, 0]
                    )

                    if rec.nodeA != undefined then rec.anchorType = "nodeA"
                    else if rec.nodeB != undefined then rec.anchorType = "nodeB"
                    else rec.anchorType = "world"

                    rec.isOrphan = false
                    rec.orphanReason = ""

                    ::AmenoDimensionCA.applyCA ctrl rec
                    ::AmenoDimensionGraphics.rebuildDimension ctrl
                    repairedCount += 1
                )
            )
        )

        if repairedCount > 0 and ::AmenoRefreshMainPanel != undefined do
        (
            try (::AmenoRefreshMainPanel()) catch ()
        )

        repairedCount
    ),

    fn init =
    (
        dirtyQueue = #()

        callbacks.removeScripts id:#ameno_anchors
        callbacks.addScript #preRender "if ::AmenoAnchorService != undefined do ::AmenoAnchorService.onPreRender()" id:#ameno_anchors

        try
        (
            anchorCallback = NodeEventCallback \
                modelStructured:(fn onStruct ev nd = if ::AmenoAnchorService != undefined do ::AmenoAnchorService.handleNodesChanged ev nd) \
                geometryChanged:(fn onGeom ev nd = if ::AmenoAnchorService != undefined do ::AmenoAnchorService.handleNodesChanged ev nd) \
                deleted:(fn onDel ev nd = if ::AmenoAnchorService != undefined do ::AmenoAnchorService.handleNodesDeleted ev nd) \
                delay:50 mouseUp:false
            isCallbackActive = true
        )
        catch
        (
            isCallbackActive = false
        )
        true
    ),

    fn shutdown =
    (
        callbacks.removeScripts id:#ameno_anchors
        anchorCallback = undefined
        isCallbackActive = false
        dirtyQueue = #()
        true
    )
)

AmenoAnchorService = AmenoAnchorServiceDefinition()
AmenoAnchorService.init()
