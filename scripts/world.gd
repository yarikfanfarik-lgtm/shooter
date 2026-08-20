extends Node3D

var nickname := "Player"
var players: Dictionary = {}
var spawn_points := [
    Vector3(-18, 1.2, -18), Vector3(18, 1.2, 18),
    Vector3(18, 1.2, -18), Vector3(-18, 1.2, 18),
    Vector3(0, 1.2, -22), Vector3(0, 1.2, 22),
    Vector3(-22, 1.2, 0), Vector3(22, 1.2, 0)
]
var score := 0

const SAND := Color("d7a45f")
const SAND_LIGHT := Color("e7bd78")
const WALL := Color("d9d0bd")
const WALL_LIGHT := Color("eee5d2")
const TRIM := Color("8b6042")
const WOOD := Color("765038")
const WOOD_LIGHT := Color("9a6b45")
const DARK := Color("3a3430")
const GREEN := Color("71853a")
const GREEN_DARK := Color("4e632d")
const BLUE := Color("6689a5")

func start_match() -> void:
    _build_world()
    _spawn_player()
    for i in range(7):
        _spawn_bot(i)

func _build_world() -> void:
    var env := WorldEnvironment.new()
    var e := Environment.new()
    e.background_mode = Environment.BG_COLOR
    e.background_color = Color("9fb3c8")
    e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    e.ambient_light_color = Color("fff0d0")
    e.ambient_light_energy = 0.9
    e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    env.environment = e
    add_child(env)

    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-52, -28, 0)
    sun.light_energy = 1.55
    sun.shadow_enabled = true
    add_child(sun)

    # Main sandy arena and a lighter central courtyard.
    _block(Vector3(0, -0.5, 0), Vector3(72, 1, 72), SAND)
    _block(Vector3(0, 0.03, 0), Vector3(34, 0.12, 30), SAND_LIGHT)

    # Perimeter buildings create the compact FPS sight lines shown in the reference.
    _building(Vector3(-25, 4, -24), Vector3(16, 8, 14))
    _building(Vector3(25, 4, -24), Vector3(16, 8, 14))
    _building(Vector3(-25, 4, 24), Vector3(16, 8, 14))
    _building(Vector3(25, 4, 24), Vector3(16, 8, 14))

    # Central lanes and cover.
    _crate_stack(Vector3(-8, 1.1, -4), 2)
    _crate_stack(Vector3(8, 1.1, 5), 2)
    _crate_stack(Vector3(0, 1.1, 10), 1)
    _crate_stack(Vector3(0, 1.1, -11), 1)
    _crate_stack(Vector3(-13, 1.1, 9), 1)
    _crate_stack(Vector3(13, 1.1, -9), 1)

    # Low walls divide the courtyard without blocking every sight line.
    _wall_with_gap(Vector3(-15, 1.4, 0), Vector3(2, 2.8, 18), 0.45)
    _wall_with_gap(Vector3(15, 1.4, 0), Vector3(2, 2.8, 18), 0.45)
    _block(Vector3(0, 1.3, 0), Vector3(12, 2.6, 1.5), WALL)

    # Rooftop access stairs and raised positions.
    _stairs(Vector3(-18, 0.5, -15), 8, 1.0)
    _stairs(Vector3(18, 0.5, 15), 8, 1.0)
    _block(Vector3(-25, 8.5, -24), Vector3(15, 1, 13), WALL_LIGHT)
    _block(Vector3(25, 8.5, 24), Vector3(15, 1, 13), WALL_LIGHT)

    # Decorative door/window openings and awnings.
    _facade_details(Vector3(-25, 4, -24))
    _facade_details(Vector3(25, 4, -24))
    _facade_details(Vector3(-25, 4, 24))
    _facade_details(Vector3(25, 4, 24))

    # Blocky palms to match the stylized low-poly look.
    for p in [Vector3(-30, 0, -8), Vector3(30, 0, 8), Vector3(-30, 0, 12), Vector3(30, 0, -12)]:
        _palm(p)

    # Small stone paving strips.
    for x in [-9, -6, -3, 0, 3, 6, 9]:
        _block(Vector3(x, 0.10, 0), Vector3(2.2, 0.12, 1.4), WALL_LIGHT)
    for z in [-9, -6, -3, 3, 6, 9]:
        _block(Vector3(0, 0.11, z), Vector3(1.4, 0.12, 2.2), WALL_LIGHT)

func _block(pos: Vector3, size: Vector3, color: Color) -> void:
    var mesh := MeshInstance3D.new()
    var box := BoxMesh.new()
    box.size = size
    mesh.mesh = box
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.roughness = 0.82
    mesh.material_override = mat
    mesh.position = pos
    add_child(mesh)

    var body := StaticBody3D.new()
    body.position = pos
    var shape := CollisionShape3D.new()
    var box_shape := BoxShape3D.new()
    box_shape.size = size
    shape.shape = box_shape
    body.add_child(shape)
    add_child(body)

