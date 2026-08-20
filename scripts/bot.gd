extends CharacterBody3D

# Tactical bot AI for BlockStrike.
# The bots use visibility checks, target scoring, cover seeking, strafing,
# burst fire, reaction time, ammo/reload logic and stuck recovery.

var world: Node
var player_id := 100
var health := 100
var target: Node3D
var state := "SEARCH"
var gravity := 18.0
var speed := 4.2
var sprint_speed := 5.4
var think_timer := 0.0
var shoot_timer := 0.0
var reaction_timer := 0.0
var burst_left := 0
var burst_timer := 0.0
var reload_timer := 0.0
var ammo := 30
var reserve_ammo := 90
var reloading := false
var last_health := 100
var last_position := Vector3.ZERO
var stuck_timer := 0.0
var strafe_sign := 1.0
var strafe_timer := 0.0
var cover_point := Vector3.ZERO
var investigate_point := Vector3.ZERO
var patrol_point := Vector3.ZERO
var rng := RandomNumberGenerator.new()
var visual: Node3D
var rifle: Node3D
var anim_time := 0.0
var muzzle_flash := 0.0

const DAMAGE := 12
const MAX_SIGHT_DISTANCE := 55.0
const COMBAT_DISTANCE := 20.0
const IDEAL_DISTANCE := 12.0
const REACTION_MIN := 0.12
const REACTION_MAX := 0.34
const THINK_INTERVAL := 0.12
const RELOAD_TIME := 1.65
const FIRE_INTERVAL := 0.105
const GRAVITY := 18.0

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
    rng.randomize()
    last_position = global_position
    _make_body()
    strafe_sign = -1.0 if rng.randf() < 0.5 else 1.0

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
    visual = Node3D.new()
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

    rifle = Node3D.new()
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

    _update_timers(delta)
    _apply_gravity(delta)
    _animate(delta)

    if think_timer <= 0.0:
        think_timer = THINK_INTERVAL
        _think()
    else:
        think_timer -= delta

    _execute_movement(delta)
    move_and_slide()
    _recover_if_stuck(delta)

func _update_timers(delta: float) -> void:
    shoot_timer = maxf(0.0, shoot_timer - delta)
    reaction_timer = maxf(0.0, reaction_timer - delta)
    burst_timer = maxf(0.0, burst_timer - delta)
    strafe_timer = maxf(0.0, strafe_timer - delta)
    muzzle_flash = maxf(0.0, muzzle_flash - delta)
    if reloading:
        reload_timer -= delta
        if reload_timer <= 0.0:
            _finish_reload()

func _apply_gravity(delta: float) -> void:
    if not is_on_floor():
        velocity.y -= GRAVITY * delta
    else:
        velocity.y = 0.0

func _think() -> void:
    # Choose the most dangerous visible opponent rather than blindly using
    # the closest player. Visible, healthy and close targets score highest.
    var candidate := _choose_best_target()
    if candidate != null:
        if target != candidate:
            target = candidate
            reaction_timer = rng.randf_range(REACTION_MIN, REACTION_MAX)
            state = "ENGAGE"
        _combat_decision()
    else:
        target = null
        _search_or_patrol()

func _choose_best_target() -> Node3D:
    var best: Node3D = null
    var best_score := -INF
    for id in world.players:
        var p = world.players[id]
        if p == self or not is_instance_valid(p):
            continue
        if p.get("health") != null and int(p.health) <= 0:
            continue
        var distance := global_position.distance_to(p.global_position)
        if distance > MAX_SIGHT_DISTANCE:
            continue
        var visible := _has_line_of_sight(p)
        var score := 0.0
        score += maxf(0.0, 40.0 - distance) * 1.5
        score += 35.0 if visible else -25.0
        if p == target:
            score += 12.0
        if p.get("is_local") == true:
            score += 8.0
        var hp := float(p.health) if p.get("health") != null else 100.0
        score += (100.0 - hp) * 0.18
        if score > best_score:
            best_score = score
            best = p
    return best

