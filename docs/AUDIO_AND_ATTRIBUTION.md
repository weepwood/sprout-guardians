# Audio and Attribution

## Audio foundation

The current content slice does not bundle third-party audio files. `ProceduralAudioManager` generates short 16-bit PCM waveforms at runtime and routes them through `Music` and `SFX` audio buses.

Implemented events:

- UI click
- tower build
- tower upgrade
- tower sale
- wave start
- wave clear
- sprout damage
- Forest Golem phase transition
- victory
- defeat

A lightweight looping forest melody is also synthesized at runtime. The system exposes music and sound-effect enable switches so later settings screens can control both categories without changing gameplay code.

## Visual attribution

The current forest background, towers, enemies, projectiles, status feedback, panels, and icons are drawn procedurally with Godot canvas APIs. No commercial-game sprites, copied TileSets, fonts, music, or sound effects are included.

Future external art or audio must be recorded here with:

- asset title;
- creator;
- source;
- license;
- modification notes;
- repository paths where the asset is used.
