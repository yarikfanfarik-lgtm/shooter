extends Node

var smoke_count := 2
var mine_count := 2
var input_lock := false

func _ready() -> void:
    process_priority = 100
    set_process_input(true)
    add_to_group("tactical_manager")

func _input(event: InputEvent) -> void:
    if input_lock:
        return
    if event is InputEventKey and event.pressed and not event.echo:
        if event.physical_keycode == KEY_G:
            get_viewport().set_input_as_handled()
            _throw_smoke()
        elif event.physical_keycode == KEY_H:
            get_viewport().set_input_as_handled()
            _place_mine()

func _process(_delta: float) -> void:
    var player = _get_player()
    if player == null:
        return
    # Keep the recoil noticeable, but controlled.
    if player.weapon_mode == 0:
        player.recoil = minf(player.recoil, 0.045)
    else:
        player.recoil = minf(player.recoil, 0.055)

func _get_player():
    var players := get_tree().get_nodes_in_group("local_player")
    if players.is_empty():
        return null
    return players[0]

func _throw_smoke() -> void:
    if smoke_count <= 0 or input_lock:
        return
    var player = _get_player()
    if player == null or player.camera == null or player.world == null:
        return
    smoke_count -= 1
    input_lock = true
    var grenade := preload("res://scripts/tactical_device.gd").new()
    grenade.device_type = "smoke"
    grenade.owner_id = player.player_id
    player.world.add_child(grenade)
    grenade.global_position = player.camera.global_position - player.camera.global_transform.basis.z * 0.65
    grenade.call_deferred("launch", -player.camera.global_transform.basis.z * 10.5 + Vector3.UP * 4.0)
    get_tree().create_timer(0.25).timeout.connect(func(): input_lock = false)

func _place_mine() -> void:
    if mine_count <= 0 or input_lock:
        return
    var player = _get_player()
    if player == null or player.camera == null or player.world == null:
        return
    var from := player.camera.global_position
    var to := from + (-player.camera.global_transform.basis.z * 5.0)
    var query := PhysicsRayQueryParameters3D.create(from, to)
    query.exclude = [player]
    var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
    if hit.is_empty() or hit.normal.y < 0.55:
        return
    mine_count -= 1
    input_lock = true
    var mine := preload("res://scripts/tactical_device.gd").new()
    mine.device_type = "mine"
    mine.owner_id = player.player_id
    player.world.add_child(mine)
    mine.global_position = hit.position + hit.normal * 0.08
    mine.call_deferred("arm")
    get_tree().create_timer(0.25).timeout.connect(func(): input_lock = false)
