/* E14.2/E14.3 — persistência e geometria gráfica em uma vista de fachada. */

global AmenoApp
global AmenoDimensionPlaneService
global AmenoDimensionGraphics
global AmenoDimensionMath
global AmenoDimensionCA
global AmenoUnitService

(
    local testFile = getSourceFileName()
    local testPath = getFilenamePath testFile
    local repositoryRoot = pathConfig.normalizePath (pathConfig.appendPath testPath @"..\..")
    local bootstrapPath = pathConfig.normalizePath (pathConfig.appendPath repositoryRoot @"Contents\scripts\startup\ameno_bootstrap.ms")
    fileIn bootstrapPath quiet:true

    resetMaxFile #noPrompt
    local sceneState = AmenoApp.prepareScene()
    if sceneState.status != #ready then throw "E14 graphics: cena não preparada."

    local facade = AmenoDimensionPlaneService.standardForViewType #view_front
    local created = AmenoDimensionGraphics.createDimension [0,2,10] [100,9,40] [50,0,20] \
        role:"e14-test" dimensionMode:#horizontal plane:facade useUndo:false
    if created == undefined or created.controller == undefined then throw "E14 graphics: criação retornou vazio."
    if created.layout.planeType != #viewPlane then throw "E14 graphics: layout não preservou o tipo de plano."
    if created.layout.linePointA != [0,0,20] or created.layout.linePointB != [100,0,20] then throw "E14 graphics: linha horizontal não está no plano da fachada."

    local invalidLayout = AmenoDimensionMath.layoutForMode [0,0,10] [100,0,10] [0,0,20] mode:#horizontal plane:facade
    invalidLayout.planeAxisV = [1,0,0]
    local invalidResolvedPlane = AmenoDimensionGraphics.resolvePlane layout:invalidLayout
    if invalidResolvedPlane == undefined or invalidResolvedPlane.valid then throw "E14 graphics: base persistida inválida caiu silenciosamente em XY."

    local ca = AmenoDimensionCA.readCA created.controller
    if ca == undefined or ca.schemaVersion != 6 then throw "E14 graphics: schema v6 não foi gravado."
    if ca.planeType != "viewPlane" then throw "E14 graphics: tipo de plano não persistiu."
    if (length (ca.planeNormal - [0,-1,0])) > 0.0001 then throw "E14 graphics: normal não persistiu."

    local audit = AmenoDimensionGraphics.getDimensionAudit created.controller
    local expectedMillimeters = 100.0 * AmenoUnitService.currentMillimetersPerSceneUnit()
    if audit == undefined or abs (audit.measuredMillimeters - expectedMillimeters) > 0.0001 then throw "E14 graphics: audit da fachada incorreto."

    local dimensionId = created.dimensionId
    local rebuilt = AmenoDimensionGraphics.rebuildDimension created.controller
    if rebuilt == undefined or rebuilt.layout.planeType != #viewPlane then throw "E14 graphics: rebuild perdeu o plano."
    if (AmenoDimensionGraphics.findNodesForDimension dimensionId).count != 3 then throw "E14 graphics: rebuild deixou nós incorretos."

    local savePath = pathConfig.appendPath (getDir #temp) "ameno_e14_graphics.max"
    deleteFile savePath
    saveMaxFile savePath clearNeedSaveFlag:true quiet:true
    resetMaxFile #noPrompt
    loadMaxFile savePath quiet:true
    deleteFile savePath
    AmenoApp.refreshDimensions()

    local loadedController = undefined
    for controllerValue in (AmenoDimensionGraphics.findControllers role:"e14-test") do loadedController = controllerValue
    if loadedController == undefined then throw "E14 graphics: controlador não carregou do .max."
    local loadedCA = AmenoDimensionCA.readCA loadedController
    if loadedCA == undefined or loadedCA.schemaVersion != 6 or loadedCA.planeType != "viewPlane" then throw "E14 graphics: plano não persistiu após load."
    local loadedAudit = AmenoDimensionGraphics.getDimensionAudit loadedController
    if loadedAudit == undefined or abs (loadedAudit.measuredMillimeters - expectedMillimeters) > 0.0001 then throw "E14 graphics: medida mudou após load."

    format "[AMENO_TEST][PASS] E14.2/E14.3 persistence and facade graphics passed.\n"
)
