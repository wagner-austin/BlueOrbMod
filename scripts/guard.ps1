<#
.SYNOPSIS
    Enforce project rules across the workspace. Prevents drift.

.DESCRIPTION
    Runs a set of checks that aren't easily covered by linters but
    matter for code health. Fails (exit 1) on any violation. Each
    rule corresponds to an entry in docs/STANDARDS.md.

    Rules enforced:
      1. No 'TODO' / 'FIXME' / 'HACK' / 'XXX' markers without a tracked
         issue reference. Format must be 'TODO(#NN): description'.
      2. Every suppression in launcher.props / Render DLL.props is
         documented in docs/PATCHES.md (suppressions without a docs
         entry are forbidden -- see STANDARDS.md "When standards
         conflict with reality").
      3. Every patch in patches/ applies cleanly to the populated
         games/DeusEx/ tree, OR is already applied (reverse-applies
         cleanly). Drift in either direction fails the guard.
      4. Every PowerShell script under scripts/ has comment-based help
         with .SYNOPSIS and .DESCRIPTION.
      5. Every internal Markdown link in docs/ resolves.
      6. No 'best-effort' / 'best effort' phrasing in code, comments,
         or docstrings (per STANDARDS.md).

.OUTPUTS
    System.Int32. 0 on success, 1 on any violation.

.EXAMPLE
    PS> ./scripts/guard.ps1
    Runs all rules. Prints a report. Exit code 0 if clean.
#>
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$Root        = Split-Path -Parent $PSScriptRoot
$Violations  = [System.Collections.Generic.List[string]]::new()

# Files that DEFINE rules naturally mention their forbidden tokens.
# Tests for the rules also legitimately contain those tokens as
# fixtures. Both are excluded from rules that scan for those tokens.
$RuleSelfExclude = @(
    'docs/STANDARDS.md',
    'scripts/guard.ps1',
    'tests/Guard.Tests.ps1'
)

# Path-segment fragments that mark vendored / external content. Files
# under any of these paths are skipped by every scanning rule. Third-
# party content (.tools/Modules/* PSGallery modules, vendored SDK
# trees) is not ours to lint.
$ExternalPaths = @(
    '\.tools\',
    '\DeusExe\',
    '\render11\',
    '\games\',
    '\_sdk_extract\',
    '\_sdk_cache\',
    '\detours\',
    '\dist\'
)

function Add-Violation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $Rule,
        [Parameter(Mandatory)][string] $Message
    )
    $Violations.Add("[$Rule] $Message")
}

function Step {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string] $Msg)
    Write-Host "==> $Msg" -ForegroundColor Cyan
}

