# Greed arena redesign

The default game mode is being rebuilt as a single-room autonomous arena roguelite. The fixed lane, build slots, path goal, leaked-enemy damage, and manual tower operations are no longer part of the default experience.

## Core run loop

`starter plant squad → automatic arena wave → coins and greed meter → surprise choice → automatic formation evolution → elite wave → shop or cursed deal → boss wave → next floor`

The player does not place, move, upgrade, aim, or start waves. During combat the only meaningful input is selecting one of the offered surprise drops, deals, or route branches.

## Greed-mode structure

A floor contains one combat room with four spawn doors and a central garden core.

- Waves 1–4: normal escalation
- Wave 5: elite rupture
- Intermission: surprise choice and optional shop/deal
- Waves 6–8: higher-density escalation
- Wave 9: miniboss
- Wave 10: floor boss
- Completion reward: relic choice and next-floor transition

Waves start automatically after a short countdown. Enemy movement is free-form pursuit rather than path following.

## Starter-power safety contract

The game must never require a reward to become capable of earning its first reward.

- Start with three combat plants: Pea Shooter, Spore Bloom, and Frost Petal.
- Starter combined sustained DPS must be at least 2.0× the wave-1 enemy health spawn rate.
- Wave 1 must clear under 18 seconds using starter stats and no player choices.
- Every cleared wave guarantees a surprise choice, independent of chest progress.
- If a wave remains active for 20 seconds, Garden Fury begins increasing plant damage by 12% every 5 seconds, capped at +120%.
- If no enemy has died for 12 seconds, targeting range and projectile speed receive a temporary rescue boost.
- Balance tests calculate the starter DPS budget and fail CI if the contract is broken.

## Autonomous combat actors

### Garden core

- Moves slowly inside a safe central region using deterministic threat avoidance.
- Has health and temporary contact invulnerability.
- Draws enemies toward itself.

### Plant familiars

- Orbit or trail the core instead of occupying tower slots.
- Automatically acquire targets in all directions.
- Reposition continuously to maintain spacing and line of fire.
- Preserve three readable roles: direct damage, area/status damage, and control.
- Evolve from surprise choices rather than purchase-button upgrades.

### Enemies

- Spawn from north, south, east, and west doors.
- Chase the core or pressure the closest familiar.
- Deal contact damage and recoil after impact.
- Later variants may dash, shoot, split, orbit, or create hazards.

## Reward model

Each wave completion opens a three-choice surprise panel. Rewards include:

- plant mutations
- relics
- projectile transformations
- formation rules
- temporary overdrive
- coin jackpots
- cursed bargains

Choices should change behavior, not only percentages. Seeded randomness, rarity weights, duplicate evolution, pity, and run history remain mandatory.

## Pixel-impact language

The arena uses bounded integer-aligned particles, directional hit sparks, enemy squash, death fragmentation, critical bursts, contact recoil, and short hit-stop for major events. The implementation borrows only general impact principles from high-energy pixel action games and does not copy protected assets or animations.

## Migration

Legacy tower-defense scripts and Morning Forest resources remain in the repository temporarily for regression comparison, but `scenes/main.tscn` must point to the new greed arena. No tower-defense UI is visible in the default mode.