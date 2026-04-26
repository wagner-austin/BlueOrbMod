<#
.SYNOPSIS
    Set up the BlueOrbMod build environment from a clean checkout.

.DESCRIPTION
    1. Verifies prerequisites (Visual Studio 2022, Windows SDK, git).
    2. Downloads the Deus Ex SDK 1.112fm (Square Enix / Ion Storm, 2000)
       from deusexnetwork.com and verifies its MD5 hash.
    3. Maps SDK contents into games/DeusEx/{engine,core,...}/{inc,lib}/
       to match the layout the forked DeusExE / render11 projects expect.
    4. Applies modernization patches from patches/ so the SDK headers
       compile cleanly under modern MSVC. Each patch's purpose is
       documented in the patch header.
    5. Clones/updates Microsoft Detours into detours/.

    SDK content (Square Enix IP) is downloaded fresh on every clean
    setup; we never redistribute the binary in our git history.

.PARAMETER Force
    Re-extract SDK and re-apply patches even if games/DeusEx/ already
    exists. Useful after pulling new patches.

.EXAMPLE
    PS> ./scripts/setup.ps1
#>
[CmdletBinding()]
param(
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$Root         = Split-Path -Parent $PSScriptRoot
$SdkUrl       = 'https://download.deusexnetwork.com/20/DeusExSDK1112f.exe'
$SdkExpectMd5 = '1d7560c513f945b607ee96cd2f9aec57'
$SdkCachePath = Join-Path $Root '_sdk_cache/DeusExSDK1112f.exe'
$SdkExtract   = Join-Path $Root '_sdk_extract'
$GamesDir     = Join-Path $Root 'games/DeusEx'
$PatchesDir   = Join-Path $Root 'patches'

function Step($Msg) { Write-Host "==> $Msg" -ForegroundColor Cyan }
function Ok($Msg)   { Write-Host "    OK: $Msg" -ForegroundColor Green }
function Warn($Msg) { Write-Host "    WARN: $Msg" -ForegroundColor Yellow }
function Fail($Msg) { Write-Host "    FAIL: $Msg" -ForegroundColor Red; exit 1 }

# --- Step 1: prerequisites ------------------------------------------------
Step 'Verifying prerequisites'

$vswhere = 'C:\Program Files (x86)\Microsoft Visual Studio\Installer\vswhere.exe'
if (-not (Test-Path $vswhere)) { Fail 'Visual Studio 2022 installer not found. Install VS 2022 with the "Desktop development with C++" workload.' }
$msbuild = & $vswhere -latest -requires Microsoft.Component.MSBuild -find 'MSBuild\**\Bin\MSBuild.exe' | Select-Object -First 1
if (-not $msbuild -or -not (Test-Path $msbuild)) { Fail 'MSBuild not found via vswhere. Install VS 2022 C++ workload.' }
Ok "MSBuild: $msbuild"

$sdkRoot = 'C:\Program Files (x86)\Windows Kits\10\Include'
if (-not (Test-Path $sdkRoot)) { Fail 'Windows 10 SDK not found.' }
$sdks = Get-ChildItem $sdkRoot -Directory | Sort-Object { [version]$_.Name } -Descending
if (-not $sdks) { Fail 'No Windows 10 SDK versions installed.' }
Ok "Windows SDK: $($sdks[0].Name)"

if (-not (Get-Command git -ErrorAction SilentlyContinue)) { Fail 'git not on PATH.' }
Ok 'git available'

# --- Step 2: download SDK -------------------------------------------------
Step 'Acquiring Deus Ex SDK 1.112fm'

if (-not (Test-Path $SdkCachePath) -or $Force) {
    New-Item -ItemType Directory -Force -Path (Split-Path $SdkCachePath) | Out-Null
    Write-Host "    Downloading from $SdkUrl..."
    Invoke-WebRequest -Uri $SdkUrl -OutFile $SdkCachePath -UseBasicParsing
}
$actualMd5 = (Get-FileHash -Algorithm MD5 -Path $SdkCachePath).Hash.ToLower()
if ($actualMd5 -ne $SdkExpectMd5) {
    Fail "SDK MD5 mismatch. Expected $SdkExpectMd5, got $actualMd5. Delete _sdk_cache/ and retry."
}
Ok "SDK MD5 verified: $actualMd5"

# --- Step 3: extract + map ------------------------------------------------
Step 'Extracting and mapping SDK contents'

if ((Test-Path $GamesDir) -and -not $Force) {
    Ok 'games/DeusEx already populated (use -Force to redo)'
} else {
    if (Test-Path $SdkExtract) { Remove-Item -Recurse -Force $SdkExtract }
    if (Test-Path $GamesDir)   { Remove-Item -Recurse -Force $GamesDir }
    New-Item -ItemType Directory -Force -Path $SdkExtract | Out-Null

    # The SDK .exe is a WinZip self-extractor — rename to .zip and unzip.
    $sdkZip = Join-Path $SdkExtract 'DeusExSDK1112f.zip'
    Copy-Item $SdkCachePath $sdkZip
    Expand-Archive -Path $sdkZip -DestinationPath $SdkExtract -Force

    # Inside ReleaseSDK1112f/Headers/ are two zips: DXLibs.zip + DxHeaders.zip
    $headersDir = Join-Path $SdkExtract 'ReleaseSDK1112f/Headers'
    Expand-Archive -Path (Join-Path $headersDir 'DXLibs.zip')   -DestinationPath (Join-Path $SdkExtract 'DXLibs')   -Force
    Expand-Archive -Path (Join-Path $headersDir 'DxHeaders.zip') -DestinationPath (Join-Path $SdkExtract 'DxHeaders') -Force

    # Map per-package: copy <Package>/Inc/ -> games/DeusEx/<lower>/inc/, lib stub -> games/DeusEx/<lower>/lib/
    $packages = @('Engine', 'Core', 'Extension', 'Window', 'DeusEx', 'Render')
    foreach ($pkg in $packages) {
        $lower = $pkg.ToLower()
        $destInc = Join-Path $GamesDir "$lower/inc"
        $destLib = Join-Path $GamesDir "$lower/lib"
        New-Item -ItemType Directory -Force -Path $destInc, $destLib | Out-Null

        # Render package's "headers" live in Src/ in the SDK (private headers)
        $srcInc = if ($pkg -eq 'Render') {
            Join-Path $SdkExtract "DxHeaders/$pkg/Src"
        } else {
            Join-Path $SdkExtract "DxHeaders/$pkg/Inc"
        }
        if (Test-Path $srcInc) { Copy-Item -Recurse -Force "$srcInc/*" $destInc }

        $srcLib = Join-Path $SdkExtract "DXLibs/$pkg.lib"
        if (Test-Path $srcLib) { Copy-Item -Force $srcLib (Join-Path $destLib "$lower.lib") }
    }

    # Window.h includes "..\Src\Res\WindowRes.h" — preserve that path.
    $winRes = Join-Path $SdkExtract 'DxHeaders/Window/Src/Res'
    if (Test-Path $winRes) {
        $destRes = Join-Path $GamesDir 'window/Src/Res'
        New-Item -ItemType Directory -Force -Path $destRes | Out-Null
        Copy-Item -Recurse -Force "$winRes/*" $destRes
    }
    Ok 'SDK content mapped into games/DeusEx/'
}

# --- Step 4: apply patches ------------------------------------------------
Step 'Applying SDK modernization patches'

Push-Location $GamesDir
try {
    # Use git apply (no actual git repo needed; --unsafe-paths if outside repo).
    $patchFiles = Get-ChildItem $PatchesDir -Filter '*.patch' | Sort-Object Name
    foreach ($p in $patchFiles) {
        Write-Host "    Applying $($p.Name)"
        $check = & git apply --check $p.FullName 2>&1
        if ($LASTEXITCODE -ne 0) {
            # Already applied? Test reverse-apply check.
            & git apply --reverse --check $p.FullName 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) {
                Warn "$($p.Name) already applied, skipping"
                continue
            }
            Fail "Patch $($p.Name) failed --check: $check"
        }
        & git apply $p.FullName
        if ($LASTEXITCODE -ne 0) { Fail "Patch $($p.Name) failed to apply" }
    }
    Ok "$($patchFiles.Count) patch(es) applied"
} finally {
    Pop-Location
}

Write-Host ''
Write-Host 'Setup complete. Next: ./scripts/build-all.ps1' -ForegroundColor Green
# Note: Microsoft Detours is no longer needed. Kentie's launcher.props
# referenced "../detours" historically, but his v7 (2015) changelog
# removed the Detours dependency ("Added free disk space fix that
# doesn't require detoured.dll"). Verified zero references in current
# source. The include path has been trimmed from our fork's
# launcher.props.
