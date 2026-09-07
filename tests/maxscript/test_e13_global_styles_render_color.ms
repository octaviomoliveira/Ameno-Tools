/*
    E13 — biblioteca global de estilos, cor de material e escopo do overlay.
    Executado em Batch isolado: não instala o pacote nem faz render interativo.
*/

(
    global AmenoStyleService
    global AmenoStyleServiceDefinition
    global AmenoDimensionGraphics
    global AmenoRenderCotasService
    global AmenoAdapterRenderResult
    global AmenoSceneSetup

    local testFile = getSourceFileName()
    local testPath = getFilenamePath testFile
    local worktreeRoot = pathConfig.normalizePath (pathConfig.appendPath testPath @"..\..")
    local bootstrapPath = pathConfig.normalizePath (pathConfig.appendPath worktreeRoot @"Contents\scripts\startup\ameno_bootstrap.ms")
    local environmentApi = dotNetClass "System.Environment"
    local directoryApi = dotNetClass "System.IO.Directory"
    local originalLocalAppData = environmentApi.GetEnvironmentVariable "LOCALAPPDATA"
    local isolatedLocalAppData = pathConfig.normalizePath (pathConfig.appendPath (getDir #temp) ("AmenoTools-E13-global-styles-" + (timestamp() as string)))
    directoryApi.CreateDirectory isolatedLocalAppData
    environmentApi.SetEnvironmentVariable "LOCALAPPDATA" isolatedLocalAppData
    local globalStylesPath = pathConfig.normalizePath (pathConfig.appendPath isolatedLocalAppData @"AmenoTools\Profiles\styles.library")

    -- Esta suíte precisa começar sem estado persistido de outra execução.
    deleteFile globalStylesPath
    deleteFile (globalStylesPath + ".bak")
    deleteFile (globalStylesPath + ".tmp")

    resetMaxFile #noPrompt
    if doesFileExist bootstrapPath then fileIn bootstrapPath quiet:true
    else throw ("bootstrap nao encontrado: " + bootstrapPath)

    local passed = 0
    local failed = 0
    local errors = #()

    fn check label conditionValue =
    (
        if conditionValue == true then
        (
            passed += 1
            format "[AMENO_TEST][PASS] %\n" label
        )
        else
        (
            failed += 1
            append errors label
            format "[AMENO_TEST][FAIL] %\n" label
        )
    )

    fn colorMatches colorValue rValue gValue bValue =
    (
        colorValue != undefined and colorValue.r == rValue and colorValue.g == gValue and colorValue.b == bValue
    )

    struct AmenoE13ColorAdapter
    (
        createdColors = #(),

        fn createAnnotationMaterial colorValue:(color 245 245 245) =
        (
            append createdColors colorValue
            local materialValue = standardMaterial name:(uniqueName "AMENO_E13_COLOR_RENDER_MTL_")
            materialValue.diffuse = colorValue
            materialValue
        )
    )

    check "serviço de estilos global carregado" (::AmenoStyleService != undefined and ::AmenoStyleService.globalStyles != undefined)
    check "parser de cor RGB normaliza valor" (colorMatches (::AmenoStyleService.colorFromString "12,34,56") 12 34 56)
    check "parser de cor inválida usa fallback" (colorMatches (::AmenoStyleService.colorFromString "x") 245 245 245)

    local baseStyle = ::AmenoStyleService.getStyle "default"
    local globalStyle = ::AmenoStyleService.saveAsNewStyle "E13 Global Azul" baseStyle
    globalStyle.annotationColor = "12,34,56"
    check "saveStyle persiste o RGB no estilo" (::AmenoStyleService.saveStyle globalStyle)
    check "arquivo da biblioteca global foi criado" (doesFileExist globalStylesPath)

    local serialized = ""
    try (serialized = (dotNetClass "System.IO.File").ReadAllText globalStylesPath) catch ()
    check "arquivo global contém a cor escolhida" ((findString serialized "12,34,56") != undefined)

    -- Simula uma nova instância do serviço sem consultar o registro da cena.
    local freshService = AmenoStyleServiceDefinition()
    freshService.styles = freshService.createDefaultPresets()
    local globalLoaded = freshService.loadGlobalLibrary()
    local loadedGlobal = freshService.getStyle globalStyle.styleId
    check "nova instância lê biblioteca global" (globalLoaded and loadedGlobal != undefined and loadedGlobal.name == "E13 Global Azul")
    check "biblioteca global preserva RGB após recarregar" (loadedGlobal != undefined and loadedGlobal.annotationColor == "12,34,56")

    local secondStyle = ::AmenoStyleService.saveAsNewStyle "E13 Global Vermelho" baseStyle
    secondStyle.annotationColor = "210,40,30"
    ::AmenoStyleService.saveStyle secondStyle

    local firstDimension = try (::AmenoDimensionGraphics.createDimension [0,0,0] [100,0,0] [50,30,0] role:"color-test-1" styleId:globalStyle.styleId style:globalStyle useUndo:false) catch (undefined)
    local secondDimension = try (::AmenoDimensionGraphics.createDimension [0,100,0] [100,100,0] [50,130,0] role:"color-test-2" styleId:secondStyle.styleId style:secondStyle useUndo:false) catch (undefined)
    local firstMaterial = if firstDimension != undefined then firstDimension.lineNode.material else undefined
    local secondMaterial = if secondDimension != undefined then secondDimension.lineNode.material else undefined
    check "criação aplica cor do estilo ao material da cota" (firstDimension != undefined and colorMatches firstMaterial.diffuse 12 34 56 and secondDimension != undefined and colorMatches secondMaterial.diffuse 210 40 30)

    local targetNodes = ::AmenoRenderCotasService.collectTargetNodes #all
    local fakeAdapter = AmenoE13ColorAdapter()
    local materialEntries = try (::AmenoRenderCotasService.createAnnotationMaterials targetNodes fakeAdapter) catch (#())
    check "overlay cria um material por cor distinta" (materialEntries.count == 2 and fakeAdapter.createdColors.count == 2)
    check "overlay encaminha primeira cor ao adapter" (fakeAdapter.createdColors.count >= 1 and colorMatches fakeAdapter.createdColors[1] 12 34 56)
    check "overlay encaminha segunda cor ao adapter" (fakeAdapter.createdColors.count >= 2 and colorMatches fakeAdapter.createdColors[2] 210 40 30)

    if firstDimension != undefined and isValidNode firstDimension.controller do ::AmenoDimensionGraphics.removeDimension firstDimension.dimensionId
    if secondDimension != undefined and isValidNode secondDimension.controller do ::AmenoDimensionGraphics.removeDimension secondDimension.dimensionId
    try (::AmenoStyleService.removeStyle globalStyle.styleId) catch ()
    try (::AmenoStyleService.removeStyle secondStyle.styleId) catch ()
    deleteFile globalStylesPath
    deleteFile (globalStylesPath + ".bak")
    deleteFile (globalStylesPath + ".tmp")
    environmentApi.SetEnvironmentVariable "LOCALAPPDATA" originalLocalAppData
    try (directoryApi.Delete isolatedLocalAppData true) catch ()

    format "\n[AMENO_TEST] Resultado biblioteca/cor: % passou(aram), % falhou(aram)\n" passed failed
    if failed == 0 then
        format "[AMENO_TEST][PASS] E13 biblioteca global e cor de render passaram.\n"
    else
    (
        format "[AMENO_TEST][FAIL] Falhas biblioteca/cor: %\n" (errors as string)
        throw ("E13 biblioteca global/cor falhou: " + (failed as string))
    )
)
