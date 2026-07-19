# Data-driven content guide

This project keeps gameplay values in Godot Resource files under `data/`. The runtime code should not contain per-level enemy counts, tower prices or wave statistics.

## Add an enemy

1. In Godot, right-click `data/enemies` and create a new `EnemyData` resource.
2. Set a unique `id`, name, movement speed, health, reward and presentation color.
3. Save it as a `.tres` file.
4. Reference the resource from a `SpawnGroupData` inside a wave.

No change to `main.gd` or `WaveManager` is required.

## Add or rebalance a wave

1. Create a `WaveData` resource under `data/waves`.
2. Add one or more `SpawnGroupData` subresources.
3. For each group, select an `EnemyData`, count, interval, delay and path index.
4. Set the wave-clear reward.
5. Add the wave resource to the `waves` array of a `LevelData` resource.

Multiple groups run concurrently. A delayed group can therefore introduce a second enemy type midway through the same wave.

## Add a tower

1. Create a `TowerData` resource under `data/towers`.
2. Configure its build cost, sell ratio, upgrade costs, damage, interval, range and targeting mode.
3. Add the tower to the level's `available_towers` array.
4. Provide a tower scene later when the game has a build-selection panel. The current prototype uses the shared `SproutTower` presentation.

Combat behavior is separated through `AttackStrategy`. A new beam or area attack should be implemented as a new strategy rather than by adding tower-specific conditions to `main.gd`.

## Add a status effect

1. Create a `StatusEffectData` resource.
2. Configure duration, tick interval, damage per tick, speed multiplier and stacking policy.
3. Call `enemy.apply_status(effect_data)` from an attack strategy or projectile impact behavior.

The reusable `StatusEffectComponent` handles expiration and movement multiplier restoration.

## Add a level

Create a `LevelData` resource and configure:

- initial sunlight and sprout health;
- route points;
- build-slot positions;
- available tower resources;
- ordered wave resources.

The next campaign milestone will replace the single preloaded default level with a level-selection service. Until then, `scripts/main.gd` preloads `morning_forest.tres` as the active level.

## Validation

Run the dependency-free tests locally with Godot 4.6.3:

```bash
godot --headless --path . --editor --quit
godot --headless --path . --script res://tests/run_tests.gd
```

The GitHub Actions workflow runs both commands before creating platform exports.
