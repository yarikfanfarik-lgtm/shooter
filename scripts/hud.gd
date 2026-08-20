extends CanvasLayer

var player: Node
var hp_label: Label
var ammo_label: Label
var weapon_label: Label
var score_label: Label
var crosshair: Label
var reload_label: Label
var tactical_label: Label

func setup(p: Node) -> void:
    player = p
    _build()

func _build() -> void:
    hp_label = _label("HP 100", Vector2(28, 620), 28)
    ammo_label = _label("30 / 90", Vector2(1040, 620), 28)
    weapon_label = _label("AK-47", Vector2(1040, 575), 22)
    score_label = _label("KILLS 0", Vector2(28, 575), 22)
    reload_label = _label("", Vector2(510, 620), 24)
    tactical_label = _label("SMOKE G x2   MINE H x2", Vector2(28, 535), 18)
    crosshair = _label("+", Vector2(632, 348), 30)
    crosshair.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    crosshair.size = Vector2(20, 30)
    for label in [hp_label, ammo_label, weapon_label, score_label, reload_label, tactical_label]:
        label.add_theme_color_override("font_color", Color.WHITE)
        label.add_theme_color_override("font_shadow_color", Color.BLACK)
        label.add_theme_constant_override("shadow_offset_x", 2)
        label.add_theme_constant_override("shadow_offset_y", 2)

func _label(text: String, pos: Vector2, size: int) -> Label:
    var l := Label.new()
    l.text = text
    l.position = pos
    l.add_theme_font_size_override("font_size", size)
    add_child(l)
    return l

func _process(_delta: float) -> void:
    if not is_instance_valid(player):
        return
    hp_label.text = "HP %d" % player.health
    ammo_label.text = "%d / %d" % [player.ammo, player.reserve_ammo]
    weapon_label.text = player.weapon_name
    score_label.text = "KILLS %d" % player.world.score
    reload_label.text = "RELOADING..." if player.reloading else ""
    crosshair.text = "•" if player.aiming else "+"
    crosshair.position = Vector2(632, 348)
    var tactical_nodes := get_tree().get_nodes_in_group("tactical_manager")
    if tactical_nodes.is_empty():
        tactical_label.text = "SMOKE G x2   MINE H x2"
    else:
        var tactical = tactical_nodes[0]
        tactical_label.text = "SMOKE G x%d   MINE H x%d" % [tactical.smoke_count, tactical.mine_count]
