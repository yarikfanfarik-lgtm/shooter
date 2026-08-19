extends CanvasLayer

var world: Node
var editor := false
var buttons: Dictionary = {}
var selected_button: String = ""
var status: Label

func _ready() -> void:
    var cross := Label.new(); cross.text = "+"; cross.position = Vector2(638,350); cross.add_theme_font_size_override("font_size",24); add_child(cross)
    status = Label.new(); status.position = Vector2(20,20); status.size = Vector2(420,90); add_child(status)
    if DisplayServer.is_touchscreen_available() or OS.has_feature("mobile"):
        _make_mobile_button("fire", "FIRE")
        _make_mobile_button("jump", "JUMP")
        _make_mobile_button("reload", "R")
        _make_mobile_button("weapon", "WEAPON")
        _make_mobile_button("move", "MOVE")

func _process(_delta: float) -> void:
    if not world: return
    var m := world.scores
    var cash := world.money.get(1,0)
    status.text = "MODE: %s   MAP: %s\nSCORE: %s   MONEY: $%d" % [world.match_mode, world.map_name, str(m), cash]

func _make_mobile_button(id: String, text: String) -> void:
    var b := Button.new()
    b.text = text
    var item: Dictionary = Settings.mobile_layout.get(id, {"x":0.85,"y":0.8,"size":80.0})
    b.position = Vector2(item.x * 1200.0, item.y * 640.0)
    b.size = Vector2(item.size, item.size)
    b.modulate.a = 0.75
    b.gui_input.connect(func(e): _button_gui(id, b, e))
    add_child(b); buttons[id] = b

func _button_gui(id: String, b: Button, event: InputEvent) -> void:
    if event is InputEventMouseButton and event.pressed:
        selected_button = id
    if event is InputEventMouseMotion and selected_button == id and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and editor:
        b.position += event.relative
        Settings.mobile_layout[id] = {"x":b.position.x/1200.0,"y":b.position.y/640.0,"size":b.size.x}
        Settings.save()

func start_mobile_edit() -> void:
    editor = true
    for b in buttons.values(): b.modulate = Color(0.4,0.8,1.0,0.65)

func stop_mobile_edit() -> void:
    editor = false
    for b in buttons.values(): b.modulate.a = 0.75
