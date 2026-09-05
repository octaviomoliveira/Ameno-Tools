/*
    E12 — Testes headless para AmenoDimensionContinuousTool.

    Segue o padrão dos testes E11: tudo dentro de um bloco (),
    bootstrap carregado via fileIn a partir da raiz do repositório.
*/

(
    global AmenoDimensionContinuousTool

    format "\n=========================================================\n"
    format "=== [AMENO_TEST] Iniciando Testes E12: Cotação Contínua ===\n"
    format "=========================================================\n\n"

    resetMaxFile #noPrompt

    local testFile       = getSourceFileName()
    local testPath       = getFilenamePath testFile
    local repoRoot       = pathConfig.normalizePath (pathConfig.appendPath testPath @"..\..")
    local bootstrapPath  = pathConfig.normalizePath (pathConfig.appendPath repoRoot @"Contents\scripts\startup\ameno_bootstrap.ms")
    fileIn bootstrapPath quiet:true

    local totalTests  = 0
    local passedTests = 0

    -- ── Asserções ─────────────────────────────────────────────────────────────

    fn e12_eq desc got expected =
    (
        totalTests += 1
        if got == expected then
        (
            passedTests += 1
            format "[PASS] %\n" desc
        )
        else
        (
            format "[FAIL] % — esperado: <%> obtido: <%>\n" desc expected got
        )
    )

    fn e12_ok desc cond =
    (
        totalTests += 1
        if cond then
        (
            passedTests += 1
            format "[PASS] %\n" desc
        )
        else
        (
            format "[FAIL] % — condição falsa\n" desc
        )
    )

    fn e12_no desc cond = e12_ok desc (not cond)

    -- ── Helpers ───────────────────────────────────────────────────────────────

    fn e12_resetTool =
    (
        AmenoDimensionContinuousTool.active          = false
        AmenoDimensionContinuousTool.stage           = #idle
        AmenoDimensionContinuousTool.points          = #()
        AmenoDimensionContinuousTool.anchorNodes     = #()
        AmenoDimensionContinuousTool.anchorVertexIds = #()
        AmenoDimensionContinuousTool.segmentPreviews = #()
        AmenoDimensionContinuousTool.activePreview   = undefined
        AmenoDimensionContinuousTool.lastSessionIds  = #()
        AmenoDimensionContinuousTool.lastError       = ""
        AmenoDimensionContinuousTool.hudOpen         = false
    )

    fn e12_begin =
    (
        e12_resetTool()
        AmenoDimensionContinuousTool.active = true
        AmenoDimensionContinuousTool.stage  = #collectingPoints
    )

    fn e12_addPoint x y =
    (
        local pt = [x, y, 0.0]
        append AmenoDimensionContinuousTool.points          pt
        append AmenoDimensionContinuousTool.anchorNodes     undefined
        append AmenoDimensionContinuousTool.anchorVertexIds -1
    )

    -- ── Teste 1: Estado inicial ───────────────────────────────────────────────

    format "\n=== E12.1 Estado inicial ===\n"
    e12_ok "T1.1 tool instanciado"    (AmenoDimensionContinuousTool != undefined)
    e12_no "T1.2 active=false"        AmenoDimensionContinuousTool.active
    e12_eq "T1.3 stage=#idle"         AmenoDimensionContinuousTool.stage #idle
    e12_eq "T1.4 points vazio"        AmenoDimensionContinuousTool.points.count 0
    e12_eq "T1.5 mode=#aligned"       AmenoDimensionContinuousTool.activeMode #aligned

    -- ── Teste 2: Acumulação de pontos ─────────────────────────────────────────

    format "\n=== E12.2 Acumulação de pontos ===\n"
    e12_begin()
    e12_addPoint 0    0
    e12_addPoint 1000 0
    e12_addPoint 2000 0
    e12_addPoint 2000 1500

    e12_eq "T2.1 4 pontos acumulados"     AmenoDimensionContinuousTool.points.count 4
    e12_eq "T2.2 anchorNodes count"       AmenoDimensionContinuousTool.anchorNodes.count 4
    e12_eq "T2.3 anchorVertexIds count"   AmenoDimensionContinuousTool.anchorVertexIds.count 4
    e12_eq "T2.4 ponto[1].x = 0"         AmenoDimensionContinuousTool.points[1].x 0.0
    e12_eq "T2.5 ponto[2].x = 1000"      AmenoDimensionContinuousTool.points[2].x 1000.0
    e12_eq "T2.6 ponto[4].y = 1500"      AmenoDimensionContinuousTool.points[4].y 1500.0
    e12_eq "T2.7 stage=#collectingPoints" AmenoDimensionContinuousTool.stage #collectingPoints

    -- ── Teste 3: Undo de ponto ────────────────────────────────────────────────

    format "\n=== E12.3 Undo de ponto ===\n"
    e12_begin()
    e12_addPoint 0   0
    e12_addPoint 500 0
    e12_addPoint 1000 0

    e12_eq "T3.1 antes do undo: 3 pontos" AmenoDimensionContinuousTool.points.count 3

    local ok1 = AmenoDimensionContinuousTool.undoLastPoint()
    e12_ok "T3.2 undoLastPoint retorna true"  ok1
    e12_eq "T3.3 após 1 undo: 2 pontos"       AmenoDimensionContinuousTool.points.count 2
    e12_eq "T3.4 último ponto x=500"          AmenoDimensionContinuousTool.points[2].x 500.0

    local ok2 = AmenoDimensionContinuousTool.undoLastPoint()
    e12_ok "T3.5 segundo undo retorna true"   ok2
    e12_eq "T3.6 após 2 undos: 1 ponto"       AmenoDimensionContinuousTool.points.count 1
    e12_eq "T3.7 ponto restante x=0"          AmenoDimensionContinuousTool.points[1].x 0.0

    local ok3 = AmenoDimensionContinuousTool.undoLastPoint()
    e12_ok "T3.8 undo do último ponto = true" ok3
    e12_eq "T3.9 após undo do único: 0 pts"   AmenoDimensionContinuousTool.points.count 0

    local ok4 = AmenoDimensionContinuousTool.undoLastPoint()
    e12_no "T3.10 undo com 0 pontos = false"  ok4

    -- ── Teste 4: confirmPoints ────────────────────────────────────────────────

    format "\n=== E12.4 confirmPoints ===\n"
    e12_begin()

    local r1 = AmenoDimensionContinuousTool.confirmPoints()
    e12_no "T4.1 confirmPoints sem pontos = false"    r1
    e12_eq "T4.2 stage permanece #collectingPoints"   AmenoDimensionContinuousTool.stage #collectingPoints

    e12_addPoint 0 0
    local r2 = AmenoDimensionContinuousTool.confirmPoints()
    e12_no "T4.3 confirmPoints com 1 ponto = false"   r2

    e12_addPoint 1000 0
    local r3 = AmenoDimensionContinuousTool.confirmPoints()
    e12_ok "T4.4 confirmPoints com 2 pontos = true"   r3
    e12_eq "T4.5 stage muda para #offset"             AmenoDimensionContinuousTool.stage #offset

    local r4 = AmenoDimensionContinuousTool.confirmPoints()
    e12_no "T4.6 confirmPoints em #offset = false"    r4

    -- ── Teste 5: Cancel ───────────────────────────────────────────────────────

    format "\n=== E12.5 Cancel ===\n"
    e12_begin()
    e12_addPoint 0    0
    e12_addPoint 1000 0
    e12_addPoint 2000 0

    e12_ok "T5.1 active=true antes do cancel"  AmenoDimensionContinuousTool.active
    e12_eq "T5.2 3 pontos antes do cancel"     AmenoDimensionContinuousTool.points.count 3

    AmenoDimensionContinuousTool.cancel()

    e12_no "T5.3 active=false após cancel"     AmenoDimensionContinuousTool.active
    e12_eq "T5.4 stage=#idle após cancel"      AmenoDimensionContinuousTool.stage #idle
    e12_eq "T5.5 points zerado após cancel"    AmenoDimensionContinuousTool.points.count 0
    e12_eq "T5.6 anchorNodes zerado"           AmenoDimensionContinuousTool.anchorNodes.count 0
    e12_eq "T5.7 segmentPreviews zerado"       AmenoDimensionContinuousTool.segmentPreviews.count 0

    -- ── Teste 6: calcTotalMillimeters ─────────────────────────────────────────

    format "\n=== E12.6 Cálculo de total ===\n"
    e12_begin()

    local t0 = AmenoDimensionContinuousTool.calcTotalMillimeters()
    e12_eq "T6.1 total sem pontos = 0.0" t0 0.0

    e12_addPoint 0 0
    local t1 = AmenoDimensionContinuousTool.calcTotalMillimeters()
    e12_eq "T6.2 total com 1 ponto = 0.0" t1 0.0

    e12_addPoint 1000 0
    local t2 = AmenoDimensionContinuousTool.calcTotalMillimeters()
    e12_ok "T6.3 total com 2 pontos > 0" (t2 > 0.0)

    e12_addPoint 2000 0
    local t3 = AmenoDimensionContinuousTool.calcTotalMillimeters()
    e12_ok "T6.4 total com 3 pontos > total com 2" (t3 > t2)

    e12_addPoint 3000 0
    local t4 = AmenoDimensionContinuousTool.calcTotalMillimeters()
    e12_ok "T6.5 total com 4 pontos > total com 3" (t4 > t3)

    -- ── Teste 7: Modo propagado ───────────────────────────────────────────────

    format "\n=== E12.7 Modo ===\n"
    e12_resetTool()
    AmenoDimensionContinuousTool.activeMode = #aligned
    e12_eq "T7.1 modo #aligned"    AmenoDimensionContinuousTool.activeMode #aligned

    AmenoDimensionContinuousTool.activeMode = #horizontal
    e12_eq "T7.2 modo #horizontal" AmenoDimensionContinuousTool.activeMode #horizontal

    AmenoDimensionContinuousTool.activeMode = #vertical
    e12_eq "T7.3 modo #vertical"   AmenoDimensionContinuousTool.activeMode #vertical

    -- ── Resumo ────────────────────────────────────────────────────────────────

    format "\n=== E12 RESUMO: %/% PASS ===\n" passedTests totalTests
    if passedTests == totalTests then
        format "[AMENO_TEST][PASS] Todos os testes E12 passaram.\n"
    else
        format "[AMENO_TEST][FAIL] % teste(s) falharam.\n" (totalTests - passedTests)
)
