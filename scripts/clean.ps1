<#
.SYNOPSIS
    Remove build outputs and intermediate files.

.DESCRIPTION
    Cleans:
      - dist/                       (staged install artifacts)
      - DeusExe/Release, _work/     (DeusExE build artifacts)
      - render11/_work, packages/   (render11 build artifacts)
      - DeusExe/build.log, render11/build.log (last build logs)
      - coverage.xml                (last coverage run)

    Preserves:
      - _sdk_cache/, _sdk_extract/, games/  (SDK content; re-downloading
        would burn network for no reason)
      - .tools/                     (PSGallery modules, dev tooling)
      - patches/                    (versioned, never auto-removed)

    To wipe SDK + tools too, do it manually:
      Remove-Item -Recurse _sdk_cache, _sdk_extract, games, .tools

.OUTPUTS
    None. Prints what was removed.

.EXAMPLE
    PS> ./scripts/clean.ps1
#>
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$Root = Split-Path -Parent $PSScriptRoot

$paths = @(
    'dist',
    'DeusExe/Release',
    'DeusExe/_work',
    'DeusExe/build.log',
    'render11/_work',
    'render11/packages',
    'render11/build.log',
    'coverage.xml'
)

$removed = 0
foreach ($p in $paths) {
    $full = Join-Path $Root $p
    if (Test-Path $full) {
        Remove-Item -Recurse -Force -Path $full
        Write-Host "  removed $p"
        $removed++
    }
}

Write-Host ''
Write-Host "OK  clean ($removed item(s) removed; SDK + tools preserved)" -ForegroundColor Green
