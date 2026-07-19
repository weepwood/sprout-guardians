# Architecture

## Runtime composition

`Main` is now a thin composition root. It creates the runtime systems, connects their signals, renders the prototype map and owns the current UI interactions. Gameplay state no longer lives in `main.gd`.

```text
Main
├── GameManager
├── EconomySystem
├── BaseHealthSystem
├── WaveManager
├── EnemyRegistry
├── ProjectilePool
├── DebugPerformanceOverlay
├── SproutTower instances
└── SproutEnemy instances
```

## Responsibilities

### GameManager

Owns pause, time scale, preparation/running state, victory, defeat and scene restart. It is the only module allowed to change the global pause state during normal gameplay.

### EconomySystem

Owns the sunlight balance. Every build, upgrade, sale, enemy reward and wave-clear reward passes through `spend` or `earn`, producing a single transaction signal for the UI and future telemetry.

### BaseHealthSystem

Owns current and maximum sprout health. It clamps damage, emits health changes and guarantees that depletion is emitted only once.

### WaveManager

Reads `LevelData` and `WaveData`, schedules any number of `SpawnGroupData` groups, tracks active enemies and emits spawn requests. It does not instantiate enemies or know about the UI.

### EnemyRegistry

Maintains a lightweight spatial hash that is rebuilt ten times per second. Towers query only nearby cells when an attack becomes ready instead of traversing every enemy node in the scene tree.

### ProjectilePool

Preallocates reusable `SproutProjectile` nodes. Projectile attack strategies borrow nodes from the pool and return them after impact or target invalidation.

### StatusEffectComponent

Stores timed status effects independently from enemy movement and health code. It currently supports replace, refresh and stack policies, periodic damage and movement multipliers.

## Data layer

Editor-authored Resources are stored under `data/`:

```text
data/
├── towers/
│   └── pea_tower.tres
├── enemies/
│   ├── beetle.tres
│   ├── jump_mushroom.tres
│   ├── corrupted_slime.tres
│   └── forest_golem.tres
├── waves/
│   ├── wave_01.tres
│   ├── wave_02.tres
│   ├── wave_03.tres
│   └── wave_04.tres
└── levels/
    └── morning_forest.tres
```

`TowerData`, `EnemyData`, `SpawnGroupData`, `WaveData`, `LevelData` and `StatusEffectData` are custom Resource classes. Content changes no longer require edits to `main.gd`.

## Attack extension point

`SproutTower` delegates attacks to an `AttackStrategy`. The current `ProjectileAttackStrategy` launches pooled projectiles. Future beam, aura, chain, trap and summon strategies can implement the same interface without changing wave or economy code.

## Signal flow

```text
WaveManager enemy_spawn_requested
    -> Main instantiates SproutEnemy
    -> EnemyRegistry registers it

SproutEnemy defeated
    -> EconomySystem earns reward
    -> WaveManager decrements active count

SproutEnemy escaped
    -> BaseHealthSystem takes damage
    -> WaveManager decrements active count

WaveManager wave_completed
    -> EconomySystem earns clear reward
    -> UI enables the next wave
```

## Performance rules

- Towers search only when their cooldown expires.
- Nearby targets are resolved through a spatial registry, not scene-tree group scans.
- Projectiles are pooled and never call `queue_free` during normal reuse.
- UI labels update only after state-change signals.
- Fixed-route enemies do not perform pathfinding.
- The F3 overlay exposes FPS, active enemies and projectile pool use.

## Test boundary

`tests/run_tests.gd` is a dependency-free headless suite. CI validates Resource serialization, economy transactions, base depletion and wave lifecycle before exporting Windows, Linux and Web builds.
