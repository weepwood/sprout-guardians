# Greed arena redesign

The default game mode is rebuilt as a single-room autonomous arena roguelite. The fixed lane, build slots, path goal, leaked-enemy damage, and manual tower operations are no longer part of the default experience.

## Core run loop

`starter plant squad → automatic arena wave → coins and greed score → surprise choice → automatic familiar evolution → elite wave → further mutations → boss wave → floor clear`

The player does not place, move, upgrade, aim, or start waves. During combat the meaningful input is selecting one of the offered surprise drops, deals, or future route branches.

## Implemented Greed floor

A floor contains one combat room with four spawn doors and a moving central garden core.

- Waves 1–4: normal escalation
- Wave 5: elite rupture
- Waves 6–8: higher-density escalation
- Wave 9: miniboss pair
- Wave 10: floor boss
- Every non-final wave: guaranteed three-choice mutation reward
- Every reward: one familiar also evolves automatically
- Normal wave clear: core heals 1 health
- Elite and miniboss wave clear: core heals 2 health

Waves start automatically after a short countdown. Enemy movement is free-form pursuit rather than path following.

## Starter-power safety contract

The game must never require a reward to become capable of earning its first reward.

- Start with three combat familiars: Pea Shooter, Spore Bloom, and Frost Petal.
- Starter combined sustained DPS must be at least 2.0× the wave-1 enemy health spawn rate.
- The current balance margin is approximately 3.0×.
- Wave 1 must project to clear under 18 seconds using starter stats and no player choices.
- Every wave must project to clear under 18 seconds using only guaranteed automatic familiar evolution; lucky mutation effects are not counted.
- Every cleared wave guarantees a surprise choice, independent of chest progress.
- If a wave remains active for 20 seconds, Garden Fury begins increasing familiar damage by 12% every 5 seconds, capped at +120%.
- If no enemy has died for 12 seconds, targeting range increases by 60% and attack intervals are multiplied by 0.68 until a kill occurs.
- Balance tests calculate the starter and minimum-progression DPS budgets and fail CI if the contract is broken.

## Autonomous combat actors

### Garden core

- Moves slowly inside a safe central region using deterministic threat avoidance.
- Has health and temporary contact invulnerability.
- Draws enemies toward itself.
- Recovers health between waves so chip damage cannot create an unavoidable long-run failure.

### Plant familiars

- Orbit or trail the core instead of occupying tower slots.
- Automatically acquire targets in all directions.
- Reposition continuously to maintain spacing and line of fire.
- Preserve three readable roles: direct damage, area damage, and control.
- Evolve after every reward choice without requiring purchase-button upgrades.

### Enemies

- Spawn from north, south, east, and west doors.
- Chase the core using free movement and local separation.
- Deal contact damage and recoil after impact.
- Elite and boss waves use distinct health, scale, color, rewards, and impact feedback.

## Reward model

Each non-final wave completion opens a three-choice surprise panel. The reward does not depend on killing enough enemies to fill a separate chest meter.

Current rewards reuse the seeded blessing system for damage, attack speed, range, economy, status effects, critical hits, and jackpots. Later iterations will add rule-changing relics, projectile transformations, formation rules, temporary overdrive, and cursed bargains.

Seeded randomness, rarity weights, duplicate evolution, pity, and run history remain mandatory.

## Pixel-impact language

The arena uses bounded integer-aligned particles, directional hit sparks, enemy squash, death fragmentation, critical bursts, contact recoil, and short major-event flashes. The implementation borrows only general impact principles from high-energy pixel action games and does not copy protected assets or animations.

## Default entry flow

The main menu starts a new arena run directly. The old campaign and level-select resources remain in the repository temporarily for regression comparison, but they are not part of the default player flow. `scenes/main.tscn` points to the Greed arena implementation, and no tower-defense UI is visible in the default mode.