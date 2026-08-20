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
    e.background_mode = Environment.BG_SKY
    var sky := Sky.new()
    var sky_mat := ProceduralSkyMaterial.new()
    sky_mat.sky_top_color = Color("294a70")
    sky_mat.sky_horizon_color = Color("d8b784")
    sky_mat.ground_bottom_color = Color("171817")
    sky_mat.ground_horizon_color = Color("8d765d")
    sky_mat.sun_angle_max = 8.0
    sky.sky_material = sky_mat
    e.sky = sky
    e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
    e.ambient_light_energy = 1.15
    e.ambient_light_color = Color("fff0d0")
    e.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
    e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    e.glow_enabled = true
    e.glow_intensity = 0.65
    e.glow_bloom = 0.12
    e.ssr_enabled = true
    e.ssr_max_steps = 96
    e.ssr_fade_in = 0.15
    e.ssr_fade_out = 1.0
    e.volumetric_fog_enabled = true
    e.volumetric_fog_density = 0.008
    e.volumetric_fog_albedo = Color("d7c5aa")
    e.volumetric_fog_emission = Color("5b5148")
    e.volumetric_fog_emission_energy = 0.08
    env.environment = e
    add_child(env)

    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-48,-32,0)
    sun.light_energy = 2.2
    sun.shadow_enabled = true
    sun.directional_shadow_max_distance = 120.0
    sun.directional_shadow_fade_start = 0.82
    sun.light_angular_distance = 0.35
    add_child(sun)

    var fill := OmniLight3D.new()
    fill.position = Vector3(0,7,0)
    fill.light_color = Color("f0c78d")
    fill.light_energy = 1.2
    fill.omni_range = 28.0
    fill.shadow_enabled = true
    add_child(fill)

    # Temporary visual-only map: geometry has no gameplay collision.
    _visual_block(Vector3(0,-0.5,0),Vector3(52,1,52),SAND)
    _visual_block(Vector3(0,0.02,0),Vector3(30,0.12,28),Color("e7bd78"))
    _visual_block(Vector3(0,-8,0),Vector3(90,0.5,90),SAND)
    _visual_block(Vector3(0,2,-26),Vector3(52,4,1),WALL)
    _visual_block(Vector3(0,2,26),Vector3(52,4,1),WALL)
    _visual_block(Vector3(-26,2,0),Vector3(1,4,52),WALL)
    _visual_block(Vector3(26,2,0),Vector3(1,4,52),WALL)
    _building(Vector3(-19,3.5,-18),Vector3(11,7,10))
    _building(Vector3(19,3.5,18),Vector3(11,7,10))
    _visual_block(Vector3(-12.5,1.6,-8),Vector3(1.5,3.2,13),WALL)
    _visual_block(Vector3(-8,1.6,-12.5),Vector3(9,3.2,1.5),WALL)
    _visual_block(Vector3(12.5,1.6,8),Vector3(1.5,3.2,13),WALL)
    _visual_block(Vector3(8,1.6,12.5),Vector3(9,3.2,1.5),WALL)
    _visual_block(Vector3(-5.5,1.4,0),Vector3(2.2,2.8,10),WALL)
    _visual_block(Vector3(5.5,1.4,0),Vector3(2.2,2.8,10),WALL)
    _visual_block(Vector3(0,1.4,-7.5),Vector3(7,2.8,1.6),WALL)
    _visual_block(Vector3(0,1.4,7.5),Vector3(7,2.8,1.6),WALL)
    _visual_block(Vector3(-2.5,0.9,-3.2),Vector3(3.2,1.8,1.2),WALL_LIGHT)
    _visual_block(Vector3(2.5,0.9,3.2),Vector3(3.2,1.8,1.2),WALL_LIGHT)
    _visual_block(Vector3(-9,0.8,5.5),Vector3(4,1.6,1.2),WALL_LIGHT)
    _visual_block(Vector3(9,0.8,-5.5),Vector3(4,1.6,1.2),WALL_LIGHT)
    _crate_stack(Vector3(-7.5,1,-4),2)
    _crate_stack(Vector3(7.5,1,4),2)
    _crate_stack(Vector3(-15.5,1,8.5),2)
    _crate_stack(Vector3(15.5,1,-8.5),2)
    _facade_details(Vector3(-19,3.5,-18))
    _facade_details(Vector3(19,3.5,18))
    for p in [Vector3(-23,0,8),Vector3(23,0,-8),Vector3(-8,0,22),Vector3(8,0,-22)]: _palm(p)

