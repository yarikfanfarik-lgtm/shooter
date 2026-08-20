extends CharacterBody3D

var world: Node
var player_id := 1
var nickname := "Player"
var is_local := false
var health := 100
var ammo := 30
var reserve_ammo := 90
var reloading := false
var reload_timer := 0.0
var fire_cooldown := 0.0
var camera: Camera3D
var view_rifle: Node3D
var yaw := 0.0
var pitch := 0.0
var bob_time := 0.0
var recoil := 0.0
var aiming := false
var trigger_held := false
var weapon_mode := 0
var weapon_name := "AK-47"

const AK_MAG := 30
const AK_RESERVE := 90
const SNIPER_MAG := 5
const SNIPER_RESERVE := 25
const AK_DAMAGE := 34
const SNIPER_DAMAGE := 100
const SPEED := 6.0
const GRAVITY := 18.0
const NORMAL_FOV := 75.0
const AK_AIM_FOV := 55.0
const SNIPER_AIM_FOV := 24.0

func _ready() -> void:
    if is_local:
        add_to_group("local_player")
        _setup_camera()
        _refresh_weapon()

func _setup_camera() -> void:
    camera = Camera3D.new()
    camera.position = Vector3(0, 1.55, 0)
    camera.current = true
    camera.fov = NORMAL_FOV
    add_child(camera)

func _make_weapon(parent: Node3D, first_person := false) -> void:
    var body := MeshInstance3D.new()
    var box := BoxMesh.new()
    box.size = Vector3(0.18, 0.16, 0.75 if weapon_mode == 0 else 0.95)
    body.mesh = box
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color("30343a") if weapon_mode == 0 else Color("24272c")
    mat.roughness = 0.5
    body.material_override = mat
    parent.add_child(body)
    if weapon_mode == 0:
        var mag := MeshInstance3D.new()
        var mag_box := BoxMesh.new()
        mag_box.size = Vector3(0.12, 0.34, 0.16)
        mag.mesh = mag_box
        mag.position = Vector3(0, -0.18, 0.02)
        mag.material_override = mat
        parent.add_child(mag)
    var barrel := MeshInstance3D.new()
    var barrel_box := BoxMesh.new()
    barrel_box.size = Vector3(0.10, 0.10, 0.55 if weapon_mode == 0 else 1.0)
    barrel.mesh = barrel_box
    barrel.position = Vector3(0, 0.01, -0.62 if weapon_mode == 0 else -0.95)
    barrel.material_override = mat
    parent.add_child(barrel)

func _make_view_arms(parent: Node3D) -> void:
    for side in [-1.0, 1.0]:
        var arm := MeshInstance3D.new()
        var box := BoxMesh.new()
        box.size = Vector3(0.14, 0.14, 0.48)
        arm.mesh = box
        arm.position = Vector3(0.18 * side, -0.16, -0.34)
        arm.rotation_degrees = Vector3(-18, 0, 8 * side)
        var mat := StandardMaterial3D.new()
        mat.albedo_color = Color("4d5660")
        mat.roughness = 0.8
        arm.material_override = mat
        parent.add_child(arm)

func _refresh_weapon() -> void:
    if not is_local or view_rifle == null:
        return
    for child in view_rifle.get_children():
        child.queue_free()
    _make_weapon(view_rifle, true)
    _make_view_arms(view_rifle)

func _set_aiming(value: bool) -> void:
    aiming = value and not reloading
    if weapon_mode == 1 and aiming:
        camera.fov = SNIPER_AIM_FOV
        view_rifle.position = Vector3(0.0, -0.34, -0.92)
    elif weapon_mode == 0 and aiming:
        camera.fov = AK_AIM_FOV
        view_rifle.position = Vector3(0.08, -0.38, -0.94)
    else:
        camera.fov = NORMAL_FOV
        view_rifle.position = Vector3(0.38, -0.28, -0.78)

