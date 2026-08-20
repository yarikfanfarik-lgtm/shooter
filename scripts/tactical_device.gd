extends RigidBody3D

var device_type := "smoke"
var owner_id := 1
var armed := false
var deployed := false
var smoke_time := 0.0

const SMOKE_LIFETIME := 17.0
const MINE_DAMAGE := 100
const MINE_RADIUS := 4.5

func _ready() -> void:
    contact_monitor = true
    max_contacts_reported = 4
    if device_type == "smoke":
        _make_smoke_canister()
        gravity_scale = 1.0
        linear_damp = 0.45
        angular_damp = 0.55
        mass = 0.35
        var timer := get_tree().create_timer(0.9)
        timer.timeout.connect(_deploy_smoke)
    else:
        freeze = true
        _make_mine()

func launch(force: Vector3) -> void:
    if device_type != "smoke":
        return
    apply_central_impulse(force)
    apply_torque_impulse(Vector3(1.5, 0.8, 1.1))

func _make_smoke_canister() -> void:
    var mesh := MeshInstance3D.new()
    var cylinder := CylinderMesh.new()
    cylinder.top_radius = 0.10
    cylinder.bottom_radius = 0.12
    cylinder.height = 0.32
    mesh.mesh = cylinder
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color("65707a")
    mat.metallic = 0.55
    mat.roughness = 0.42
    mesh.material_override = mat
    add_child(mesh)
    var cap := MeshInstance3D.new()
    var cap_mesh := CylinderMesh.new()
    cap_mesh.top_radius = 0.13
    cap_mesh.bottom_radius = 0.13
    cap_mesh.height = 0.035
    cap.mesh = cap_mesh
    cap.position.y = 0.18
    var cap_mat := StandardMaterial3D.new()
    cap_mat.albedo_color = Color("2b3035")
    cap.material_override = cap_mat
    add_child(cap)
    var shape := CollisionShape3D.new()
    var cylinder_shape := CylinderShape3D.new()
    cylinder_shape.radius = 0.13
    cylinder_shape.height = 0.34
    shape.shape = cylinder_shape
    add_child(shape)

func _deploy_smoke() -> void:
    if deployed or not is_instance_valid(self):
        return
    deployed = true
    freeze = true
    linear_velocity = Vector3.ZERO
    angular_velocity = Vector3.ZERO
    _remove_canister_visuals()
    _create_smoke_cloud()
    var timer := get_tree().create_timer(SMOKE_LIFETIME)
    timer.timeout.connect(queue_free)

func _remove_canister_visuals() -> void:
    for child in get_children():
        if child is MeshInstance3D or child is CollisionShape3D:
            child.queue_free()

func _create_smoke_cloud() -> void:
    _add_smoke_layer(420, 11.0, 0.7, 1.0, 0.75, 1.25, 0.65)
    _add_smoke_layer(220, 15.0, 0.35, 1.4, 0.95, 1.65, 0.48)
    _add_smoke_layer(120, 18.0, 0.18, 2.0, 1.25, 2.25, 0.30)

func _add_smoke_layer(amount: int, lifetime: float, speed: float, spread: float, scale_min: float, scale_max: float, alpha: float) -> void:
    var particles := GPUParticles3D.new()
    particles.amount = amount
    particles.lifetime = lifetime
    particles.preprocess = minf(2.5, lifetime * 0.2)
    particles.randomness = 0.65
    particles.local_coords = false
    particles.visibility_aabb = AABB(Vector3(-14, -1, -14), Vector3(28, 22, 28))

    var process := ParticleProcessMaterial.new()
    process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
    process.emission_sphere_radius = 0.9
    process.direction = Vector3(0, 1, 0)
    process.spread = 180.0
    process.initial_velocity_min = speed * 0.55
    process.initial_velocity_max = speed * 1.45
    process.gravity = Vector3(0, 0.10, 0)
    process.damping_min = 0.10
    process.damping_max = 0.40
    process.scale_min = scale_min
    process.scale_max = scale_max
    process.angular_velocity_min = -18.0
    process.angular_velocity_max = 18.0
    process.turbulence_enabled = true
    process.turbulence_noise_strength = 1.8
    process.turbulence_noise_scale = 1.6
    process.turbulence_influence_min = 0.25
    process.turbulence_influence_max = 0.75
    process.color = Color(0.30, 0.32, 0.34, alpha)
    particles.process_material = process

    var quad := QuadMesh.new()
    quad.size = Vector2(2.0, 2.0)
    quad.orientation = PlaneMesh.FACE_Z
    var shader_mat := ShaderMaterial.new()
    var shader := Shader.new()
    shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_alpha_prepass;

