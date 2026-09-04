global AmenoDiagnosticService
global AmenoDiagnosticReport

struct AmenoDiagnosticReport
(
    generatedAt = "",
    rendererName = "",
    rendererSupport = "",
    totalDimensions = 0,
    healthyCount = 0,
    partialCount = 0,
    missingGraphicsCount = 0,
    orphanCount = 0,
    alignedCount = 0,
    horizontalCount = 0,
    verticalCount = 0,
    worldAnchorCount = 0,
    nodeAAnchorCount = 0,
    nodeBAnchorCount = 0,
    bothAnchorCount = 0,
    measuredCount = 0,
    manualCount = 0,
    issues = #(),

    fn summaryText =
    (
        local s = ""
        s += "=====================================================\n"
        s += "        AMENO TOOLS - RELATÓRIO DE DIAGNÓSTICO       \n"
        s += "=====================================================\n"
        s += "Data/Hora:        " + generatedAt + "\n"
        s += "Renderer Ativo:   " + rendererName + " (" + rendererSupport + ")\n"
        s += "-----------------------------------------------------\n"
        s += "TOTAL DE COTAS:   " + (totalDimensions as string) + "\n"
        s += "  Saudáveis:      " + (healthyCount as string) + "\n"
        s += "  Gráficos inc.:  " + (partialCount as string) + "\n"
        s += "  Sem gráficos:   " + (missingGraphicsCount as string) + "\n"
        s += "  Órfãs:          " + (orphanCount as string) + "\n"
        s += "-----------------------------------------------------\n"
        s += "MODOS:\n"
        s += "  Alinhada:       " + (alignedCount as string) + "\n"
        s += "  Horizontal:     " + (horizontalCount as string) + "\n"
        s += "  Vertical:       " + (verticalCount as string) + "\n"
        s += "-----------------------------------------------------\n"
        s += "ÂNCORAS:\n"
        s += "  Mundial (fixa): " + (worldAnchorCount as string) + "\n"
        s += "  Objeto A:       " + (nodeAAnchorCount as string) + "\n"
        s += "  Objeto B:       " + (nodeBAnchorCount as string) + "\n"
        s += "  Ambos nós:      " + (bothAnchorCount as string) + "\n"
        s += "-----------------------------------------------------\n"
        s += "VALORES:\n"
        s += "  Medido real:    " + (measuredCount as string) + "\n"
        s += "  Manual/Override:" + (manualCount as string) + "\n"
        s += "-----------------------------------------------------\n"
        if issues.count == 0 then
        (
            s += "STATUS: Todos os nós e âncoras estão íntegros.\n"
        )
        else
        (
            s += "PROBLEMAS ENCONTRADOS (" + (issues.count as string) + "):\n"
            for iss in issues do s += "  [!] " + iss + "\n"
        )
        s += "=====================================================\n"
        s
    )
)

struct AmenoDiagnosticServiceDefinition
(
    fn generateReport =
    (
        local r = AmenoDiagnosticReport()
        r.generatedAt = localTime

        if ::AmenoRendererProbe != undefined do
        (
            local info = ::AmenoRendererProbe.detect()
            r.rendererName = info.displayName
            r.rendererSupport = info.statusLabel()
        )

        local controllers = if ::AmenoDimensionGraphics != undefined then (::AmenoDimensionGraphics.findControllers()) else #()
        r.totalDimensions = controllers.count

        for ctrl in controllers where isValidNode ctrl do
        (
            -- Inspecao grafica
            local health = if ::AmenoDimensionGraphics != undefined then (::AmenoDimensionGraphics.inspectDimension ctrl) else #invalid
            case health of
            (
                #healthy: r.healthyCount += 1
                #partial:
                (
                    r.partialCount += 1
                    append r.issues ("Cota '" + ctrl.name + "': geometria parcial (linhas ou texto ausente).")
                )
                #missing_graphics:
                (
                    r.missingGraphicsCount += 1
                    append r.issues ("Cota '" + ctrl.name + "': representação gráfica completamente ausente.")
                )
                default: ()
            )

            -- Inspecao de dados CA
            if ::AmenoDimensionCA != undefined do
            (
                local rec = ::AmenoDimensionCA.readCA ctrl
                if rec != undefined do
                (
                    -- Modo
                    case rec.dimensionMode of
                    (
                        "horizontal": r.horizontalCount += 1
                        "vertical":   r.verticalCount += 1
                        default:      r.alignedCount += 1
                    )

                    -- Ancoras
                    case rec.anchorType of
                    (
                        "nodeA": r.nodeAAnchorCount += 1
                        "nodeB": r.nodeBAnchorCount += 1
                        "both":  r.bothAnchorCount += 1
                        default: r.worldAnchorCount += 1
                    )

                    -- Status de orfa
                    if rec.isOrphan do
                    (
                        r.orphanCount += 1
                        append r.issues ("Cota '" + ctrl.name + "' é órfã: " + rec.orphanReason)
                    )

                    -- Manual / Override
                    if rec.displayMode == "manualNumeric" or rec.displayMode == "manualText" then
                    (
                        r.manualCount += 1
                    )
                    else
                    (
                        r.measuredCount += 1
                    )
                )
            )
        )

        r
    ),

    fn printReport =
    (
        local rep = generateReport()
        local txt = rep.summaryText()
        format "%\n" txt
        txt
    ),

    fn exportReportToFile targetPath =
    (
        local rep = generateReport()
        local txt = rep.summaryText()
        local fileStream = createFile targetPath
        if fileStream != undefined then
        (
            format "%" txt to:fileStream
            close fileStream
            true
        )
        else
            false
    )
)

AmenoDiagnosticService = AmenoDiagnosticServiceDefinition()
