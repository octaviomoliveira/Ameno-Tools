/* E18 — contratos Qt, preview local e breakpoints no host Max 2026. */

global AmenoApp
global AmenoPythonUI

(
    local testFile = getSourceFileName()
    local testPath = getFilenamePath testFile
    local repositoryRoot = pathConfig.normalizePath (pathConfig.appendPath testPath @"..\..")
    local bootstrapPath = pathConfig.normalizePath (pathConfig.appendPath repositoryRoot @"Contents\scripts\startup\ameno_bootstrap.ms")
    fileIn bootstrapPath quiet:true

    if AmenoApp == undefined or not AmenoApp.started then throw "E18 host: runtime não iniciou."
    if AmenoPythonUI == undefined then throw "E18 host: launcher ausente."

    -- A instalação E17 do usuário pode ser descoberta pelo 3ds Max batch antes
    -- do worktree. Aponte explicitamente o launcher para o checkout sob teste;
    -- isso mantém o gate hermético sem remover a instalação real do usuário.
    local sourceEntrypoint = pathConfig.normalizePath (pathConfig.appendPath repositoryRoot @"Contents\python\ameno_ui\entrypoint.py")
    if not doesFileExist sourceEntrypoint then throw "E18 host: entrypoint do checkout ausente."
    AmenoPythonUI.scriptPath = sourceEntrypoint
    if not (AmenoPythonUI.show pageName:"login") then throw "E18 host: Login não abriu."

    if (python.Execute "from ameno_ui.style_draft import StyleDraft; from ameno_ui.dimension_preview import build_preview_geometry") != #success then throw "E18 host: módulos locais ausentes."
    if (python.Execute "d=StyleDraft(); assert d.to_snapshot().style_id == 'default'") != #success then throw "E18 host: draft não nasce válido."
    if (python.Execute "g=build_preview_geometry(d.to_snapshot(), (620,240)); assert len(g.extension_segments) == 2") != #success then throw "E18 host: geometria local inválida."
    if (python.Execute "import ameno_ui; from PySide6 import QtWidgets; w=ameno_ui._application.window; w.resize(780,560); w.show_application('create'); w.show(); QtWidgets.QApplication.processEvents(); w.shell._apply_responsive_layout(); assert w.shell._responsive_mode == 'compact'") != #success then throw "E18 host: breakpoint compacto falhou."
    if (python.Execute "assert all(v.horizontalScrollBar().maximum() == 0 for v in w.shell.page_views.values())") != #success then throw "E18 host: overflow horizontal."
    if (python.Execute "assert len(w.shell.pages['styles'].findChildren(__import__('PySide6').QtWidgets.QSplitter)) == 0") != #success then throw "E18 host: splitter legado presente."
    if (python.Execute "from ameno_ui.assets import nav_icon; assert all(not nav_icon(n).isNull() for n in ('cotar','aparencia','revisar','exportar','configuracao','ajuda'))") != #success then throw "E18 host: ícone ausente."

    AmenoPythonUI.close()
    format "[AMENO_TEST][PASS] E18 Qt host: draft, preview puro, rail compacto, overflow e ícones validados.\n"
)