# ---- Rule 1: untracked TODO/FIXME/HACK/XXX markers ----
Step 'Rule 1: TODO/FIXME/HACK/XXX must reference a tracked issue'
$markerPattern = '\b(TODO|FIXME|HACK|XXX)\b(?!\(#\d+\))'
$scanRoots = @('scripts', 'tools', 'tests', 'docs', '.github', 'patches', 'Makefile', 'README.md')
foreach ($p in $scanRoots) {
    $full = Join-Path $Root $p
    if (-not (Test-Path $full)) { continue }
    $files = if ((Get-Item $full).PSIsContainer) {
        Get-ChildItem -Path $full -Recurse -File `
            -Include '*.ps1','*.psd1','*.psm1','*.md','*.yml','*.yaml','*.patch','*.cmd','Makefile' `
            -ErrorAction SilentlyContinue
    } else {
        Get-Item -Path $full
    }
    foreach ($f in $files) {
        $rel = $f.FullName.Substring($Root.Length + 1).Replace('\', '/')
        if ($RuleSelfExclude -contains $rel) { continue }
        $content = Get-Content -Path $f.FullName -Raw -ErrorAction Stop
        $found = [regex]::Matches($content, $markerPattern)
        foreach ($m in $found) {
            $line = ($content.Substring(0, $m.Index) -split "`n").Count
            Add-Violation -Rule 'Rule1' -Message "${rel}:${line} unscoped marker '$($m.Value)'. Use 'TODO(#NN): description' or remove."
        }
    }
}

# ---- Rule 2: every props suppression has a PATCHES.md / DEPENDENCIES.md entry ----
Step 'Rule 2: every C++ suppression has a docs explanation'
$patchesContent      = Get-Content -Path (Join-Path $Root 'docs/PATCHES.md') -Raw
$dependenciesContent = Get-Content -Path (Join-Path $Root 'docs/DEPENDENCIES.md') -Raw
$docsContent         = $patchesContent + "`n" + $dependenciesContent

$propsFiles = @(
    'DeusExe/launcher.props',
    'render11/Render DLL.props'
)
$suppressionTokens = @(
    'StructMemberAlignment',
    'TreatWChar_tAsBuiltInType',
    'WINDOWS_IGNORE_PACKING_MISMATCH',
    'DisableSpecificWarnings'
)
foreach ($pp in $propsFiles) {
    $full = Join-Path $Root $pp
    if (-not (Test-Path $full)) { continue }
    $propsRaw = Get-Content -Path $full -Raw
    foreach ($token in $suppressionTokens) {
        if ($propsRaw -match $token) {
            if ($docsContent -notmatch $token) {
                Add-Violation -Rule 'Rule2' -Message "${pp} uses '$token' but no entry in docs/PATCHES.md or docs/DEPENDENCIES.md explains why."
            }
        }
    }
}

# ---- Rule 3: every patches/*.patch applies (or is already applied) ----
Step 'Rule 3: patches in patches/ apply cleanly'
$gamesDir   = Join-Path $Root 'games/DeusEx'
$patchFiles = Get-ChildItem -Path (Join-Path $Root 'patches') -Filter '*.patch' -ErrorAction SilentlyContinue | Sort-Object Name
if (-not (Test-Path $gamesDir)) {
    Write-Host '    skip - games/DeusEx not populated; run scripts/setup.ps1 first' -ForegroundColor Yellow
} else {
    Push-Location $gamesDir
    try {
        # Scope $ErrorActionPreference locally: git writing to stderr is
        # how it signals "patch already applied" - we read it via exit code,
        # so PS5.1's NativeCommandError wrapping must not propagate.
        $prevEAP = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        try {
            foreach ($p in $patchFiles) {
                & git apply --check $p.FullName 2>&1 | Out-Null
                $forwardOk = $LASTEXITCODE -eq 0
                & git apply --reverse --check $p.FullName 2>&1 | Out-Null
                $reverseOk = $LASTEXITCODE -eq 0
                if (-not $forwardOk -and -not $reverseOk) {
                    Add-Violation -Rule 'Rule3' -Message "patches/$($p.Name) does not apply forward AND does not reverse - drift between patch and SDK."
                }
            }
        } finally {
            $ErrorActionPreference = $prevEAP
        }
    } finally {
        Pop-Location
    }
}

# ---- Rule 4: every scripts/*.ps1 has comment-based help ----
Step 'Rule 4: every script has .SYNOPSIS and .DESCRIPTION'
$scriptFiles = Get-ChildItem -Path (Join-Path $Root 'scripts') -Filter '*.ps1' -ErrorAction SilentlyContinue
foreach ($s in $scriptFiles) {
    $sRaw = Get-Content -Path $s.FullName -Raw
    if ($sRaw -notmatch '\.SYNOPSIS') {
        Add-Violation -Rule 'Rule4' -Message "scripts/$($s.Name) missing .SYNOPSIS in comment-based help."
    }
    if ($sRaw -notmatch '\.DESCRIPTION') {
        Add-Violation -Rule 'Rule4' -Message "scripts/$($s.Name) missing .DESCRIPTION in comment-based help."
    }
}

# ---- Rule 5: internal markdown links resolve ----
Step 'Rule 5: internal markdown links resolve'
$externalRegex = '(' + (($ExternalPaths | ForEach-Object { [regex]::Escape($_) }) -join '|') + ')'
$mdFiles = Get-ChildItem -Path $Root -Recurse -Filter '*.md' -File `
    | Where-Object { $_.FullName -notmatch $externalRegex }
foreach ($md in $mdFiles) {
    $content = Get-Content -Path $md.FullName -Raw
    # match ](relative/path.md) or ](relative/path.md#anchor)
    $linkMatches = [regex]::Matches($content, '\]\(([^)]+\.md)(?:#[^)]*)?\)')
    foreach ($m in $linkMatches) {
        $target = $m.Groups[1].Value
        # Skip absolute URLs and anchor-only links
        if ($target -match '^https?://' -or $target.StartsWith('#')) { continue }
        $resolved = Join-Path (Split-Path $md.FullName -Parent) $target
        if (-not (Test-Path $resolved)) {
            $rel = $md.FullName.Substring($Root.Length + 1)
            Add-Violation -Rule 'Rule5' -Message "${rel}: broken internal link to '$target'."
        }
    }
}

# ---- Rule 6: no best-effort phrasing in code/docs (excluding the rule definition itself) ----
Step 'Rule 6: no best-effort phrasing in code/docs'
$bestEffortFiles = Get-ChildItem -Path $Root -Recurse -File `
    -Include '*.ps1','*.psd1','*.psm1','*.md','*.yml','*.yaml','*.cpp','*.h','*.cs' `
    -ErrorAction SilentlyContinue `
    | Where-Object { $_.FullName -notmatch $externalRegex }
foreach ($f in $bestEffortFiles) {
    $rel = $f.FullName.Substring($Root.Length + 1).Replace('\', '/')
    if ($RuleSelfExclude -contains $rel) { continue }
    $content = Get-Content -Path $f.FullName -Raw
    if ($content -match '(?i)best[\s-]effort') {
        Add-Violation -Rule 'Rule6' -Message ("{0}: contains best-effort phrasing. APIs declare failure modes; core logic does not soften failures." -f $rel)
    }
}

# ---- Report ----
Write-Host ''
if ($Violations.Count -eq 0) {
    Write-Host "OK  guard passed (6 rules, 0 violations)" -ForegroundColor Green
    exit 0
} else {
    Write-Host "FAIL  guard found $($Violations.Count) violation(s):" -ForegroundColor Red
    foreach ($v in $Violations) {
        Write-Host "  - $v" -ForegroundColor Red
    }
    Write-Host ''
    Write-Host 'See docs/STANDARDS.md for the full rule definitions.' -ForegroundColor Yellow
    exit 1
}
