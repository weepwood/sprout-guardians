# Sprout Guardians / 芽芽守卫战

A lightweight plant-themed pixel-art survivors roguelite built with **Godot 4.7.1** and statically typed GDScript.

The repository contains a playable 90-second survival slice with editor-visible scenes, automatic combat, floating familiars, experience pickups, seeded level-up choices, elite milestones, and a final boss.

## Current playable loop

- WASD, arrow-key, mouse movement, and dash controls
- Automatic main-plant and familiar attacks
- Physical projectiles, critical feedback, hit stop, knockback, splash, slow, and status effects
- Continuously escalating enemy pressure
- Experience dew pickups and three-choice level-ups
- Elite encounters at timed milestones and a final boss
- Main menu, settings, localization, save data, and run results
- Windows and Web player exports through GitHub Actions
- Internal Linux export used only for CI startup validation

## Run locally

1. Install **Godot 4.7.1 Standard**.
2. Clone or download this repository.
3. Open `project.godot` in Godot.
4. Open `scenes/main_menu.tscn` or `scenes/main.tscn` to edit the visible scene structure.
5. Press **F6** to run the current scene or **F5** to run the project.

The base viewport is 640×360 and uses integer scaling with nearest-neighbor texture filtering.

## Controls

- Move with WASD or the arrow keys.
- Click the arena to move toward a destination.
- Drag the main plant for direct mouse control.
- Press Space or double-click the arena to dash.
- Click an enemy to prioritize it as the automatic attack target.
- Right-click to clear the selected target.
- Choose one of three mutations whenever enough experience is collected.

## Automated packaging

`.github/workflows/build.yml` installs **Godot 4.7.1-stable**, imports and validates the project, runs all automated tests, and exports:

- `SproutGuardians-Windows-x86_64.zip`
- `SproutGuardians-Web.zip`

The workflow also creates a private Linux smoke build, launches it headlessly to detect runtime failures, and excludes it from player-facing artifacts.

Every pull request and push to `main` produces downloadable workflow artifacts. Pushing a tag such as `v0.1.0` creates a GitHub Release containing the Windows and Web packages.

## Repository structure

```text
.github/workflows/  CI validation, testing, export, packaging, and releases
assets/             Pixel art, atlases, environment textures, and UI assets
docs/               Design, architecture, migration, and milestone documents
scenes/             Editor-visible Godot scenes and reusable PackedScenes
scripts/            Gameplay, UI, services, and visual controllers
tests/              Headless gameplay and scene-structure tests
export_presets.cfg  Windows, Linux smoke, and Web export presets
project.godot       Godot 4.7 project configuration
```

## Development direction

- Replace temporary visual assets with production PNG sprite sheets and `AnimatedSprite2D` animations
- Expand the arena into a scrolling TileMap-based world
- Add rule-changing weapons, familiar synergies, enemy archetypes, and multi-stage bosses
- Improve controller, touch, accessibility, performance, and long-run balance

See [docs/ROADMAP.md](docs/ROADMAP.md) and [docs/ASSET_PACK_SELECTION.md](docs/ASSET_PACK_SELECTION.md) for the implementation and asset plans.

## License

Code is released under the MIT License. Third-party art and audio assets must be tracked with their original license and attribution files.
