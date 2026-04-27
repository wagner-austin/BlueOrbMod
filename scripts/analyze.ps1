<#
.SYNOPSIS
    Run cl /analyze static analysis on the C++ forks.

.DESCRIPTION
    Builds DeusExe and render11 with Microsoft's static analysis
    enabled. Surfaces latent bugs (uninitialized memory reads,
    buffer issues, null derefs, etc.) that don't show up in the
    normal compiler warning set.

    Output is captured to dist/analyze-{deusexe,render11}.log for
    review. The script does NOT fail on analyze warnings - they're
    informational findings to triage, not gate gates. To gate on
    them, raise their severity to error in the .vcxproj or filter
    via this script.

    Static analysis IS slow (~2-3x the normal compile time).

.OUTPUTS
    System.Int32. 0 if both forks built cleanly with /analyze;
    1 if either fork failed to build at all.

.EXAMPLE
    PS> ./scripts/analyze.ps1
#>
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$Root        = Split-Path -Parent $PSScriptRoot
$DistDir     = Join-Path $Root 'dist'
New-Item -ItemType Directory -Force -Path $DistDir | Out-Null

function Step {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string] $Msg)
    Write-Host "==> $Msg" -ForegroundColor Cyan
}

# Locate MSBuild via vswhere.
$vswhere = 'C:\Program Files (x86)\Microsoft Visual Studio\Installer\vswhere.exe'
if (-not (Test-Path $vswhere)) {
    Write-Host 'vswhere.exe not found. Install VS 2022 or Build Tools.' -ForegroundColor Red
    exit 1
}
$msbuild = & $vswhere -latest -requires Microsoft.Component.MSBuild -find 'MSBuild\**\Bin\MSBuild.exe' | Select-Object -First 1
if (-not $msbuild) {
    Write-Host 'MSBuild not located via vswhere.' -ForegroundColor Red
    exit 1
}

$forks = @(
    @{
        Name          = 'DeusExe'
        Sln           = Join-Path $Root 'DeusExe/DeusExe.sln'
        Configuration = 'Release'
        LogPath       = Join-Path $DistDir 'analyze-deusexe.log'
    },
    @{
        Name          = 'render11'
        Sln           = Join-Path $Root 'render11/Render11.sln'
        Configuration = 'Deus Ex Release'
        LogPath       = Join-Path $DistDir 'analyze-render11.log'
    }
)

$failed = $false
foreach ($f in $forks) {
    Step "Static analysis: $($f.Name) ($($f.Configuration) | Win32)"

    & $msbuild $f.Sln `
        "-p:Configuration=$($f.Configuration)" `
        '-p:Platform=Win32' `
        '-p:EnablePREfast=true' `
        '-p:RunCodeAnalysis=true' `
        '-v:minimal' `
        '-m' `
        "-fl" `
        "-flp:logfile=$($f.LogPath);verbosity=normal"

    if ($LASTEXITCODE -ne 0) {
        Write-Host "    FAIL: $($f.Name) build failed under /analyze" -ForegroundColor Red
        $failed = $true
        continue
    }

    # Count C6xxx warnings (PREfast = C6000-C6999 range)
    $analyzeWarnings = (Select-String -Path $f.LogPath -Pattern 'warning C6\d{3}' -ErrorAction SilentlyContinue) | Measure-Object | Select-Object -ExpandProperty Count
    Write-Host "    OK $($f.Name): $analyzeWarnings static-analysis finding(s) in $($f.LogPath)"
}

if ($failed) {
    Write-Host ''
    Write-Host 'FAIL  one or more forks did not build under /analyze' -ForegroundColor Red
    exit 1
}

Write-Host ''
Write-Host 'OK  static analysis complete (review dist/analyze-*.log for findings)' -ForegroundColor Green
exit 0
