extends Node3D

var nickname := "Player"
var players: Dictionary = {}
var spawn_points := [Vector3(-18,1,-18), Vector3(18,1,-18), Vector3(-18,1,18), Vector3(18,1,18), Vector3(0,1,0), Vector3(-10,1,10), Vector3(10,1,10), Vector3(0,1,-14)]
var score := 0

func start_match() -> void:
    _build_world()
    _spawn_player()
    for i in range(7):
        _spawn_bot(i)

func _build_world() -> void:
    var env := WorldEnvironment.new()
    var e := Environment.new()
    e.background_mode = Environment.BG_COLOR
    e.background_color = Color("67727d")
    e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    e.ambient_light_color = Color("d7dce2")
    e.ambient_light_energy = 0.8
    env.environment = e
    add_child(env)

    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-55,-25,0)
    sun.light_energy = 1.2
    add_child(sun)

    _block(Vector3(0,-0.5,0), Vector3(70,1,70), Color("4b535b"))
    for x in [-22,-11,0,11,22]:
        _building(Vector3(x,3,-20), Vector3(8,6,8))
    for z in [-8,4,16]:
        _block(Vector3(-25,2,z), Vector3(3,4,8), Color("8b9096"))
        _block(Vector3(25,2,z), Vector3(3,4,8), Color("8b9096"))
    _block(Vector3(0,2,-31), Vector3(50,4,2), Color("777f86"))
    _block(Vector3(0,2,31), Vector3(50,4,2), Color("777f86"))

func _block(pos: Vector3, size: Vector3, color: Color) -> void:
    var mesh := MeshInstance3D.new()
    var box := BoxMesh.new()
    box.size = size
    mesh.mesh = box
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
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
    _block(pos, size, Color("8b7660"))
    for sx in [-1,1]:
        for sz in [-1,1]:
            _block(pos + Vector3(sx*3.2,3.4,sz*3.2), Vector3(1,1,1), Color("2e3338"))

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
