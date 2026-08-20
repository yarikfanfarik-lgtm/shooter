# BlockStrike Node.js server

This is the room/master server for BlockStrike. It keeps the public room list, room codes and player lists. A room can contain up to 16 players.

## Run

From the `server` folder:

```bash
npm install
npm start
```

The server listens on port `3000` by default.

- HTTP health check: `http://localhost:3000/health`
- HTTP room list: `http://localhost:3000/rooms`
- WebSocket: `ws://localhost:3000`

Set a different port with `PORT=3000` (Windows PowerShell: `$env:PORT=3000`) before `npm start`.

## Protocol

WebSocket messages are JSON.

Client -> server:

- `{ "type": "create_room", "nickname": "Player", "mode": "ffa", "map": "construction" }`
- `{ "type": "join_room", "code": "ABC123", "nickname": "Player" }`
- `{ "type": "list_rooms" }`
- `{ "type": "start_room" }`
- `{ "type": "leave_room" }`

Server -> client:

- `room_created`
- `room_joined`
- `room_state`
- `host_changed`
- `room_list`
- `match_start`
- `error`

The game client can use the room code without asking the player to type an IP address. The actual WebSocket address is configured by the game/server deployment.
