[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$manifestPath = Join-Path $repositoryRoot 'PackageContents.xml'

if (-not (Test-Path -LiteralPath $manifestPath)) {
    throw "PackageContents.xml não encontrado em $repositoryRoot"
}

[xml]$manifest = Get-Content -Raw -LiteralPath $manifestPath
$package = $manifest.ApplicationPackage

if ($package.AutodeskProduct -ne '3ds Max') {
    throw 'AutodeskProduct deve ser 3ds Max.'
}

if ($package.AppVersion -ne '0.0.1') {
    throw "Versão inesperada no manifesto: $($package.AppVersion)"
}

$componentEntries = @($package.Components | ForEach-Object {
    if ($_.RuntimeRequirements.SeriesMin -ne '2026' -or $_.RuntimeRequirements.SeriesMax -ne '2026') {
        throw "Componente fora do alvo 2026: $($_.Description)"
    }

    @($_.ComponentEntry)
})

if ($componentEntries.Count -lt 2) {
    throw 'O pacote deve conter ao menos MacroScript e bootstrap.'
}

foreach ($entry in $componentEntries) {
    $relativePath = $entry.ModuleName -replace '^\./', ''
    $absolutePath = Join-Path $repositoryRoot ($relativePath -replace '/', '\')

    if (-not (Test-Path -LiteralPath $absolutePath -PathType Leaf)) {
        throw "Componente ausente: $absolutePath"
    }
}

Write-Host "Ameno Tools $($package.AppVersion): pacote válido para 3ds Max 2026."
