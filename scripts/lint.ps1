<#
.SYNOPSIS
    Lint all scripts and config files in the workspace.

.DESCRIPTION
    Runs PSScriptAnalyzer with our strict settings against scripts/
    and tests/. Errors fail the lint; warnings fail the lint
    (we treat them as errors).

    Settings file: tools/PSScriptAnalyzerSettings.psd1

    Future: actionlint for .github/workflows, markdownlint for docs/
    (added when we lock dependency choices for those).

.OUTPUTS
    System.Int32. 0 if no findings, 1 if any.

.EXAMPLE
    PS> ./scripts/lint.ps1
#>
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$Root         = Split-Path -Parent $PSScriptRoot
$SettingsPath = Join-Path $Root 'tools/PSScriptAnalyzerSettings.psd1'
$LocalModules = Join-Path $Root '.tools/Modules'

function Step {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string] $Msg)
    Write-Host "==> $Msg" -ForegroundColor Cyan
}

# Prepend our workspace-local modules dir so Import-Module picks it up
# before any system-wide module of the same name (Pester 3.x ships with
# Windows; we need 5.x here).
if (Test-Path $LocalModules) {
    $env:PSModulePath = "$LocalModules;$env:PSModulePath"
}

if (-not (Get-Module -ListAvailable -Name PSScriptAnalyzer)) {
    Write-Host 'PSScriptAnalyzer not installed. Run scripts/install-tools.ps1 first.' -ForegroundColor Red
    exit 1
}
Import-Module PSScriptAnalyzer -ErrorAction Stop

if (-not (Test-Path $SettingsPath)) {
    Write-Host "Settings file missing: $SettingsPath" -ForegroundColor Red
    exit 1
}

$paths = @(
    (Join-Path $Root 'scripts'),
    (Join-Path $Root 'tests')
) | Where-Object { Test-Path $_ }

$allFindings = [System.Collections.Generic.List[object]]::new()
foreach ($p in $paths) {
    Step "PSScriptAnalyzer on $($p.Substring($Root.Length + 1))"
    $findings = Invoke-ScriptAnalyzer -Path $p -Recurse -Settings $SettingsPath
    foreach ($f in $findings) { $allFindings.Add($f) }
}

# Errors fail the build. Warnings/Information print but don't fail —
# they're cosmetic/style hints (PSPlaceCloseBrace, etc.) and are
# tracked separately. Real correctness rules in PSSA are at Error
# severity; project-specific correctness rules live in guard.ps1.
$errors   = @($allFindings | Where-Object { $_.Severity -eq 'Error' })
$warnings = @($allFindings | Where-Object { $_.Severity -eq 'Warning' })
$infos    = @($allFindings | Where-Object { $_.Severity -eq 'Information' })

if ($warnings.Count -gt 0) {
    Write-Host ''
    Write-Host "    $($warnings.Count) style warning(s) (informational, do not fail lint):" -ForegroundColor DarkYellow
    foreach ($f in $warnings) {
        $rel = $f.ScriptPath.Substring($Root.Length + 1).Replace('\', '/')
        Write-Host ("      {0}:{1} ({2}) {3}" -f $rel, $f.Line, $f.RuleName, $f.Message) -ForegroundColor DarkGray
    }
}

if ($errors.Count -eq 0) {
    Write-Host ''
    Write-Host "OK  lint passed ($($warnings.Count) warning(s), 0 error(s))" -ForegroundColor Green
    exit 0
}

Write-Host ''
Write-Host "FAIL  $($errors.Count) lint error(s):" -ForegroundColor Red
foreach ($f in $errors) {
    $rel = $f.ScriptPath.Substring($Root.Length + 1).Replace('\', '/')
    Write-Host ("  {0}:{1} ({2}) {3}" -f $rel, $f.Line, $f.RuleName, $f.Message) -ForegroundColor Red
}
exit 1
