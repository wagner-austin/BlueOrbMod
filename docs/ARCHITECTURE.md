# BlueOrbMod Architecture

How the pieces fit together at runtime.

## Layered view

```
                 ┌────────────────────────────────┐
                 │   BlueOrbModLauncher.exe (WPF) │   ← user double-clicks this
                 │   (mode picker + settings)     │
                 └───────────────┬────────────────┘
                                 │  spawns process with URL args + flags
                                 ▼
       ┌────────────────────────────────────────────────────┐
       │   BlueOrbMod.exe (renamed from our deusex.exe build)│
       │   - Kentie's launcher fixes (widescreen/FOV/raw    │
       │     input/save redirect/etc.)                       │
       │   - We compile this from source (forked DeusExE).   │
       └────────────────┬───────────────────────────────────┘
                        │  loads
                        ▼
       ┌──────────────────────────────────┐    ┌──────────────────┐
       │  Deus Ex 1.112fm engine binary   │◄───┤  Render11.dll    │
       │  (Square Enix; user-owned)       │    │  (our build of   │
       │                                  │    │  forked render11)│
       │  Loads packages:                 │    └──────────────────┘
       │    - DeusEx.u (vanilla)          │
       │    - BlueOrbMod.u (our mod)      │
       │      with custom weapons,        │
       │      mutators, map transforms    │
       │    - Maps from BlueOrbMod/Maps/  │
       │      and vanilla Maps/           │
       └──────────────────────────────────┘
```

## What we own vs. what we depend on

### We own (in this workspace)
- The launcher (`BlueOrbModLauncher.exe`) — from-scratch WPF app
- The mod content (`BlueOrbMod.u` + maps + textures + sounds)
- Our build of Kentie's engine wrapper (forked, source-built)
- Our build of Kentie's D3D11 renderer (forked, source-built)
- The installer script (Inno Setup `.iss`)
- The patches that modernize the SDK headers

### We depend on (must exist on user's machine)
- A legitimate Deus Ex 1.112fm install (Steam, GOG, retail)
  - Steam version is auto-1.112fm
  - Non-Steam may need the official 1.112fm patch
- Visual C++ runtime (we bundle redistributables in our installer)
- Windows 10/11

### We never redistribute
- Square Enix's Deus Ex game files (textures, models, vanilla maps,
  vanilla executable) — user must own a copy
- Microsoft's Windows SDK headers, the Detours source, etc. — only
  used at our build time, never shipped
- The Deus Ex SDK content from `games/DeusEx/` — downloaded fresh
  per developer machine via `setup.ps1`

## Per-component design

### BlueOrbModLauncher (planned)

**Single window, no nested launchers.** When user double-clicks the
desktop shortcut, this window appears immediately.

Modes:
- Single Player (New Game / Load / Continue)
- Multiplayer Host (pick base map + mood preset)
- Multiplayer Join (live server browser fed by master.deusexnetwork.com)
- Settings (renderer, resolution, FOV, master server URL)

Each mode launches `BlueOrbMod.exe` with `-skipdialog -localdata` flags
plus the URL arg sequence that bypasses the in-game title screen.

The launcher is the only UI surface the user sees outside of gameplay.
Kentie's own launcher dialog is suppressed via the `-skipdialog` flag
(documented in his readme). The DX engine's title screen is bypassed
via URL args (e.g., `DXMP_Cathedral.dx?game=DeusEx.DeathMatchGame?Mutator=...`).

### BlueOrbMod.exe (renamed from our DeusExe build)

Why renamed: UE1 convention is `<ExeName>.ini` and `<ExeName>.log`
tied to the running exe's basename. By naming our copy `BlueOrbMod.exe`,
saves/configs/logs go to `BlueOrbMod.ini`, `BlueOrbMod.log` etc. —
isolated from any vanilla DX install, isolated from any other DX mod
profile.

This is the standard pattern used by Shifter, Revision, GMDX, HDTP.

### Render11.dll (our render11 build)

