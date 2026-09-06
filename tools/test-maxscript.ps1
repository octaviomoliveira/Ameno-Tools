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
$generatedConfigPath = Join-Path $outputDirectory 'batch-isolated.generated.ini'

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

$resolvedTestScript = (Resolve-Path -LiteralPath $TestScript).Path
$resolvedConfigPath = (Resolve-Path -LiteralPath $ConfigPath).Path
$isolatedPlugCfg = Join-Path $outputDirectory 'isolated-plugcfg'
$isolatedMaxData = Join-Path $outputDirectory 'isolated-maxdata'
$isolatedTemp = Join-Path $outputDirectory 'isolated-temp'
$isolatedMacros = Join-Path $outputDirectory 'isolated-macros'
$isolatedLocalAppData = Join-Path $outputDirectory 'isolated-localappdata'

foreach ($isolatedDirectory in @($isolatedPlugCfg, $isolatedMaxData, $isolatedTemp, $isolatedMacros, $isolatedLocalAppData)) {
    New-Item -ItemType Directory -Force -Path $isolatedDirectory | Out-Null
}

# O INI versionado serve como template. Estas três entradas precisam apontar para o
# worktree corrente para que dois agentes não compartilhem perfil, logs ou temporários.
$configText = Get-Content -Raw -LiteralPath $resolvedConfigPath
$configText = [regex]::Replace($configText, '(?m)^PlugCFG=.*$', ('PlugCFG=' + $isolatedPlugCfg))
$configText = [regex]::Replace($configText, '(?m)^MaxData=.*$', ('MaxData=' + $isolatedMaxData))
$configText = [regex]::Replace($configText, '(?m)^Temp=.*$', ('Temp=' + $isolatedTemp))
$configText = [regex]::Replace($configText, '(?m)^Additional Macros=.*$', ('Additional Macros=' + $isolatedMacros))
[System.IO.File]::WriteAllText($generatedConfigPath, $configText, [System.Text.Encoding]::Default)

Remove-Item -LiteralPath $listenerLog -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath $systemLog -Force -ErrorAction SilentlyContinue

$previousLocalAppData = $env:LOCALAPPDATA
try {
    # O diagnóstico E12-R0 grava em LOCALAPPDATA; manter esse perfil isolado
    # evita depender de permissões/estado de outra instalação ou sessão.
    $env:LOCALAPPDATA = $isolatedLocalAppData
    & $MaxBatchPath $resolvedTestScript -i $generatedConfigPath -v 3 -listenerlog $listenerLog -log $systemLog
    $batchExitCode = $LASTEXITCODE
}
finally {
    $env:LOCALAPPDATA = $previousLocalAppData
}

if ($batchExitCode -ne 0) {
    throw "3ds Max Batch terminou com código $batchExitCode. Consulte $systemLog"
}

$listenerText = Get-Content -Raw -LiteralPath $listenerLog

$passMatches = [regex]::Matches($listenerText, '\[(?:AMENO_TEST|AMENO_INSTALLED_TEST)\]\[PASS\]')
$failMatches = [regex]::Matches($listenerText, '\[(?:AMENO_TEST|AMENO_INSTALLED_TEST)\]\[FAIL\]')

# Um PASS isolado não basta: o runner precisa rejeitar qualquer falha emitida
# pela suíte, mesmo quando o processo termina com código 0.
if ($failMatches.Count -gt 0) {
    throw "Marcadores de falha encontrados ($($failMatches.Count)). Consulte $listenerLog"
}

if ($passMatches.Count -eq 0) {
    throw "O marcador de sucesso não foi encontrado. Consulte $listenerLog"
}

Write-Host "MAXScript smoke test: OK. PASS markers: $($passMatches.Count); FAIL markers: 0."
