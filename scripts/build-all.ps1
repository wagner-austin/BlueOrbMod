<#
.SYNOPSIS
    Build BlueOrbMod's engine wrapper (DeusExE) and renderer (render11)
    from our forks of Kentie's source.

.DESCRIPTION
    Builds in this order:
      1. DeusExe → produces deusex.exe (renamed BlueOrbMod.exe in installer)
      2. render11 → produces Render11.dll + shader files

    Auto-runs setup.ps1 first if games/DeusEx/ doesn't exist.

    Outputs are also copied by each project's own post-build event
    into the live DX install dir (System/) for in-place testing.

.PARAMETER Configuration
    'Release' (default), 'Debug'. render11 maps these to its
    'Deus Ex Release' / 'Deus Ex Debug' configurations.

.EXAMPLE
    PS> ./scripts/build-all.ps1
#>
[CmdletBinding()]
param(
    [ValidateSet('Release', 'Debug')]
    [string]$Configuration = 'Release'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$Root    = Split-Path -Parent $PSScriptRoot
$DistDir = Join-Path $Root 'dist'

function Step($Msg) { Write-Host "==> $Msg" -ForegroundColor Cyan }
function Ok($Msg)   { Write-Host "    OK: $Msg" -ForegroundColor Green }
function Fail($Msg) { Write-Host "    FAIL: $Msg" -ForegroundColor Red; exit 1 }

# Auto-run setup if needed
if (-not (Test-Path (Join-Path $Root 'games/DeusEx/engine/lib/engine.lib'))) {
    Step 'games/DeusEx/ not populated — running setup.ps1 first'
    & (Join-Path $PSScriptRoot 'setup.ps1')
    if ($LASTEXITCODE -ne 0) { Fail 'setup.ps1 failed' }
}

# Locate MSBuild
$vswhere = 'C:\Program Files (x86)\Microsoft Visual Studio\Installer\vswhere.exe'
$msbuild = & $vswhere -latest -requires Microsoft.Component.MSBuild -find 'MSBuild\**\Bin\MSBuild.exe' | Select-Object -First 1
if (-not $msbuild) { Fail 'MSBuild not found.' }

# --- DeusExe -----------------------------------------------------------
Step "Building DeusExe ($Configuration | Win32)"
$deusExeSln = Join-Path $Root 'DeusExe/DeusExe.sln'
& $msbuild $deusExeSln "-p:Configuration=$Configuration" '-p:Platform=Win32' '-v:minimal' '-m'
if ($LASTEXITCODE -ne 0) { Fail "DeusExe build failed" }

$deusExePath = Join-Path $Root "DeusExe/$Configuration/deusex.exe"
if (-not (Test-Path $deusExePath)) { Fail "deusex.exe missing at $deusExePath" }
Ok "deusex.exe ($([math]::Round((Get-Item $deusExePath).Length / 1KB)) KB)"

# --- render11 ----------------------------------------------------------
$render11Config = "Deus Ex $Configuration"
Step "Building render11 ($render11Config | Win32)"
$render11Sln = Join-Path $Root 'render11/Render11.sln'
& $msbuild $render11Sln "-p:Configuration=$render11Config" '-p:Platform=Win32' '-v:minimal' '-m'
if ($LASTEXITCODE -ne 0) { Fail "render11 build failed" }

$render11DllPath = Join-Path $Root "render11/_work/bin/$render11Config/Render11.dll"
if (-not (Test-Path $render11DllPath)) { Fail "Render11.dll missing at $render11DllPath" }
Ok "Render11.dll ($([math]::Round((Get-Item $render11DllPath).Length / 1KB)) KB)"

# --- Stage outputs to dist/ -------------------------------------------
Step 'Staging outputs to dist/'
if (Test-Path $DistDir) { Remove-Item -Recurse -Force $DistDir }
New-Item -ItemType Directory -Force -Path $DistDir | Out-Null

Copy-Item $deusExePath (Join-Path $DistDir 'deusex.exe')
Copy-Item $render11DllPath (Join-Path $DistDir 'Render11.dll')

# Copy render11 shader files (.hlsl/.hlsli) which the renderer needs at runtime
$render11Pkg = Join-Path $Root "render11/packages/DeusEx/Render11"
if (Test-Path $render11Pkg) {
    New-Item -ItemType Directory -Force -Path (Join-Path $DistDir 'Render11') | Out-Null
    Copy-Item "$render11Pkg/*" (Join-Path $DistDir 'Render11')
}
$render11Int = Join-Path $Root 'render11/Render11/Render11.int'
if (Test-Path $render11Int) { Copy-Item $render11Int $DistDir }

Ok "Outputs in $DistDir"
Get-ChildItem $DistDir -Recurse | Format-Table FullName, Length -AutoSize

Write-Host ''
Write-Host "Build complete. dist/ has the artifacts ready for installer packaging." -ForegroundColor Green
