# BlockStrike

Clean rewrite of the project.

## Client

Godot 4.7 project. The first milestone is a local playable 3D match with one player and seven bots.

Controls: WASD, mouse, left click, R, Space.

## LAN server

Python server is in `server/server.py` and uses only Python's standard library.

Run:

```text
cd server
python server.py
```

It listens on UDP 3001 and is intended for one local Wi-Fi/LAN network.

The game client will use room codes for LAN discovery; IP addresses are not part of the player-facing UI.
