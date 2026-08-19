extends CharacterBody3D

var player_id := 100
var team := "ffa"
var world: Node
var health := 100
var max_health := 100
var money := 500
var target: Node3D
var think_time := 0.0

func _ready() -> void:
    _make_body()

func _make_body() -> void:
    var mesh := MeshInstance3D.new()
    var box := BoxMesh.new(); box.size = Vector3(0.8,1.8,0.55); mesh.mesh = box
    var mat := StandardMaterial3D.new(); mat.albedo_color = Color("d04b4b") if team == "red" else Color("4e79d1") if team == "blue" else Color("7f8996")
    mesh.material_override = mat; mesh.position.y = 0.9; add_child(mesh)
    var shape := CollisionShape3D.new(); var capsule := CapsuleShape3D.new(); capsule.height=1.8; capsule.radius=0.4; shape.shape=capsule; shape.position.y=0.9; add_child(shape)

func _physics_process(delta: float) -> void:
    think_time -= delta
    if think_time > 0: return
    think_time = 0.35
    target = _find_target()
    if not target: return
    var flat := target.global_position; flat.y = global_position.y
    look_at(flat, Vector3.UP)
    var distance := global_position.distance_to(target.global_position)
    if distance > 12:
        velocity = -global_transform.basis.z * 3.5
        move_and_slide()
    elif target.has_method("take_damage"):
        target.take_damage(10, player_id, false)

func _find_target() -> Node3D:
    var best: Node3D
    var best_d := INF
    for p in world.players.values():
        if p == self or not is_instance_valid(p): continue
        if world.match_mode == "team" and p.team == team: continue
        var d := global_position.distance_to(p.global_position)
        if d < best_d:
            best_d = d; best = p
    return best

func take_damage(amount: int, killer: int, headshot: bool=false) -> void:
    health -= amount
    if health <= 0:
        world.award_kill(killer, headshot)
        health = max_health
        position = world.spawn_points[player_id % world.spawn_points.size()] if world.spawn_points.size() else Vector3.ZERO
