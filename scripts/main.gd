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
var ip_edit: LineEdit
var code_edit: LineEdit
var sens_slider: HSlider
var fov_slider: HSlider
var graphics_option: OptionButton
var mobile_editing := false
var mobile_buttons: Array[Button] = []

func _ready() -> void:
    _load_settings()
    _build_menu()
    multiplayer.peer_connected.connect(_on_peer_connected)
    multiplayer.peer_disconnected.connect(_on_peer_disconnected)
    multiplayer.server_disconnected.connect(_on_server_disconnected)

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
    title.position = Vector2(70, 45)
    title.add_theme_font_size_override("font_size", 48)
    menu.add_child(title)

    var subtitle := Label.new()
    subtitle.text = "Blocky tactical shooter • up to 16 players"
    subtitle.position = Vector2(74, 105)
    subtitle.add_theme_color_override("font_color", Color("9aa4b2"))
    menu.add_child(subtitle)

    var host := Button.new()
    host.text = "CREATE ROOM"
    host.position = Vector2(75, 165)
    host.size = Vector2(250, 52)
    host.pressed.connect(_create_room)
    menu.add_child(host)

    var join := Button.new()
    join.text = "JOIN BY CODE / IP"
    join.position = Vector2(75, 230)
    join.size = Vector2(250, 52)
    join.pressed.connect(_join_room)
    menu.add_child(join)

    var bots := Button.new()
    bots.text = "PLAY VS BOTS"
    bots.position = Vector2(75, 295)
    bots.size = Vector2(250, 52)
    bots.pressed.connect(_play_bots)
    menu.add_child(bots)

    var settings := Button.new()
    settings.text = "SETTINGS"
    settings.position = Vector2(75, 360)
    settings.size = Vector2(250, 52)
    settings.pressed.connect(_open_settings)
    menu.add_child(settings)

    var dev := Button.new()
    dev.text = "DEVELOPER MODE"
    dev.position = Vector2(75, 425)
    dev.size = Vector2(250, 52)
    dev.pressed.connect(_open_dev_menu)
    menu.add_child(dev)

    room_list = ItemList.new()
    room_list.position = Vector2(390, 165)
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

func _create_room() -> void:
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
    status_label.text = "Room created • code: %s • port %d" % [room_code, DEFAULT_PORT]
    _show_lobby(true)

func _join_room() -> void:
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
    box.add_child(ip); box.add_child(port); box.add_child(mode_box)
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
    status_label.text = "Connecting to %s:%d..." % [ip, port]
    _show_lobby(false)

func _play_bots() -> void:
    multiplayer.multiplayer_peer = null
    server_started = false
    mode = "bots"
    _start_match(true)

func _show_lobby(is_host: bool) -> void:
    mode = "lobby"
    var dialog := AcceptDialog.new()
    dialog.title = "Match lobby"
    var box := VBoxContainer.new()
    var mode_select := OptionButton.new()
    mode_select.add_item("Each for himself", 0)
    mode_select.add_item("Team battle", 1)
    var team_select := OptionButton.new()
    team_select.add_item("Automatic team", 0)
    team_select.add_item("Red", 1)
    team_select.add_item("Blue", 2)
    var map_select := OptionButton.new()
    map_select.add_item("Construction", 0)
    map_select.add_item("City", 1)
    map_select.add_item("Industrial Zone", 2)
    box.add_child(Label.new()); box.get_child(0).text = "Mode"
    box.add_child(mode_select); box.add_child(Label.new()); box.get_child(2).text = "Team"
    box.add_child(team_select); box.add_child(Label.new()); box.get_child(4).text = "Map"; box.add_child(map_select)
    dialog.add_child(box)
    dialog.confirmed.connect(func():
        match_mode = "team" if mode_select.selected == 1 else "ffa"
        team = ["auto", "red", "blue"][team_select.selected]
        map_name = ["construction", "city", "industrial"][map_select.selected]
        dialog.queue_free()
        _start_match(false)
    )
    dialog.canceled.connect(func(): dialog.queue_free())
    add_child(dialog); dialog.popup_centered(Vector2(420, 380))

func _start_match(with_bots: bool) -> void:
    mode = "match"
    menu.queue_free()
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
    sens_slider = HSlider.new(); sens_slider.min_value = 0.1; sens_slider.max_value = 5.0; sens_slider.step = 0.05; sens_slider.value = Settings.sensitivity
    fov_slider = HSlider.new(); fov_slider.min_value = 60; fov_slider.max_value = 120; fov_slider.value = Settings.fov
    graphics_option = OptionButton.new(); graphics_option.add_item("Low"); graphics_option.add_item("Medium"); graphics_option.add_item("High"); graphics_option.selected = Settings.graphics
    box.add_child(_label_control("Mouse sensitivity", sens_slider))
    box.add_child(_label_control("FOV", fov_slider))
    box.add_child(_label_control("Graphics", graphics_option))
    var key := Button.new(); key.text = "Rebind controls"; key.pressed.connect(func(): _show_keybinds())
    var mobile := Button.new(); mobile.text = "Customize mobile buttons"; mobile.pressed.connect(func(): _toggle_mobile_editor())
    box.add_child(key); box.add_child(mobile)
    dialog.add_child(box)
    dialog.confirmed.connect(func(): Settings.sensitivity = sens_slider.value; Settings.fov = fov_slider.value; Settings.graphics = graphics_option.selected; Settings.save(); dialog.queue_free())
    add_child(dialog); dialog.popup_centered(Vector2(500, 430))

func _label_control(text: String, control: Control) -> VBoxContainer:
    var v := VBoxContainer.new(); var l := Label.new(); l.text = text; v.add_child(l); v.add_child(control); return v

func _show_keybinds() -> void:
    var d := AcceptDialog.new(); d.title = "Keyboard bindings"
    var text := Label.new(); text.text = "WASD Move\nMouse Left Fire\nR Reload\nE Use\nSpace Jump\nPress the buttons in the live game to customize more actions."
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
    status_label.text = "Player connected: %d" % id

func _on_peer_disconnected(id: int) -> void:
    status_label.text = "Player left: %d" % id

func _on_server_disconnected() -> void:
    status_label.text = "Server disconnected"

func _load_settings() -> void:
    if not Engine.has_singleton("Settings"):
        pass
