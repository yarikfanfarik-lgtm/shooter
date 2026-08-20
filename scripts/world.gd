extends Node3D

var nickname := "Player"
var players: Dictionary = {}
var spawn_points := [Vector3(-13,1.2,-13),Vector3(13,1.2,13),Vector3(13,1.2,-13),Vector3(-13,1.2,13),Vector3(0,1.2,-20),Vector3(0,1.2,20),Vector3(-20,1.2,0),Vector3(20,1.2,0)]
var score := 0
const SAND := Color("d7a45f")
const WALL := Color("d9d0bd")
const WALL_LIGHT := Color("eee5d2")
const TRIM := Color("8b6042")
const WOOD := Color("765038")
const WOOD_LIGHT := Color("9a6b45")
const DARK := Color("3a3430")
const GREEN := Color("71853a")
const GREEN_DARK := Color("4e632d")
const BLUE := Color("6689a5")

func start_match() -> void:
    _build_world()
    _spawn_player()
    for i in range(7): _spawn_bot(i)
    var tactical := preload("res://scripts/tactical.gd").new()
    tactical.name = "TacticalEquipment"
    add_child(tactical)

func _build_world() -> void:
    var env := WorldEnvironment.new()
    var e := Environment.new()
    e.background_mode = Environment.BG_COLOR
    e.background_color = Color("9fb3c8")
    e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    e.ambient_light_color = Color("fff0d0")
    e.ambient_light_energy = 0.9
    e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    env.environment = e
    add_child(env)
    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-52,-28,0)
    sun.light_energy = 1.55
    sun.shadow_enabled = true
    add_child(sun)

    # One continuous physical floor + four solid perimeter walls.
    _collision_box(Vector3(0,-0.5,0), Vector3(52,1,52), SAND, true)
    _collision_box(Vector3(0,0.02,0), Vector3(30,0.12,28), Color("e7bd78"), true, false)
    _collision_box(Vector3(0,-8,0), Vector3(90,0.5,90), SAND, true, false)
    _collision_box(Vector3(0,2,-26), Vector3(52,4,1), WALL, true)
    _collision_box(Vector3(0,2,26), Vector3(52,4,1), WALL, true)
    _collision_box(Vector3(-26,2,0), Vector3(1,4,52), WALL, true)
    _collision_box(Vector3(26,2,0), Vector3(1,4,52), WALL, true)

    _building(Vector3(-19,3.5,-18),Vector3(11,7,10))
    _building(Vector3(19,3.5,18),Vector3(11,7,10))
    _collision_box(Vector3(-12.5,1.6,-8),Vector3(1.5,3.2,13),WALL,true)
    _collision_box(Vector3(-8,1.6,-12.5),Vector3(9,3.2,1.5),WALL,true)
    _collision_box(Vector3(12.5,1.6,8),Vector3(1.5,3.2,13),WALL,true)
    _collision_box(Vector3(8,1.6,12.5),Vector3(9,3.2,1.5),WALL,true)
    _collision_box(Vector3(-5.5,1.4,0),Vector3(2.2,2.8,10),WALL,true)
    _collision_box(Vector3(5.5,1.4,0),Vector3(2.2,2.8,10),WALL,true)
    _collision_box(Vector3(0,1.4,-7.5),Vector3(7,2.8,1.6),WALL,true)
    _collision_box(Vector3(0,1.4,7.5),Vector3(7,2.8,1.6),WALL,true)
    _collision_box(Vector3(-2.5,0.9,-3.2),Vector3(3.2,1.8,1.2),WALL_LIGHT,true)
    _collision_box(Vector3(2.5,0.9,3.2),Vector3(3.2,1.8,1.2),WALL_LIGHT,true)
    _collision_box(Vector3(-9,0.8,5.5),Vector3(4,1.6,1.2),WALL_LIGHT,true)
    _collision_box(Vector3(9,0.8,-5.5),Vector3(4,1.6,1.2),WALL_LIGHT,true)
    _crate_stack(Vector3(-7.5,1,-4),2)
    _crate_stack(Vector3(7.5,1,4),2)
    _crate_stack(Vector3(-15.5,1,8.5),2)
    _crate_stack(Vector3(15.5,1,-8.5),2)
    _facade_details(Vector3(-19,3.5,-18))
    _facade_details(Vector3(19,3.5,18))
    for p in [Vector3(-23,0,8),Vector3(23,0,-8),Vector3(-8,0,22),Vector3(8,0,-22)]: _palm(p)

