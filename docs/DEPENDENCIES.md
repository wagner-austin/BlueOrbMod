# Dependencies

Every external thing the build, runtime, or development workflow
relies on, and how we pin / verify it.

We don't use a package manager (no NuGet/vcpkg/Conan/Poetry) for the
C++ projects — they only need the Windows SDK and the Deus Ex SDK,
both handled directly. The future WPF launcher will use NuGet.

## Build-time dependencies (developer machine)

These must exist on the host running `setup.ps1` + `build-all.ps1`.

| Dep | Version | Pinned how | Verified how |
|---|---|---|---|
| Windows | 10 / 11 | n/a | OS check |
| MSVC toolset | **v143** (VS 2022) | `<PlatformToolset>v143</PlatformToolset>` in `DeusExe/DeusExe.vcxproj` and `render11/Render11/Render11.vcxproj` | MSBuild errors if v143 not installed |
| Windows SDK | **10.0.26100.0** | `<WindowsTargetPlatformVersion>10.0.26100.0</WindowsTargetPlatformVersion>` in both vcxproj files | MSBuild errors if SDK missing |
| MSBuild | from VS 2022 (any flavor) | Located via `vswhere.exe` in `setup.ps1` | Setup verifies + reports path |
| git | any modern | n/a | Setup verifies on PATH |
| PowerShell | 5.1+ | ships with Win10+ | Setup runs as PS scripts |

### Visual Studio: full IDE OR Build Tools

Both work. `vswhere.exe -latest -requires Microsoft.Component.MSBuild`
finds either:

| Edition | Source | Disk |
|---|---|---|
| Visual Studio 2022 Community/Pro/Enterprise | https://visualstudio.microsoft.com/downloads/ | ~5 GB |
| Build Tools for Visual Studio 2022 | https://aka.ms/vs/17/release/vs_BuildTools.exe | ~2-3 GB |

When installing, pick **"Desktop development with C++"** (full VS) or
**"MSVC v143 - VS 2022 C++ x64/x86 build tools"** + a Windows 10 SDK
(Build Tools).

## Source dependencies (downloaded by setup.ps1)

| Dep | Source | Pinned | Verified |
|---|---|---|---|
| **Deus Ex SDK 1.112fm** (engine.lib, core.lib, headers) | https://download.deusexnetwork.com/20/DeusExSDK1112f.exe | URL is stable since 2010; file hasn't changed | **MD5 `1d7560c513f945b607ee96cd2f9aec57`** verified by `setup.ps1` before extraction |
| **DeusExe fork** (Kentie's engine wrapper, source) | https://github.com/wagner-austin/DeusExe (forked from mkentie/DeusExE) | Cloned by user; pin via specific commit if needed | git history is the audit trail |
| **render11 fork** (Kentie's D3D11 renderer, source) | https://github.com/wagner-austin/render11 (forked from mkentie/render11) | Same | Same |

If the SDK URL ever changes, `setup.ps1` will fail loudly at the MD5
check rather than silently using whatever it downloaded — we never
trust an unverified blob.

## Runtime dependencies (end-user machine)

What the user needs to actually run our binaries (separate from
building them).

| Dep | What for | How handled |
|---|---|---|
| Windows 10 / 11 | OS | n/a |
| Deus Ex 1.112fm | Game data (vanilla maps, textures, models, vanilla DeusEx.exe to provide engine code) | User must own a legitimate copy. Steam GOTY ships with 1.112fm; non-GOTY needs the official 1.112fm patch. |
| **VC++ 2022 x64 redistributable** | render11.dll links against MSVC runtime (vcruntime140, msvcp140) | **Will be bundled by the Inno installer** (Microsoft permits redistribution via `vcredist_x64.exe` linked from MS) |
| MSVBVM50.DLL (legacy VB5 runtime) | Only needed if user runs UnrealEd (the SDK editor). NOT needed by deusex.exe / Render11.dll. | Not bundled — only relevant for modders, not players. We removed UnrealEd from the player workflow entirely. |

### Microsoft redistributables we'll bundle

The Inno installer (when built) will silent-install:

| Redistributable | Source | Why |
|---|---|---|
| Visual C++ 2022 x64 (vcredist_x64.exe) | https://aka.ms/vs/17/release/vc_redist.x64.exe | Required by render11.dll |
| _Optional_: VC++ 2022 x86 | https://aka.ms/vs/17/release/vc_redist.x86.exe | Required if any 32-bit mod components were rebuilt with VS 2022; deusex.exe itself is 32-bit but our build of it doesn't depend on the modern x86 runtime |

These are Microsoft's official URLs that always serve the current
redistributable. Inno's `[Files]` section can either embed them in the
installer (for no-internet installs) or download at install time (for
smaller installer size).

## CI dependencies (GitHub Actions)

The workflow at `.github/workflows/build.yml` uses these GitHub
Actions:

| Action | Version | What for |
|---|---|---|
| `actions/checkout@v4` | v4 | Clone repos |
| `microsoft/setup-msbuild@v2` | v2 | Locate MSBuild on the runner |
| `actions/upload-artifact@v4` | v4 | Publish dist/ as a downloadable artifact |

Runner: `windows-latest` (currently Windows Server 2022). Pinned to
"latest" because GitHub keeps it patched and our build doesn't depend
on a specific runner image — any reasonably modern Windows + VS 2022
works.

GitHub showed a deprecation notice that Node.js 20 actions will be
forced to Node.js 24 in June 2026. The action versions above will get
bumped to Node 24 by their maintainers before then; we'll update if CI
ever fails on that.

## What we're NOT depending on

Explicitly verified to not be needed (so we don't ship workarounds for
problems we don't have):

| Once-suspected dep | Reality |
|---|---|
| **Microsoft Detours** | NOT used. Kentie removed it in v7 (2015). Verified by grep — zero references in either project. We removed it from `setup.ps1` and from `launcher.props`. |
| **MSVBVM50.DLL** | Needed only by UnrealEd, not by `deusex.exe` or `Render11.dll`. Not bundled. |
| **Specific Direct3D version DLLs** | Render11 dynamic-loads `d3d11.dll`, `d3dcompiler.dll`, `dxgi.dll` — all present on Windows 10+ by default. No bundling needed. |
| **OpenGL / Glide / SoftDrv DLLs** | Vestigial in DX, replaced by D3D11. We don't depend on or ship these. |
| **GameSpy SDK** | Replaced by `master.deusexnetwork.com` (see project memory). No vendor dep. |

## Update procedure

If we ever need to update a pinned version:

### Bumping Windows SDK
1. Update `<WindowsTargetPlatformVersion>` in both vcxproj files.
2. Run `setup.ps1` + `build-all.ps1` to validate.
3. Commit with rationale ("Bump Windows SDK to X.Y.Z because <reason>").

### Bumping toolset
1. Update `<PlatformToolset>` in both vcxproj files.
2. Same as above — validate locally + CI.

### Bumping the SDK MD5
The DX SDK has been static for 25 years; this shouldn't happen. If a
new SDK release appears, regenerate the modernization patches
(`docs/PATCHES.md` covers this), update the MD5 in `setup.ps1`, and
re-run the build pipeline.

### Bumping a fork upstream
If Kentie pushes new commits to `mkentie/DeusExE`:
1. In our fork, `git remote add upstream https://github.com/mkentie/DeusExE`
2. `git fetch upstream && git merge upstream/master`
3. Resolve any conflicts with our build-config changes
4. CI catches regressions
