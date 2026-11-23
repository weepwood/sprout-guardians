# Sprout Guardians / 芽芽守卫战

A lightweight plant-themed survivors roguelite built with **Godot 4.7.1** and statically typed GDScript. The current work-in-progress art direction uses transparent toy-style sprites in place of code-drawn actors.

The repository contains a playable 90-second survival slice with editor-visible scenes, automatic combat, floating familiars, experience pickups, seeded level-up choices, elite milestones, a final boss, and locally persisted survivor run records.

## Current playable loop

- WASD / arrow-key movement with automatic attacks; mouse controls menus and level-up cards only
- Automatic main-plant and familiar attacks
- Physical projectiles, critical feedback, hit stop, knockback, splash, slow, and status effects
- Continuously escalating enemy pressure, safer edge spawning, short elite/Boss warnings and kill-combo feedback
- Experience dew pickups and three-choice level-ups
- Elite encounters at timed milestones and a final boss
- Main menu, settings, localization, save data, garden journal with persistent run statistics, and run results
- Windows, macOS Universal and Web player exports through GitHub Actions
- Internal Linux export used only for CI startup validation

## Run locally

1. Install **Godot 4.7.1 Standard**.
2. Clone or download this repository.
3. Open `project.godot` in Godot.
4. Open `scenes/main_menu.tscn` or `scenes/main.tscn` to edit the visible scene structure.
5. Press **F6** to run the current scene or **F5** to run the project.

The base viewport is 640×360 (1280×720 default window). Survivor mode now uses an expanded active arena, a full-bleed authored garden background, a minimal top HUD with lightweight frosted blur, and a slim XP bar. Toy-style character sprites use linear filtering; legacy pixel/UI art can retain nearest-neighbor filtering.

## Controls

- Move with WASD or the arrow keys.
- Keep moving to dodge enemies while your main plant and floating familiars fire automatically.
- Level up from dew drops and choose one of three **horizontal** reward cards with the mouse, Left/Right + Enter, or keys 1–3.
- Use Escape or P to pause/resume, with your current garden build shown on the pause screen.
- There is no click-to-move, manual enemy lock-on, or default dash in survivor mode.

## Automated packaging

`.github/workflows/build.yml` installs **Godot 4.7.1-stable**, imports and validates the project, runs all automated tests, and exports:

- `SproutGuardians-Windows-x86_64.zip`
- `SproutGuardians-Web.zip`
- `SproutGuardians-macOS-Universal.zip`
- `SproutGuardians-macOS-Universal.dmg`

The workflow also exports a **macOS Universal 2 app** (Intel + Apple Silicon), ad-hoc signs and smoke-tests it on a native macOS runner, and packages it as **.zip** and **.dmg**. A private Linux smoke build is excluded from player-facing artifacts.

macOS downloads are not Apple-notarized yet; Gatekeeper may require explicit approval on first launch. See [Desktop packages & UI design](docs/DESKTOP_PACKAGING_AND_UI.md) for installation and verification details.

Every pull request and push to `main` produces downloadable workflow artifacts. Pushing a version tag creates a GitHub Release with Windows, macOS Universal (ZIP + DMG) and Web packages, after cross-platform checks.

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

## Classic-survivors controls and HUD (v0.4.0)

- Arcade-style directional movement is polled every frame by `SurvivorInputController`, independent from UI clicks.
- The hero uses direct velocity and stops on input release; weapons automatically target nearby enemies.
- The original click-to-move/drag/lock-on/dash handler remains only in legacy Greed mode.
- Reward selection displays three side-by-side cards with authored icons, rarity indicators and keyboard navigation.
- Details move to the pause panel; temporary on-screen instructions fade and the expanded gameplay area stays unobstructed.
- Background SVG and frosted-glass shader are kept as standalone assets in `assets/backgrounds/` and `assets/ui/`.

See [Survivors v0.4 implementation](docs/SURVIVORS_V04.md) for editable scene paths, controls, trade-offs and test coverage. The `v0.4.0` release request is guarded by full multi-platform validation.

## Work-in-progress art and runtime architecture

The current refactor uses `assets/toy/sprout_toy_atlas.png` (original transparent images arranged in 3×3 cells), editor-visible `Sprite2D` actor scenes, a pooled textured impact effect, a bounded damage-number label pool, and an extracted `SurvivorRunState` lifecycle. The previous procedural actor drawing remains available **only for legacy scenes** during the transition.

The extended test suite now covers a full 90-second logical run, reward selection, pausing and Boss victory. Export smoke tests open the actual survival scene; Windows, Linux and macOS checks run separately.

**To diagnose an exit or crash**, collect the native `user://logs/godot.log` and `user://diagnostics/survivor-session.log` files. Completed run records are stored in the existing `user://savegame.json`, with the existing backup safeguard. See [Refactor and crash diagnostics](docs/REFACTOR_AND_CRASH_DIAGNOSTICS.md) for Windows/macOS paths and an incremental migration plan. The `v0.3.0` release introduces these changes while retaining previous save data.

## Development direction

- Replace temporary visual assets with production PNG sprite sheets and `AnimatedSprite2D` animations
- Expand the arena into a scrolling TileMap-based world
- Add rule-changing weapons, familiar synergies, enemy archetypes, and multi-stage bosses
- Improve controller, touch, accessibility, performance, and long-run balance

See [docs/ROADMAP.md](docs/ROADMAP.md), [docs/ASSET_PACK_SELECTION.md](docs/ASSET_PACK_SELECTION.md), and the [November 2026 engineering audit](docs/ENGINEERING_AUDIT_2026_11.md) for current limitations, completed hardening, and prioritized next steps.

## License

Code is released under the MIT License. Third-party art and audio assets must be tracked with their original license and attribution files.
