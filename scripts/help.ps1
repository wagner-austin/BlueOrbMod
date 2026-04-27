<#
.SYNOPSIS
    Print the make-target reference for the BlueOrbMod workspace.

.DESCRIPTION
    Invoked by `make help`. Single source of truth for the user-facing
    description of each make target. Lives as a separate script (not
    inline in the Makefile) because Make's recipe quoting + PowerShell
    line-continuation don't compose cleanly on Windows.

.OUTPUTS
    None. Writes to host.

.EXAMPLE
    PS> make help
#>
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Write-Host ''
Write-Host 'BlueOrbMod workspace - make targets' -ForegroundColor Cyan
Write-Host ''
Write-Host '  check         lint + guard + build + test (the gate before commit)'
Write-Host '  ci            everything + coverage + analyze (what CI runs)'
Write-Host '  ci-fast       lint + guard only (quick local feedback)'
Write-Host ''
Write-Host '  lint          PSScriptAnalyzer on scripts/ + tests/'
Write-Host '  guard         scripts/guard.ps1 - enforces project rules'
Write-Host '  build         scripts/build-all.ps1 - compile DeusExE + render11'
Write-Host '  test          Pester tests in tests/'
Write-Host '  coverage      Pester with statement coverage report'
Write-Host '  analyze       cl /analyze static-analysis pass on the C++ forks'
Write-Host ''
Write-Host '  setup         scripts/setup.ps1 - bootstrap SDK + patches'
Write-Host '  verify-env    check VS 2022, Windows SDK, git are installed'
Write-Host '  install-tools install required PSGallery modules into .tools/Modules'
Write-Host ''
Write-Host '  clean         remove build outputs (keeps SDK cache + tools)'
Write-Host ''
