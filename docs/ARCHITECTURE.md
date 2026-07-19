# Architecture

## Current vertical slice

The first milestone intentionally minimizes asset and scene dependencies:

- `Main` owns the wave, economy, base-health, build-slot, and HUD orchestration.
- `SproutEnemy` follows a fixed polyline and emits `defeated` or `escaped` exactly once.
- `SproutTower` searches only the enemy group when its attack cooldown expires, then targets the enemy closest to the goal.
- The UI and placeholder pixel visuals are generated at runtime.

This gives the repository a testable gameplay loop before content production begins.

## Planned modular architecture

The next milestone will separate responsibilities into:

- `GameManager`: run state, pause, time scale, victory, and defeat
- `WaveManager`: spawn groups, route selection, early-wave rewards, and completion
- `EconomySystem`: all coin transactions
- `BaseHealthSystem`: life changes and defeat protection
- `TowerData`, `EnemyData`, `WaveData`, `LevelData`: editor-authored Resources
- Components for health, targeting, attacks, projectiles, and status effects
- Object pools for projectiles, damage numbers, and frequently reused effects

## Performance rules

- Towers do not scan every enemy every frame.
- Target selection runs only when an attack becomes ready.
- UI labels update only after state changes.
- Fixed-route enemies do not perform pathfinding.
- Reusable transient objects will move to pools before high-enemy-count levels are introduced.