func _visual_block(pos:Vector3,size:Vector3,color:Color) -> void:
    var mesh := MeshInstance3D.new()
    var box := BoxMesh.new()
    box.size=size
    mesh.mesh=box
    var mat:=StandardMaterial3D.new()
    mat.albedo_color=color
    mat.roughness=0.72
    mat.metallic=0.03
    mat.specular_mode=BaseMaterial3D.SPECULAR_SCHLICK_GGX
    mesh.material_override=mat
    mesh.position=pos
    mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON
    add_child(mesh)

func _building(pos:Vector3,size:Vector3)->void:
    _visual_block(pos,size,WALL)
    _visual_block(pos+Vector3(0,size.y*.5+.25,0),Vector3(size.x+.7,.5,size.z+.7),TRIM)
    _visual_block(pos+Vector3(0,size.y+.65,0),Vector3(size.x+1,.35,size.z+1),WALL_LIGHT)
    for sx in [-1,1]:
        for sz in [-1,1]:
            _visual_block(pos+Vector3(sx*size.x*.42,size.y+1.0,sz*size.z*.42),Vector3(1.4,1.6,1.4),WALL_LIGHT)

func _facade_details(pos:Vector3)->void:
    var front_z:=-1.0 if pos.z<0 else 1.0
    _visual_block(pos+Vector3(0,2,front_z*5.08),Vector3(2.6,4,.18),DARK)
    for x in [-3.2,3.2]:
        _visual_block(pos+Vector3(x,4,front_z*5.1),Vector3(2.2,1.7,.16),BLUE)
        _visual_block(pos+Vector3(x,5,front_z*5.25),Vector3(2.7,.18,.55),TRIM)

func _crate_stack(pos:Vector3,count:int)->void:
    for i in range(count):
        var c:=pos+Vector3((i%2)*1.15,i*1.05,(i%2)*.45)
        _visual_block(c,Vector3(2.1,2,2.1),WOOD)
        _visual_block(c+Vector3(0,0,-1.08),Vector3(1.5,.12,.08),WOOD_LIGHT)
        _visual_block(c+Vector3(0,0,1.08),Vector3(1.5,.12,.08),WOOD_LIGHT)

func _palm(pos:Vector3)->void:
    for i in range(5): _visual_block(pos+Vector3(0,i*1.25+.7,0),Vector3(.55,1.35,.55),TRIM)
    var top:=pos+Vector3(0,6.4,0)
    _visual_block(top,Vector3(1,.45,1),GREEN_DARK)
    _visual_block(top+Vector3(2,.15,0),Vector3(4,.35,.65),GREEN)
    _visual_block(top+Vector3(-2,.15,0),Vector3(4,.35,.65),GREEN)
    _visual_block(top+Vector3(0,.15,2),Vector3(.65,.35,4),GREEN)
    _visual_block(top+Vector3(0,.15,-2),Vector3(.65,.35,4),GREEN)

func _spawn_player()->void:
    var p:=preload("res://scripts/player.gd").new()
    p.world=self;p.player_id=1;p.nickname=nickname;p.position=spawn_points[0];p.is_local=true
    add_child(p);p.add_to_group("local_player");players[1]=p

func _spawn_bot(index:int)->void:
    var b:=preload("res://scripts/bot.gd").new()
    b.world=self;b.player_id=100+index;b.position=spawn_points[(index+1)%spawn_points.size()]
    add_child(b);players[b.player_id]=b

func award_kill(killer:int)->void:
    if killer==1: score+=1

func get_target_for(bot:Node3D)->Node3D:
    var best:Node3D=null;var best_distance:=INF
    for id in players:
        var p=players[id]
        if p==bot or not is_instance_valid(p):continue
        var d:=bot.global_position.distance_to(p.global_position)
        if d<best_distance:best_distance=d;best=p
    return best
