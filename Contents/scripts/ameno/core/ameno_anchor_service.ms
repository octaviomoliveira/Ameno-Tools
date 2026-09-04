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
global AmenoDimensionMath
global AmenoStyleService
global AmenoRefreshMainPanel
global AmenoRegisterTransformWatcher
global AmenoRegisterGeometryWatcher

-- Função global para registrar watcher de transform em nós âncora.
-- Usa execute() com handle embutido na string para evitar closure e race condition.
-- "when transform X changes" PRECISA estar no nível de script (não em função),
-- então compilamos a string em runtime via execute().
fn AmenoRegisterTransformWatcher theNode =
(
    local h = getHandleByAnim theNode
    local hStr = h as string
    -- Embutir o handle como literal na string do callback evita qualquer
    -- dependência de variáveis externas quando o handler disparar mais tarde.
    local cbBody = \
        "if ::AmenoAnchorService != undefined and " + \
        "::AmenoAnchorService.indexTable != undefined and " + \
        "(hasDictValue ::AmenoAnchorService.indexTable \"" + hStr + "\") do (" + \
        "local _cl = getDictValue ::AmenoAnchorService.indexTable \"" + hStr + "\";" + \
        "if _cl != undefined do (" + \
        "for _c in _cl where isValidNode _c do ::AmenoAnchorService.markDirty _c;" + \
        "if ::AmenoAnchorService.dirtyQueue.count > 0 do ::AmenoAnchorService.flushQueue()))"
    local watchScript = \
        "when transform (getAnimByHandle " + hStr + ") changes id:#ameno_watchers do (" + \
        cbBody + ")"
    try (execute watchScript) catch ()
)

-- O NodeEventCallback permanece como rede global, mas algumas stacks de Edit Poly
-- nao entregam o evento de forma consistente durante a edicao interativa. Este
-- change handler fica ligado diretamente ao no ancorado e usa a mesma dirty queue.
fn AmenoRegisterGeometryWatcher theNode =
(
    local h = getHandleByAnim theNode
    local hStr = h as string
    local cbBody = \
        "if ::AmenoAnchorService != undefined and " + \
        "::AmenoAnchorService.indexTable != undefined and " + \
        "(hasDictValue ::AmenoAnchorService.indexTable \"" + hStr + "\") do (" + \
        "local _cl = getDictValue ::AmenoAnchorService.indexTable \"" + hStr + "\";" + \
        "if _cl != undefined do (" + \
        "for _c in _cl where isValidNode _c do ::AmenoAnchorService.markDirty _c;" + \
        "if ::AmenoAnchorService.dirtyQueue.count > 0 do ::AmenoAnchorService.flushQueue()))"
    local watchScript = \
        "when geometry (getAnimByHandle " + hStr + ") changes id:#ameno_geometry_watchers do (" + \
        cbBody + ")"
    try (execute watchScript) catch ()
)


