[CmdletBinding()]
param(
    [string]$Destination = (Join-Path $env:APPDATA 'Autodesk\ApplicationPlugins\AmenoTools')
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$manifestPath = Join-Path $repositoryRoot 'PackageContents.xml'
$contentsPath = Join-Path $repositoryRoot 'Contents'

& (Join-Path $PSScriptRoot 'validate-package.ps1')

New-Item -ItemType Directory -Force -Path $Destination | Out-Null
Copy-Item -LiteralPath $manifestPath -Destination $Destination -Force
Copy-Item -LiteralPath $contentsPath -Destination $Destination -Recurse -Force

Write-Host "Ameno Tools instalado para desenvolvimento em: $Destination"
Write-Host 'Reinicie o 3ds Max 2026 e procure Ameno Tools em Customize User Interface.'
