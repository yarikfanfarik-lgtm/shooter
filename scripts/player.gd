extends CharacterBody3D

var world: Node
var player_id := 1
var nickname := "Player"
var is_local := false
var health := 100
var ammo := 30
var fire_cooldown := 0.0
var camera: Camera3D
var yaw := 0.0
var pitch := 0.0

const SPEED := 6.0
const GRAVITY := 18.0
const DAMAGE := 34

func _ready() -> void:
    _make_body(Color("d6d9df"))
    if is_local:
        camera = Camera3D.new()
        camera.position = Vector3(0,1.55,0)
        camera.current = true
        add_child(camera)
        Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _make_body(color: Color) -> void:
    var mesh := MeshInstance3D.new()
    var box := BoxMesh.new()
    box.size = Vector3(0.8,1.8,0.55)
    mesh.mesh = box
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mesh.material_override = mat
    mesh.position.y = 0.9
    add_child(mesh)
    var body := CollisionShape3D.new()
    var capsule := CapsuleShape3D.new()
    capsule.height = 1.8
    capsule.radius = 0.4
    body.shape = capsule
    body.position.y = 0.9
    add_child(body)

func _unhandled_input(event: InputEvent) -> void:
    if not is_local:
        return
    if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
        yaw -= event.relative.x * 0.0025
        pitch = clamp(pitch - event.relative.y * 0.0025, -1.4, 1.4)
        rotation.y = yaw
        camera.rotation.x = pitch
    if event.is_action_pressed("fire"):
        _shoot()
    if event.is_action_pressed("reload"):
        ammo = 30
    if event.is_action_pressed("jump") and is_on_floor():
        velocity.y = 7.0
    if event.is_action_pressed("ui_cancel"):
        Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _physics_process(delta: float) -> void:
    if not is_local:
        return
    fire_cooldown = maxf(0.0, fire_cooldown - delta)
    var input_vec := Input.get_vector("move_left","move_right","move_forward","move_back")
    var dir := (transform.basis * Vector3(input_vec.x,0,input_vec.y)).normalized()
    velocity.x = move_toward(velocity.x, dir.x * SPEED, 25.0 * delta)
    velocity.z = move_toward(velocity.z, dir.z * SPEED, 25.0 * delta)
    if not is_on_floor():
        velocity.y -= GRAVITY * delta
    move_and_slide()

func _shoot() -> void:
    if ammo <= 0 or fire_cooldown > 0.0:
        return
    ammo -= 1
    fire_cooldown = 0.12
    var from := camera.global_position
    var to := from + -camera.global_transform.basis.z * 100.0
    var query := PhysicsRayQueryParameters3D.create(from, to)
    query.exclude = [self]
    var hit := get_world_3d().direct_space_state.intersect_ray(query)
    if hit and hit.collider and hit.collider.has_method("take_damage"):
        hit.collider.take_damage(DAMAGE, player_id)

func take_damage(amount: int, killer: int) -> void:
    health -= amount
    if health <= 0:
        if world:
            world.award_kill(killer)
        health = 100
        position = world.spawn_points[player_id % world.spawn_points.size()]
