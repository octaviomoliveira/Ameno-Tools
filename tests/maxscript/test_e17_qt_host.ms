/* E17 — construção e lifecycle da UI no Python/PySide6 embarcado do Max 2026. */

global AmenoApp
global AmenoPythonUI

(
    local testFile = getSourceFileName()
    local testPath = getFilenamePath testFile
    local repositoryRoot = pathConfig.normalizePath (pathConfig.appendPath testPath @"..\..")
    local bootstrapPath = pathConfig.normalizePath (pathConfig.appendPath repositoryRoot @"Contents\scripts\startup\ameno_bootstrap.ms")
    fileIn bootstrapPath quiet:true

    if AmenoApp == undefined or not AmenoApp.started then throw "E17 host: runtime não iniciou."
    if AmenoPythonUI == undefined then throw "E17 host: launcher Python/Qt ausente."

    python.Execute "import sys"
    python.Execute "import PySide6"
    if (python.Execute "assert sys.version.split()[0] == '3.11.12'") != #success then throw "E17 host: Python inesperado."
    if (python.Execute "assert PySide6.__version__ == '6.5.3'") != #success then throw "E17 host: PySide6 inesperado."

    if not (AmenoPythonUI.show pageName:"login") then throw "E17 host: show(login) falhou."
    if not (AmenoPythonUI.isOpen()) then throw "E17 host: launcher não registrou a janela aberta."
    if (python.Execute "import ameno_ui; assert ameno_ui.is_open()") != #success then throw "E17 host: janela não ficou aberta."

    if (python.Execute "assert bool(ameno_ui._application and ameno_ui._application.window and ameno_ui._application.window.objectName() == 'AmenoMainWindow')") != #success then throw "E17 host: AmenoMainWindow não foi construída."
    if (python.Execute "assert len(ameno_ui._application.window.shell.pages) == 5") != #success then throw "E17 host: cardinalidade de páginas inválida."

    if (python.Execute "[ameno_ui._application.window.shell.show_page(name) for name in ('create','styles','edit','render','config')]") != #success then throw "E17 host: navegação local falhou."
    if (python.Execute "assert len(ameno_ui._application.window.shell.pages) == 5") != #success then throw "E17 host: navegação alterou a cardinalidade."

    if (python.Execute "ameno_ui._application.authenticate('e17-host-gate')") != #success then throw "E17 host: autenticação local falhou."
    if (python.Execute "assert ameno_ui._application.auth.authenticated") != #success then throw "E17 host: sessão não autenticou."
    if (python.Execute "ameno_ui._application.logout()") != #success then throw "E17 host: logout falhou."
    if (python.Execute "assert (not ameno_ui._application.auth.authenticated) and ameno_ui._application.window.login_page.token.text() == ''") != #success then throw "E17 host: logout não apagou sessão/widget."

    if not (AmenoPythonUI.close()) then throw "E17 host: fechamento falhou."
    if AmenoPythonUI.isOpen() then throw "E17 host: launcher manteve estado aberto após close."
    if (python.Execute "assert not ameno_ui.is_open()") != #success then throw "E17 host: janela permaneceu visível após close."
    if not (AmenoPythonUI.show pageName:"login") then throw "E17 host: reabertura falhou."
    if not (AmenoPythonUI.isOpen()) then throw "E17 host: launcher não registrou reabertura."
    if (python.Execute "assert ameno_ui.is_open()") != #success then throw "E17 host: janela não reabriu."
    AmenoPythonUI.close()

    format "[AMENO_TEST][PASS] E17 UI construída no host Python 3.11.12 / PySide6 6.5.3, cinco páginas, Login/App/logout e close/reopen validados.\n"
)
