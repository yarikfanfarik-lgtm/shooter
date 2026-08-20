extends "res://scripts/main.gd"

const LAN_SERVER_PORT := 3001
const DISCOVERY_BROADCAST := "255.255.255.255"
const HEARTBEAT_INTERVAL := 5.0

var lan_udp: PacketPeerUDP
var lan_server_address := ""
var lan_action := ""
var pending_room_code := ""
var pending_game_host := ""
var pending_game_port := 24567
var heartbeat_timer := 0.0

func _ready() -> void:
    super._ready()
    for child in menu.get_children():
        if child is Button and child.text == "JOIN BY CODE / IP":
            child.text = "JOIN ROOM"
    lan_udp = PacketPeerUDP.new()
    var err := lan_udp.bind(0)
    if err != OK:
        status_label.text = "LAN networking unavailable"
    else:
        lan_udp.set_broadcast_enabled(true)
        status_label.text = "Searching for LAN server..."
        _discover_lan_server()

func _process(delta: float) -> void:
    if not lan_udp:
        return
    heartbeat_timer += delta
    if heartbeat_timer >= HEARTBEAT_INTERVAL:
        heartbeat_timer = 0.0
        if not lan_server_address.is_empty() and not pending_room_code.is_empty():
            _lan_send({"type":"heartbeat"})
        elif lan_server_address.is_empty() and mode == "menu":
            _discover_lan_server()
    while lan_udp.get_available_packet_count() > 0:
        var packet := lan_udp.get_packet()
        _handle_lan_packet(packet.get_string_from_utf8(), lan_udp.get_packet_ip(), lan_udp.get_packet_port())

func _discover_lan_server() -> void:
    if not lan_udp:
        return
    lan_action = "discover"
    lan_udp.set_broadcast_enabled(true)
    lan_udp.set_dest_address(DISCOVERY_BROADCAST, LAN_SERVER_PORT)
    lan_udp.put_packet(JSON.stringify({"type":"discover"}).to_utf8_buffer())

func _lan_connect(address: String) -> void:
    lan_server_address = address
    lan_udp.set_dest_address(lan_server_address, LAN_SERVER_PORT)

func _lan_send(message: Dictionary) -> void:
    if not lan_udp or lan_server_address.is_empty():
        return
    lan_udp.set_dest_address(lan_server_address, LAN_SERVER_PORT)
    lan_udp.put_packet(JSON.stringify(message).to_utf8_buffer())

func _create_room() -> void:
    var nickname := _current_nickname()
    if nickname.is_empty():
        status_label.text = "Enter a nickname first"
        return
    if not lan_udp:
        status_label.text = "LAN networking unavailable"
        return
    peer = ENetMultiplayerPeer.new()
    var err := peer.create_server(DEFAULT_PORT, MAX_PLAYERS)
    if err != OK:
        status_label.text = "Game server error: %s" % err
        return
    multiplayer.multiplayer_peer = peer
    server_started = true
    player_names.clear()
    player_names[1] = nickname
    room_code = "------"
    pending_game_host = ""
    status_label.text = "Creating LAN room..."
    if lan_server_address.is_empty():
        lan_action = "create"
        _discover_lan_server()
    else:
        _lan_send({"type":"create_room", "nickname":nickname, "game_port":DEFAULT_PORT, "mode":match_mode, "team":team, "map":map_name})

func _join_room() -> void:
    if not lan_udp:
        status_label.text = "LAN networking unavailable"
        return
    var dialog := AcceptDialog.new()
    dialog.title = "Join room"
    var box := VBoxContainer.new()
    var label := Label.new()
    label.text = "ROOM CODE"
    box.add_child(label)
    var code_edit := LineEdit.new()
    code_edit.placeholder_text = "Example: K7P4X2"
    code_edit.max_length = 6
    code_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
    box.add_child(code_edit)
    dialog.add_child(box)
    dialog.confirmed.connect(func():
        var code := code_edit.text.strip_edges().to_upper()
        if code.length() != 6:
            status_label.text = "Enter a 6-character room code"
            dialog.queue_free()
            return
        if _current_nickname().is_empty():
            status_label.text = "Enter a nickname first"
            dialog.queue_free()
            return
        pending_room_code = code
        lan_action = "join"
        status_label.text = "Finding LAN room %s..." % code
        if lan_server_address.is_empty():
            _discover_lan_server()
        else:
            _lan_send({"type":"join_room", "code":pending_room_code, "nickname":_current_nickname()})
        dialog.queue_free()
    )
    dialog.canceled.connect(func(): dialog.queue_free())
    add_child(dialog)
    dialog.popup_centered(Vector2(420, 190))

