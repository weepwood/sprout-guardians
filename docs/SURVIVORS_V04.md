# Sprout Guardians — Survivors v0.4 implementation

## Core experience
The default survivor mode now follows a one-stick / one-job model inspired by common *survivors-like* gameplay conventions: steer the plant, dodge crowds, collect XP, choose upgrades, and let all weapons attack automatically.

This adaptation retains Sprout Guardians' own art and theme. No assets or character designs from *Vampire Survivors* are included.

### Controls
| Input | Behavior |
| --- | --- |
| WASD / direction keys | Immediate eight-way movement (diagonals normalized) |
| Gamepad mapped `ui_left/right/up/down` | Shared directional mapping |
| Mouse | UI buttons and reward choices only |
| Left / Right (during level-up) | Select one of the three reward cards |
| Enter / Space (during level-up) | Confirm currently focused upgrade |
| 1, 2, 3 | Pick a corresponding upgrade |
| Esc / P | Pause / resume |

Hero movement is integrated each frame with direct directional velocity, rather than repeatedly setting a move destination. The controller is a standalone scene node `RunInput` backed by `scripts/greed/survivor_input_controller.gd`. The inherited mouse controller is bypassed only in the survival scene; legacy Greed scenes remain supported. The basic dash is disabled in survivor mode.

## Editable scene composition
- `scenes/main.tscn` — full-viewport garden background, HUD layers and reward card layouts
- `assets/backgrounds/garden_meadow.svg` — original meadow background, drawn once as a texture
- `assets/ui/glass_frosted.gdshader` — lightweight screen-texture blur, only used behind the top HUD; no costly full-screen multi-pass blur
- `assets/ui/leaf_sigil.svg` — original leaf badge
- `scripts/ui/playful_ui_theme.gd` — translucent rounded UI surface, shared button states
- `scripts/greed/survivor_pixel_game.gd` — reward presentation, pause summary and minimal-HUD visibility
- `scripts/greed/survivor_game.gd` — timed spawns, XP and directional movement

## HUD and reward structure
The combat area extends near the full 640 × 360 viewport, with gameplay restricted below the 38px HUD and above the 337px XP indicator. Build statistics move to the pause dialog. Transient keyboard tips disappear after ~4 seconds. Enemy/Boss alerts remain optional.

Upgrade choice is a horizontal row of three ~174×179px cards, each containing a texture icon, rarity, title and concise text. Supports mouse clicks and keyboard navigation, and is editable without modifying drawing code.

## Tests
- `tests/run_survivor_tests.gd` checks immediate directional movement, release-to-stop, disabled click travel/dash and reward navigation
- `tests/run_ui_smoke.gd` confirms background coverage, no blocking build panel and horizontal card layout
- `tests/run_session_integration.gd` covers the full run lifecycle including pause, XP and Boss endgame
- Existing Windows, macOS, Linux smoke test and Web export pipeline are preserved

## Deliberate boundaries
This first phase does **not** implement a scrolling infinite map, larger virtual resolution, full animated sprite sheets, touch virtual sticks, skill tree or entirely independent survivor combat composition. Those remain separate roadmap items.

True screen blur is restricted to the small HUD strip to reduce GPU cost. If lower-end devices struggle, the HUD can fall back to the existing semi-transparent `StyleBoxFlat` without a screen sampling shader.
