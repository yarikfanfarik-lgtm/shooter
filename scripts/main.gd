extends Node

const MAX_PLAYERS := 16
const DEFAULT_PORT := 24567

var peer: ENetMultiplayerPeer
var mode := "menu"
var match_mode := "ffa"
var team := "auto"
var room_code := ""
var map_name := "construction"
var server_started := false
var menu: Control
var status_label: Label
var room_list: ItemList
var sens_slider: HSlider
var fov_slider: HSlider
var graphics_option: OptionButton
var nickname_edit: LineEdit
var mobile_editing := false
var mobile_buttons: Array[Button] = []

var player_names: Dictionary = {}
var lobby_overlay: Control
var lobby_dialog: AcceptDialog
var lobby_player_list: ItemList
var lobby_code_label: Label
var lobby_status_label: Label
var lobby_start_button: Button
var lobby_host := false

func _ready() -> void:
    _load_settings()
    _build_menu()
    multiplayer.peer_connected.connect(_on_peer_connected)
    multiplayer.peer_disconnected.connect(_on_peer_disconnected)
    multiplayer.server_disconnected.connect(_on_server_disconnected)
    multiplayer.connected_to_server.connect(_on_connected_to_server)
    multiplayer.connection_failed.connect(_on_connection_failed)

func _build_menu() -> void:
    menu = Control.new()
    menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(menu)

    var bg := ColorRect.new()
    bg.color = Color("10131b")
    bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    menu.add_child(bg)

    var title := Label.new()
    title.text = "BLOCKSTRIKE"
    title.position = Vector2(70, 35)
    title.add_theme_font_size_override("font_size", 48)
    menu.add_child(title)

    var subtitle := Label.new()
    subtitle.text = "Blocky tactical shooter • up to 16 players"
    subtitle.position = Vector2(74, 92)
    subtitle.add_theme_color_override("font_color", Color("9aa4b2"))
    menu.add_child(subtitle)

    var nickname_label := Label.new()
    nickname_label.text = "NICKNAME"
    nickname_label.position = Vector2(75, 130)
    nickname_label.add_theme_font_size_override("font_size", 15)
    menu.add_child(nickname_label)

    nickname_edit = LineEdit.new()
    nickname_edit.position = Vector2(75, 154)
    nickname_edit.size = Vector2(250, 46)
    nickname_edit.placeholder_text = "Enter your nickname"
    nickname_edit.text = Settings.player_name
    nickname_edit.max_length = 20
    nickname_edit.text_changed.connect(_on_nickname_changed)
    menu.add_child(nickname_edit)

    var host := Button.new()
    host.text = "CREATE ROOM"
    host.position = Vector2(75, 220)
    host.size = Vector2(250, 52)
    host.pressed.connect(_create_room)
    menu.add_child(host)

    var join := Button.new()
    join.text = "JOIN BY CODE / IP"
    join.position = Vector2(75, 285)
    join.size = Vector2(250, 52)
    join.pressed.connect(_join_room)
    menu.add_child(join)

    var bots := Button.new()
    bots.text = "PLAY VS BOTS"
    bots.position = Vector2(75, 350)
    bots.size = Vector2(250, 52)
    bots.pressed.connect(_play_bots)
    menu.add_child(bots)

    var settings := Button.new()
    settings.text = "SETTINGS"
    settings.position = Vector2(75, 415)
    settings.size = Vector2(250, 52)
    settings.pressed.connect(_open_settings)
    menu.add_child(settings)

    var dev := Button.new()
    dev.text = "DEVELOPER MODE"
    dev.position = Vector2(75, 480)
    dev.size = Vector2(250, 52)
    dev.pressed.connect(_open_dev_menu)
    menu.add_child(dev)

    room_list = ItemList.new()
    room_list.position = Vector2(390, 170)
    room_list.size = Vector2(470, 312)
    room_list.add_item("ROOM BROWSER")
    room_list.add_item("Create a room to become its listen-server.")
    room_list.add_item("Public discovery needs a master server URL.")
    menu.add_child(room_list)

    status_label = Label.new()
    status_label.position = Vector2(390, 505)
    status_label.text = "Offline"
    status_label.add_theme_color_override("font_color", Color("7ed6a5"))
    menu.add_child(status_label)

    _update_nickname_buttons()

func _on_nickname_changed(value: String) -> void:
    Settings.player_name = value.strip_edges()
    Settings.save()
    _update_nickname_buttons()

