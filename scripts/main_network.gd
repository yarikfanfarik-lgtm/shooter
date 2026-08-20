extends "res://scripts/main.gd"

const MASTER_SERVER_URL := "ws://127.0.0.1:3000"
var master_ws: WebSocketPeer
var master_action := ""
var pending_room_code := ""
var pending_game_host := ""
var pending_game_port := 24567

func _ready() -> void:
    super._ready()
    for child in menu.get_children():
        if child is Button and child.text == "JOIN BY CODE / IP":
            child.text = "JOIN ROOM"
    status_label.text = "Master server: offline"

func _process(_delta: float) -> void:
    if not master_ws:
        return
    master_ws.poll()
    if master_ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
        while master_ws.get_available_packet_count() > 0:
            var packet := master_ws.get_packet()
            if master_ws.was_string_packet():
                _on_master_message(packet.get_string_from_utf8())
    elif master_ws.get_ready_state() == WebSocketPeer.STATE_CLOSED:
        master_ws = null
        if mode == "lobby" and lobby_status_label:
            lobby_status_label.text = "Room server disconnected"

func _master_connect(action: String) -> void:
    master_action = action
    master_ws = WebSocketPeer.new()
    var err := master_ws.connect_to_url(MASTER_SERVER_URL)
    if err != OK:
        master_ws = null
        status_label.text = "Room server unavailable"

func _master_send(data: Dictionary) -> void:
    if master_ws and master_ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
        master_ws.send_text(JSON.stringify(data))

func _create_room() -> void:
    if _current_nickname().is_empty():
        return
    peer = ENetMultiplayerPeer.new()
    var err := peer.create_server(DEFAULT_PORT, MAX_PLAYERS)
    if err != OK:
        status_label.text = "Game server error: %s" % err
        return
    multiplayer.multiplayer_peer = peer
    server_started = true
    player_names.clear()
    player_names[1] = _current_nickname()
    room_code = "CONNECTING..."
    status_label.text = "Creating room..."
    _master_connect("create")

func _join_room() -> void:
    var dialog := AcceptDialog.new()
    dialog.title = "Join room"
    var box := VBoxContainer.new()
    var code_edit := LineEdit.new()
    code_edit.placeholder_text = "Room code, example K7P4X2"
    code_edit.max_length = 6
    code_edit.text = ""
    box.add_child(Label.new())
    box.get_child(0).text = "ROOM CODE"
    box.add_child(code_edit)
    dialog.add_child(box)
    dialog.confirmed.connect(func():
        var code := code_edit.text.strip_edges().to_upper()
        if code.length() != 6:
            status_label.text = "Enter a 6-character room code"
            dialog.queue_free()
            return
        pending_room_code = code
        status_label.text = "Finding room %s..." % code
        _master_connect("join")
        dialog.queue_free()
    )
    dialog.canceled.connect(func(): dialog.queue_free())
    add_child(dialog)
    dialog.popup_centered(Vector2(420, 190))

func _on_master_message(text: String) -> void:
    var parsed = JSON.parse_string(text)
    if typeof(parsed) != TYPE_DICTIONARY:
        return
    var msg: Dictionary = parsed
    match str(msg.get("type", "")):
        "hello":
            if master_action == "create":
                _master_send({"type":"create_room", "nickname":_current_nickname(), "game_port":DEFAULT_PORT, "mode":match_mode, "map":map_name})
            elif master_action == "join":
                _master_send({"type":"join_room", "code":pending_room_code, "nickname":_current_nickname()})
        "room_created":
            var room: Dictionary = msg.get("room", {})
            _apply_room_info(room)
            lobby_host = true
            _show_lobby(true)
            lobby_status_label.text = "Room created • waiting for players"
        "room_joined":
            var joined_room: Dictionary = msg.get("room", {})
            _apply_room_info(joined_room)
            lobby_host = false
            _show_lobby(false)
            _connect_to_hidden_host(str(joined_room.get("hostAddress", "")), int(joined_room.get("gamePort", DEFAULT_PORT)))
        "room_state":
            var state_room: Dictionary = msg.get("room", {})
            _apply_room_info(state_room)
            if lobby_status_label:
                lobby_status_label.text = "Players: %d/%d" % [player_names.size(), MAX_PLAYERS]
        "host_changed":
            lobby_host = bool(msg.get("host", false))
            if lobby_start_button:
                _set_lobby_start_state()
        "error":
            status_label.text = str(msg.get("message", "Room server error"))
            if lobby_status_label:
                lobby_status_label.text = status_label.text

func _apply_room_info(room: Dictionary) -> void:
    room_code = str(room.get("code", room_code))
    pending_game_host = str(room.get("hostAddress", pending_game_host))
    pending_game_port = int(room.get("gamePort", DEFAULT_PORT))
    match_mode = "team" if str(room.get("mode", "ffa")) == "team" else "ffa"
    var players: Array = room.get("players", [])
    player_names.clear()
    for player in players:
        if typeof(player) == TYPE_DICTIONARY:
            player_names[str(player.get("id", ""))] = str(player.get("nickname", "Player"))
    if lobby_code_label:
        lobby_code_label.text = "ROOM CODE: %s" % room_code
    _refresh_lobby_players()

func _connect_to_hidden_host(host: String, port: int) -> void:
    if host.is_empty():
        status_label.text = "Host address was not available"
        return
    peer = ENetMultiplayerPeer.new()
    var err := peer.create_client(host, port)
    if err != OK:
        status_label.text = "Unable to connect to room"
        return
    multiplayer.multiplayer_peer = peer
    status_label.text = "Connecting to room %s..." % room_code

func _leave_lobby() -> void:
    if master_ws and master_ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
        _master_send({"type":"leave_room"})
    super._leave_lobby()
    pending_room_code = ""
    pending_game_host = ""

func _on_connection_failed() -> void:
    status_label.text = "Unable to connect to room"
    super._on_connection_failed()
