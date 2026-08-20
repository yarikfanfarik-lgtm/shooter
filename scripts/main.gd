extends Node

var menu: Control
var nickname := "Player"

func _ready() -> void:
    _build_menu()

func _build_menu() -> void:
    menu = Control.new()
    menu.name = "MainMenu"
    add_child(menu)
    menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    menu.mouse_filter = Control.MOUSE_FILTER_STOP

    var bg := ColorRect.new()
    bg.name = "Background"
    bg.color = Color("11151c")
    menu.add_child(bg)
    bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    bg.mouse_filter = Control.MOUSE_FILTER_IGNORE

    var title := Label.new()
    title.text = "BLOCKSTRIKE"
    title.position = Vector2(70, 50)
    title.add_theme_font_size_override("font_size", 52)
    menu.add_child(title)

    var sub := Label.new()
    sub.text = "Blocky tactical shooter"
    sub.position = Vector2(74, 112)
    sub.add_theme_font_size_override("font_size", 20)
    sub.add_theme_color_override("font_color", Color("9da7b5"))
    menu.add_child(sub)

    var nick_label := Label.new()
    nick_label.text = "NICKNAME"
    nick_label.position = Vector2(76, 175)
    menu.add_child(nick_label)

    var nick := LineEdit.new()
    nick.name = "Nickname"
    nick.position = Vector2(75, 205)
    nick.size = Vector2(300, 46)
    nick.text = nickname
    nick.placeholder_text = "Enter nickname"
    nick.max_length = 20
    nick.text_changed.connect(_on_nickname_changed)
    menu.add_child(nick)

    var bots := Button.new()
    bots.name = "PlayVsBots"
    bots.text = "PLAY VS BOTS"
    bots.position = Vector2(75, 285)
    bots.size = Vector2(300, 58)
    bots.pressed.connect(_on_play_bots)
    menu.add_child(bots)

    var hint := Label.new()
    hint.text = "WASD • Mouse • LMB Fire • R Reload • 1/2 Weapons • Space Jump"
    hint.position = Vector2(75, 365)
    hint.add_theme_color_override("font_color", Color("9da7b5"))
    menu.add_child(hint)

func _on_nickname_changed(value: String) -> void:
    nickname = value.strip_edges()

func _on_play_bots() -> void:
    if nickname.is_empty():
        nickname = "Player"
    _start_match()

func _start_match() -> void:
    if is_instance_valid(menu):
        menu.queue_free()
        menu = null

    var world := preload("res://scripts/world.gd").new()
    world.name = "World"
    world.nickname = nickname if not nickname.is_empty() else "Player"
    add_child(world)
    world.start_match()
