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

const SKIN := Color("c88f6a")
const ARMOR := Color("252a31")
const ARMOR_LIGHT := Color("39414a")
const DARK := Color("171a1f")
const METAL := Color("4b5158")
const CLOTH := Color("343941")
const CAMO_A := Color("5b5b4f")
const CAMO_B := Color("777565")
const BOOT := Color("202328")
const WOOD := Color("765238")

func _ready() -> void:
    _make_body()
    if is_local:
        camera = Camera3D.new()
        camera.position = Vector3(0, 1.55, 0)
        camera.current = true
        add_child(camera)
        _make_view_rifle()
        Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _box(parent: Node3D, size: Vector3, pos: Vector3, color: Color, name := "Block") -> MeshInstance3D:
    var mesh := MeshInstance3D.new()
    mesh.name = name
    var box := BoxMesh.new()
    box.size = size
    mesh.mesh = box
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.roughness = 0.78
    mesh.material_override = mat
    mesh.position = pos
    parent.add_child(mesh)
    return mesh

func _make_body() -> void:
    # Detailed block-built soldier. Every visible part is made from box geometry.
    var visual := Node3D.new()
    visual.name = "BlockCharacter"
    add_child(visual)

    # Boots / lower legs.
    _box(visual, Vector3(0.34, 0.18, 0.62), Vector3(-0.22, 0.09, -0.02), BOOT, "LeftBoot")
    _box(visual, Vector3(0.34, 0.18, 0.62), Vector3(0.22, 0.09, -0.02), BOOT, "RightBoot")
    _box(visual, Vector3(0.32, 0.58, 0.34), Vector3(-0.22, 0.42, 0), CAMO_A, "LeftShin")
    _box(visual, Vector3(0.32, 0.58, 0.34), Vector3(0.22, 0.42, 0), CAMO_B, "RightShin")
    _box(visual, Vector3(0.36, 0.16, 0.38), Vector3(-0.22, 0.70, -0.01), DARK, "LeftKnee")
    _box(visual, Vector3(0.36, 0.16, 0.38), Vector3(0.22, 0.70, -0.01), DARK, "RightKnee")
    _box(visual, Vector3(0.38, 0.58, 0.40), Vector3(-0.22, 0.96, 0), CLOTH, "LeftThigh")
    _box(visual, Vector3(0.38, 0.58, 0.40), Vector3(0.22, 0.96, 0), CLOTH, "RightThigh")

    # Belt and torso.
    _box(visual, Vector3(0.92, 0.14, 0.52), Vector3(0, 1.25, 0), DARK, "Belt")
    _box(visual, Vector3(0.86, 0.72, 0.48), Vector3(0, 1.62, 0), ARMOR, "Torso")
    _box(visual, Vector3(0.70, 0.46, 0.10), Vector3(0, 1.68, -0.27), ARMOR_LIGHT, "ChestPlate")
    _box(visual, Vector3(0.22, 0.25, 0.10), Vector3(-0.27, 1.50, -0.27), DARK, "LeftPouch")
    _box(visual, Vector3(0.22, 0.25, 0.10), Vector3(0.27, 1.50, -0.27), DARK, "RightPouch")
    _box(visual, Vector3(0.16, 0.28, 0.12), Vector3(-0.38, 1.35, -0.25), ARMOR_LIGHT, "LeftMagazine")
    _box(visual, Vector3(0.16, 0.28, 0.12), Vector3(0.38, 1.35, -0.25), ARMOR_LIGHT, "RightMagazine")

    # Neck and head.
    _box(visual, Vector3(0.25, 0.18, 0.25), Vector3(0, 2.05, 0), SKIN, "Neck")
    _box(visual, Vector3(0.54, 0.52, 0.50), Vector3(0, 2.32, 0), SKIN, "Head")
    _box(visual, Vector3(0.60, 0.14, 0.54), Vector3(0, 2.58, 0), DARK, "HelmetTop")
    _box(visual, Vector3(0.68, 0.14, 0.48), Vector3(0, 2.48, 0), ARMOR, "HelmetBand")
    _box(visual, Vector3(0.58, 0.14, 0.08), Vector3(0, 2.30, -0.27), DARK, "Visor")
    _box(visual, Vector3(0.16, 0.12, 0.06), Vector3(-0.18, 2.30, -0.30), METAL, "VisorLeft")
    _box(visual, Vector3(0.16, 0.12, 0.06), Vector3(0.18, 2.30, -0.30), METAL, "VisorRight")

    # Shoulders and arms.
    _box(visual, Vector3(0.28, 0.28, 0.48), Vector3(-0.57, 1.87, 0), ARMOR_LIGHT, "LeftShoulder")
    _box(visual, Vector3(0.28, 0.28, 0.48), Vector3(0.57, 1.87, 0), ARMOR_LIGHT, "RightShoulder")
    _box(visual, Vector3(0.30, 0.48, 0.34), Vector3(-0.68, 1.60, 0), CLOTH, "LeftUpperArm")
    _box(visual, Vector3(0.30, 0.48, 0.34), Vector3(0.68, 1.60, 0), CLOTH, "RightUpperArm")
    _box(visual, Vector3(0.34, 0.16, 0.38), Vector3(-0.68, 1.33, 0), DARK, "LeftElbow")
    _box(visual, Vector3(0.34, 0.16, 0.38), Vector3(0.68, 1.33, 0), DARK, "RightElbow")
    _box(visual, Vector3(0.30, 0.40, 0.34), Vector3(-0.62, 1.10, 0), CLOTH, "LeftForearm")
    _box(visual, Vector3(0.30, 0.40, 0.34), Vector3(0.62, 1.10, 0), CLOTH, "RightForearm")
    _box(visual, Vector3(0.28, 0.18, 0.30), Vector3(-0.58, 0.84, -0.02), DARK, "LeftGlove")
    _box(visual, Vector3(0.28, 0.18, 0.30), Vector3(0.58, 0.84, -0.02), DARK, "RightGlove")

    var body := CollisionShape3D.new()
    var capsule := CapsuleShape3D.new()
    capsule.height = 2.0
    capsule.radius = 0.38
    body.shape = capsule
    body.position.y = 1.05
    add_child(body)

    # A detailed rifle is mounted on the right side for third-person views.
    var rifle := Node3D.new()
    rifle.name = "Rifle"
    rifle.position = Vector3(0.42, 1.42, -0.42)
    rifle.rotation_degrees = Vector3(-8, 0, -8)
    visual.add_child(rifle)
    _make_rifle(rifle, false)