func _update_nickname_buttons() -> void:
    if nickname_edit:
        nickname_edit.tooltip_text = "Nickname: %d/20" % nickname_edit.text.length()

func _current_nickname() -> String:
    var name := nickname_edit.text.strip_edges() if nickname_edit else Settings.player_name.strip_edges()
    if name.is_empty():
        name = "Player"
    Settings.player_name = name.substr(0, 20)
    Settings.save()
    return Settings.player_name

func _create_room() -> void:
    _current_nickname()
    peer = ENetMultiplayerPeer.new()
    var err := peer.create_server(DEFAULT_PORT, MAX_PLAYERS)
    if err != OK:
        status_label.text = "Server error: %s" % err
        return
    multiplayer.multiplayer_peer = peer
    server_started = true
    var addresses: Array = []
    for address in IP.get_local_addresses():
        if str(address).find(".") >= 0:
            addresses.append(address)
    room_code = _make_room_code(addresses, DEFAULT_PORT)
    player_names.clear()
    player_names[1] = _current_nickname()
    status_label.text = "Room created • code: %s • port %d" % [room_code, DEFAULT_PORT]
    _show_lobby(true)
    _broadcast_lobby_state()

func _join_room() -> void:
    _current_nickname()
    var dialog := AcceptDialog.new()
    dialog.title = "Join room"
    var box := VBoxContainer.new()
    var ip := LineEdit.new()
    ip.placeholder_text = "IP address (example 192.168.1.10)"
    var port := LineEdit.new()
    port.text = str(DEFAULT_PORT)
    var mode_box := OptionButton.new()
    mode_box.add_item("Each for himself", 0)
    mode_box.add_item("Team battle", 1)
    box.add_child(ip)
    box.add_child(port)
    box.add_child(mode_box)
    dialog.add_child(box)
    dialog.confirmed.connect(func():
        _connect_to(ip.text.strip_edges(), int(port.text), mode_box.selected == 1)
        dialog.queue_free()
    )
    dialog.canceled.connect(func(): dialog.queue_free())
    add_child(dialog)
    dialog.popup_centered(Vector2(420, 240))

func _connect_to(ip: String, port: int, team_game: bool) -> void:
    peer = ENetMultiplayerPeer.new()
    var err := peer.create_client(ip, port)
    if err != OK:
        status_label.text = "Connect error: %s" % err
        return
    multiplayer.multiplayer_peer = peer
    match_mode = "team" if team_game else "ffa"
    room_code = "%s:%d" % [ip, port]
    status_label.text = "Connecting to %s:%d..." % [ip, port]
    _show_lobby(false)

func _on_connected_to_server() -> void:
    var my_id := multiplayer.get_unique_id()
    _send_nickname.rpc_id(1, _current_nickname())
    lobby_status_label.text = "Connected • waiting for host to start"
    if my_id != 1:
        _set_lobby_start_state()

@rpc("any_peer", "reliable")
func _send_nickname(nickname: String) -> void:
    if not multiplayer.is_server():
        return
    var sender_id := multiplayer.get_remote_sender_id()
    var clean_name := nickname.strip_edges().substr(0, 20)
    if clean_name.is_empty():
        clean_name = "Player %d" % sender_id
    player_names[sender_id] = clean_name
    _broadcast_lobby_state()

func _broadcast_lobby_state() -> void:
    if not multiplayer.is_server():
        return
    _sync_lobby_state.rpc(player_names)

@rpc("authority", "call_local", "reliable")
func _sync_lobby_state(names: Dictionary) -> void:
    player_names = names.duplicate(true)
    _refresh_lobby_players()

