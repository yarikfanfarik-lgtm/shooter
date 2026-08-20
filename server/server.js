const http = require('http');
const crypto = require('crypto');
const { WebSocketServer } = require('ws');

const PORT = Number(process.env.PORT || 3000);
const HOST = process.env.HOST || '0.0.0.0';
const MAX_PLAYERS = 16;
const ROOM_CODE_LENGTH = 6;
const rooms = new Map();

function makeCode() {
  const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  let code;
  do {
    code = '';
    for (let i = 0; i < ROOM_CODE_LENGTH; i++) {
      code += alphabet[crypto.randomInt(0, alphabet.length)];
    }
  } while (rooms.has(code));
  return code;
}

function cleanName(name) {
  const value = String(name || '').trim().replace(/[^a-zA-Z0-9_А-Яа-яЁё -]/g, '');
  return value.slice(0, 20) || 'Player';
}

function roomInfo(room) {
  return {
    code: room.code,
    host: room.host,
    map: room.map,
    mode: room.mode,
    maxPlayers: MAX_PLAYERS,
    players: [...room.players.values()].map(p => ({ id: p.id, nickname: p.nickname }))
  };
}

function send(ws, type, data = {}) {
  if (ws.readyState === 1) ws.send(JSON.stringify({ type, ...data }));
}

function broadcast(room, type, data = {}) {
  for (const player of room.players.values()) send(player.ws, type, data);
}

function broadcastRoom(room) {
  broadcast(room, 'room_state', { room: roomInfo(room) });
}

function removePlayer(room, player) {
  room.players.delete(player.id);
  if (room.host === player.id) {
    const next = room.players.values().next().value;
    room.host = next ? next.id : null;
    if (next) send(next.ws, 'host_changed', { host: true });
  }
  if (room.players.size === 0) {
    rooms.delete(room.code);
  } else {
    broadcastRoom(room);
  }
}

function leaveCurrentRoom(ws) {
  if (!ws.roomCode) return;
  const room = rooms.get(ws.roomCode);
  ws.roomCode = null;
  if (!room) return;
  const player = room.players.get(ws.playerId);
  if (player) removePlayer(room, player);
}

function createRoom(ws, msg) {
  leaveCurrentRoom(ws);
  const code = makeCode();
  const id = crypto.randomUUID();
  const room = {
    code,
    host: id,
    mode: msg.mode === 'team' ? 'team' : 'ffa',
    map: String(msg.map || 'construction'),
    players: new Map()
  };
  const player = { id, nickname: cleanName(msg.nickname), ws };
  room.players.set(id, player);
  rooms.set(code, room);
  ws.roomCode = code;
  ws.playerId = id;
  send(ws, 'room_created', { room: roomInfo(room), host: true });
}

function joinRoom(ws, msg) {
  leaveCurrentRoom(ws);
  const code = String(msg.code || '').trim().toUpperCase();
  const room = rooms.get(code);
  if (!room) return send(ws, 'error', { message: 'Room not found' });
  if (room.players.size >= MAX_PLAYERS) return send(ws, 'error', { message: 'Room is full' });

  const id = crypto.randomUUID();
  const player = { id, nickname: cleanName(msg.nickname), ws };
  room.players.set(id, player);
  ws.roomCode = code;
  ws.playerId = id;
  send(ws, 'room_joined', { room: roomInfo(room), host: room.host === id });
  broadcastRoom(room);
}

function startRoom(ws) {
  const room = rooms.get(ws.roomCode);
  if (!room) return send(ws, 'error', { message: 'You are not in a room' });
  if (room.host !== ws.playerId) return send(ws, 'error', { message: 'Only the host can start' });
  if (room.players.size < 2) return send(ws, 'error', { message: 'At least 2 players are required' });
  broadcast(room, 'match_start', { mode: room.mode, map: room.map, room: roomInfo(room) });
}

function listRooms(ws) {
  const list = [...rooms.values()].map(room => ({
    code: room.code,
    mode: room.mode,
    map: room.map,
    players: room.players.size,
    maxPlayers: MAX_PLAYERS
  })).filter(r => r.players < r.maxPlayers);
  send(ws, 'room_list', { rooms: list });
}

const server = http.createServer((req, res) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Content-Type', 'application/json; charset=utf-8');
  if (req.method === 'GET' && req.url === '/health') {
    return res.end(JSON.stringify({ ok: true, rooms: rooms.size, players: [...rooms.values()].reduce((n, r) => n + r.players.size, 0) }));
  }
  if (req.method === 'GET' && req.url === '/rooms') {
    return res.end(JSON.stringify([...rooms.values()].map(room => ({ code: room.code, mode: room.mode, map: room.map, players: room.players.size, maxPlayers: MAX_PLAYERS }))));
  }
  res.statusCode = 404;
  res.end(JSON.stringify({ error: 'Not found' }));
});

const wss = new WebSocketServer({ server });

wss.on('connection', ws => {
  ws.roomCode = null;
  ws.playerId = null;

  send(ws, 'hello', { name: 'BlockStrike Server', maxPlayers: MAX_PLAYERS });

  ws.on('message', raw => {
    let msg;
    try { msg = JSON.parse(raw.toString()); } catch { return send(ws, 'error', { message: 'Invalid JSON' }); }
    switch (msg.type) {
      case 'create_room': createRoom(ws, msg); break;
      case 'join_room': joinRoom(ws, msg); break;
      case 'list_rooms': listRooms(ws); break;
      case 'start_room': startRoom(ws); break;
      case 'leave_room': leaveCurrentRoom(ws); break;
      default: send(ws, 'error', { message: `Unknown message type: ${msg.type}` });
    }
  });

  ws.on('close', () => leaveCurrentRoom(ws));
});

server.listen(PORT, HOST, () => {
  console.log(`BlockStrike server listening on http://localhost:${PORT}`);
  console.log(`WebSocket endpoint: ws://localhost:${PORT}`);
  console.log(`Max players per room: ${MAX_PLAYERS}`);
});