func _handle_lan_packet(text: String, source_address: String, _source_port: int) -> void:
    var parsed = JSON.parse_string(text)
    if typeof(parsed) != TYPE_DICTIONARY:
        return
    var msg: Dictionary = parsed
    var msg_type := str(msg.get("type", ""))
    if msg_type == "server_found":
        _lan_connect(source_address)
        if lan_action == "create":
            _lan_send({"type":"create_room", "nickname":_current_nickname(), "game_port":DEFAULT_PORT, "mode":match_mode, "team":team, "map":map_name})
        elif lan_action == "join" and not pending_room_code.is_empty():
            _lan_send({"type":"join_room", "code":pending_room_code, "nickname":_current_nickname()})
        elif lan_action == "discover":
            status_label.text = "LAN server found"
        return

    match msg_type:
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
            _connect_to_hidden_host(pending_game_host, pending_game_port)
        "room_state":
            var state_room: Dictionary = msg.get("room", {})
            _apply_room_info(state_room)
            if lobby_status_label:
                lobby_status_label.text = "Players: %d/%d" % [player_names.size(), MAX_PLAYERS]
        "host_changed":
            lobby_host = bool(msg.get("host", false))
            if lobby_start_button:
                _set_lobby_start_state()
        "heartbeat_ok":
            var heartbeat_room: Dictionary = msg.get("room", {})
            _apply_room_info(heartbeat_room)
        "error":
            status_label.text = str(msg.get("message", "LAN room server error"))
            if lobby_status_label:
                lobby_status_label.text = status_label.text

func _apply_room_info(room: Dictionary) -> void:
    room_code = str(room.get("code", room_code))
    pending_game_host = str(room.get("host_address", pending_game_host))
    pending_game_port = int(room.get("game_port", DEFAULT_PORT))
    match_mode = "team" if str(room.get("mode", "ffa")) == "team" else "ffa"
    team = str(room.get("team", team))
    map_name = str(room.get("map", map_name))
    var players: Array = room.get("players", [])
    player_names.clear()
    for player in players:
        if typeof(player) == TYPE_DICTIONARY:
            var player_id := str(player.get("id", ""))
            player_names[player_id] = str(player.get("nickname", "Player"))
    if lobby_code_label:
        lobby_code_label.text = "ROOM CODE: %s" % room_code
    _refresh_lobby_players()
    _sync_lobby_controls()

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

func _show_lobby(is_host: bool) -> void:
    super._show_lobby(is_host)
    _sync_lobby_controls()
    if lobby_dialog:
        var selects := lobby_dialog.find_children("", "OptionButton", true, false)
        if selects.size() >= 3:
            for control in selects:
                control.item_selected.connect(_on_lobby_setting_changed)

func _on_lobby_setting_changed(_index: int) -> void:
    if not lobby_host:
        return
    var selects := lobby_dialog.find_children("", "OptionButton", true, false) if lobby_dialog else []
    if selects.size() < 3:
        return
    match_mode = "team" if selects[0].selected == 1 else "ffa"
    team = ["auto", "red", "blue"][selects[1].selected]
    map_name = ["construction", "city", "industrial"][selects[2].selected]
    _lan_send({"type":"update_room", "mode":match_mode, "team":team, "map":map_name})

func _sync_lobby_controls() -> void:
    if not lobby_dialog:
        return
    var selects := lobby_dialog.find_children("", "OptionButton", true, false)
    if selects.size() < 3:
        return
    selects[0].selected = 1 if match_mode == "team" else 0
    selects[1].selected = {"auto":0, "red":1, "blue":2}.get(team, 0)
    selects[2].selected = {"construction":0, "city":1, "industrial":2}.get(map_name, 0)
    selects[0].disabled = not lobby_host
    selects[1].disabled = not lobby_host
    selects[2].disabled = not lobby_host

func _set_lobby_start_state() -> void:
    if not lobby_start_button:
        return
    var connected_players := 1 + multiplayer.get_peers().size() if multiplayer.multiplayer_peer else 1
    lobby_start_button.visible = lobby_host
    lobby_start_button.disabled = not lobby_host or connected_players < 2
    lobby_start_button.tooltip_text = "Need at least 2 connected players" if lobby_start_button.disabled else "Start the match"

func _leave_lobby() -> void:
    if not lan_server_address.is_empty():
        _lan_send({"type":"leave_room"})
    super._leave_lobby()
    pending_room_code = ""
    pending_game_host = ""
    room_code = ""

func _on_connected_to_server() -> void:
    super._on_connected_to_server()
    if not pending_room_code.is_empty() and not lan_server_address.is_empty():
        _lan_send({"type":"heartbeat"})

func _on_connection_failed() -> void:
    status_label.text = "Unable to connect to room"
    super._on_connection_failed()
