/*
    E11.5 — Testes de Integração, Ciclo de Vida e Fallback do Editor Visual de Estilos.
    Executado por 3dsmaxbatch.exe via tools\test-maxscript.ps1.

    Matriz de cobertura:
    1. Ciclo de vida estendido: abrir e fechar 20 vezes sem acúmulo de callbacks ou vazamentos.
    2. Reset de cena com editor aberto: manipulador onSceneReset sem exceções e atualização de draft.
    3. Fallback diagnosticável: simulação de erro no WPF aciona AmenoStyleEditorRollout e loga diagnóstico.
    4. Abertura explícita de legado: AmenoApp.openStyleEditor useLegacy:true abre o rollout legado.
    5. Integração com Main Panel: botão 'Editor de Estilos...' abre o host WPF por padrão.
    6. Independência de caminhos e integridade de módulos: AmenoBootstrap carrega todos os módulos de forma autônoma.
    7. Isolamento de cena estrito: 0 nós criados ao abrir, editar rascunho, gerar preview e fechar.
*/

(
    local totalTests = 0
    local passedTests = 0

    fn assertCondition msg cond =
    (
        totalTests += 1
        if cond then
        (
            passedTests += 1
            format "[PASS] %\n" msg
        )
        else
        (
            format "[FAIL] %\n" msg
        )
    )

    format "\n=================================================================\n"
    format "INICIANDO SUÍTE E11.5: INTEGRAÇÃO, CICLO DE VIDA E FALLBACK\n"
    format "=================================================================\n\n"

    resetMaxFile #noPrompt

    -- Carregar ambiente Ameno via bootstrap
    local thisFile = getSourceFileName()
    local thisDir = getFilenamePath thisFile
    local repoRoot = pathConfig.normalizePath (pathConfig.appendPath thisDir @"..\..")
    local bootstrapFile = pathConfig.normalizePath (pathConfig.appendPath repoRoot @"Contents\scripts\startup\ameno_bootstrap.ms")
    fileIn bootstrapFile quiet:true

    assertCondition "AmenoApp inicializado com sucesso" (AmenoApp != undefined and AmenoApp.started)
    assertCondition "AmenoStyleEditorWPF singleton registrado" (::AmenoStyleEditorWPF != undefined)
    assertCondition "AmenoPreviewRenderer singleton registrado" (::AmenoPreviewRenderer != undefined)

    -- TESTE 1: Ciclo de vida estendido (20 ciclos de Show/Close)
    format "\n--- Teste 1: Ciclo de Vida Estendido (20 ciclos) ---\n"
    local cycleSuccess = true
    for i = 1 to 20 do
    (
        local win = AmenoApp.openStyleEditor()
        if win == undefined or not AmenoStyleEditorWPF.isOpen() do
        (
            cycleSuccess = false
            exit
        )
        AmenoStyleEditorWPF.close()
        if AmenoStyleEditorWPF.isOpen() do
        (
            cycleSuccess = false
            exit
        )
    )
    assertCondition "20 ciclos de abertura e fechamento concluídos sem falhas" cycleSuccess

    -- Verificar que nenhum callback residual permaneceu
    local cbStream = stringStream ""
    callbacks.show id:#amenoStyleEditorWpfSelection to:cbStream
    local cbOutput = cbStream as string
    assertCondition "Nenhum callback residual acumulado após 20 ciclos de fechamento" (cbOutput == "" or (filterString cbOutput "\n").count == 0)

    -- TESTE 2: Reset de Cena com Editor Aberto
    format "\n--- Teste 2: Reset de Cena com Editor Aberto ---\n"
    local win2 = AmenoApp.openStyleEditor()
    assertCondition "Editor aberto antes do reset de cena" (AmenoStyleEditorWPF.isOpen())
    AmenoStyleEditorWPF.onFieldChanged #fontSize 42.0
    assertCondition "Draft marcado como dirty antes do reset" AmenoStyleEditorWPF.currentDraft.isDirty

    -- Disparar reset de cena do 3ds Max
    resetMaxFile #noPrompt
    AmenoApp.onSceneReset()

    assertCondition "Editor permanece aberto e íntegro após reset de cena" (AmenoStyleEditorWPF.isOpen())
    assertCondition "Draft reiniciado com sucesso para estilo padrão após reset" (AmenoStyleEditorWPF.currentDraft != undefined and AmenoStyleEditorWPF.currentDraft.sourceStyleId == "default")
    assertCondition "Mensagem de status informa estado pronto após reset de cena" (AmenoStyleEditorWPF.txtPreviewStatus.Text == "Pronto" or matchPattern AmenoStyleEditorWPF.txtPreviewStatus.Text pattern:"*reiniciada*")

    AmenoStyleEditorWPF.close()
    assertCondition "Editor fechado após teste de reset" (not AmenoStyleEditorWPF.isOpen())

    -- TESTE 3: Fallback Diagnosticável em Caso de Falha no WPF
    format "\n--- Teste 3: Fallback Diagnosticável ---\n"
    struct AmenoMockFailingWPF
    (
        fn open styleId:undefined = (throw "Erro simulado no carregamento de assembly WPF para teste de fallback")
    )
    local realWPF = ::AmenoStyleEditorWPF
    ::AmenoStyleEditorWPF = AmenoMockFailingWPF()

    -- Fechar qualquer diálogo legado pré-existente
    try (destroyDialog ::AmenoStyleEditorRollout) catch ()

    -- Chamar openStyleEditor que deve capturar a exceção e abrir o rollout legado
    AmenoApp.openStyleEditor()
    assertCondition "Rollout legado AmenoStyleEditorRollout aberto como fallback após falha do WPF" (::AmenoStyleEditorRollout != undefined and ::AmenoStyleEditorRollout.open)

    -- Fechar diálogo legado e restaurar o serviço real
    try (destroyDialog ::AmenoStyleEditorRollout) catch ()
    ::AmenoStyleEditorWPF = realWPF
    assertCondition "Serviço real AmenoStyleEditorWPF restaurado com sucesso" (::AmenoStyleEditorWPF == realWPF)

    -- TESTE 4: Abertura Explícita de Editor Legado
    format "\n--- Teste 4: Abertura Explícita do Editor Legado ---\n"
    try (destroyDialog ::AmenoStyleEditorRollout) catch ()
    AmenoApp.openStyleEditor useLegacy:true
    assertCondition "AmenoApp.openStyleEditor useLegacy:true abre AmenoStyleEditorRollout" (::AmenoStyleEditorRollout != undefined and ::AmenoStyleEditorRollout.open)
    try (destroyDialog ::AmenoStyleEditorRollout) catch ()

    -- TESTE 5: Abertura Padrão via Main Panel
    format "\n--- Teste 5: Ponto de Entrada do Main Panel ---\n"
    local winPanel = AmenoApp.openStyleEditor()
    assertCondition "AmenoApp.openStyleEditor() abre o host moderno WPF por padrão" (winPanel != undefined and AmenoStyleEditorWPF.isOpen())
    AmenoStyleEditorWPF.close()

    -- TESTE 6: Independência de Caminhos e Autonomia dos Módulos
    format "\n--- Teste 6: Autonomia e Estrutura de Módulos ---\n"
    local modPath = AmenoBootstrap.rootPath
    assertCondition "AmenoBootstrap.rootPath aponta para pasta ameno normalizada" (matchPattern modPath pattern:"*ameno*")
    assertCondition "Módulo ameno_preview_renderer.ms resolvido" (doesFileExist (AmenoBootstrap.resolveModulePath @"ui\ameno_preview_renderer.ms"))
    assertCondition "Módulo ameno_style_editor_wpf.ms resolvido" (doesFileExist (AmenoBootstrap.resolveModulePath @"ui\ameno_style_editor_wpf.ms"))
    assertCondition "Módulo ameno_style_editor.ms resolvido (legado preservado para fallback)" (doesFileExist (AmenoBootstrap.resolveModulePath @"ui\ameno_style_editor.ms"))

    -- TESTE 7: Isolamento Estrito de Cena
    format "\n--- Teste 7: Isolamento de Cena ---\n"
    resetMaxFile #noPrompt
    local objCountStart = objects.count

    local winIso = AmenoApp.openStyleEditor()
    AmenoStyleEditorWPF.onFieldChanged #lineThickness 4.0
    AmenoStyleEditorWPF.onFieldChanged #fontSize 28.0
    AmenoStyleEditorWPF.onFieldChanged #terminalType #dot
    AmenoStyleEditorWPF.updatePreview()
    AmenoStyleEditorWPF.close()

    assertCondition "Zero nós criados na cena durante abertura, edição, preview e descarte" (objects.count == objCountStart)

    -- Resumo final
    format "\n=================================================================\n"
    format "Total de Testes E11.5: % | Aprovados: % | Falhas: %\n" totalTests passedTests (totalTests - passedTests)
    format "=================================================================\n\n"

    if passedTests == totalTests then (
        format "[AMENO_TEST][PASS] E11.5 Integracao, Ciclo de Vida e Fallback aprovada com 100 por cento de sucesso.\n"
    ) else (
        format "[AMENO_TEST][FAIL] Falhas detectadas na suite E11.5.\n"
    )
)
