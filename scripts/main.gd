extends Node

var menu: Control
var nickname := "Player"

func _ready() -> void:
    _build_menu()

func _build_menu() -> void:
    menu = Control.new()
    menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(menu)

    var bg := ColorRect.new()
    bg.color = Color("11151c")
    bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    menu.add_child(bg)

    var title := Label.new()
    title.text = "BLOCKSTRIKE"
    title.position = Vector2(70, 50)
    title.add_theme_font_size_override("font_size", 52)
    menu.add_child(title)

    var sub := Label.new()
    sub.text = "Blocky tactical shooter"
    sub.position = Vector2(74, 112)
    menu.add_child(sub)

    var nick_label := Label.new()
    nick_label.text = "NICKNAME"
    nick_label.position = Vector2(76, 175)
    menu.add_child(nick_label)

    var nick := LineEdit.new()
    nick.position = Vector2(75, 205)
    nick.size = Vector2(300, 46)
    nick.text = nickname
    nick.max_length = 20
    nick.text_changed.connect(func(v: String): nickname = v.strip_edges())
    menu.add_child(nick)

    var bots := Button.new()
    bots.text = "PLAY VS BOTS"
    bots.position = Vector2(75, 285)
    bots.size = Vector2(300, 58)
    bots.pressed.connect(func():
        if nickname.is_empty(): nickname = "Player"
        _start_match()
    )
    menu.add_child(bots)

    var hint := Label.new()
    hint.text = "WASD • Mouse • LMB Fire • R Reload • Space Jump"
    hint.position = Vector2(75, 365)
    hint.add_theme_color_override("font_color", Color("9da7b5"))
    menu.add_child(hint)

func _start_match() -> void:
    menu.visible = false
    var world := preload("res://scripts/world.gd").new()
    world.name = "World"
    world.nickname = nickname if not nickname.is_empty() else "Player"
    add_child(world)
    world.start_match()
