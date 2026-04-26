# BlueOrbMod Workspace

Self-hosted, source-built modding stack for Deus Ex (2000). Goal: a single
`BlueOrbMod-Setup.exe` installer that gives any player a fully patched,
modded Deus Ex with one double-click.

This workspace owns every component of the stack:

| Component | Source | Repo |
|---|---|---|
| Engine wrapper (windowed/widescreen/FOV/save-redirect/raw-input) | Forked from [mkentie/DeusExE](https://github.com/mkentie/DeusExE) | [`wagner-austin/DeusExe`](https://github.com/wagner-austin/DeusExe) |
| Direct3D 11 renderer (HDR + bloom + AA + AF) | Forked from [mkentie/render11](https://github.com/mkentie/render11) | [`wagner-austin/render11`](https://github.com/wagner-austin/render11) |
| Mod content (UnrealScript + textures + maps + sounds) | Original | `BlueOrbMod/` (lives in DX install dir, separate repo) |
| Single-window launcher (mode picker, settings, server browser) | Original | _planned_ |
| One-click installer (Inno Setup) | Original | _planned_ |

## Why we own all of it

- **Future-proof**: if upstream sources go dark, we still build.
- **Bug control**: anything broken, we patch directly.
- **Forward-thinking**: we can extend the engine wrapper or renderer
  with mod-specific features (e.g. baking the masterserver fix into
  the binary, custom `-bluedebug` flags, etc.).

Attribution to Kentie (kentie.net) goes prominently in the launcher's
About panel and the installer welcome screen.

## Structure

```
BlueOrbMod/
├── DeusExe/              ← forked engine wrapper (our build)
├── render11/             ← forked Direct3D 11 renderer (our build)
├── games/                ← Deus Ex SDK content (downloaded fresh; not in git)
├── patches/              ← SDK modernization patches (versioned)
├── scripts/
│   ├── setup.ps1         ← one-time bootstrap (downloads SDK, applies patches)
│   └── build-all.ps1     ← rebuild everything cleanly
├── docs/
│   ├── BUILDING.md       ← detailed build instructions
│   ├── PATCHES.md        ← what each SDK patch does and why
│   └── ARCHITECTURE.md   ← how the pieces fit together
└── dist/                 ← build outputs ready for installer (gitignored)
```

## Quick start (build everything)

Prerequisites: Visual Studio 2022 with the "Desktop development with C++"
workload, Windows 10 SDK (any 10.0.x ≥ 19041), git.

```powershell
git clone https://github.com/wagner-austin/DeusExe.git DeusExe
git clone https://github.com/wagner-austin/render11.git render11
# (in this BlueOrbMod workspace)

./scripts/setup.ps1     # downloads + extracts SDK, applies patches, clones Detours
./scripts/build-all.ps1 # builds DeusExE + render11
```

After this, `dist/` contains:
- `deusex.exe` (our build of Kentie's modified launcher)
- `Render11.dll` + `Render11/*.hlsl` (our build of Kentie's D3D11 renderer)

These get bundled into the installer (when that lands).

## Prerequisites you must have

The SDK download is automated via `setup.ps1`. The host requirements:

| Dependency | Version | Notes |
|---|---|---|
| MSVC v143 toolset | from VS 2022 (Community OK) **or** [Build Tools 2022](https://aka.ms/vs/17/release/vs_BuildTools.exe) | Build Tools is ~2–3GB and skips the IDE; full VS is ~5GB if you also want the editor |
| Windows 10 SDK | 10.0.19041 or newer | We test against 10.0.26100 |
| git | any modern | for fork clones + Detours |
| Deus Ex (Steam, GOG, retail) | 1.112fm | Required to run the build outputs in-place. NOT required for the build itself; required to test/play. |

## Reproducibility

Every build artifact is reproducible from a clean checkout:

1. Source code: pinned via git (forks at specific commits).
2. SDK: downloaded fresh via `setup.ps1` with MD5 verification (`1d7560c513f945b607ee96cd2f9aec57`).
3. Patches: versioned in `patches/` and applied deterministically.
4. Toolchain: VS 2022 v143 + Windows SDK 10.0.x (verified by `setup.ps1`).

If you can `git clone` and have VS 2022, you can reproduce the
binaries byte-for-byte (modulo timestamps in the PE).

## Licensing & attribution

- **Kentie's source** (DeusExE, render11): no LICENSE file in upstream
  repos. Used here under permissive community precedent (Revision, GMDX,
  HDTP all build on Kentie's work). Full attribution in
  launcher About panel. We compile from his public source — we don't
  redistribute his binaries.
- **Microsoft Detours**: MIT.
- **Deus Ex SDK**: Square Enix / Eidos / Ion Storm. Downloaded fresh
  per-user from deusexnetwork.com; never redistributed in our git
  history.
- **Deus Ex game data**: Square Enix. End user must own a legitimate
  copy.
- **Our original code** (BlueOrbMod, launcher, installer): MIT.

## Status

| Component | State |
|---|---|
| DeusExE fork | ✅ Forked, modernized, builds clean under VS 2022 |
| render11 fork | ✅ Forked, modernized, builds clean under VS 2022 |
| SDK setup automation | ✅ `setup.ps1` |
| Build automation | ✅ `build-all.ps1` |
| BlueOrbMod content | 🟡 Existing UnrealScript work in DX install dir; will move into this workspace |
| Launcher (WPF) | ⬜ Not started |
| Installer (Inno) | ⬜ Not started |
| GitHub Actions CI | ⬜ Not started |

See [docs/ROADMAP.md](docs/ROADMAP.md) for what's next.
