/* Integration smoke test executed by 3dsmaxbatch.exe. */

global AmenoApp
global AmenoVersion
global AmenoRendererProbe

(
    local testFile = getSourceFileName()
    local testPath = getFilenamePath testFile
    local repositoryRoot = pathConfig.normalizePath (pathConfig.appendPath testPath @"..\..")
    local bootstrapPath = pathConfig.normalizePath (pathConfig.appendPath repositoryRoot @"Contents\scripts\startup\ameno_bootstrap.ms")
    local macroPath = pathConfig.normalizePath (pathConfig.appendPath repositoryRoot @"Contents\macroscripts\AmenoTools.mcr")

    fileIn bootstrapPath quiet:true

    if AmenoApp == undefined then throw "AmenoApp não foi criada pelo bootstrap."
    if not AmenoApp.started then throw "AmenoApp não terminou o startup."
    if AmenoVersion.appVersion != "0.0.1" then throw "Versão inesperada no runtime."
    if AmenoApp.rendererInfo == undefined then throw "Renderer probe não retornou informação."

    local coronaInfo = AmenoRendererProbe.classify "CoronaRenderer"
    local vrayCpuInfo = AmenoRendererProbe.classify "V_Ray_7_Hotfix_1"
    local vrayGpuInfo = AmenoRendererProbe.classify "V_Ray_GPU_Next"

    if coronaInfo.family != #corona or coronaInfo.supportState != #supported then throw "Classificação Corona inválida."
    if vrayCpuInfo.family != #vray or vrayCpuInfo.engine != #cpu or vrayCpuInfo.supportState != #supported then throw "Classificação V-Ray CPU inválida."
    if vrayGpuInfo.family != #vray or vrayGpuInfo.engine != #gpu or vrayGpuInfo.supportState != #experimental then throw "Classificação V-Ray GPU inválida."

    fileIn macroPath quiet:true

    format "[AMENO_TEST][PASS] Bootstrap %, renderer % (%).\n" AmenoVersion.appVersion AmenoApp.rendererInfo.displayName AmenoApp.rendererInfo.className
)
