# Sprout Guardians / 芽芽守卫战

A lightweight pixel-art tower defense game built with **Godot 4.6.3** and statically typed GDScript.

The repository currently contains the first playable vertical slice. All visuals are generated in code, so the game can run before final sprites, TileSets, music, and sound effects are added.

## Current playable loop

- Fixed-path enemy movement
- Four escalating waves, including a boss wave
- Six build slots
- Pea Tower construction, targeting, upgrades, and selling
- Coins, base health, kill rewards, and wave-clear rewards
- Pause, 1x/2x/3x speed, victory, defeat, and restart
- Windows, Linux, and Web exports through GitHub Actions

## Run locally

1. Install Godot 4.6.3 Standard.
2. Clone or download this repository.
3. Open `project.godot` in Godot.
4. Press **F6/F5** to run the main scene/project.

The base viewport is 640×360 and uses integer scaling with nearest-neighbor texture filtering.

## Controls

- Click an empty green slot to build a Pea Tower for 75 sunlight.
- Click a tower to select it.
- Use the lower-right panel to upgrade or sell the selected tower.
- Start each wave using the top toolbar.
- Pause or switch between 1x, 2x, and 3x speed.

## Automated packaging

`.github/workflows/build.yml` validates the project and exports:

- `SproutGuardians-Windows-x86_64.zip`
- `SproutGuardians-Linux-x86_64.tar.gz`
- `SproutGuardians-Web.zip`

Every pull request and push to `main` produces downloadable workflow artifacts. Pushing a tag such as `v0.1.0` creates a GitHub Release and uploads all three packages automatically.

## Repository structure

```text
.github/workflows/  CI validation, export, packaging, and releases
docs/               Design, architecture, and milestone documents
scenes/             Godot scene files
scripts/            Gameplay scripts
export_presets.cfg  Windows, Linux, and Web presets
project.godot       Godot project configuration
```

## Development milestones

- **M0 — Foundation:** playable code-generated prototype and automated packaging
- **M1 — Core systems:** data-driven towers, enemies, projectiles, waves, and status effects
- **M2 — First content slice:** pixel art, three towers, four enemies, ten waves, and one boss
- **M3 — Campaign shell:** menus, settings, save data, level selection, and star ratings
- **M4 — Polish:** audio, particles, accessibility, touch controls, profiling, and balancing

See [docs/ROADMAP.md](docs/ROADMAP.md) for the implementation plan.

## License

Code is released under the MIT License. Future art and audio assets may use separate attribution files where required.