func _combat_decision() -> void:
    if not is_instance_valid(target):
        return

    var distance := global_position.distance_to(target.global_position)
    var visible := _has_line_of_sight(target)

    if reloading:
        state = "RELOAD"
        return

    if ammo <= 0:
        _start_reload()
        state = "RELOAD"
        return

    if not visible:
        state = "HUNT"
        investigate_point = target.global_position
        return

    if reaction_timer > 0.0:
        state = "AIM"
        return

    state = "ENGAGE"

    # Keep useful distance instead of running directly into the player.
    if distance < 5.5:
        state = "RETREAT"
    elif distance > COMBAT_DISTANCE:
        state = "PUSH"
    elif distance < IDEAL_DISTANCE:
        state = "STRAFE"
    else:
        state = "STRAFE"

    if strafe_timer <= 0.0:
        strafe_timer = rng.randf_range(0.55, 1.35)
        strafe_sign = -strafe_sign if rng.randf() < 0.65 else strafe_sign

    # Bursts become shorter and more accurate at longer range.
    if visible and distance <= MAX_SIGHT_DISTANCE and shoot_timer <= 0.0:
        if burst_left <= 0:
            burst_left = rng.randi_range(2, 6) if distance < 18.0 else rng.randi_range(1, 3)
        _shoot_target()
        burst_left -= 1
        shoot_timer = FIRE_INTERVAL + rng.randf_range(0.01, 0.06)

func _execute_movement(delta: float) -> void:
    var desired := Vector3.ZERO

    if state == "PUSH" and is_instance_valid(target):
        desired = _safe_direction_to(target.global_position)
    elif state == "RETREAT" and is_instance_valid(target):
        desired = _safe_direction_to(global_position * 2.0 - target.global_position)
    elif state == "STRAFE" and is_instance_valid(target):
        var to_target := (target.global_position - global_position)
        to_target.y = 0.0
        if to_target.length() > 0.1:
            var forward := to_target.normalized()
            var side := Vector3(-forward.z, 0, forward.x) * strafe_sign
            var distance := to_target.length()
            var correction := 0.0
            if distance < IDEAL_DISTANCE - 2.0:
                correction = -0.45
            elif distance > IDEAL_DISTANCE + 3.0:
                correction = 0.45
            desired = (side + forward * correction).normalized()
            desired = _avoid_obstacles(desired)
    elif state == "HUNT":
        desired = _safe_direction_to(investigate_point)
        if global_position.distance_to(investigate_point) < 2.0:
            state = "SEARCH"
    elif state == "SEARCH" or state == "PATROL":
        if patrol_point == Vector3.ZERO or global_position.distance_to(patrol_point) < 2.0:
            patrol_point = _pick_patrol_point()
        desired = _safe_direction_to(patrol_point)
    elif state == "AIM":
        desired = _avoid_obstacles(Vector3.ZERO)

    if desired.length() > 0.05:
        var move_speed := sprint_speed if state == "PUSH" or state == "HUNT" else speed
        velocity.x = move_toward(velocity.x, desired.x * move_speed, 18.0 * delta)
        velocity.z = move_toward(velocity.z, desired.z * move_speed, 18.0 * delta)
        _face_direction(desired, delta)
    else:
        velocity.x = move_toward(velocity.x, 0.0, 16.0 * delta)
        velocity.z = move_toward(velocity.z, 0.0, 16.0 * delta)
        if is_instance_valid(target):
            var aim := target.global_position - global_position
            aim.y = 0.0
            if aim.length() > 0.1:
                _face_direction(aim.normalized(), delta)

func _safe_direction_to(point: Vector3) -> Vector3:
    var d := point - global_position
    d.y = 0.0
    if d.length() < 0.05:
        return Vector3.ZERO
    return _avoid_obstacles(d.normalized())

func _avoid_obstacles(direction: Vector3) -> Vector3:
    if direction.length() < 0.05:
        return Vector3.ZERO

    var space := get_world_3d().direct_space_state
    var origin := global_position + Vector3.UP * 0.8
    var forward := direction.normalized()
    var right := Vector3(-forward.z, 0, forward.x)
    var choices := [forward, (forward + right * 0.65).normalized(), (forward - right * 0.65).normalized(), right, -right]
    var best := forward
    var best_score := -INF

    for choice in choices:
        var end := origin + choice * 2.8
        var query := PhysicsRayQueryParameters3D.create(origin, end)
        query.exclude = [self]
        var hit := space.intersect_ray(query)
        var score := 0.0
        if hit.is_empty():
            score += 10.0
        else:
            score -= 20.0
        score += choice.dot(forward) * 5.0
        if score > best_score:
            best_score = score
            best = choice
    return best.normalized()

