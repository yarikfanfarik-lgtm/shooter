extends Node3D

var match_mode := "ffa"
var team := "auto"
var map_name := "construction"
var with_bots := false
var max_players := 16
var players: Dictionary = {}
var scores := {"red": 0, "blue": 0, "ffa": 0}
var money: Dictionary = {}
var spawn_points: Array[Vector3] = []

const WEAPONS := {
    "knife": {"cost": 0, "damage": 45, "headshot": 75, "range": 2.5},
    "pistol": {"cost": 0, "damage": 28, "headshot": 56, "range": 90.0},
    "ak47": {"cost": 0, "damage": 32, "headshot": 64, "range": 120.0},
    "shotgun": {"cost": 900, "damage": 18, "headshot": 30, "range": 35.0, "pellets": 8},
    "sniper": {"cost": 2200, "damage": 90, "headshot": 150, "range": 250.0},
    "minigun": {"cost": 3200, "damage": 17, "headshot": 25, "range": 100.0},
    "flamethrower": {"cost": 1800, "damage": 12, "headshot": 12, "range": 18.0},
    "grenade": {"cost": 300, "damage": 90, "headshot": 90, "range": 12.0},
    "flash": {"cost": 250, "damage": 0, "headshot": 0, "range": 10.0},
    "smoke": {"cost": 250, "damage": 0, "headshot": 0, "range": 10.0},
    "mine": {"cost": 500, "damage": 100, "headshot": 100, "range": 5.0}
}

func start_match() -> void:
    # Hide the main menu before creating the 3D match.
    # Without this, the menu stayed above the camera and made PLAY VS BOTS
    # look like it did nothing.
    var main_root := get_parent()
    if main_root:
        var main_menu = main_root.get("menu")
        if main_menu is Control:
            main_menu.visible = false
    _build_map(map_name)
    _spawn_player(1, true)
    if with_bots:
        var bot_count := 7 if match_mode == "ffa" else 7
        for i in range(bot_count):
            _spawn_bot(100 + i)
    _setup_hud()

func _build_map(which: String) -> void:
    var env := WorldEnvironment.new()
    var environment := Environment.new()
    environment.background_mode = Environment.BG_COLOR
    environment.background_color = Color("77808c")
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color("d6dbe3")
    environment.ambient_light_energy = 0.65
    env.environment = environment
    add_child(env)
    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-55, -35, 0)
    sun.light_energy = 1.2
    add_child(sun)

    var ground_size := Vector3(80, 1, 80)
    _block(Vector3(0, -0.5, 0), ground_size, Color("555c66"))
    if which == "construction": _construction_map()
    elif which == "city": _city_map()
    else: _industrial_map()

func _construction_map() -> void:
    for x in [-24,-12,0,12,24]:
        for z in [-18,0,18]:
            _building(Vector3(x, 3, z), Vector3(10, 6, 10), Color("8f7c68"))
    _block(Vector3(0, 3, -32), Vector3(50, 6, 2), Color("a0a5aa"))
    _block(Vector3(0, 8, -24), Vector3(2, 16, 2), Color("bd8d4a"))
    _block(Vector3(8, 11, -24), Vector3(2, 22, 2), Color("bd8d4a"))
    _block(Vector3(8, 12, -28), Vector3(18, 1, 1), Color("bd8d4a"))
    spawn_points = [Vector3(-30,1,-30),Vector3(30,1,-30),Vector3(-30,1,30),Vector3(30,1,30),Vector3(0,1,28),Vector3(0,1,-5)]

func _city_map() -> void:
    for x in [-24,-12,0,12,24]:
        for z in [-24,-8,8,24]:
            var h := 6 + ((abs(x)+abs(z)) % 12)
            _building(Vector3(x, h/2.0, z), Vector3(9,h,9), Color("737b88"))
    for x in [-20,0,20]:
        _block(Vector3(x, 0.5, 0), Vector3(2,1,60), Color("a3a5a8"))
    spawn_points = [Vector3(-34,1,-34),Vector3(34,1,-34),Vector3(-34,1,34),Vector3(34,1,34),Vector3(0,1,-34),Vector3(0,1,34)]