Loaded by the DX engine at runtime when `RenderDevice=` in the ini
points to `D3D11Drv.D3D11RenderDevice`. Provides:

- HDR + bloom (via `ClassicLighting=False`)
- High-quality anisotropic filtering
- Anti-aliasing
- Proper widescreen sky rendering

Required runtime: Visual C++ 2022 redistributable (we bundle it).

### BlueOrbMod.u (the actual mod)

UnrealScript classes that extend Deus Ex behavior. Compiled by the DX
SDK's `UCC.exe make` (this part doesn't go through Visual Studio; it's
managed by the dx-mod MCP).

Current contents:
- Custom weapons (BlueOrbPistol, BlueOrbCrossbow)
- Custom projectiles + ammo
- Game-rules mutator (gravity, jump, movement)
- Map atmosphere mutators (BlueOrbForestMap, etc.)

This package gets bundled into the installer alongside the binaries.
Auto-downloads to MP clients via UE1's package map system.

### Installer (planned, Inno Setup)

Single `BlueOrbMod-Setup.exe` that:

1. Detects user's DX install (Steam registry probe, GOG registry probe,
   or interactive picker)
2. Verifies it's the 1.112fm version
3. Drops:
   - Our `BlueOrbMod.exe` into `<DX>/System/`
   - Our `Render11.dll` + shaders into `<DX>/System/`
   - `BlueOrbMod.u` + INT + maps + textures + sounds into `<DX>/BlueOrbMod/`
   - `BlueOrbModLauncher.exe` into `<DX>/BlueOrbMod/`
4. Writes:
   - Patched `BlueOrbMod.ini` (cloned from vanilla DeusEx.ini, with
     master server fix, EditPackages, RenderDevice=D3D11Drv...)
   - `EditPackages=BlueOrbMod` line in the user's `DeusEx.ini`
5. Runs:
   - VC++ runtime redistributable
6. Creates:
   - Start Menu folder + desktop shortcut to `BlueOrbModLauncher.exe`

User experience: download → run installer → click through → desktop
shortcut → click → play.

## Multiplayer flow

1. User opens the launcher → "Multiplayer Join"
2. Launcher queries `master.deusexnetwork.com` (UDP GameSpy heartbeat
   protocol or 333networks JSON API) for active server list
3. User picks a server → launcher spawns
   `BlueOrbMod.exe -skipdialog -localdata <ip>:<port>`
4. DX engine connects to the server
5. If the server is running custom mods/maps the client doesn't have,
   UE1's package auto-download fetches them (limited to ~10-20 KB/s
   over UE1's native protocol; faster if the server uses HTTP redirect)
6. User plays

For hosting, the launcher's "Multiplayer Host" mode spawns:
`BlueOrbMod.exe -skipdialog -localdata <Map>.dx?game=DeusEx.DeathMatchGame?Mutator=BlueOrbMod.<MoodMutator>?listen`

## Single-player flow

1. User opens the launcher → "Single Player → New Game"
2. Launcher spawns `BlueOrbMod.exe -skipdialog -localdata 00_Intro.dx?game=DeusEx.BlueOrbGameInfo`
3. DX engine boots straight into the intro level — no title screen
4. `BlueOrbGameInfo.AddDefaultInventory` grants the BlueOrb pistol +
   custom mutators apply (low gravity, custom movement, etc.)
5. User plays

## Why this design

**One launcher window, ever.** No Kentie config dialog, no DX title
screen, no "click Play to continue." The launcher is the only chrome
between the user and gameplay.

**Source ownership of every binary.** We built the engine wrapper. We
built the renderer. We built the launcher. If something breaks, we can
fix it. If a future Windows update breaks something, we can patch it.

**Separation of concerns.** Each component has one job: launcher
(picks modes), engine wrapper (modern Windows compat), renderer
(graphics), mod content (gameplay rules), installer (deployment).

**Reproducibility.** A new contributor can clone this workspace and
have a working build in ~10 minutes via `setup.ps1` + `build-all.ps1`.
The SDK is downloaded fresh, patches are versioned, toolchain is
pinned.