func _show_lobby(is_host: bool) -> void:
    mode = "lobby"
    lobby_host = is_host
    menu.visible = false

    lobby_overlay = Control.new()
    lobby_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(lobby_overlay)

    var overlay_bg := ColorRect.new()
    overlay_bg.color = Color("0a0d14cc")
    overlay_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    lobby_overlay.add_child(overlay_bg)

    lobby_code_label = Label.new()
    lobby_code_label.text = "ROOM CODE: %s" % room_code
    lobby_code_label.position = Vector2(0, 48)
    lobby_code_label.size = Vector2(1280, 46)
    lobby_code_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    lobby_code_label.add_theme_font_size_override("font_size", 30)
    lobby_overlay.add_child(lobby_code_label)

    var players_panel := VBoxContainer.new()
    players_panel.position = Vector2(32, 34)
    players_panel.size = Vector2(300, 500)
    lobby_overlay.add_child(players_panel)

    var players_title := Label.new()
    players_title.text = "PLAYERS"
    players_title.add_theme_font_size_override("font_size", 20)
    players_panel.add_child(players_title)

    lobby_player_list = ItemList.new()
    lobby_player_list.custom_minimum_size = Vector2(300, 260)
    players_panel.add_child(lobby_player_list)

    lobby_status_label = Label.new()
    lobby_status_label.text = "Room created • waiting for another player" if is_host else "Connecting..."
    lobby_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    players_panel.add_child(lobby_status_label)

    lobby_dialog = AcceptDialog.new()
    lobby_dialog.title = "MATCH LOBBY"
    var box := VBoxContainer.new()
    box.custom_minimum_size = Vector2(420, 310)

    var mode_label := Label.new()
    mode_label.text = "Mode"
    box.add_child(mode_label)
    var mode_select := OptionButton.new()
    mode_select.add_item("Each for himself", 0)
    mode_select.add_item("Team battle", 1)
    mode_select.disabled = not is_host
    box.add_child(mode_select)

    var team_label := Label.new()
    team_label.text = "Team"
    box.add_child(team_label)
    var team_select := OptionButton.new()
    team_select.add_item("Automatic team", 0)
    team_select.add_item("Red", 1)
    team_select.add_item("Blue", 2)
    team_select.disabled = not is_host
    box.add_child(team_select)

    var map_label := Label.new()
    map_label.text = "Map"
    box.add_child(map_label)
    var map_select := OptionButton.new()
    map_select.add_item("Construction", 0)
    map_select.add_item("City", 1)
    map_select.add_item("Industrial Zone", 2)
    map_select.disabled = not is_host
    box.add_child(map_select)

    var info := Label.new()
    info.text = "START becomes available when at least 2 players are connected."
    info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    box.add_child(info)

    lobby_dialog.add_child(box)
    add_child(lobby_dialog)
    lobby_dialog.popup_centered(Vector2(520, 460))

    lobby_start_button = lobby_dialog.get_ok_button()
    lobby_start_button.text = "START"
    lobby_start_button.disabled = true
    lobby_start_button.visible = is_host

    lobby_dialog.confirmed.connect(func():
        if not lobby_host or player_names.size() < 2:
            return
        match_mode = "team" if mode_select.selected == 1 else "ffa"
        team = ["auto", "red", "blue"][team_select.selected]
        map_name = ["construction", "city", "industrial"][map_select.selected]
        _remote_start_match.rpc(match_mode, team, map_name)
    )
    lobby_dialog.canceled.connect(func():
        _leave_lobby()
    )

    _refresh_lobby_players()
    _set_lobby_start_state()

func _refresh_lobby_players() -> void:
    if not lobby_player_list:
        return
    lobby_player_list.clear()
    var ids: Array = player_names.keys()
    ids.sort()
    for id in ids:
        var display_name := str(player_names[id])
        if int(id) == 1:
            display_name += "  [HOST]"
        lobby_player_list.add_item(display_name)
    if lobby_status_label:
        var count := player_names.size()
        if lobby_host:
            lobby_status_label.text = "Players: %d/%d" % [count, MAX_PLAYERS]
        elif count > 0:
            lobby_status_label.text = "Players: %d/%d • waiting for host" % [count, MAX_PLAYERS]
    _set_lobby_start_state()

func _set_lobby_start_state() -> void:
    if not lobby_start_button:
        return
    lobby_start_button.disabled = not lobby_host or player_names.size() < 2
    if lobby_host:
        lobby_start_button.text = "START"

@rpc("authority", "call_local", "reliable")
func _remote_start_match(new_mode: String, new_team: String, new_map: String) -> void:
    match_mode = new_mode
    team = new_team
    map_name = new_map
    _start_match(false)

func _leave_lobby() -> void:
    if lobby_dialog:
        lobby_dialog.queue_free()
        lobby_dialog = null
    if lobby_overlay:
        lobby_overlay.queue_free()
        lobby_overlay = null
    menu.visible = true
    mode = "menu"
    if peer:
        peer = null
    multiplayer.multiplayer_peer = null
    server_started = false

func _play_bots() -> void:
    _current_nickname()
    multiplayer.multiplayer_peer = null
    server_started = false
    mode = "bots"
    _start_match(true)