func _collision_box(pos:Vector3,size:Vector3,color:Color,solid:=true,visual:=true) -> void:
    if visual:
        var mesh := MeshInstance3D.new()
        var box := BoxMesh.new()
        box.size = size
        mesh.mesh = box
        var mat := StandardMaterial3D.new()
        mat.albedo_color = color
        mat.roughness = 0.82
        mesh.material_override = mat
        mesh.position = pos
        add_child(mesh)
    if solid:
        var body := StaticBody3D.new()
        body.position = pos
        body.collision_layer = 1
        body.collision_mask = 1
        var shape := CollisionShape3D.new()
        var box_shape := BoxShape3D.new()
        box_shape.size = size
        shape.shape = box_shape
        body.add_child(shape)
        add_child(body)

func _block(pos:Vector3,size:Vector3,color:Color) -> void:
    _collision_box(pos,size,color,true)

func _building(pos:Vector3,size:Vector3) -> void:
    _collision_box(pos,size,WALL,true)
    _collision_box(pos+Vector3(0,size.y*.5+.25,0),Vector3(size.x+.7,.5,size.z+.7),TRIM,true)
    _collision_box(pos+Vector3(0,size.y+.65,0),Vector3(size.x+1,.35,size.z+1),WALL_LIGHT,true)

func _facade_details(pos:Vector3) -> void:
    var front_z := -1.0 if pos.z < 0 else 1.0
    _collision_box(pos+Vector3(0,2,front_z*5.08),Vector3(2.6,4,.18),DARK,true)
    for x in [-3.2,3.2]:
        _collision_box(pos+Vector3(x,4,front_z*5.1),Vector3(2.2,1.7,.16),BLUE,true)

func _crate_stack(pos:Vector3,count:int) -> void:
    for i in range(count):
        var c := pos+Vector3((i%2)*1.15,i*1.05,(i%2)*.45)
        _collision_box(c,Vector3(2.1,2,2.1),WOOD,true)
        _collision_box(c+Vector3(0,0,-1.08),Vector3(1.5,.12,.08),WOOD_LIGHT,true)
        _collision_box(c+Vector3(0,0,1.08),Vector3(1.5,.12,.08),WOOD_LIGHT,true)

func _palm(pos:Vector3) -> void:
    for i in range(5): _collision_box(pos+Vector3(0,i*1.25+.7,0),Vector3(.55,1.35,.55),TRIM,true)
    var top:=pos+Vector3(0,6.4,0)
    _collision_box(top,Vector3(1,.45,1),GREEN_DARK,true)
    _collision_box(top+Vector3(2,.15,0),Vector3(4,.35,.65),GREEN,false)
    _collision_box(top+Vector3(-2,.15,0),Vector3(4,.35,.65),GREEN,false)
    _collision_box(top+Vector3(0,.15,2),Vector3(.65,.35,4),GREEN,false)
    _collision_box(top+Vector3(0,.15,-2),Vector3(.65,.35,4),GREEN,false)

func _spawn_player() -> void:
    var p:=preload("res://scripts/player.gd").new()
    p.world=self
    p.player_id=1
    p.nickname=nickname
    p.position=spawn_points[0]
    p.is_local=true
    p.floor_snap_length=0.35
    p.safe_margin=0.08
    add_child(p)
    p.add_to_group("local_player")
    players[1]=p

func _spawn_bot(index:int) -> void:
    var b:=preload("res://scripts/bot.gd").new()
    b.world=self
    b.player_id=100+index
    b.position=spawn_points[(index+1)%spawn_points.size()]
    b.floor_snap_length=0.35
    b.safe_margin=0.08
    add_child(b)
    players[b.player_id]=b

func award_kill(killer:int)->void:
    if killer==1: score+=1

func get_target_for(bot:Node3D)->Node3D:
    var best:Node3D=null
    var best_distance:=INF
    for id in players:
        var p=players[id]
        if p==bot or not is_instance_valid(p): continue
        var d:=bot.global_position.distance_to(p.global_position)
        if d<best_distance:
            best_distance=d
            best=p
    return best
