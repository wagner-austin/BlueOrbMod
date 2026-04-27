<#
.SYNOPSIS
    Install PSGallery modules into a workspace-local .tools/Modules.

.DESCRIPTION
    Idempotent. Saves Pester and PSScriptAnalyzer to .tools/Modules
    inside the workspace, NOT to $env:USERPROFILE\Documents (which on
    OneDrive-synced machines is redirected to a path that breaks
    Install-Module's directory-create assumptions).

    The other scripts (lint.ps1, test.ps1, guard.ps1) prepend
    .tools/Modules to $env:PSModulePath before importing, so they
    pick up the local copy automatically.

    Versions are pinned via the script. Bump deliberately.

.OUTPUTS
    None. Prints what was installed.

.EXAMPLE
    PS> ./scripts/install-tools.ps1
#>
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$Root        = Split-Path -Parent $PSScriptRoot
$ToolsRoot   = Join-Path $Root '.tools/Modules'

$RequiredModules = @(
    @{ Name = 'Pester';            MinimumVersion = '5.5.0' },
    @{ Name = 'PSScriptAnalyzer';  MinimumVersion = '1.21.0' }
)

function Step {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string] $Msg)
    Write-Host "==> $Msg" -ForegroundColor Cyan
}

# Bootstrap NuGet provider non-interactively (needed for Save-Module).
$nuget = Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue
if (-not $nuget -or $nuget.Version -lt [version]'2.8.5.201') {
    Step 'Installing NuGet package provider (>= 2.8.5.201, CurrentUser)'
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Scope CurrentUser | Out-Null
}

# Ensure PSGallery is registered + trusted.
$psg = Get-PSRepository -Name 'PSGallery' -ErrorAction SilentlyContinue
if (-not $psg) {
    Step 'Registering PSGallery'
    Register-PSRepository -Default
    $psg = Get-PSRepository -Name 'PSGallery'
}
if ($psg.InstallationPolicy -ne 'Trusted') {
    Step 'Trusting PSGallery (CurrentUser)'
    Set-PSRepository -Name 'PSGallery' -InstallationPolicy Trusted
}

# Ensure local tools dir exists.
if (-not (Test-Path $ToolsRoot)) {
    New-Item -ItemType Directory -Force -Path $ToolsRoot | Out-Null
}

foreach ($spec in $RequiredModules) {
    $name = $spec.Name
    $minV = [version]$spec.MinimumVersion

    # Check if already saved at >= required version.
    $modulePath = Join-Path $ToolsRoot $name
    $existingVersion = $null
    if (Test-Path $modulePath) {
        $versionDirs = Get-ChildItem $modulePath -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -match '^\d+(\.\d+){1,3}$' } |
            Sort-Object { [version]$_.Name } -Descending
        if ($versionDirs) {
            $existingVersion = [version]$versionDirs[0].Name
        }
    }

    if ($existingVersion -and $existingVersion -ge $minV) {
        Write-Host "    OK $name $existingVersion >= $minV (in .tools/Modules)"
        continue
    }

    Step "Saving $name >= $minV to .tools/Modules"
    Save-Module -Name $name -MinimumVersion $minV -Path $ToolsRoot -Force
    Write-Host "    saved"
}

Write-Host ''
Write-Host 'OK  tools installed in .tools/Modules' -ForegroundColor Green
