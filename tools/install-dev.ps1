[CmdletBinding()]
param(
    [string]$Destination = (Join-Path $env:APPDATA 'Autodesk\ApplicationPlugins\AmenoTools')
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$manifestPath = Join-Path $repositoryRoot 'PackageContents.xml'
$contentsPath = Join-Path $repositoryRoot 'Contents'

& (Join-Path $PSScriptRoot 'validate-package.ps1')

if (Test-Path -LiteralPath $Destination) {
    Remove-Item -LiteralPath $Destination -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $Destination | Out-Null
Copy-Item -LiteralPath $manifestPath -Destination $Destination -Force
Copy-Item -LiteralPath $contentsPath -Destination $Destination -Recurse -Force

# O candidato E15 usa a interface Python/Qt no Max 2026. Os módulos WPF
# antigos permanecem no repositório para histórico/rollback, mas ficam fora da
# instalação ativa para impedir carregamento acidental pela inicialização.
$legacyWpfFiles = @(
    'Contents\scripts\ameno\ui\ameno_style_editor_wpf.ms',
    'Contents\scripts\ameno\ui\ameno_cotas_criar_tab.ms',
    'Contents\scripts\ameno\ui\ameno_cotas_estilos_tab.ms',
    'Contents\scripts\ameno\ui\ameno_cotas_editar_tab.ms',
    'Contents\scripts\ameno\ui\ameno_cotas_render_tab.ms',
    'Contents\scripts\ameno\ui\ameno_cotas_window.ms',
    'Contents\scripts\ameno\ui\ameno_main_panel.ms'
)
foreach ($legacyWpfFile in $legacyWpfFiles) {
    $installedLegacyFile = Join-Path $Destination $legacyWpfFile
    if (Test-Path -LiteralPath $installedLegacyFile) {
        Remove-Item -LiteralPath $installedLegacyFile -Force
    }
}
$pythonCacheDir = Join-Path $Destination 'Contents\python\ameno_ui\__pycache__'
if (Test-Path -LiteralPath $pythonCacheDir) {
    Remove-Item -LiteralPath $pythonCacheDir -Recurse -Force
}

Write-Host "Ameno Tools instalado para desenvolvimento em: $Destination"
Write-Host 'Reinicie o 3ds Max 2026 e procure Ameno Tools em Customize User Interface.'
