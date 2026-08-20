extends CharacterBody3D

var world: Node
var player_id := 100
var health := 100
var target: Node3D
var think := 0.0
var shoot_timer := 0.0
var gravity := 18.0
var speed := 3.4

const DAMAGE := 12
const ARMOR := Color("4b2022")
const ARMOR_LIGHT := Color("713033")
const DARK := Color("241a1b")
const CLOTH := Color("4a3a36")
const CAMO_A := Color("635a4b")
const CAMO_B := Color("81735e")
const BOOT := Color("241f1e")
const SKIN := Color("b77e61")
const METAL := Color("5d4f4b")
const WOOD := Color("684838")

func _ready() -> void:
    _make_body()

func _box(parent: Node3D, size: Vector3, pos: Vector3, color: Color, name := "Block") -> MeshInstance3D:
    var mesh := MeshInstance3D.new()
    mesh.name = name
    var box := BoxMesh.new()
    box.size = size
    mesh.mesh = box
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.roughness = 0.8
    mesh.material_override = mat
    mesh.position = pos
    parent.add_child(mesh)
    return mesh

func _make_body() -> void:
    var visual := Node3D.new()
    visual.name = "BlockBot"
    add_child(visual)
    _box(visual, Vector3(0.34, 0.18, 0.62), Vector3(-0.22, 0.09, -0.02), BOOT, "LeftBoot")
    _box(visual, Vector3(0.34, 0.18, 0.62), Vector3(0.22, 0.09, -0.02), BOOT, "RightBoot")
    _box(visual, Vector3(0.32, 0.58, 0.34), Vector3(-0.22, 0.42, 0), CAMO_A, "LeftShin")
    _box(visual, Vector3(0.32, 0.58, 0.34), Vector3(0.22, 0.42, 0), CAMO_B, "RightShin")
    _box(visual, Vector3(0.36, 0.16, 0.38), Vector3(-0.22, 0.70, -0.01), DARK, "LeftKnee")
    _box(visual, Vector3(0.36, 0.16, 0.38), Vector3(0.22, 0.70, -0.01), DARK, "RightKnee")
    _box(visual, Vector3(0.38, 0.58, 0.40), Vector3(-0.22, 0.96, 0), CLOTH, "LeftThigh")
    _box(visual, Vector3(0.38, 0.58, 0.40), Vector3(0.22, 0.96, 0), CLOTH, "RightThigh")
    _box(visual, Vector3(0.92, 0.14, 0.52), Vector3(0, 1.25, 0), DARK, "Belt")
    _box(visual, Vector3(0.86, 0.72, 0.48), Vector3(0, 1.62, 0), ARMOR, "Torso")
    _box(visual, Vector3(0.70, 0.46, 0.10), Vector3(0, 1.68, -0.27), ARMOR_LIGHT, "ChestPlate")
    _box(visual, Vector3(0.22, 0.25, 0.10), Vector3(-0.27, 1.50, -0.27), DARK, "LeftPouch")
    _box(visual, Vector3(0.22, 0.25, 0.10), Vector3(0.27, 1.50, -0.27), DARK, "RightPouch")
    _box(visual, Vector3(0.16, 0.28, 0.12), Vector3(-0.38, 1.35, -0.25), ARMOR_LIGHT, "LeftMagazine")
    _box(visual, Vector3(0.16, 0.28, 0.12), Vector3(0.38, 1.35, -0.25), ARMOR_LIGHT, "RightMagazine")
    _box(visual, Vector3(0.25, 0.18, 0.25), Vector3(0, 2.05, 0), SKIN, "Neck")
    _box(visual, Vector3(0.54, 0.52, 0.50), Vector3(0, 2.32, 0), SKIN, "Head")
    _box(visual, Vector3(0.60, 0.14, 0.54), Vector3(0, 2.58, 0), DARK, "HelmetTop")
    _box(visual, Vector3(0.68, 0.14, 0.48), Vector3(0, 2.48, 0), ARMOR, "HelmetBand")
    _box(visual, Vector3(0.58, 0.14, 0.08), Vector3(0, 2.30, -0.27), DARK, "Visor")
    _box(visual, Vector3(0.16, 0.12, 0.06), Vector3(-0.18, 2.30, -0.30), METAL, "VisorLeft")
    _box(visual, Vector3(0.16, 0.12, 0.06), Vector3(0.18, 2.30, -0.30), METAL, "VisorRight")
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

    var rifle := Node3D.new()
    rifle.name = "BotRifle"
    rifle.position = Vector3(0.42, 1.42, -0.42)
    rifle.rotation_degrees = Vector3(-8, 0, -8)
    visual.add_child(rifle)
    _box(rifle, Vector3(0.16, 0.16, 0.82), Vector3(0, 0, 0), DARK, "Receiver")
    _box(rifle, Vector3(0.12, 0.12, 0.58), Vector3(0, 0, -0.62), METAL, "Barrel")
    _box(rifle, Vector3(0.18, 0.12, 0.34), Vector3(0, -0.06, 0.40), WOOD, "Stock")
    _box(rifle, Vector3(0.16, 0.30, 0.18), Vector3(0, -0.20, -0.08), DARK, "Magazine")
    _box(rifle, Vector3(0.20, 0.08, 0.26), Vector3(0, 0.14, 0.04), ARMOR_LIGHT, "Rail")
    _box(rifle, Vector3(0.10, 0.12, 0.12), Vector3(0, 0.22, -0.12), METAL, "Sight")
    _box(rifle, Vector3(0.12, 0.18, 0.14), Vector3(0, -0.10, 0.20), WOOD, "Grip")
    _box(rifle, Vector3(0.18, 0.08, 0.20), Vector3(0, 0.01, -0.94), DARK, "Muzzle")

    var collision := CollisionShape3D.new()
    var capsule := CapsuleShape3D.new()
    capsule.height = 2.0
    capsule.radius = 0.38
    collision.shape = capsule
    collision.position.y = 1.05
    add_child(collision)