func _industrial_map() -> void:
    for x in [-24,-12,0,12,24]:
        _block(Vector3(x,3,-18), Vector3(9,6,8), Color("596269"))
    for z in [-5,8,21]:
        _block(Vector3(0,3,z), Vector3(50,6,7), Color("66716e"))
    for x in [-25,25]:
        _block(Vector3(x,4,15), Vector3(3,8,28), Color("ad6d48"))
    for i in range(8):
        _cylinder_like(Vector3(-18 + i*5.0, 2, 25), 1.4, 4, Color("626b73"))
    spawn_points = [Vector3(-32,1,-30),Vector3(32,1,-30),Vector3(-32,1,30),Vector3(32,1,30),Vector3(0,1,30),Vector3(0,1,-30)]

func _building(pos: Vector3, size: Vector3, color: Color) -> void:
    _block(pos, size, color)
    _block(pos + Vector3(0,size.y/2.0+0.25,0), Vector3(size.x+0.4,0.5,size.z+0.4), color.darkened(0.15))
    for sx in [-1,1]:
        for sz in [-1,1]:
            _block(pos + Vector3(sx*(size.x/2.0-1),0,sz*(size.z/2.0+0.1)), Vector3(1,2,1), Color("30353b"))

func _block(pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
    var m := MeshInstance3D.new()
    var box := BoxMesh.new(); box.size = size; m.mesh = box
    var mat := StandardMaterial3D.new(); mat.albedo_color = color; m.material_override = mat
    m.position = pos; add_child(m)
    var body := StaticBody3D.new(); body.position = pos
    var shape := CollisionShape3D.new(); var box_shape := BoxShape3D.new(); box_shape.size = size; shape.shape = box_shape
    body.add_child(shape); add_child(body)
    return m

func _cylinder_like(pos: Vector3, r: float, h: float, color: Color) -> void:
    var steps := 10
    for y in range(2):
        for i in range(steps):
            var a := TAU * float(i) / steps
            _block(pos + Vector3(cos(a)*r, -h/2.0 + y*h, sin(a)*r), Vector3(0.9, h/2.0, 0.9), color)

func _spawn_player(id: int, local_player: bool) -> void:
    var p := preload("res://scripts/player.gd").new()
    p.player_id = id; p.is_local = local_player; p.team = _choose_team(id)
    p.position = spawn_points[(id - 1) % maxi(spawn_points.size(),1)] if spawn_points.size() > 0 else Vector3.ZERO
    p.world = self
    p.max_health = 100
    add_child(p)
    players[id] = p; money[id] = 500

func _spawn_bot(id: int) -> void:
    var b := preload("res://scripts/bot.gd").new()
    b.player_id = id; b.team = _choose_team(id); b.world = self
    b.position = spawn_points[id % spawn_points.size()] if spawn_points.size() else Vector3.ZERO
    add_child(b); players[id] = b; money[id] = 500

func _choose_team(id: int) -> String:
    if match_mode != "team": return "ffa"
    if team == "red" and id == 1: return "red"
    if team == "blue" and id == 1: return "blue"
    var reds := 0; var blues := 0
    for p in players.values():
        if is_instance_valid(p):
            if p.team == "red": reds += 1
            elif p.team == "blue": blues += 1
    return "red" if reds <= blues else "blue"

func award_kill(killer: int, headshot: bool) -> void:
    var reward := 150 if headshot else 100
    money[killer] = int(money.get(killer,0)) + reward
    var killer_node = players.get(killer)
    if killer_node: killer_node.money = money[killer]
    if match_mode == "ffa": scores["ffa"] += 1
    elif killer_node: scores[killer_node.team] += 1

func buy(player_id: int, weapon: String) -> bool:
    if not WEAPONS.has(weapon): return false
    var cost: int = WEAPONS[weapon].cost
    if money.get(player_id,0) < cost: return false
    money[player_id] -= cost
    var p = players.get(player_id)
    if p: p.give_weapon(weapon)
    return true

func _setup_hud() -> void:
    var hud := preload("res://scripts/hud.gd").new()
    hud.world = self
    add_child(hud)
