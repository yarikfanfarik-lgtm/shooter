extends CharacterBody3D

var world: Node
var player_id := 100
var health := 100
var target: Node3D
var think := 0.0
var shoot_timer := 0.0

func _ready() -> void:
    _make_body()

func _make_body() -> void:
    var mesh := MeshInstance3D.new()
    var box := BoxMesh.new()
    box.size = Vector3(0.8,1.8,0.55)
    mesh.mesh = box
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color("d05a55")
    mesh.material_override = mat
    mesh.position.y = 0.9
    add_child(mesh)
    var collision := CollisionShape3D.new()
    var capsule := CapsuleShape3D.new()
    capsule.height = 1.8
    capsule.radius = 0.4
    collision.shape = capsule
    collision.position.y = 0.9
    add_child(collision)

func _physics_process(delta: float) -> void:
    if not world:
        return
    think -= delta
    shoot_timer -= delta
    if think > 0.0:
        return
    think = 0.25
    target = world.get_target_for(self)
    if not target:
        return
    var flat := target.global_position
    flat.y = global_position.y
    look_at(flat, Vector3.UP)
    var distance := global_position.distance_to(target.global_position)
    if distance > 9.0:
        velocity = -global_transform.basis.z * 3.0
        move_and_slide()
    else:
        velocity = Vector3.ZERO
        if shoot_timer <= 0.0 and target.has_method("take_damage"):
            shoot_timer = 0.7
            target.take_damage(12, player_id)

func take_damage(amount: int, killer: int) -> void:
    health -= amount
    if health <= 0:
        world.award_kill(killer)
        health = 100
        position = world.spawn_points[player_id % world.spawn_points.size()]
