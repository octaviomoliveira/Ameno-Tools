[CmdletBinding()]
param(
    [string]$Version = "0.0.1-alpha",
    [string]$OutputDir = "dist"
)

$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $repoRoot

Write-Host "=====================================================" -ForegroundColor Cyan
Write-Host "   Ameno Tools - Empacotamento de Release Alpha      " -ForegroundColor Cyan
Write-Host "=====================================================" -ForegroundColor Cyan

# 1. Validação estrutural do pacote Autodesk
Write-Host "1. Validando estrutura do ApplicationPackage..." -ForegroundColor Yellow
& (Join-Path $PSScriptRoot "validate-package.ps1")
Write-Host "   Estrutura do pacote aprovada!" -ForegroundColor Green

# 2. Prepara diretório de distribuição
$distPath = Join-Path $repoRoot $OutputDir
if (-not (Test-Path $distPath)) {
    New-Item -ItemType Directory -Path $distPath -Force | Out-Null
}

$zipFileName = "AmenoTools-$Version.zip"
$zipFilePath = Join-Path $distPath $zipFileName

if (Test-Path $zipFilePath) {
    Remove-Item $zipFilePath -Force
}

# 3. Prepara diretório temporário para empacotamento
$tempStageDir = Join-Path $env:TEMP ("AmenoToolsStage_" + [System.Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $tempStageDir -Force | Out-Null

try {
    $targetAppFolder = Join-Path $tempStageDir "AmenoTools"
    New-Item -ItemType Directory -Path $targetAppFolder -Force | Out-Null

    # Copia arquivos essenciais do pacote
    Copy-Item -Path (Join-Path $repoRoot "PackageContents.xml") -Destination $targetAppFolder -Force
    Copy-Item -Path (Join-Path $repoRoot "Contents") -Destination $targetAppFolder -Recurse -Force
    Copy-Item -Path (Join-Path $repoRoot "README.md") -Destination $targetAppFolder -Force
    
    $docsDir = Join-Path $targetAppFolder "docs"
    New-Item -ItemType Directory -Path $docsDir -Force | Out-Null
    Copy-Item -Path (Join-Path $repoRoot "docs\user-guide.md") -Destination $docsDir -Force

    Write-Host "2. Criando arquivo comprimido: $zipFileName..." -ForegroundColor Yellow
    Compress-Archive -Path (Join-Path $targetAppFolder "*") -DestinationPath $zipFilePath -CompressionLevel Optimal

    $zipFile = Get-Item $zipFilePath
    $fileSizeKb = [math]::Round($zipFile.Length / 1KB, 2)
    $hash = (Get-FileHash -Path $zipFilePath -Algorithm SHA256).Hash

    Write-Host "=====================================================" -ForegroundColor Green
    Write-Host "   PACOTE ALPHA GERADO COM SUCESSO!                 " -ForegroundColor Green
    Write-Host "=====================================================" -ForegroundColor Green
    Write-Host "Arquivo:   $zipFilePath" -ForegroundColor White
    Write-Host "Tamanho:   $fileSizeKb KB" -ForegroundColor White
    Write-Host "SHA-256:   $hash" -ForegroundColor White
    Write-Host "`nPara instalar em qualquer estacao com 3ds Max 2026:" -ForegroundColor Yellow
    Write-Host "  Extrair o conteudo do zip em:" -ForegroundColor Gray
    Write-Host "  %APPDATA%\Autodesk\ApplicationPlugins\AmenoTools" -ForegroundColor Cyan
}
finally {
    if (Test-Path $tempStageDir) {
        Remove-Item $tempStageDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}
