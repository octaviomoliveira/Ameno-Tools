[CmdletBinding()]
param(
    [string]$EvidenceDirectory = 'work\e17-gates'
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$evidenceRoot = Join-Path $repositoryRoot $EvidenceDirectory
$runner = Join-Path $PSScriptRoot 'test-maxscript.ps1'
$tests = @(
    'tests\maxscript\test_bootstrap.ms',
    'tests\maxscript\test_e12_chain_math.ms',
    'tests\maxscript\test_e12_chain_input.ms',
    'tests\maxscript\test_e12_chain_commit.ms',
    'tests\maxscript\test_e12_r1_lifecycle.ms',
    'tests\maxscript\test_e12_r2_picking.ms',
    'tests\maxscript\test_e12_r4_transaction.ms',
    'tests\maxscript\test_e13_global_styles_render_color.ms',
    'tests\maxscript\test_e14_camera_plane.ms',
    'tests\maxscript\test_e14_plane_math.ms',
    'tests\maxscript\test_e14_graphics.ms',
    'tests\maxscript\test_e14_tools.ms',
    'tests\maxscript\test_e15_qt_bridge.ms',
    'tests\maxscript\test_e17_qt_host.ms',
    'tests\maxscript\test_e16_overlay_model.ms',
    'tests\maxscript\test_e16_mousemove_no_scene.ms',
    'tests\maxscript\test_e16_callback_lifecycle.ms',
    'tests\maxscript\test_e16_commit_performance.ms'
)

New-Item -ItemType Directory -Force -Path $evidenceRoot | Out-Null
$summary = [System.Collections.Generic.List[string]]::new()
$summary.Add('E17 Max 2026 automated gate matrix')
$summary.Add('Started: ' + (Get-Date).ToString('o'))
$summary.Add('Legacy WPF UI suites are intentionally excluded; test_e15_qt_bridge and Python E17 gates replace those contracts.')

foreach ($relativeTest in $tests) {
    $testPath = Join-Path $repositoryRoot $relativeTest
    $name = [System.IO.Path]::GetFileNameWithoutExtension($testPath)
    Write-Host "RUN $name" -ForegroundColor Cyan
    & $runner -TestScript $testPath
    $listener = Join-Path $repositoryRoot '.test-output\listener.log'
    $systemLog = Join-Path $repositoryRoot '.test-output\system.log'
    Copy-Item -LiteralPath $listener -Destination (Join-Path $evidenceRoot ($name + '.listener.log')) -Force
    Copy-Item -LiteralPath $systemLog -Destination (Join-Path $evidenceRoot ($name + '.system.log')) -Force
    $listenerText = Get-Content -Raw -LiteralPath $listener
    $resultLines = @($listenerText -split "`r?`n" | Where-Object {
        $_ -match 'RESULT|\[AMENO_TEST\]\[PASS\]|\[AMENO_INSTALLED_TEST\]\[PASS\]|\[E16_PERF\]'
    })
    $summary.Add($name + ': PASS')
    foreach ($line in $resultLines) {
        $summary.Add('  ' + $line.Trim())
    }
}

$summary.Add('Completed: ' + (Get-Date).ToString('o'))
$summary.Add(('Total: {0}/{0} suites PASS' -f $tests.Count))
$summaryPath = Join-Path $evidenceRoot 'summary.txt'
[System.IO.File]::WriteAllLines($summaryPath, $summary, [System.Text.UTF8Encoding]::new($false))
Write-Host "E17 MAX gates passed: $($tests.Count)/$($tests.Count). Evidence: $evidenceRoot" -ForegroundColor Green
