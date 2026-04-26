# Building BlueOrbMod from Source

End-to-end build of every component, suitable for cold-clone scenarios
(new machine, new contributor, CI runner).

## Time budget

- First build (cold): **~10 minutes** including SDK download,
  Detours clone, two C++ compilations, and patch application.
- Incremental rebuild: **~30 seconds** (just the C++ compile pass).

## Required tooling

| Tool | Version | Why |
|---|---|---|
| Windows 10 / 11 | x64 | Build target is Win32 (the engine is 32-bit only) |
| MSVC v143 toolset | from VS 2022 or Build Tools 2022 | C++ compiler, linker, MSBuild, rc.exe |
| Windows 10 SDK | 10.0.19041 or newer | Provides `winres.h` and current `winnt.h` |
| git | any modern | clone forks + Detours |
| PowerShell | 5.1+ (ships with Windows) | Build scripts |

### Compiler: full VS 2022 *or* Build Tools 2022

You only need the compile pipeline; the IDE is optional. Two ways to get it:

| Option | Disk | When to pick |
|---|---|---|
| **[Visual Studio 2022 Community](https://visualstudio.microsoft.com/downloads/)** (free) | ~5 GB | You also want the IDE for code editing + debugging |
| **[Build Tools for Visual Studio 2022](https://aka.ms/vs/17/release/vs_BuildTools.exe)** (free) | ~2–3 GB | CI runners, lean dev setups, you don't need the IDE |

Both ship the same v143 toolset, MSBuild, and Windows SDK options.
`setup.ps1` uses `vswhere.exe` which finds either install.

When installing, pick the **"Desktop development with C++"** workload
(VS) or **"MSVC v143 - VS 2022 C++ x64/x86 build tools"** + a
**Windows 10 SDK** (Build Tools).

## Optional tooling

| Tool | Why |
|---|---|
| Inno Setup 6 | Builds the final installer |
| WiX Toolset 4 | Alternative to Inno (not used by default) |
| Deus Ex itself | To smoke-test the binaries in-place |

## One-time setup

```powershell
# Clone both forks side by side
cd C:\Users\<you>\PROJECTS\BlueOrbMod
git clone https://github.com/wagner-austin/DeusExe.git DeusExe
git clone https://github.com/wagner-austin/render11.git render11

# Run setup. This downloads the Deus Ex SDK from deusexnetwork.com
# (with MD5 verification), maps it into games/DeusEx/, applies our
# modernization patches, and clones Microsoft Detours.
./scripts/setup.ps1
```

`setup.ps1` is idempotent. Re-running with `-Force` will re-download
the SDK and re-apply patches from scratch. Re-running without `-Force`
is a no-op if everything is already in place.

## Build everything

```powershell
./scripts/build-all.ps1
```

Outputs:
- `dist/deusex.exe` — our build of Kentie's modified launcher (~400 KB)
- `dist/Render11.dll` — our build of the D3D11 renderer (~50 KB)
- `dist/Render11/*.hlsl` — shader sources the renderer needs at runtime
- `dist/Render11.int` — localization metadata for the renderer

The post-build events in each fork's `.props` files also auto-copy
binaries into your DX install's `System/` directory for in-place
smoke-testing (controlled by `GAMEDIR` in the per-fork `deus ex.props`).

## Build targets / configurations

`build-all.ps1` accepts:

```powershell
./scripts/build-all.ps1               # Release (default)
./scripts/build-all.ps1 -Configuration Debug
```

`render11` uses MSBuild configurations named "Deus Ex Release" /
"Deus Ex Debug" (with the space — the script handles the quoting).

## Editing in Visual Studio

Each fork has its own .sln:

```
DeusExe/DeusExe.sln
render11/Render11.sln
```

Open either in VS 2022. They'll build out of the box if `setup.ps1`
has been run. The MSBuild output paths are:

- `DeusExe/Release/deusex.exe`
- `render11/_work/bin/Deus Ex Release/Render11.dll`

## Troubleshooting

### "MSBuild not found"
Install VS 2022 with the "Desktop development with C++" workload. The
v143 toolset and Windows SDK 10.0.x come with that workload by default.

### "Windows SDK 10.0.10586.0 was not found"
You're trying to build without our modernization patches applied.
Re-run `./scripts/setup.ps1`. The forks set the SDK version to 10.0.26100,
but if you reverted that change, msbuild will look for the original.

### "Patch failed: .../UnTemplate.h"
Either:
1. The patch is already applied (setup detects this and skips — should
   not error out).
2. You've manually edited `games/DeusEx/core/inc/UnTemplate.h` after
   the SDK was extracted. Run `./scripts/setup.ps1 -Force` to nuke
   `games/DeusEx/` and re-extract+re-patch from scratch.

### "Cannot open include file: 'engine.h'"
`games/DeusEx/engine/inc/` is empty or missing. Run setup again with
`-Force`.

### `deusex.exe` builds but won't run on your DX install
- Verify your DX is the **1.112fm** patched version (Steam GOTY edition
  ships with this; non-GOTY needs the official patch).
- Verify `GAMEDIR` in `DeusExe/deus ex.props` matches your actual DX
  install location. Steam's default is
  `C:\Program Files (x86)\Steam\steamapps\common\Deus Ex`.

### `Render11.dll` doesn't show up in the renderer picker
- The shader files (`*.hlsl`, `*.hlsli`) MUST be in
  `<DX>/System/Render11/` next to `Render11.dll`. The post-build event
  copies them there. If you're packaging manually, don't forget them.
- Check `<DX>/System/BlueOrbMod.log` for `Render11Drv.dll: <reason>`
  load errors.

## Clean rebuild

```powershell
# Remove all build outputs but keep SDK + patches
Remove-Item -Recurse DeusExe/Release, DeusExe/_work
Remove-Item -Recurse render11/_work, render11/packages
./scripts/build-all.ps1
```

Full nuke (start from scratch):

```powershell
Remove-Item -Recurse _sdk_cache, _sdk_extract, games, detours, dist
./scripts/setup.ps1
./scripts/build-all.ps1
```

## CI

GitHub Actions workflows in each fork run `setup.ps1 + build-all.ps1`
on every push to `master`. Status badges:

- _to be added once workflows land_

A green CI run is the contract for "this commit builds clean".