func _building(pos: Vector3, size: Vector3) -> void:
    _block(pos, size, WALL)
    _block(pos + Vector3(0, size.y * 0.5 + 0.25, 0), Vector3(size.x + 0.7, 0.5, size.z + 0.7), TRIM)
    _block(pos + Vector3(0, size.y + 0.65, 0), Vector3(size.x + 1.0, 0.35, size.z + 1.0), WALL_LIGHT)

    # Corner parapets and rooftop cover.
    for sx in [-1, 1]:
        for sz in [-1, 1]:
            _block(pos + Vector3(sx * (size.x * 0.42), size.y + 1.0, sz * (size.z * 0.42)), Vector3(1.4, 1.6, 1.4), WALL)

func _facade_details(pos: Vector3) -> void:
    # Front-side door and windows are placed as dark recess-like blocks.
    var front_z := -1.0 if pos.z < 0 else 1.0
    _block(pos + Vector3(0, 2.0, front_z * 7.08), Vector3(2.6, 4.0, 0.18), DARK)
    for x in [-4.5, 4.5]:
        _block(pos + Vector3(x, 4.5, front_z * 7.10), Vector3(2.2, 1.7, 0.16), BLUE)
        _block(pos + Vector3(x, 5.5, front_z * 7.25), Vector3(2.7, 0.18, 0.55), TRIM)

func _crate_stack(pos: Vector3, count: int) -> void:
    for i in range(count):
        var offset := Vector3((i % 2) * 1.15, i * 1.05, (i % 2) * 0.45)
        var c := pos + offset
        _block(c, Vector3(2.1, 2.0, 2.1), WOOD)
        _block(c + Vector3(0, 0, -1.08), Vector3(1.5, 0.12, 0.08), WOOD_LIGHT)
        _block(c + Vector3(0, 0, 1.08), Vector3(1.5, 0.12, 0.08), WOOD_LIGHT)

func _wall_with_gap(pos: Vector3, size: Vector3, gap_ratio: float) -> void:
    var gap_axis := size.z if size.z > size.x else size.x
    var segment := gap_axis * (1.0 - gap_ratio) * 0.5
    if size.z > size.x:
        _block(pos + Vector3(0, 0, -(gap_axis - segment) * 0.5), Vector3(size.x, size.y, segment), WALL)
        _block(pos + Vector3(0, 0, (gap_axis - segment) * 0.5), Vector3(size.x, size.y, segment), WALL)
    else:
        _block(pos + Vector3(-(gap_axis - segment) * 0.5, 0, 0), Vector3(segment, size.y, size.z), WALL)
        _block(pos + Vector3((gap_axis - segment) * 0.5, 0, 0), Vector3(segment, size.y, size.z), WALL)

func _stairs(start: Vector3, steps: int, direction: float) -> void:
    for i in range(steps):
        var h := 0.28 + i * 0.34
        var z := start.z + i * 0.62 * direction
        _block(Vector3(start.x, h * 0.5, z), Vector3(3.4, h, 0.72), WALL_LIGHT)
    _block(Vector3(start.x, 3.0, start.z + steps * 0.62 * direction), Vector3(5.0, 0.5, 4.0), WALL_LIGHT)

func _palm(pos: Vector3) -> void:
    # Deliberately made from boxes: chunky, readable, low-poly/block style.
    for i in range(5):
        _block(pos + Vector3(0, i * 1.25 + 0.7, 0), Vector3(0.55, 1.35, 0.55), TRIM)
    var top := pos + Vector3(0, 6.4, 0)
    _block(top, Vector3(1.0, 0.45, 1.0), GREEN_DARK)
    _block(top + Vector3(2.0, 0.15, 0), Vector3(4.0, 0.35, 0.65), GREEN)
    _block(top + Vector3(-2.0, 0.15, 0), Vector3(4.0, 0.35, 0.65), GREEN)
    _block(top + Vector3(0, 0.15, 2.0), Vector3(0.65, 0.35, 4.0), GREEN)
    _block(top + Vector3(0, 0.15, -2.0), Vector3(0.65, 0.35, 4.0), GREEN)

func _spawn_player() -> void:
    var p := preload("res://scripts/player.gd").new()
    p.world = self
    p.player_id = 1
    p.nickname = nickname
    p.position = spawn_points[0]
    p.is_local = true
    add_child(p)
    players[1] = p

func _spawn_bot(index: int) -> void:
    var b := preload("res://scripts/bot.gd").new()
    b.world = self
    b.player_id = 100 + index
    b.position = spawn_points[(index + 1) % spawn_points.size()]
    add_child(b)
    players[b.player_id] = b

func award_kill(killer: int) -> void:
    if killer == 1:
        score += 1

func get_target_for(bot: Node3D) -> Node3D:
    var best: Node3D = null
    var best_distance := INF
    for id in players:
        var p = players[id]
        if p == bot or not is_instance_valid(p):
            continue
        var d := bot.global_position.distance_to(p.global_position)
        if d < best_distance:
            best_distance = d
            best = p
    return best
