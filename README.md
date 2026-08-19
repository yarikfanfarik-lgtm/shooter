# BlockStrike

A block-styled tactical 3D shooter for Windows and Android.

## Current foundation

- Godot 4 project with one shared codebase for Windows `.exe` and Android `.apk`.
- Listen-server networking: the room creator hosts the match.
- 16-player room limit.
- Room creation and direct join by IP/port.
- Modes: Free For All, Team Battle, and Play vs Bots.
- Team selection: Auto, Red, Blue.
- Procedural block-style maps: Construction, City, Industrial Zone.
- Economy, starting loadout, kill rewards and headshot rewards.
- Weapon data for knife, pistol, AK-47, shotgun, sniper, minigun, flamethrower, grenade, flash, smoke and mine.
- Settings for sensitivity, FOV and graphics.
- Mobile HUD positions/sizes saved in `user://settings.cfg`.
- Private developer tools placeholder for local testing.

## Networking note

The current prototype uses a listen-server. For internet games, the host must be reachable on the selected UDP port (default `24567`) or be port-forwarded. A public room browser requires a small master-server service; the Godot client already separates room hosting/joining so that service can be added without replacing the listen-server model.

## Build

Open the project in Godot 4 and import `project.godot`. Desktop uses the GL Compatibility renderer to keep the same project viable on lower-end PCs and Android.

The export presets and CI workflow are intended to be extended with the Android SDK and Godot export templates on the build runner.
