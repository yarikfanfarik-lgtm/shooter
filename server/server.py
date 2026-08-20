#!/usr/bin/env python3
import json
import secrets
import socket
import time

HOST = "0.0.0.0"
PORT = 3001
MAX_PLAYERS = 16
ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
rooms = {}
clients = {}


def code():
    while True:
        value = "".join(secrets.choice(ALPHABET) for _ in range(6))
        if value not in rooms:
            return value


def send(sock, addr, message):
    sock.sendto(json.dumps(message, ensure_ascii=False, separators=(",", ":")).encode(), addr)


def info(room):
    return {
        "code": room["code"],
        "host": room["host"],
        "mode": room["mode"],
        "map": room["map"],
        "players": [{"id": p["id"], "nickname": p["nickname"]} for p in room["players"].values()],
        "max_players": MAX_PLAYERS,
    }


def broadcast(sock, room, message):
    for p in room["players"].values():
        send(sock, p["addr"], message)


def room_state(sock, room):
    broadcast(sock, room, {"type": "room_state", "room": info(room)})


def find_client(addr):
    return clients.get(addr)


def leave(sock, addr):
    client = clients.pop(addr, None)
    if not client:
        return
    room = rooms.get(client["room"])
    if not room:
        return
    room["players"].pop(client["id"], None)
    if room["host"] == client["id"]:
        next_player = next(iter(room["players"].values()), None)
        if next_player:
            room["host"] = next_player["id"]
            send(sock, next_player["addr"], {"type": "host_changed"})
    if room["players"]:
        room_state(sock, room)
    else:
        rooms.pop(room["code"], None)


def create(sock, addr, msg):
    leave(sock, addr)
    player_id = secrets.token_hex(8)
    room_code = code()
    room = {
        "code": room_code,
        "host": player_id,
        "mode": msg.get("mode", "ffa"),
        "map": msg.get("map", "construction"),
        "players": {},
    }
    player = {"id": player_id, "nickname": str(msg.get("nickname", "Player"))[:20], "addr": addr}
    room["players"][player_id] = player
    rooms[room_code] = room
    clients[addr] = {"room": room_code, "id": player_id}
    send(sock, addr, {"type": "room_created", "room": info(room)})


def join(sock, addr, msg):
    leave(sock, addr)
    room = rooms.get(str(msg.get("code", "")).upper())
    if not room:
        return send(sock, addr, {"type": "error", "message": "Room not found"})
    if len(room["players"]) >= MAX_PLAYERS:
        return send(sock, addr, {"type": "error", "message": "Room is full"})
    player_id = secrets.token_hex(8)
    player = {"id": player_id, "nickname": str(msg.get("nickname", "Player"))[:20], "addr": addr}
    room["players"][player_id] = player
    clients[addr] = {"room": room["code"], "id": player_id}
    send(sock, addr, {"type": "room_joined", "room": info(room)})
    room_state(sock, room)


def update(sock, addr, msg):
    client = find_client(addr)
    if not client:
        return
    room = rooms.get(client["room"])
    if not room or room["host"] != client["id"]:
        return send(sock, addr, {"type": "error", "message": "Only host can change settings"})
    if msg.get("mode") in ("ffa", "team"):
        room["mode"] = msg["mode"]
    if msg.get("map") in ("construction", "city", "industrial"):
        room["map"] = msg["map"]
    room_state(sock, room)


def start(sock, addr):
    client = find_client(addr)
    if not client:
        return
    room = rooms.get(client["room"])
    if not room or room["host"] != client["id"]:
        return send(sock, addr, {"type": "error", "message": "Only host can start"})
    if len(room["players"]) < 2:
        return send(sock, addr, {"type": "error", "message": "Need at least 2 players"})
    broadcast(sock, room, {"type": "match_start", "room": info(room)})


def main():
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
    sock.bind((HOST, PORT))
    print(f"BlockStrike Python LAN server: udp://0.0.0.0:{PORT}")
    print("LAN only. Press Ctrl+C to stop.")
    while True:
        try:
            raw, addr = sock.recvfrom(65535)
        except KeyboardInterrupt:
            break
        try:
            msg = json.loads(raw.decode())
        except Exception:
            continue
        kind = msg.get("type")
        if kind == "discover":
            send(sock, addr, {"type": "server_found"})
        elif kind == "create_room":
            create(sock, addr, msg)
        elif kind == "join_room":
            join(sock, addr, msg)
        elif kind == "update_room":
            update(sock, addr, msg)
        elif kind == "start_room":
            start(sock, addr)
        elif kind == "leave_room":
            leave(sock, addr)
        elif kind == "ping":
            send(sock, addr, {"type": "pong", "time": time.time()})


if __name__ == "__main__":
    main()