func _physics_process(delta: float) -> void:
    if not world:
        return

    if not is_on_floor():
        velocity.y -= gravity * delta
    else:
        velocity.y = 0.0

    think -= delta
    shoot_timer -= delta
    if think <= 0.0:
        think = 0.20
        target = world.get_target_for(self)

    if not is_instance_valid(target):
        velocity.x = move_toward(velocity.x, 0.0, 12.0 * delta)
        velocity.z = move_toward(velocity.z, 0.0, 12.0 * delta)
        move_and_slide()
        return

    var flat_target := target.global_position
    flat_target.y = global_position.y
    var distance := global_position.distance_to(target.global_position)
    var to_target := flat_target - global_position

    if to_target.length() > 0.1:
        look_at(flat_target, Vector3.UP)

    if distance > 8.0:
        var dir := to_target.normalized()
        velocity.x = dir.x * speed
        velocity.z = dir.z * speed
    else:
        velocity.x = move_toward(velocity.x, 0.0, 12.0 * delta)
        velocity.z = move_toward(velocity.z, 0.0, 12.0 * delta)
        if shoot_timer <= 0.0:
            _shoot_target()
            shoot_timer = 0.65

    move_and_slide()

func _shoot_target() -> void:
    if not is_instance_valid(target):
        return
    var from := global_position + Vector3.UP * 1.45
    var to := target.global_position + Vector3.UP * 1.2
    var query := PhysicsRayQueryParameters3D.create(from, to)
    query.exclude = [self]
    var hit := get_world_3d().direct_space_state.intersect_ray(query)
    if hit and hit.collider == target and target.has_method("take_damage"):
        target.take_damage(DAMAGE, player_id)

func take_damage(amount: int, killer: int) -> void:
    health -= amount
    if health <= 0:
        if world:
            world.award_kill(killer)
        health = 100
        velocity = Vector3.ZERO
        position = world.spawn_points[(player_id + randi()) % world.spawn_points.size()]