func _unhandled_input(event: InputEvent) -> void:
    if not is_local:
        return
    if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
        yaw -= event.relative.x * 0.0025
        pitch = clamp(pitch - event.relative.y * 0.0025, -1.4, 1.4)
        rotation.y = yaw
        camera.rotation.x = pitch
    if event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_RIGHT:
            _set_aiming(event.pressed)
        elif event.button_index == MOUSE_BUTTON_LEFT:
            trigger_held = event.pressed
            if event.pressed and weapon_mode == 1:
                _shoot()
    if event is InputEventKey and event.pressed and not event.echo:
        match event.physical_keycode:
            KEY_G:
                if world and world.has_method("throw_smoke"):
                    world.throw_smoke()
            KEY_H:
                if world and world.has_method("place_mine"):
                    world.place_mine()
            KEY_R:
                _start_reload()
            KEY_1:
                _switch_weapon(0)
            KEY_2:
                _switch_weapon(1)
            KEY_SPACE:
                if is_on_floor():
                    velocity.y = 7.0
            KEY_ESCAPE:
                Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _physics_process(delta: float) -> void:
    if not is_local:
        return
    fire_cooldown = maxf(0.0, fire_cooldown - delta)
    if reloading:
        reload_timer -= delta
        if reload_timer <= 0.0:
            _finish_reload()
    elif weapon_mode == 0 and trigger_held:
        _shoot()
    var input_vec := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
    var dir := (transform.basis * Vector3(input_vec.x, 0, input_vec.y)).normalized()
    var speed := SPEED * (0.82 if aiming else 1.0)
    velocity.x = move_toward(velocity.x, dir.x * speed, 25.0 * delta)
    velocity.z = move_toward(velocity.z, dir.z * speed, 25.0 * delta)
    if not is_on_floor():
        velocity.y -= GRAVITY * delta
    move_and_slide()
    if view_rifle and not reloading and not aiming:
        if input_vec.length() > 0.1:
            bob_time += delta * 9.0
            view_rifle.position.y = -0.28 + sin(bob_time) * 0.018
            view_rifle.position.x = 0.38 + cos(bob_time * 0.5) * 0.012
    recoil = move_toward(recoil, 0.0, delta * 10.0)
    if camera:
        camera.rotation.x = pitch - recoil

func _shoot() -> void:
    if reloading or ammo <= 0 or fire_cooldown > 0.0:
        if ammo <= 0 and not reloading:
            _start_reload()
        return
    ammo -= 1
    fire_cooldown = 0.75 if weapon_mode == 1 else 0.12
    recoil = 0.055 if weapon_mode == 1 else 0.035
    var from := camera.global_position
    var dir := -camera.global_transform.basis.z
    if not aiming:
        var spread := 0.012 if weapon_mode == 1 else 0.02
        dir += camera.global_transform.basis.x * randf_range(-spread, spread)
        dir += camera.global_transform.basis.y * randf_range(-spread, spread)
    var to := from + dir.normalized() * 150.0
    var query := PhysicsRayQueryParameters3D.create(from, to)
    query.exclude = [self]
    var hit := get_world_3d().direct_space_state.intersect_ray(query)
    if hit and hit.collider and hit.collider.has_method("take_damage"):
        hit.collider.take_damage(SNIPER_DAMAGE if weapon_mode == 1 else AK_DAMAGE, player_id)

func _start_reload() -> void:
    var mag := SNIPER_MAG if weapon_mode == 1 else AK_MAG
    if reloading or ammo >= mag or reserve_ammo <= 0:
        return
    trigger_held = false
    reloading = true
    reload_timer = 2.0 if weapon_mode == 1 else 1.35
    _set_aiming(false)
    if view_rifle:
        var tween := create_tween()
        tween.tween_property(view_rifle, "position", Vector3(0.38, -0.48, -0.70), 0.22)
        tween.tween_property(view_rifle, "rotation_degrees", Vector3(35, -8, -8), 0.35)
        tween.tween_property(view_rifle, "position", Vector3(0.38, -0.20, -0.82), 0.35)
        tween.tween_property(view_rifle, "rotation_degrees", Vector3(-2, -3, -2), 0.35)

func _finish_reload() -> void:
    var mag := SNIPER_MAG if weapon_mode == 1 else AK_MAG
    var needed := mag - ammo
    var loaded := mini(needed, reserve_ammo)
    ammo += loaded
    reserve_ammo -= loaded
    reloading = false
    _set_aiming(false)

func _switch_weapon(mode: int) -> void:
    if reloading or mode == weapon_mode:
        return
    trigger_held = false
    weapon_mode = mode
    weapon_name = "AK-47" if mode == 0 else "SNIPER"
    ammo = AK_MAG if mode == 0 else SNIPER_MAG
    reserve_ammo = AK_RESERVE if mode == 0 else SNIPER_RESERVE
    _set_aiming(false)
    _refresh_weapon()

func take_damage(amount: int, killer: int) -> void:
    health -= amount
    if health <= 0:
        if world:
            world.award_kill(killer)
        health = 100
        position = world.spawn_points[randi() % world.spawn_points.size()]
