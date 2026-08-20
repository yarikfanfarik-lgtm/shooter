# BlockStrike LAN server

This is the LAN-only room/master server for BlockStrike.

## Run

Windows:

```bat
cd server_lan
python server.py
```

No `pip install` is required. The server uses only the Python standard library.

## Network

The server listens on UDP `3001` and is intended for one local network (same Wi-Fi/Ethernet). The game discovers it automatically with UDP broadcast.

The server manages:

- room codes;
- up to 16 players per room;
- nicknames;
- room mode and map;
- lobby state synchronization;
- host change;
- START when at least 2 players are present.

The actual game traffic continues to use the Godot ENet listen-server hosted by the room creator on UDP `24567`.

On Windows, allow Python through the firewall on **Private networks** when prompted. Both UDP 3001 and the game port 24567 must be allowed on the LAN.