struct AmenoAnchorServiceDefinition
(
    dirtyQueue = #(),
    anchorCallback = undefined,
    isCallbackActive = false,
    isSyncing = false,
    indexTable = undefined,

    fn rebuildIndex =
    (
        indexTable = Dictionary #string
        if ::AmenoDimensionGraphics == undefined or ::AmenoDimensionCA == undefined then return 0

        -- Remove watchers anteriores antes de recriar o índice
        try (deleteAllChangeHandlers id:#ameno_watchers) catch ()
        try (deleteAllChangeHandlers id:#ameno_geometry_watchers) catch ()

        local controllers = ::AmenoDimensionGraphics.findControllers()
        local watchedHandles = #()

        for ctrl in controllers where isValidNode ctrl do
        (
            local rec = ::AmenoDimensionCA.readCA ctrl
            if rec != undefined do
            (
                if (rec.anchorType == "nodeA" or rec.anchorType == "both") and rec.nodeA != undefined and isValidNode rec.nodeA do
                (
                    local kA = (getHandleByAnim rec.nodeA) as string
                    if hasDictValue indexTable kA then
                    (
                        local listA = getDictValue indexTable kA
                        if (findItem listA ctrl) == 0 do append listA ctrl
                    )
                    else
                    (
                        putDictValue indexTable kA #(ctrl)
                    )
                    -- Registra watcher de transform para este nó (uma vez por nó)
                    local hA = getHandleByAnim rec.nodeA
                    if (findItem watchedHandles hA) == 0 do
                    (
                        append watchedHandles hA
                        if ::AmenoRegisterTransformWatcher != undefined do
                            try (::AmenoRegisterTransformWatcher rec.nodeA) catch ()
                        if ::AmenoRegisterGeometryWatcher != undefined do
                            try (::AmenoRegisterGeometryWatcher rec.nodeA) catch ()
                    )
                )

                if (rec.anchorType == "nodeB" or rec.anchorType == "both") and rec.nodeB != undefined and isValidNode rec.nodeB do
                (
                    local kB = (getHandleByAnim rec.nodeB) as string
                    if hasDictValue indexTable kB then
                    (
                        local listB = getDictValue indexTable kB
                        if (findItem listB ctrl) == 0 do append listB ctrl
                    )
                    else
                    (
                        putDictValue indexTable kB #(ctrl)
                    )
                    -- Registra watcher de transform para este nó (uma vez por nó)
                    local hB = getHandleByAnim rec.nodeB
                    if (findItem watchedHandles hB) == 0 do
                    (
                        append watchedHandles hB
                        if ::AmenoRegisterTransformWatcher != undefined do
                            try (::AmenoRegisterTransformWatcher rec.nodeB) catch ()
                        if ::AmenoRegisterGeometryWatcher != undefined do
                            try (::AmenoRegisterGeometryWatcher rec.nodeB) catch ()
                    )
                )
            )
        )
        controllers.count
    ),


    fn markDirty controller =
    (
        if controller == undefined or not isValidNode controller then return false
        if (findItem dirtyQueue controller) == 0 do append dirtyQueue controller
        true
    ),

    fn updateDimensionFast controller rec resolved =
    (
        local dimensionId = ::AmenoDimensionGraphics.getDimensionId controller
        local nodes = ::AmenoDimensionGraphics.findNodesForDimension dimensionId
        local lineNode = undefined
        local textNode = undefined
        local markerNode = undefined

        for n in nodes where isValidNode n do
        (
            local r = ::AmenoDimensionGraphics.readTextProperty n "Ameno.GraphicRole"
            if r == "lines" do lineNode = n
            if r == "label" do textNode = n
            if r == "marker" do markerNode = n
        )

        -- Se faltarem nós essenciais, reconstrói por completo
        if lineNode == undefined or textNode == undefined then
        (
            return (::AmenoDimensionGraphics.rebuildDimension controller) != undefined
        )

        local mode = #aligned
        try (mode = rec.dimensionMode as name) catch ()
        local layout = ::AmenoDimensionMath.layoutForMode rec.pointA rec.pointB rec.offsetPoint mode:mode
        if layout == undefined or not layout.valid then
        (
            return (::AmenoDimensionGraphics.rebuildDimension controller) != undefined
        )

        local outputUnit = #meters
        try (outputUnit = (rec.outputUnit as name)) catch ()
        local audit = ::AmenoDimensionGraphics.calculateAudit controller layout outputUnit:outputUnit precision:rec.precision

        local resolvedStyle = undefined
        if ::AmenoStyleService != undefined do
        (
            local sId = if rec.styleId != undefined and rec.styleId != "" then rec.styleId else "default"
            resolvedStyle = ::AmenoStyleService.getStyle sId
        )

        ::AmenoDimensionGraphics.updateLineSplinePoints lineNode layout style:resolvedStyle
        ::AmenoDimensionGraphics.updateTextNode textNode audit.displayText layout style:resolvedStyle

        rec.lastMeasuredMm = audit.measuredMillimeters
        rec.lastDeltaMm = audit.deltaMillimeters
        ::AmenoDimensionCA.applyCA controller rec

        -- Atualiza cores de diagnóstico conforme prioridade visual:
        -- 1º Órfã (Vermelho alerta 230, 70, 70)
        -- 2º Manual Válida (Âmbar 245, 166, 35)
        -- 3º Normal / Medida (Branco neutro 245, 245, 245)
        if resolved.isOrphan then
        (
            try (lineNode.wirecolor = (color 230 70 70)) catch ()
            try (textNode.wirecolor = (color 230 70 70)) catch ()
            if markerNode != undefined do try (markerNode.wirecolor = (color 230 70 70)) catch ()
        )
        else if audit.isManual then
        (
            try (lineNode.wirecolor = (color 245 166 35)) catch ()
            try (textNode.wirecolor = (color 245 166 35)) catch ()
            if markerNode != undefined do try (markerNode.wirecolor = (color 245 166 35)) catch ()
        )
        else
        (
            try (lineNode.wirecolor = (color 245 245 245)) catch ()
            try (textNode.wirecolor = (color 245 245 245)) catch ()
        )

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

            with undo off
            (
                updateDimensionFast controller rec resolved
            )
            true
        )
        else
        (
            false
        )
    ),

    fn flushQueue =
    (
        if isSyncing then return 0
        if dirtyQueue.count == 0 then return 0

        isSyncing = true
        local updatedCount = 0

        try
        (
            with undo off
            (
                local currentQueue = for c in dirtyQueue where isValidNode c collect c
                dirtyQueue = #()

                for ctrl in currentQueue do
                (
                    if syncDimension ctrl do updatedCount += 1
                )
            )

            if updatedCount > 0 and ::AmenoRefreshMainPanel != undefined do
            (
                try (::AmenoRefreshMainPanel()) catch ()
            )
        )
        catch
        (
            dirtyQueue = #()
        )

        isSyncing = false
        updatedCount
    ),

    fn syncAll force:false =
    (
        if isSyncing then return 0
        if ::AmenoDimensionGraphics == undefined then return 0

        isSyncing = true
        local controllers = ::AmenoDimensionGraphics.findControllers()
        local updatedCount = 0

        try
        (
            with undo off
            (
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
            )

            if updatedCount > 0 and ::AmenoRefreshMainPanel != undefined do
            (
                try (::AmenoRefreshMainPanel()) catch ()
            )
            rebuildIndex()
        )
        catch ()

        isSyncing = false
        updatedCount
    ),

    fn handleNodesChanged ev nd =
    (
        if isSyncing then return ()
        if nd == undefined or nd.count == 0 then return ()
        if ::AmenoDimensionGraphics == undefined or ::AmenoDimensionCA == undefined then return ()

        if indexTable == undefined do rebuildIndex()

        -- Rebuild lazy: se o índice está vazio mas há controladores na cena,
        -- o init() ocorreu antes de qualquer cota ser criada (ou a cena foi
        -- reaberta). Reindexar agora para não perder a notificação atual.
        if (indexTable.count == 0) and (::AmenoDimensionGraphics.findControllers()).count > 0 do
            rebuildIndex()

        for animHandle in nd do
        (
            local k = animHandle as string
            if hasDictValue indexTable k do
            (
                local list = getDictValue indexTable k
                if list != undefined do
                (
                    for ctrl in list where isValidNode ctrl do markDirty ctrl
                )
            )
        )

        if dirtyQueue.count > 0 do flushQueue()
    ),

    fn handleNodesDeleted ev nd =
    (
        if isSyncing then return ()
        if ::AmenoDimensionGraphics == undefined or ::AmenoDimensionCA == undefined then return ()

        if indexTable != undefined and nd != undefined do
        (
            for animHandle in nd do
            (
                local k = animHandle as string
                if hasDictValue indexTable k do
                (
                    local list = getDictValue indexTable k
                    if list != undefined do
                    (
                        for ctrl in list where isValidNode ctrl do markDirty ctrl
                    )
                )
            )
        )

        -- Verificação de integridade para todos os controladores com âncoras
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
        rebuildIndex()
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
                    rec.anchorVertexIdA = -1
                    rec.anchorEdgeIdA = -1
                    rec.anchorEdgeMidA = false
                    local toleranceA = ::AmenoDimensionGraphics.toSceneUnits 10.0
                    local vertexHitA = ::AmenoDimensionCA.findNearestVertex targetNode targetWorldPoint maxDistance:toleranceA
                    if vertexHitA != undefined do rec.anchorVertexIdA = vertexHitA.vertexId
                    rec.pointA = targetWorldPoint
                    rec.anchorType = if (rec.anchorType == "nodeB" or rec.anchorType == "both") then "both" else "nodeA"
                )
                else
                (
                    rec.nodeA = undefined
                    rec.anchorVertexIdA = -1
                    rec.anchorEdgeIdA = -1
                    rec.anchorEdgeMidA = false
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
                    rec.anchorVertexIdB = -1
                    rec.anchorEdgeIdB = -1
                    rec.anchorEdgeMidB = false
                    local toleranceB = ::AmenoDimensionGraphics.toSceneUnits 10.0
                    local vertexHitB = ::AmenoDimensionCA.findNearestVertex targetNode targetWorldPoint maxDistance:toleranceB
                    if vertexHitB != undefined do rec.anchorVertexIdB = vertexHitB.vertexId
                    rec.pointB = targetWorldPoint
                    rec.anchorType = if (rec.anchorType == "nodeA" or rec.anchorType == "both") then "both" else "nodeB"
                )
                else
                (
                    rec.nodeB = undefined
                    rec.anchorVertexIdB = -1
                    rec.anchorEdgeIdB = -1
                    rec.anchorEdgeMidB = false
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
            rebuildIndex()
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
                    local invalidVertexA = false
                    if rec.anchorVertexIdA != -1 do
                        invalidVertexA = (rec.anchorVertexIdA < 1 or (::AmenoDimensionCA.resolveVertexWorld rec.nodeA rec.anchorVertexIdA) == undefined)
                    if rec.nodeA == undefined or not (isValidNode rec.nodeA) or invalidVertexA do
                    (
                        rec.nodeA = undefined
                        rec.localPointA = [0, 0, 0]
                        rec.anchorVertexIdA = -1
                        rec.anchorEdgeIdA = -1
                        rec.anchorEdgeMidA = false
                    )
                    local invalidVertexB = false
                    if rec.anchorVertexIdB != -1 do
                        invalidVertexB = (rec.anchorVertexIdB < 1 or (::AmenoDimensionCA.resolveVertexWorld rec.nodeB rec.anchorVertexIdB) == undefined)
                    if rec.nodeB == undefined or not (isValidNode rec.nodeB) or invalidVertexB do
                    (
                        rec.nodeB = undefined
                        rec.localPointB = [0, 0, 0]
                        rec.anchorVertexIdB = -1
                        rec.anchorEdgeIdB = -1
                        rec.anchorEdgeMidB = false
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
            rebuildIndex()
        )

        if repairedCount > 0 and ::AmenoRefreshMainPanel != undefined do
        (
            try (::AmenoRefreshMainPanel()) catch ()
        )

        repairedCount
    ),

    fn shutdown =
    (
        callbacks.removeScripts id:#ameno_anchors
        -- Remove os watchers de transform registrados por rebuildIndex
        try (deleteAllChangeHandlers id:#ameno_watchers) catch ()
        try (deleteAllChangeHandlers id:#ameno_geometry_watchers) catch ()
        if anchorCallback != undefined do
        (
            try (anchorCallback.enabled = false) catch ()
            anchorCallback = undefined
        )
        isCallbackActive = false
        dirtyQueue = #()
        isSyncing = false
        if indexTable != undefined do
        (
            try (free indexTable) catch ()
            indexTable = undefined
        )
        true
    ),

    fn init =
    (
        shutdown()
        dirtyQueue = #()
        rebuildIndex()

        callbacks.removeScripts id:#ameno_anchors
        callbacks.addScript #preRender "if ::AmenoAnchorService != undefined do ::AmenoAnchorService.onPreRender()" id:#ameno_anchors

        try
        (
            -- Um único callback retido atende eventos estruturais e mudanças
            -- de geometria; criar outro watcher global duplicaria atualizações.
            anchorCallback = NodeEventCallback \
                controllerOtherEvent:(fn onCtrl ev nd = if ::AmenoAnchorService != undefined do ::AmenoAnchorService.handleNodesChanged ev nd) \
                controllerStructured:(fn onCtrl ev nd = if ::AmenoAnchorService != undefined do ::AmenoAnchorService.handleNodesChanged ev nd) \
                modelStructured:(fn onStruct ev nd = if ::AmenoAnchorService != undefined do ::AmenoAnchorService.handleNodesChanged ev nd) \
                geometryChanged:(fn onGeom ev nd = if ::AmenoAnchorService != undefined do ::AmenoAnchorService.handleNodesChanged ev nd) \
                topologyChanged:(fn onTopo ev nd = if ::AmenoAnchorService != undefined do ::AmenoAnchorService.handleNodesChanged ev nd) \
                deleted:(fn onDel ev nd = if ::AmenoAnchorService != undefined do ::AmenoAnchorService.handleNodesDeleted ev nd) \
                delay:50 mouseUp:false
            isCallbackActive = true
        )
        catch
        (
            isCallbackActive = false
        )
        true
    )
)

AmenoAnchorService = AmenoAnchorServiceDefinition()
