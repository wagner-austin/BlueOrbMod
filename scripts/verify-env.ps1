<#
.SYNOPSIS
    Verify the build environment has all prerequisites.

.DESCRIPTION
    Checks for Visual Studio 2022 (or Build Tools), Windows SDK,
    git, and PowerShell 5.1+. Prints what's present and exits 0
    if everything required is found, 1 if anything is missing.

    Requirements (per docs/DEPENDENCIES.md):
      - MSVC v143 toolset (from VS 2022 Community/Pro/Enterprise OR
        VS 2022 Build Tools)
      - Windows 10 SDK 10.0.19041 or newer (we test against 10.0.26100)
      - git on PATH
      - PowerShell 5.1 or newer

.OUTPUTS
    System.Int32. 0 if all required prereqs present, 1 otherwise.

.EXAMPLE
    PS> ./scripts/verify-env.ps1
#>
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$Missing = [System.Collections.Generic.List[string]]::new()

function Step {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string] $Msg)
    Write-Host "==> $Msg" -ForegroundColor Cyan
}
function Ok {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string] $Msg)
    Write-Host "    OK: $Msg" -ForegroundColor Green
}
function Bad {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string] $Msg)
    Write-Host "    MISSING: $Msg" -ForegroundColor Red
    $Missing.Add($Msg)
}

# ---- PowerShell version ----
Step 'PowerShell 5.1+'
if ($PSVersionTable.PSVersion -ge [version]'5.1') {
    Ok "PowerShell $($PSVersionTable.PSVersion)"
} else {
    Bad "PowerShell $($PSVersionTable.PSVersion) (need >= 5.1)"
}

# ---- git ----
Step 'git on PATH'
$git = Get-Command git -ErrorAction SilentlyContinue
if ($git) {
    Ok "git at $($git.Source)"
} else {
    Bad 'git not on PATH'
}

# ---- VS 2022 / Build Tools (vswhere -> MSBuild) ----
Step 'Visual Studio 2022 (Community / Pro / Enterprise / Build Tools)'
$vswhere = 'C:\Program Files (x86)\Microsoft Visual Studio\Installer\vswhere.exe'
if (-not (Test-Path $vswhere)) {
    Bad 'vswhere.exe (install VS 2022 or Build Tools)'
} else {
    $msbuild = & $vswhere -latest -requires Microsoft.Component.MSBuild -find 'MSBuild\**\Bin\MSBuild.exe' | Select-Object -First 1
    if ($msbuild -and (Test-Path $msbuild)) {
        Ok "MSBuild: $msbuild"
    } else {
        Bad 'MSBuild via vswhere (install C++ workload)'
    }

    $v143Found = & $vswhere -latest -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath 2>$null
    if ($v143Found) {
        Ok 'MSVC v143 toolset present'
    } else {
        Bad 'MSVC v143 toolset (component Microsoft.VisualStudio.Component.VC.Tools.x86.x64)'
    }
}

# ---- Windows 10 SDK ----
Step 'Windows 10 SDK >= 10.0.19041'
$sdkRoot = 'C:\Program Files (x86)\Windows Kits\10\Include'
if (Test-Path $sdkRoot) {
    $sdks = Get-ChildItem $sdkRoot -Directory |
        Where-Object { $_.Name -match '^10\.\d+\.\d+\.\d+$' } |
        Sort-Object { [version]$_.Name } -Descending
    if ($sdks -and ([version]$sdks[0].Name) -ge [version]'10.0.19041.0') {
        Ok "Windows SDK $($sdks[0].Name)"
    } else {
        Bad 'Windows 10 SDK >= 10.0.19041'
    }
} else {
    Bad 'Windows 10 SDK directory not found'
}

# ---- Result ----
Write-Host ''
if ($Missing.Count -eq 0) {
    Write-Host 'OK  all prerequisites present' -ForegroundColor Green
    exit 0
} else {
    Write-Host "FAIL  $($Missing.Count) missing prerequisite(s):" -ForegroundColor Red
    foreach ($m in $Missing) { Write-Host "  - $m" -ForegroundColor Red }
    Write-Host ''
    Write-Host 'See docs/BUILDING.md for installation instructions.' -ForegroundColor Yellow
    exit 1
}
