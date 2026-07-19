# First Complete Content Slice

## Tower roles

- **Pea Tower** — inexpensive single-target damage with strong upgrade scaling.
- **Mushroom Lamp** — slower splash attacks that apply stacking poison; strongest at bends and dense groups.
- **Ice Flower** — long-range control that refreshes a movement slow and gives damage towers more time.

## Enemy roles

- **Beetle** — baseline enemy used to establish economy and targeting.
- **Jump Mushroom** — fast pressure unit that tests slowing coverage.
- **Corrupted Slime** — durable medium-speed unit that rewards concentrated damage.
- **Stone Beast** — slow armored unit; each direct hit is reduced by armor, so poison and sustained upgrades are important.
- **Forest Golem** — final boss with phase transitions at 70% and 40% health.

## Forest Golem phases

Each phase transition:

1. increases the boss movement-speed multiplier;
2. adds phase armor;
3. changes the boss body palette;
4. emits a disruption pulse;
5. temporarily disables towers within the configured radius.

All thresholds, multipliers, armor bonuses, colors, pulse radius, and disable duration are stored in `data/enemies/forest_golem.tres`.

## Ten-wave pacing

1. Beetles introduce the basic route.
2. Jump Mushrooms introduce speed pressure.
3. Corrupted Slimes introduce durable groups.
4. Stonewall introduces armor.
5. Toxic Rush mixes fast and durable units.
6. Armored Column combines armor with a light screen.
7. Threefold Pressure requires all three tower roles.
8. Mist Convergence creates dense splash opportunities.
9. Last Guard is the final economy and upgrade check.
10. Forest Golem introduces phase disruption with supporting enemies.

## Player guidance

The first-run onboarding teaches four actions without blocking the map:

1. choose a tower;
2. build on a green slot;
3. start a wave and read the preview;
4. select and upgrade a tower.

The next-wave panel lists enemy names and counts. Tactical hints are stored on each `WaveData` resource and are displayed when the wave starts.