func _start_match(with_bots: bool) -> void:
    mode = "match"
    if lobby_dialog:
        lobby_dialog.queue_free()
        lobby_dialog = null
    if lobby_overlay:
        lobby_overlay.queue_free()
        lobby_overlay = null
    var world := preload("res://scripts/world.gd").new()
    world.match_mode = match_mode
    world.team = team
    world.map_name = map_name
    world.with_bots = with_bots
    world.max_players = MAX_PLAYERS
    world.name = "World"
    add_child(world)
    world.start_match()

func _open_settings() -> void:
    var dialog := AcceptDialog.new()
    dialog.title = "Settings"
    var box := VBoxContainer.new()
    var name := LineEdit.new()
    name.text = Settings.player_name
    name.placeholder_text = "Nickname"
    name.max_length = 20
    name.text_changed.connect(func(value): Settings.player_name = value.strip_edges())
    sens_slider = HSlider.new(); sens_slider.min_value = 0.1; sens_slider.max_value = 5.0; sens_slider.step = 0.05; sens_slider.value = Settings.sensitivity
    fov_slider = HSlider.new(); fov_slider.min_value = 60; fov_slider.max_value = 120; fov_slider.value = Settings.fov
    graphics_option = OptionButton.new(); graphics_option.add_item("Low"); graphics_option.add_item("Medium"); graphics_option.add_item("High"); graphics_option.selected = Settings.graphics
    box.add_child(_label_control("Nickname", name))
    box.add_child(_label_control("Mouse sensitivity", sens_slider))
    box.add_child(_label_control("FOV", fov_slider))
    box.add_child(_label_control("Graphics", graphics_option))
    var key := Button.new(); key.text = "Rebind controls"; key.pressed.connect(func(): _show_keybinds())
    var mobile := Button.new(); mobile.text = "Customize mobile buttons"; mobile.pressed.connect(func(): _toggle_mobile_editor())
    box.add_child(key); box.add_child(mobile)
    dialog.add_child(box)
    dialog.confirmed.connect(func():
        Settings.player_name = name.text.strip_edges()
        if Settings.player_name.is_empty(): Settings.player_name = "Player"
        Settings.sensitivity = sens_slider.value
        Settings.fov = fov_slider.value
        Settings.graphics = graphics_option.selected
        Settings.save()
        if nickname_edit: nickname_edit.text = Settings.player_name
        dialog.queue_free()
    )
    add_child(dialog); dialog.popup_centered(Vector2(500, 500))

func _label_control(text: String, control: Control) -> VBoxContainer:
    var v := VBoxContainer.new(); var l := Label.new(); l.text = text; v.add_child(l); v.add_child(control); return v

func _show_keybinds() -> void:
    var d := AcceptDialog.new(); d.title = "Keyboard bindings"
    var text := Label.new(); text.text = "WASD Move\nMouse Left Fire\nR Reload\nE Use\nSpace Jump\nRebinding UI will be expanded in the next pass."
    d.add_child(text); add_child(d); d.popup_centered(Vector2(420, 260))

func _toggle_mobile_editor() -> void:
    mobile_editing = !mobile_editing
    status_label.text = "Mobile HUD editor: %s" % ("ON" if mobile_editing else "OFF")

func _open_dev_menu() -> void:
    var d := AcceptDialog.new(); d.title = "Developer tools (private build)"
    var box := VBoxContainer.new()
    for option in ["Wall ESP", "Auto Shoot", "Infinite ammo", "God mode"]:
        var c := CheckButton.new(); c.text = option; box.add_child(c)
    d.add_child(box); add_child(d); d.popup_centered(Vector2(420, 320))

func _make_room_code(addresses: Array, port: int) -> String:
    var ip := "127.0.0.1"
    for a in addresses:
        if str(a).begins_with("192.168.") or str(a).begins_with("10."):
            ip = a; break
    return "%s:%d" % [ip, port]

func _on_peer_connected(id: int) -> void:
    if multiplayer.is_server():
        lobby_status_label.text = "Player %d connected" % id if lobby_status_label else ""
        _broadcast_lobby_state()
    elif id == 1:
        _send_nickname.rpc_id(1, _current_nickname())

func _on_peer_disconnected(id: int) -> void:
    if multiplayer.is_server():
        player_names.erase(id)
        _broadcast_lobby_state()
    if lobby_status_label:
        lobby_status_label.text = "Player left: %d" % id

func _on_server_disconnected() -> void:
    if lobby_status_label:
        lobby_status_label.text = "Server disconnected"

func _on_connection_failed() -> void:
    status_label.text = "Connection failed"
    _leave_lobby()

func _load_settings() -> void:
    if not Engine.has_singleton("Settings"):
        pass
