# Roadmap

What's done, what's next. No artificial "v1/v2" — just the order things
get built.

## Done

- Forked `mkentie/DeusExE` → `wagner-austin/DeusExe`
- Forked `mkentie/render11` → `wagner-austin/render11`
- Modernized both forks for VS 2022 (v143) + Windows SDK 10.0.26100
- Both build clean from source (zero errors, zero warnings)
- SDK modernization patches versioned in `patches/`
- `setup.ps1` automates SDK download + extract + patch + Detours clone
- `build-all.ps1` automates DeusExE + render11 builds
- `README.md`, `BUILDING.md`, `PATCHES.md`, `ARCHITECTURE.md` written

## Next

1. **Move BlueOrbMod source into this workspace.** Currently lives in
   `<DX>/BlueOrbMod/` (the mod profile dir). Add it as a subdirectory
   here so everything's in one place; the dx-mod MCP gets pointed at
   the new location.

2. **WPF launcher (`BlueOrbModLauncher`).** Single-window mode picker.
   See [ARCHITECTURE.md](ARCHITECTURE.md) for the full design.
   - Mode list: SP New Game, SP Load, SP Continue, MP Host, MP Join, Settings
   - JSON-based mode definitions so non-developers can add modes
   - Settings panel writes BlueOrbMod.ini directly
   - Server browser that queries master.deusexnetwork.com

3. **GitHub Actions CI** in both forks. Runs `setup.ps1 + build-all.ps1`
   on every push to master. Catches regressions immediately. Status
   badges in this README.

4. **Inno Setup installer.** Bundles everything into a single
   `BlueOrbMod-Setup.exe`. See [ARCHITECTURE.md](ARCHITECTURE.md) for
   the install flow.
   - Detect DX install (Steam registry probe)
   - Drop binaries + mod content
   - Patch DeusEx.ini for `EditPackages=BlueOrbMod`
   - Patch BlueOrbMod.ini for masterserver fix
   - Run VC++ redistributable
   - Create Start Menu shortcuts

5. **Test on a clean VM.** Install fresh Windows, install Steam DX,
   run our installer, verify everything works without touching anything
   else. Hyper-V image checked into infra-as-code if useful.

6. **First public release.** ModDB page + GitHub releases + Discord
   announcement.

## Later (when interest justifies)

- **Custom 3D models** for BlueOrb weapons (Blender → UE1 .3d). The
  pipeline is documented in the dxmod skill; just hasn't been driven yet.
- **Custom enemy variants** (subclass `MJ12Trooper` etc.) for SP.
- **More map mood mutators** (Cemetery on Catacombs, Bunker on Area51,
  Snowy on Smuggler, etc.) — each is a small UnrealScript class.
- **HTTP redirect support for hosting** (faster auto-download for MP
  clients than UE1's native ~10-20 KB/s). Would require either
  bundling Nephthys or porting that capability into our DeusExe fork.
- **Modder template repo** so other mod authors can fork BlueOrbMod and
  create their own mods using the same launcher + installer + build
  infrastructure.
- **Bake the masterserver fix directly into DeusExe** (in our fork)
  instead of relying on ini patches. Means new DX MP installs can use
  our `BlueOrbMod.exe` standalone.
- **Integrate Hanfling's renderer (DX9) as a fallback** for users
  whose hardware doesn't support D3D11.

## Won't do

- **Bundle Kentie's pre-built binaries.** We compile from his public
  source. Provides cleaner attribution path and means we control the
  build pipeline.
- **Replicate Kentie's fixes from scratch.** We use his source — we
  don't reinvent. He did the work; we honor it via attribution and by
  contributing fixes upstream when they're general (not BlueOrbMod-specific).
- **Modify any vanilla DX file.** All overrides go through the
  BlueOrbMod profile (`BlueOrbMod.ini`, `BlueOrbMod.u`, `BlueOrbMod.exe`).
  Vanilla install stays untouched.
- **Bypass Kentie's licensing-by-default-copyright.** His repos lack
  LICENSE files but are publicly hosted. We compile from his source
  with prominent attribution; we do not re-license his work.
