[CmdletBinding()]
param(
    [string]$MaxBatchPath = 'C:\Program Files\Autodesk\3ds Max 2026\3dsmaxbatch.exe',
    [string]$ConfigPath,
    [string]$TestScript
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot

if ([string]::IsNullOrWhiteSpace($TestScript)) {
    $TestScript = Join-Path $repositoryRoot 'tests\maxscript\test_bootstrap.ms'
}

if ([string]::IsNullOrWhiteSpace($ConfigPath)) {
    $ConfigPath = Join-Path $repositoryRoot 'tests\maxscript\batch-isolated.ini'
}

$outputDirectory = Join-Path $repositoryRoot '.test-output'
$listenerLog = Join-Path $outputDirectory 'listener.log'
$systemLog = Join-Path $outputDirectory 'system.log'

if (-not (Test-Path -LiteralPath $MaxBatchPath -PathType Leaf)) {
    throw "3dsmaxbatch.exe não encontrado: $MaxBatchPath"
}

if (-not (Test-Path -LiteralPath $testScript -PathType Leaf)) {
    throw "Teste MAXScript não encontrado: $testScript"
}

if (-not (Test-Path -LiteralPath $ConfigPath -PathType Leaf)) {
    throw "Configuração isolada do 3ds Max não encontrada: $ConfigPath"
}

New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null
Remove-Item -LiteralPath $listenerLog -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath $systemLog -Force -ErrorAction SilentlyContinue

& $MaxBatchPath $TestScript -i $ConfigPath -v 3 -listenerlog $listenerLog -log $systemLog

if ($LASTEXITCODE -ne 0) {
    throw "3ds Max Batch terminou com código $LASTEXITCODE. Consulte $systemLog"
}

$listenerText = Get-Content -Raw -LiteralPath $listenerLog

if ($listenerText -notmatch '\[AMENO_TEST\]\[PASS\]' -and $listenerText -notmatch '\[AMENO_INSTALLED_TEST\]\[PASS\]') {
    throw "O marcador de sucesso não foi encontrado. Consulte $listenerLog"
}

Write-Host 'MAXScript smoke test: OK.'
