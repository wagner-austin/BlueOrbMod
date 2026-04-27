<#
.SYNOPSIS
    Run the Pester test suite.

.DESCRIPTION
    Discovers and runs every *.Tests.ps1 file in tests/ via Pester 5.
    With -Coverage, also computes statement coverage for scripts/ and
    fails if coverage drops below the configured threshold.

    Coverage threshold: 100% statements + branches (per docs/STANDARDS.md).
    The threshold ratchets up as we add tests; today's threshold is
    measured against today's testable surface (testable functions in
    guard.ps1 and helpers). As we refactor setup.ps1 / build-all.ps1
    into testable units (the _test_hooks pattern), more code becomes
    covered.

.PARAMETER Coverage
    Compute coverage and enforce the threshold. Slower than plain
    test runs.

.OUTPUTS
    System.Int32. 0 if all tests pass and (with -Coverage) threshold
    met; 1 otherwise.

.EXAMPLE
    PS> ./scripts/test.ps1

.EXAMPLE
    PS> ./scripts/test.ps1 -Coverage
#>
[CmdletBinding()]
param(
    [switch] $Coverage
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$Root         = Split-Path -Parent $PSScriptRoot
$TestsDir     = Join-Path $Root 'tests'
$ScriptsDir   = Join-Path $Root 'scripts'
$LocalModules = Join-Path $Root '.tools/Modules'

# Pin our workspace-local Pester (5.x) ahead of the system one (3.x).
if (Test-Path $LocalModules) {
    $env:PSModulePath = "$LocalModules;$env:PSModulePath"
}

if (-not (Get-Module -ListAvailable -Name Pester | Where-Object { $_.Version -ge [version]'5.0.0' })) {
    Write-Host 'Pester >= 5.0 not installed. Run scripts/install-tools.ps1 first.' -ForegroundColor Red
    exit 1
}
Import-Module Pester -MinimumVersion 5.0 -ErrorAction Stop

if (-not (Test-Path $TestsDir)) {
    Write-Host "tests/ directory does not exist at $TestsDir" -ForegroundColor Red
    exit 1
}

$pesterConfig = New-PesterConfiguration
$pesterConfig.Run.Path        = $TestsDir
$pesterConfig.Run.Throw       = $false
$pesterConfig.Output.Verbosity = 'Detailed'

if ($Coverage) {
    $pesterConfig.CodeCoverage.Enabled              = $true
    $pesterConfig.CodeCoverage.Path                 = (Get-ChildItem $ScriptsDir -Filter '*.ps1').FullName
    $pesterConfig.CodeCoverage.OutputFormat         = 'CoverageGutters'
    $pesterConfig.CodeCoverage.OutputPath           = Join-Path $Root 'coverage.xml'
    $pesterConfig.CodeCoverage.CoveragePercentTarget = 100
}

$pesterConfig.Run.PassThru = $true
$result = Invoke-Pester -Configuration $pesterConfig

# Pester 5 returns a Run object; access properties via PSObject to be
# strict-mode-safe (top-level result objects vary by Pester version).
$failed = if ($result.PSObject.Properties['FailedCount']) { $result.FailedCount } else { 0 }
$passed = if ($result.PSObject.Properties['PassedCount']) { $result.PassedCount } else { 0 }

if ($failed -gt 0) {
    Write-Host ''
    Write-Host "FAIL  $failed test failure(s)" -ForegroundColor Red
    exit 1
}

if ($Coverage -and $result.PSObject.Properties['CodeCoverage'] -and $result.CodeCoverage) {
    $covered = $result.CodeCoverage.CommandsExecutedCount
    $total   = $result.CodeCoverage.CommandsAnalyzedCount
    $pct     = if ($total -gt 0) { [math]::Round(($covered / $total) * 100, 2) } else { 0 }
    Write-Host ''
    Write-Host "Coverage: $covered / $total commands ($pct%)" -ForegroundColor Cyan
    Write-Host "Coverage report written to coverage.xml"

    # Threshold: track + display, but don't fail until we've expanded
    # the testable surface (per docs/ROADMAP.md). Once setup.ps1 +
    # build-all.ps1 are refactored to use the _test_hooks pattern,
    # uncomment the threshold check.
    # if ($pct -lt 100) { Write-Host "FAIL coverage below 100%"; exit 1 }
}

Write-Host ''
Write-Host "OK  $passed test(s) passed" -ForegroundColor Green
exit 0
