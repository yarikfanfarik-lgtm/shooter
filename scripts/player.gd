extends CharacterBody3D

var player_id := 1
var is_local := false
var team := "ffa"
var world: Node
var max_health := 100
var health := 100
var money := 500
var current_weapon := "ak47"
var ammo := 30
var camera: Camera3D
var mouse_locked := false
var yaw := 0.0
var pitch := 0.0
const SPEED := 6.5
const GRAVITY := 18.0

func _ready() -> void:
    _make_body()
    if is_local:
        camera = Camera3D.new(); camera.position = Vector3(0,1.55,0); camera.current = true
        add_child(camera)
        Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _make_body() -> void:
    var mesh := MeshInstance3D.new()
    var box := BoxMesh.new(); box.size = Vector3(0.8,1.8,0.55); mesh.mesh = box
    var mat := StandardMaterial3D.new(); mat.albedo_color = Color("d04b4b") if team == "red" else Color("4e79d1") if team == "blue" else Color("c7cbd1")
    mesh.material_override = mat; mesh.position.y = 0.9; add_child(mesh)
    var shape := CollisionShape3D.new(); var capsule := CapsuleShape3D.new(); capsule.height=1.8; capsule.radius=0.4; shape.shape=capsule; shape.position.y=0.9; add_child(shape)

func _unhandled_input(event: InputEvent) -> void:
    if not is_local: return
    if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
        yaw -= event.relative.x * 0.0025 * Settings.sensitivity
        pitch = clamp(pitch - event.relative.y * 0.0025 * Settings.sensitivity, -1.4, 1.4)
        rotation.y = yaw; camera.rotation.x = pitch
    if event.is_action_pressed("fire"): shoot()
    if event.is_action_pressed("reload"): reload()
    if event.is_action_pressed("jump") and is_on_floor(): velocity.y = 7.5
    if event.is_action_pressed("ui_cancel"): Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _physics_process(delta: float) -> void:
    if not is_local: return
    var input_vec := Input.get_vector("move_left","move_right","move_forward","move_back")
    var dir := (transform.basis * Vector3(input_vec.x,0,input_vec.y)).normalized()
    velocity.x = move_toward(velocity.x, dir.x*SPEED, 30*delta)
    velocity.z = move_toward(velocity.z, dir.z*SPEED, 30*delta)
    if not is_on_floor(): velocity.y -= GRAVITY*delta
    move_and_slide()

func shoot() -> void:
    if ammo <= 0: return
    ammo -= 1
    var stats: Dictionary = world.WEAPONS.get(current_weapon, world.WEAPONS.ak47)
    var origin := camera.global_position
    var end := origin + -camera.global_transform.basis.z * float(stats.range)
    var query := PhysicsRayQueryParameters3D.create(origin,end)
    query.exclude = [self]
    var hit := world.get_world_3d().direct_space_state.intersect_ray(query)
    if hit and hit.collider and hit.collider.has_method("take_damage"):
        var headshot := str(hit.position.y - hit.collider.global_position.y) > 1.3
        var damage := int(stats.headshot if headshot else stats.damage)
        hit.collider.take_damage(damage, player_id, headshot)

func take_damage(amount: int, killer: int, headshot: bool=false) -> void:
    health -= amount
    if health <= 0:
        world.award_kill(killer, headshot)
        health = max_health
        position = world.spawn_points[player_id % world.spawn_points.size()] if world.spawn_points.size() else Vector3.ZERO

func give_weapon(name: String) -> void:
    current_weapon = name
    ammo = 30

func reload() -> void:
    ammo = 30
