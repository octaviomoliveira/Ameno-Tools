/* E20.1 — native window geometry and state in the Max 2026 Qt host. */

global AmenoApp
global AmenoPythonUI

(
    local testFile = getSourceFileName()
    local testPath = getFilenamePath testFile
    local repositoryRoot = pathConfig.normalizePath (pathConfig.appendPath testPath @"..\..")
    local bootstrapPath = pathConfig.normalizePath (pathConfig.appendPath repositoryRoot @"Contents\scripts\startup\ameno_bootstrap.ms")
    local settingsPath = pathConfig.normalizePath (pathConfig.appendPath repositoryRoot @".test-output\e20-window-host.generated.ini")
    local pythonSettingsPath = substituteString settingsPath "\\" "/"
    local environmentApi = dotNetClass "System.Environment"
    local originalSettingsPath = environmentApi.GetEnvironmentVariable "AMENO_SETTINGS_FILE"
    local originalPythonSettingsPath = if originalSettingsPath == undefined then "" else (substituteString originalSettingsPath "\\" "/")
    if doesFileExist settingsPath do deleteFile settingsPath
    environmentApi.SetEnvironmentVariable "AMENO_SETTINGS_FILE" settingsPath
    if (python.Execute ("import os; os.environ['AMENO_SETTINGS_FILE']=r'" + pythonSettingsPath + "'")) != #success then throw "E20.1 host: não isolou as preferências Python."
    fileIn bootstrapPath quiet:true

    if AmenoApp == undefined or not AmenoApp.started then throw "E20.1 host: runtime não iniciou."
    if AmenoPythonUI == undefined then throw "E20.1 host: launcher ausente."
    local sourceEntrypoint = pathConfig.normalizePath (pathConfig.appendPath repositoryRoot @"Contents\python\ameno_ui\entrypoint.py")
    AmenoPythonUI.scriptPath = sourceEntrypoint

    if not (AmenoPythonUI.show pageName:"login") then throw "E20.1 host: primeira abertura falhou."
    if (python.Execute "import ameno_ui; from PySide6 import QtCore, QtWidgets; from ameno_ui.window_geometry import initial_window_geometry; app=QtWidgets.QApplication.instance(); w=ameno_ui._application.window; app.processEvents(); area=w.screen().availableGeometry()") != #success then throw "E20.1 host: estado Qt indisponível."
    if (python.Execute "assert area.contains(w.frameGeometry())") != #success then throw "E20.1 host: frame saiu da área útil."
    if (python.Execute "assert w.height() > w.width()") != #success then throw "E20.1 host: primeira geometria não é vertical."

    if (python.Execute "normal=QtCore.QRect(area.left()+80, area.top()+100, min(620,area.width()-160), min(780,area.height()-160)); w.showNormal(); w.setGeometry(normal); app.processEvents(); saved=QtCore.QRect(w.geometry()); w._save_geometry()") != #success then throw "E20.1 host: não salvou geometria normal."
    AmenoPythonUI.close()
    if not (AmenoPythonUI.show pageName:"login") then throw "E20.1 host: reabertura normal falhou."
    python.Execute "w=ameno_ui._application.window; app.processEvents()"
    if (python.Execute "assert w.geometry() == saved; assert not w.isMaximized(); assert area.contains(w.frameGeometry())") != #success then throw "E20.1 host: posição/tamanho normal não sobreviveram."

    if (python.Execute "w.showMaximized(); app.processEvents(); w.showMinimized(); app.processEvents(); w._save_geometry()") != #success then throw "E20.1 host: falha ao persistir maximizada após minimizar."
    AmenoPythonUI.close()
    if not (AmenoPythonUI.show pageName:"login") then throw "E20.1 host: reabertura maximizada falhou."
    if (python.Execute "w=ameno_ui._application.window; app.processEvents(); assert w.isMaximized()") != #success then throw "E20.1 host: estado maximizado não sobreviveu."
    if (python.Execute "w.windowHandle().setWindowState(QtCore.Qt.WindowState.WindowNoState); app.processEvents(); app.processEvents()") != #success then throw "E20.1 host: falha ao restaurar a janela maximizada."
    if (python.Execute "assert not w.isMaximized()") != #success then throw "E20.1 host: janela permaneceu maximizada após restaurar."
    if (python.Execute "assert w.geometry() == saved") != #success then throw "E20.1 host: geometria normal mudou após restaurar."
    if (python.Execute "assert w._frame_checked; assert area.contains(w.frameGeometry())") != #success then throw "E20.1 host: frame restaurado saiu da área útil."

    AmenoPythonUI.close()
    if originalSettingsPath == undefined then
    (
        python.Execute "os.environ.pop('AMENO_SETTINGS_FILE', None)"
        environmentApi.SetEnvironmentVariable "AMENO_SETTINGS_FILE" ""
    )
    else
    (
        python.Execute ("os.environ['AMENO_SETTINGS_FILE']=r'" + originalPythonSettingsPath + "'")
        environmentApi.SetEnvironmentVariable "AMENO_SETTINGS_FILE" originalSettingsPath
    )
    format "[AMENO_TEST][PASS] E20.1 janela vertical, frame seguro, posição/tamanho e maximização validados no Max 2026.\n"
)