float hash21(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = hash21(i);
    float b = hash21(i + vec2(1.0, 0.0));
    float c = hash21(i + vec2(0.0, 1.0));
    float d = hash21(i + vec2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
    vec2 p = UV * 2.0 - 1.0;
    float radial = 1.0 - smoothstep(0.18, 1.02, length(p));
    vec2 drift = p * 2.3 + vec2(TIME * 0.035, -TIME * 0.021);
    float n1 = noise(drift * 2.0);
    float n2 = noise(drift * 4.7 + vec2(7.2, 3.4));
    float n = mix(n1, n2, 0.42);
    float wisps = smoothstep(0.18, 0.82, n);
    float alpha = radial * wisps * 0.72;
    ALBEDO = vec3(0.30, 0.32, 0.34);
    ALPHA = alpha;
}
"""
    shader_mat.shader = shader
    quad.material = shader_mat
    particles.draw_pass_1 = quad
    add_child(particles)

func _make_mine() -> void:
    var body_mesh := MeshInstance3D.new()
    var cylinder := CylinderMesh.new()
    cylinder.top_radius = 0.22
    cylinder.bottom_radius = 0.26
    cylinder.height = 0.10
    body_mesh.mesh = cylinder
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color("25282b")
    mat.metallic = 0.5
    mat.roughness = 0.35
    body_mesh.material_override = mat
    add_child(body_mesh)

    var light := OmniLight3D.new()
    light.light_color = Color("ff3025")
    light.light_energy = 0.45
    light.omni_range = 1.5
    light.position.y = 0.09
    add_child(light)

    var area := Area3D.new()
    area.monitoring = true
    var area_shape := CollisionShape3D.new()
    var sphere := SphereShape3D.new()
    sphere.radius = MINE_RADIUS
    area_shape.shape = sphere
    area.add_child(area_shape)
    area.body_entered.connect(_on_mine_body_entered)
    add_child(area)

func arm() -> void:
    armed = false
    var timer := get_tree().create_timer(1.0)
    timer.timeout.connect(func(): armed = true)

func _on_mine_body_entered(body: Node) -> void:
    if not armed or deployed:
        return
    if not body.has_method("take_damage"):
        return
    if "player_id" in body and body.player_id == owner_id:
        return
    deployed = true
    body.take_damage(MINE_DAMAGE, owner_id)
    _explode()

func _explode() -> void:
    var particles := GPUParticles3D.new()
    particles.amount = 90
    particles.lifetime = 0.7
    particles.one_shot = true
    particles.explosiveness = 0.95
    particles.visibility_aabb = AABB(Vector3(-7, -2, -7), Vector3(14, 10, 14))
    var process := ParticleProcessMaterial.new()
    process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
    process.emission_sphere_radius = 0.25
    process.direction = Vector3(0, 1, 0)
    process.spread = 180.0
    process.initial_velocity_min = 3.0
    process.initial_velocity_max = 8.0
    process.gravity = Vector3(0, -8, 0)
    process.scale_min = 0.05
    process.scale_max = 0.18
    process.color = Color(1.0, 0.45, 0.08, 1.0)
    particles.process_material = process
    var mesh := QuadMesh.new()
    mesh.size = Vector2(0.18, 0.18)
    var mat := StandardMaterial3D.new()
    mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    mat.albedo_color = Color(1.0, 0.55, 0.12, 1.0)
    mesh.material = mat
    particles.draw_pass_1 = mesh
    get_parent().add_child(particles)
    particles.global_position = global_position
    particles.emitting = true
    var light := OmniLight3D.new()
    light.light_color = Color("ff7a18")
    light.light_energy = 6.0
    light.omni_range = 8.0
    get_parent().add_child(light)
    light.global_position = global_position
    var tween := get_tree().create_tween()
    tween.tween_property(light, "light_energy", 0.0, 0.25)
    tween.tween_callback(light.queue_free)
    get_tree().create_timer(0.9).timeout.connect(func(): particles.queue_free())
    queue_free()