func _has_line_of_sight(other: Node3D) -> bool:
    if not is_instance_valid(other):
        return false
    var from := global_position + Vector3.UP * 1.55
    var to := other.global_position + Vector3.UP * 1.35
    var query := PhysicsRayQueryParameters3D.create(from, to)
    query.exclude = [self]
    var hit := get_world_3d().direct_space_state.intersect_ray(query)
    return hit.is_empty() or hit.collider == other

func _face_direction(direction: Vector3, delta: float) -> void:
    var wanted := atan2(-direction.x, -direction.z)
    rotation.y = lerp_angle(rotation.y, wanted, minf(1.0, delta * 10.0))

func _shoot_target() -> void:
    if reloading or ammo <= 0 or not is_instance_valid(target):
        return

    var from := global_position + Vector3.UP * 1.52
    var target_point := target.global_position + Vector3.UP * 1.25
    var distance := from.distance_to(target_point)
    var aim_error := clampf(distance / 85.0, 0.012, 0.10)

    # Skilled bots compensate for distance but still have believable spread.
    var right := global_transform.basis.x
    var up := Vector3.UP
    var spread := right * rng.randf_range(-aim_error, aim_error) + up * rng.randf_range(-aim_error, aim_error)
    var to := target_point + spread

    var query := PhysicsRayQueryParameters3D.create(from, to)
    query.exclude = [self]
    var hit := get_world_3d().direct_space_state.intersect_ray(query)
    ammo -= 1
    muzzle_flash = 0.05

    if hit and hit.collider and hit.collider.has_method("take_damage"):
        hit.collider.take_damage(DAMAGE, player_id)

func _start_reload() -> void:
    if reloading or ammo >= 30 or reserve_ammo <= 0:
        return
    reloading = true
    reload_timer = RELOAD_TIME
    burst_left = 0
    state = "RELOAD"

func _finish_reload() -> void:
    reloading = false
    var needed := 30 - ammo
    var loaded := mini(needed, reserve_ammo)
    ammo += loaded
    reserve_ammo -= loaded

func _search_or_patrol() -> void:
    if rng.randf() < 0.25 and world.spawn_points.size() > 0:
        patrol_point = world.spawn_points[rng.randi_range(0, world.spawn_points.size() - 1)]
    state = "PATROL"

func _pick_patrol_point() -> Vector3:
    var candidates: Array = []
    for p in world.spawn_points:
        if global_position.distance_to(p) > 5.0:
            candidates.append(p)
    if candidates.is_empty():
        return global_position
    return candidates[rng.randi_range(0, candidates.size() - 1)]

func _recover_if_stuck(delta: float) -> void:
    var moved := global_position.distance_to(last_position)
    last_position = global_position
    if moved < 0.035 and Vector2(velocity.x, velocity.z).length() > 1.0:
        stuck_timer += delta
    else:
        stuck_timer = maxf(0.0, stuck_timer - delta * 2.0)

    if stuck_timer > 0.7:
        stuck_timer = 0.0
        strafe_sign = -strafe_sign
        velocity.y = 5.5
        if is_instance_valid(target):
            investigate_point = target.global_position
        state = "HUNT"

func _animate(delta: float) -> void:
    anim_time += delta
    if not visual:
        return
    var moving := Vector2(velocity.x, velocity.z).length() > 0.5 and is_on_floor()
    if moving:
        var walk := sin(anim_time * 8.0) * 0.035
        visual.position.y = abs(walk) * 0.25
        if rifle:
            rifle.rotation.x = deg_to_rad(-8.0) + walk * 0.5
    else:
        visual.position.y = lerpf(visual.position.y, 0.0, delta * 8.0)
    if muzzle_flash > 0.0 and rifle:
        rifle.position.x = 0.42 + rng.randf_range(-0.015, 0.015)
    elif rifle:
        rifle.position.x = lerpf(rifle.position.x, 0.42, delta * 18.0)

func take_damage(amount: int, killer: int) -> void:
    health -= amount
    last_health = health
    # Being hit immediately changes behaviour: find the attacker and strafe.
    if killer != player_id and world and world.players.has(killer):
        target = world.players[killer]
        reaction_timer = 0.0
        state = "STRAFE"
        strafe_sign = -strafe_sign
    if health <= 0:
        if world:
            world.award_kill(killer)
        health = 100
        ammo = 30
        reserve_ammo = 90
        reloading = false
        velocity = Vector3.ZERO
        position = world.spawn_points[(player_id + rng.randi_range(0, world.spawn_points.size() - 1)) % world.spawn_points.size()]
        target = null
        state = "SEARCH"
