# Project Goals

What BlueOrbMod is, who it's for, why it exists, and what "done" means.

## The problem we're solving

Deus Ex (2000) is a great game with an active modding community 25
years later. But the modding experience hasn't aged well:

- **For players**: every mod requires a chain of manual setup —
  install Kentie's launcher, install a renderer, edit `.ini` files,
  drop files in the right places, hope nothing conflicts. There's no
  "just install this and play" experience.
- **For modders**: there's no published license, no modern toolchain,
  no central reference. Every modder rediscovers the same gotchas
  (state-scoped function overrides, MultiSkins texture flag stripping,
  vanilla weapon class names, etc.).
- **Multiplayer**: GameSpy shut down in 2014. The community replacement
  works but requires manual `.ini` patching that 90% of would-be
  players don't know about.

## What we're building

A complete, polished modding stack for Deus Ex distributed as **one
installer**:

```
BlueOrbMod-Setup.exe    ← user double-clicks this
   ↓ runs
BlueOrbModLauncher.exe  ← single window, picks mode, launches game
   ↓ spawns
Deus Ex (modded)        ← game appears, plays
```

End-to-end: download → install → click → play. No `.ini` editing.
No "place these files in this folder." No "now download Kentie's
launcher separately."

## Who it's for

### Players who want to play modded Deus Ex
- Get a working modded DX in 2 clicks (download installer, run it).
- See active community servers in the in-launcher browser.
- Don't have to know what an `.ini` file is.

### Modders who want to extend BlueOrbMod
- Clone the workspace, run `setup.ps1`, build everything in 10 minutes.
- Add new map mood mutators, custom enemies, weapons via documented
  extension points.
- Their mods get the same single-installer experience.

### Future maintainers (including future-us)
- Patches versioned. Builds reproducible. Sources owned.
- If Kentie's site goes dark in 5 years, we still build.
- If Windows 12 breaks something, we patch our forks.
- If a new renderer (D3D12) becomes practical, we swap it in without
  rewriting the launcher or installer.

## Success criteria

### Minimum success (worth shipping v1)
- ✅ DeusExe + render11 build cleanly from source on a fresh VS 2022 install
- ✅ `setup.ps1` works on a clean machine in under 10 minutes
- ⬜ WPF launcher boots straight to the game (no Kentie dialog, no DX
  title screen)
- ⬜ Inno installer produces a single `.exe` that installs on a clean
  DX install end-to-end
- ⬜ MP server browser populates with active servers via masterserver
- ⬜ All builds tested on a clean Windows VM (no developer tools, no
  pre-installed deps)

### Full success (polished, modder-friendly)
- ⬜ GitHub Actions CI in both forks (every push validated)
- ⬜ Modder template repo so other mod authors can build on our
  infrastructure
- ⬜ Public ModDB page with downloads + setup instructions
- ⬜ Documented extension points for new map mutators, custom weapons,
  custom enemies (some already exist; need to formalize)
- ⬜ Custom 3D model pipeline proven (Blender → UE1 .3d) for at least
  one weapon
- ⬜ Bundled installer at < 100MB

### Stretch (long-term)
- HTTP redirect support for fast MP downloads
- Hanfling's renderer (DX9) bundled as fallback for old hardware
- Custom installer-bundled SP campaign content

## Constraints we're operating under

### Legal
- **No redistribution of Square Enix IP**: Deus Ex game data, vanilla
  maps, vanilla textures — user must own a legitimate copy.
- **No redistribution of the Deus Ex SDK binary**: downloaded fresh per
  developer machine via `setup.ps1`.
- **No LICENSE file on Kentie's source**: we compile from his public
  GitHub repos with prominent attribution. Community precedent
  (Revision/GMDX/HDTP) supports this. We don't redistribute his
  pre-built binaries.

### Technical
- **UE1 BSP geometry is build-time only**: we can't generate maps
  procedurally at runtime; map base geometry comes from existing `.dx`
  files. We compensate by using runtime actor spawning to transform
  any base map's atmosphere.
- **No shaders in UE1**: emission/glow effects rely on bright
  texture pixels + bloom from the modern renderer. No PBR materials,
  no normal maps.
- **UE1 is 32-bit**: all binaries we ship are x86, even on x64 hosts.

### Operational
- **Single maintainer (currently)**: scope must be sustainable for
  one person. No features that require ongoing service operation
  (e.g., we don't run a master server; we use the existing community
  one).
- **Free distribution**: ModDB / GitHub releases. No monetization,
  no telemetry.

## Non-goals (explicitly NOT building)

- **A new game**: BlueOrbMod modifies Deus Ex; it doesn't replace it.
- **Multiplayer matchmaking infrastructure**: we use the existing
  `master.deusexnetwork.com` masterserver run by 333networks.
- **A persistent server**: no central anything. Player launches → 
  player plays. Hosting is opt-in via the launcher.
- **Cross-game support**: this is Deus Ex specifically. The forks of
  Kentie's source could be ported to UT99 / Unreal / Rune since
  Kentie supports those games too, but that's not our project.
- **Replacing Steam Workshop / Vortex**: we're a single mod's distribution,
  not a mod platform. Other mods can fork our infra; we don't host
  them.

## Path to "done"

The ROADMAP.md has the task list. This doc is about the destination:

> A new player on Reddit reads about BlueOrbMod, downloads
> `BlueOrbMod-Setup.exe`, double-clicks it, picks where their Deus Ex
> is installed, clicks "Install." When it finishes, our launcher
> opens. They click "Multiplayer Join," see a couple of active
> servers, click one. They're in the game in under 30 seconds. They
> never edit a config file, never download a renderer separately,
> never wonder why the masterserver browser is empty.
>
> Two weeks later they want to host their own server with a custom
> map. They open the launcher, "Multiplayer Host," pick "Cathedral"
> base + "Forest" mood. Their server appears in the public browser.
> Their friends connect and the mod auto-downloads. They play.
>
> A year later, someone wants to extend BlueOrbMod with custom
> monsters. They clone our workspace, run `setup.ps1`, have working
> binaries in 10 minutes, write their UnrealScript, run
> `dxmod_compile`, build the installer, ship their fork.

Everything in the roadmap exists to make that paragraph true.
