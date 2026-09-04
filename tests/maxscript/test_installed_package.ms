/* Verifies that 3ds Max loaded the installed ApplicationPlugins package. */

global AmenoApp
global AmenoVersion
global AmenoSceneSetup
global AmenoUnitService
global AmenoDimensionMath
global AmenoDimensionCA
global AmenoDimensionGraphics
global AmenoDimensionTool
global AmenoStyleService
global AmenoAnchorService
global AmenoCoronaRendererAdapter
global AmenoRenderCotasService
global AmenoPreviewRenderer
global AmenoStyleEditorWPF
global AmenoStyleDraft
global AmenoPreviewModel

(
    if AmenoApp == undefined then throw "O pacote instalado não criou AmenoApp."
    if not AmenoApp.started then throw "O pacote instalado não concluiu o startup."
    if AmenoVersion.appVersion != "0.0.1" then throw "A versão instalada não corresponde ao teste."
    if AmenoSceneSetup == undefined then throw "O pacote instalado não carregou o serviço de preparação de cena."
    if AmenoApp.refreshScene() == undefined then throw "O pacote instalado não respondeu ao diagnóstico de cena."
    if AmenoUnitService == undefined or AmenoDimensionMath == undefined then throw "O pacote instalado não carregou o núcleo da E2."
    if AmenoDimensionCA == undefined then throw "O pacote instalado não carregou o serviço de Custom Attributes da E5."
    if AmenoDimensionGraphics == undefined then throw "O pacote instalado não carregou o construtor gráfico da E3."
    if AmenoDimensionTool == undefined then throw "O pacote instalado não carregou a ferramenta interativa da E4."
    if AmenoStyleService == undefined then throw "O pacote instalado não carregou o serviço de estilos da E7."
    if AmenoAnchorService == undefined then throw "O pacote instalado não carregou o serviço de âncoras da E8."
    if AmenoCoronaRendererAdapter == undefined then throw "O pacote instalado não carregou o adapter Corona da E9."
    if AmenoRenderCotasService == undefined then throw "O pacote instalado não carregou o serviço Renderizar Cotas da E9."

    local installedE2Format = AmenoUnitService.formatMillimeters 19555.0 outputUnit:#meters precision:2 decimalSeparator:#comma roundingIncrementMillimeters:100.0
    if installedE2Format.text != "19,60 m" then throw "O núcleo E2 instalado formatou a medida incorretamente."

    -- E6: Teste de override e auditoria no pacote instalado
    local testDim = AmenoDimensionGraphics.createDimension [0, 0, 0] [1000, 0, 0] [0, 100, 0]
    local testAudit = AmenoDimensionGraphics.getDimensionAudit testDim.controller
    if testAudit == undefined or testAudit.isManual then throw "E6 instalado: Cota inicial deveria ser medido."
    AmenoDimensionGraphics.setDimensionMode testDim.controller #manualNumeric manualValueMm:950.0 reason:"Ajuste pacote instalado"
    local manualAudit = AmenoDimensionGraphics.getDimensionAudit testDim.controller
    if manualAudit == undefined or not manualAudit.isManual then throw "E6 instalado: Cota não assumiu modo manual."
    local markerFound = false
    for n in (AmenoDimensionGraphics.findNodesForDimension testDim.dimensionId) do
    (
        if (AmenoDimensionGraphics.readTextProperty n "Ameno.GraphicRole") == "marker" do
        (
            markerFound = true
            if n.renderable != false then throw "E6 instalado: Marcador deve ter renderable = false."
        )
    )
    if not markerFound then throw "E6 instalado: Marcador [M] não encontrado."
    AmenoDimensionGraphics.removeDimension testDim.dimensionId

    -- E7: Presets de estilo no pacote instalado
    if (AmenoStyleService.listStyles()).count < 3 then throw "O pacote instalado não possui os presets de estilo da E7."

    -- E8: Teste de âncoras e órfãs no pacote instalado
    local bA = box pos:[0, 0, 0]
    local bB = box pos:[200, 0, 0]
    local testAnchored = AmenoDimensionGraphics.createDimension [0, 0, 0] [200, 0, 0] [0, 40, 0] nodeA:bA nodeB:bB
    bB.pos = [250, 0, 0]
    AmenoAnchorService.syncAll()
    local auditP = AmenoDimensionGraphics.getDimensionAudit testAnchored.controller
    if not (AmenoDimensionMath.nearlyEqual auditP.measuredMillimeters (250.0 * AmenoUnitService.currentMillimetersPerSceneUnit())) then throw "E8 instalado: Sincronização de âncoras falhou."
    delete #(bA, bB)
    AmenoAnchorService.syncAll()
    local auditOrph = AmenoDimensionGraphics.getDimensionAudit testAnchored.controller
    if not auditOrph.isOrphan then throw "E8 instalado: Detecção de órfã falhou."
    -- E8.1: Teste de estabilização de âncoras, esquemas e estilos no pacote instalado
    AmenoAnchorService.init()
    if not AmenoAnchorService.isCallbackActive then throw "E8.1 instalado: Callback de âncoras inativo."

    local instDim = AmenoDimensionGraphics.createDimension [0, 0, 0] [100, 0, 0] [0, 20, 0]
    if (AmenoDimensionGraphics.readTextProperty instDim.controller "Ameno.DataSchemaVersion") != "3" then throw "E8.1 instalado: DataSchemaVersion incorreto."
    if (AmenoDimensionGraphics.readTextProperty instDim.lineNode "Ameno.GraphicSchemaVersion") != "1" then throw "E8.1 instalado: GraphicSchemaVersion incorreto."

    local instStyle = AmenoStyleService.getStyle "default"
    instStyle.lineThickness = 999.0
    if (AmenoStyleService.getStyle "default").lineThickness == 999.0 then throw "E8.1 instalado: getStyle expôs mutação interna."

    AmenoDimensionGraphics.removeDimension instDim.dimensionId

    -- E9: contrato do adapter e coleta de escopo no pacote instalado, sem iniciar render real.
    local installedCoronaMaterial = AmenoCoronaRendererAdapter.createAnnotationMaterial()
    if installedCoronaMaterial.emitLight or not installedCoronaMaterial.visibleDirect or not installedCoronaMaterial.affectAlpha then throw "E9 instalado: Material Corona de overlay inválido."

    local installedE9Dim = AmenoDimensionGraphics.createDimension [0, 0, 0] [120, 0, 0] [0, 30, 0]
    local installedE9Targets = AmenoRenderCotasService.collectTargetNodes #all
    if installedE9Targets.count < 2 then throw "E9 instalado: Serviço não encontrou linhas e texto da cota."
    AmenoDimensionGraphics.removeDimension installedE9Dim.dimensionId

    -- E11: Editor visual de estilos e preview ao vivo no pacote instalado
    if AmenoPreviewRenderer == undefined then throw "E11 instalado: AmenoPreviewRenderer não foi carregado."
    if AmenoStyleEditorWPF == undefined then throw "E11 instalado: AmenoStyleEditorWPF não foi carregado."
    if AmenoPreviewModel == undefined or AmenoStyleDraft == undefined then throw "E11 instalado: Structs de rascunho ausentes."

    -- Verificar independência de caminhos (deve carregar do ApplicationPlugins)
    local instRoot = AmenoBootstrap.rootPath
    if (matchPattern instRoot pattern:"*\\_worktrees\\*") or (matchPattern instRoot pattern:"*\\_tools\\*") then
        throw ("E11 instalado: O pacote está apontando para o repositório em vez do ApplicationPlugins: " + instRoot)

    -- Testar ciclo de abertura e fechamento do editor WPF via AmenoApp
    local instWin = AmenoApp.openStyleEditor()
    if instWin == undefined or not AmenoStyleEditorWPF.isOpen() then
        throw "E11 instalado: Falha ao abrir AmenoStyleEditorWPF através de AmenoApp.openStyleEditor()."

    -- Verificar rascunho inicial
    if AmenoStyleEditorWPF.currentDraft == undefined or AmenoStyleEditorWPF.currentDraft.sourceStyleId != "default" then
        throw "E11 instalado: Draft inicial incorreto no editor WPF."

    -- Fechar editor instalado
    AmenoStyleEditorWPF.close()
    if AmenoStyleEditorWPF.isOpen() then
        throw "E11 instalado: AmenoStyleEditorWPF não fechou corretamente."

    format "[AMENO_INSTALLED_TEST][PASS] Pacote % carregado via ApplicationPlugins com E1-E10 e E11 Visual Editor.\n" AmenoVersion.appVersion
)
