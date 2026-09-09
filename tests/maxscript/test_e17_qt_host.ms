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

    local pyVersion = python.Execute "import sys; sys.version.split()[0]"
    local qtVersion = python.Execute "import PySide6; PySide6.__version__"
    if pyVersion != "3.11.12" then throw ("E17 host: Python inesperado: " + (pyVersion as string))
    if qtVersion != "6.5.3" then throw ("E17 host: PySide6 inesperado: " + (qtVersion as string))

    if not (AmenoPythonUI.show pageName:"login") then throw "E17 host: show(login) falhou."
    if not (AmenoPythonUI.isOpen()) then throw "E17 host: janela não ficou aberta."

    local windowOk = python.Execute "import ameno_ui; bool(ameno_ui._application and ameno_ui._application.window and ameno_ui._application.window.objectName() == 'AmenoMainWindow')"
    if windowOk != true then throw "E17 host: AmenoMainWindow não foi construída."
    local pageCount = python.Execute "import ameno_ui; len(ameno_ui._application.window.shell.pages)"
    if pageCount != 5 then throw ("E17 host: cardinalidade de páginas inválida: " + (pageCount as string))

    local navigated = python.Execute "import ameno_ui; [ameno_ui._application.window.shell.show_page(name) for name in ('create','styles','edit','render','config')]; len(ameno_ui._application.window.shell.pages) == 5"
    if navigated != true then throw "E17 host: navegação local falhou."

    local authenticated = python.Execute "import ameno_ui; ameno_ui._application.authenticate('e17-host-gate'); ameno_ui._application.auth.authenticated"
    if authenticated != true then throw "E17 host: autenticação local falhou."
    local loggedOut = python.Execute "import ameno_ui; ameno_ui._application.logout(); (not ameno_ui._application.auth.authenticated) and ameno_ui._application.window.login_page.token.text() == ''"
    if loggedOut != true then throw "E17 host: logout não apagou sessão/widget."

    if not (AmenoPythonUI.close()) then throw "E17 host: fechamento falhou."
    if AmenoPythonUI.isOpen() then throw "E17 host: janela permaneceu visível após close."
    if not (AmenoPythonUI.show pageName:"login") then throw "E17 host: reabertura falhou."
    if not (AmenoPythonUI.isOpen()) then throw "E17 host: janela não reabriu."
    AmenoPythonUI.close()

    format "[AMENO_TEST][PASS] E17 UI construída no host Python % / PySide6 %, cinco páginas, Login/App/logout e close/reopen validados.\n" pyVersion qtVersion
)
