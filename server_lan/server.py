import json
import secrets
import socket
import time

HOST = "0.0.0.0"
PORT = 3001
MAX_PLAYERS = 16
ROOM_CODE_LENGTH = 6

rooms = {}
ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"


def make_code():
    while True:
        code = "".join(secrets.choice(ALPHABET) for _ in range(ROOM_CODE_LENGTH))
        if code not in rooms:
            return code


def clean_name(value):
    value = str(value or "").strip()
    value = "".join(ch for ch in value if ch.isalnum() or ch in " _-")
    return value[:20] or "Player"


def send(sock, addr, message):
    data = json.dumps(message, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
    sock.sendto(data, addr)


def room_info(room):
    return {
        "code": room["code"],
        "host_id": room["host_id"],
        "host_address": room["host_address"],
        "game_port": room["game_port"],
        "mode": room["mode"],
        "team": room["team"],
        "map": room["map"],
        "max_players": MAX_PLAYERS,
        "players": [
            {"id": p["id"], "nickname": p["nickname"]}
            for p in room["players"].values()
        ],
    }


def broadcast(sock, room, message):
    for player in list(room["players"].values()):
        send(sock, player["addr"], message)


def broadcast_state(sock, room):
    broadcast(sock, room, {"type": "room_state", "room": room_info(room)})


def find_player(room, addr):
    for p in room["players"].values():
        if p["addr"] == addr:
            return p
    return None


def remove_player(sock, room, player_id):
    room["players"].pop(player_id, None)
    if room["host_id"] == player_id:
        next_player = next(iter(room["players"].values()), None)
        if next_player:
            room["host_id"] = next_player["id"]
            room["host_address"] = next_player["addr"][0]
            send(sock, next_player["addr"], {"type": "host_changed", "host": True})
    if not room["players"]:
        rooms.pop(room["code"], None)
    else:
        broadcast_state(sock, room)


def handle_create(sock, addr, msg):
    old = find_player_in_any_room(addr)
    if old:
        remove_player(sock, old[0], old[1]["id"])

    player_id = secrets.token_hex(8)
    room = {
        "code": make_code(),
        "host_id": player_id,
        "host_address": addr[0],
        "game_port": int(msg.get("game_port", 24567)),
        "mode": "team" if msg.get("mode") == "team" else "ffa",
        "team": str(msg.get("team", "auto")),
        "map": str(msg.get("map", "construction")),
        "players": {},
        "last_seen": time.time(),
    }
    room["players"][player_id] = {
        "id": player_id,
        "nickname": clean_name(msg.get("nickname")),
        "addr": addr,
        "last_seen": time.time(),
    }
    rooms[room["code"]] = room
    send(sock, addr, {"type": "room_created", "room": room_info(room), "host": True})


def find_player_in_any_room(addr):
    for room in rooms.values():
        for p in room["players"].values():
            if p["addr"] == addr:
                return room, p
    return None


def handle_join(sock, addr, msg):
    old = find_player_in_any_room(addr)
    if old:
        remove_player(sock, old[0], old[1]["id"])

    code = str(msg.get("code", "")).strip().upper()
    room = rooms.get(code)
    if not room:
        send(sock, addr, {"type": "error", "message": "Room not found"})
        return
    if len(room["players"]) >= MAX_PLAYERS:
        send(sock, addr, {"type": "error", "message": "Room is full"})
        return

    player_id = secrets.token_hex(8)
    room["players"][player_id] = {
        "id": player_id,
        "nickname": clean_name(msg.get("nickname")),
        "addr": addr,
        "last_seen": time.time(),
    }
    send(sock, addr, {"type": "room_joined", "room": room_info(room), "host": False})
    broadcast_state(sock, room)


def handle_update(sock, addr, msg):
    found = find_player_in_any_room(addr)
    if not found:
        return
    room, player = found
    if room["host_id"] != player["id"]:
        send(sock, addr, {"type": "error", "message": "Only the host can change room settings"})
        return
    if "mode" in msg:
        room["mode"] = "team" if msg["mode"] == "team" else "ffa"
    if "team" in msg:
        room["team"] = str(msg["team"])
    if "map" in msg:
        room["map"] = str(msg["map"])
    room["last_seen"] = time.time()
    broadcast_state(sock, room)


def handle_start(sock, addr, msg):
    found = find_player_in_any_room(addr)
    if not found:
        return
    room, player = found
    if room["host_id"] != player["id"]:
        send(sock, addr, {"type": "error", "message": "Only the host can start"})
        return
    if len(room["players"]) < 2:
        send(sock, addr, {"type": "error", "message": "At least 2 players are required"})
        return
    broadcast(sock, room, {"type": "match_start", "room": room_info(room)})


def handle_leave(sock, addr):
    found = find_player_in_any_room(addr)
    if found:
        remove_player(sock, found[0], found[1]["id"])


def handle_heartbeat(sock, addr):
    found = find_player_in_any_room(addr)
    if found:
        room, player = found
        player["last_seen"] = time.time()
        send(sock, addr, {"type": "heartbeat_ok", "room": room_info(room)})
    else:
        send(sock, addr, {"type": "server_ok"})


def cleanup(sock):
    now = time.time()
    for room in list(rooms.values()):
        for player in list(room["players"].values()):
            if now - player["last_seen"] > 30:
                remove_player(sock, room, player["id"])


def main():
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    sock.bind((HOST, PORT))

    print("BlockStrike LAN server")
    print(f"UDP: 0.0.0.0:{PORT}")
    print("LAN only: the server does not connect to the internet.")

    last_cleanup = time.time()
    while True:
        if time.time() - last_cleanup > 5:
            cleanup(sock)
            last_cleanup = time.time()

        sock.settimeout(1.0)
        try:
            raw, addr = sock.recvfrom(65535)
        except socket.timeout:
            continue
        except KeyboardInterrupt:
            print("\nStopped.")
            break

        try:
            msg = json.loads(raw.decode("utf-8"))
        except (UnicodeDecodeError, json.JSONDecodeError):
            continue

        msg_type = msg.get("type")
        if msg_type == "discover":
            send(sock, addr, {"type": "server_found", "port": PORT})
        elif msg_type == "create_room":
            handle_create(sock, addr, msg)
        elif msg_type == "join_room":
            handle_join(sock, addr, msg)
        elif msg_type == "update_room":
            handle_update(sock, addr, msg)
        elif msg_type == "start_room":
            handle_start(sock, addr, msg)
        elif msg_type == "leave_room":
            handle_leave(sock, addr)
        elif msg_type == "heartbeat":
            handle_heartbeat(sock, addr)


if __name__ == "__main__":
    main()