func _make_rifle(parent: Node3D, first_person: bool) -> void:
    _box(parent, Vector3(0.16, 0.16, 0.82), Vector3(0, 0, 0), DARK, "Receiver")
    _box(parent, Vector3(0.12, 0.12, 0.58), Vector3(0, 0, -0.62), METAL, "Barrel")
    _box(parent, Vector3(0.18, 0.12, 0.34), Vector3(0, -0.06, 0.40), WOOD, "Stock")
    _box(parent, Vector3(0.16, 0.30, 0.18), Vector3(0, -0.20, -0.08), DARK, "Magazine")
    _box(parent, Vector3(0.20, 0.08, 0.26), Vector3(0, 0.14, 0.04), ARMOR_LIGHT, "TopRail")
    _box(parent, Vector3(0.10, 0.12, 0.12), Vector3(0, 0.22, -0.12), METAL, "Sight")
    _box(parent, Vector3(0.12, 0.18, 0.14), Vector3(0, -0.10, 0.20), WOOD, "Grip")
    _box(parent, Vector3(0.18, 0.08, 0.20), Vector3(0, 0.01, -0.94), DARK, "Muzzle")
    if first_person:
        parent.position = Vector3(0.38, -0.28, -0.78)
        parent.rotation_degrees = Vector3(-2, -3, -2)

func _make_view_rifle() -> void:
    var rifle := Node3D.new()
    rifle.name = "FirstPersonRifle"
    camera.add_child(rifle)
    _make_rifle(rifle, true)

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
    var input_vec := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
    var dir := (transform.basis * Vector3(input_vec.x, 0, input_vec.y)).normalized()
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
