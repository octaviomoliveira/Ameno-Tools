/* E18.11 — smoke test against the package installed in ApplicationPlugins. */

global AmenoApp
global AmenoPythonUI

(
    local environmentApi = dotNetClass "System.Environment"
    local appData = environmentApi.GetEnvironmentVariable "APPDATA"
    if appData == undefined or appData == "" then throw "E18 instalado: APPDATA ausente."
    local installRoot = pathConfig.normalizePath (pathConfig.appendPath appData @"Autodesk\ApplicationPlugins\AmenoTools")
    local bootstrapPath = pathConfig.normalizePath (pathConfig.appendPath installRoot @"Contents\scripts\startup\ameno_bootstrap.ms")
    if not doesFileExist bootstrapPath then throw ("E18 instalado: bootstrap ausente: " + bootstrapPath)

    fileIn bootstrapPath quiet:true

    if AmenoApp == undefined or not AmenoApp.started then throw "E18 instalado: runtime não iniciou."
    if AmenoPythonUI == undefined or AmenoPythonUI.scriptPath == "" then throw "E18 instalado: launcher ausente."
    if not doesFileExist AmenoPythonUI.scriptPath then throw ("E18 instalado: entrypoint ausente: " + AmenoPythonUI.scriptPath)
    if not (AmenoPythonUI.show pageName:"login") then throw "E18 instalado: Login não abriu."

    if (python.Execute "from ameno_ui.style_draft import StyleDraft; from ameno_ui.dimension_preview import build_preview_geometry") != #success then throw "E18 instalado: módulos E18 ausentes."
    if (python.Execute "d=StyleDraft(); assert d.to_snapshot().style_id == 'default'") != #success then throw "E18 instalado: draft inválido."
    if (python.Execute "g=build_preview_geometry(d.to_snapshot(), (620,240)); assert len(g.extension_segments) == 2") != #success then throw "E18 instalado: preview inválido."
    if (python.Execute "import ameno_ui; from PySide6 import QtWidgets; w=ameno_ui._application.window; w.resize(780,560); w.show_application('create'); w.show(); QtWidgets.QApplication.processEvents(); w.shell._apply_responsive_layout(); assert w.shell._responsive_mode == 'compact'") != #success then throw "E18 instalado: breakpoint compacto falhou."
    if (python.Execute "assert all(v.horizontalScrollBar().maximum() == 0 for v in w.shell.page_views.values())") != #success then throw "E18 instalado: overflow horizontal."
    if (python.Execute "assert len(w.shell.pages['styles'].findChildren(__import__('PySide6').QtWidgets.QSplitter)) == 0") != #success then throw "E18 instalado: splitter legado presente."
    if (python.Execute "from ameno_ui.assets import nav_icon; assert all(not nav_icon(n).isNull() for n in ('cotar','aparencia','revisar','exportar','configuracao','ajuda'))") != #success then throw "E18 instalado: ícone ausente."

    AmenoPythonUI.close()
    format "[AMENO_INSTALLED_TEST][PASS] E18 Qt instalado: draft, preview, rail compacto, overflow e ícones validados.\n"
)
