class_name Look
extends RefCounted
## 材质、基础网格、环境与灯光的统一工厂（与概念稿同一套观感）。

static var _mats := {}


static func mat(key: String, color: Color, rough: float = 0.7, metal: float = 0.0) -> StandardMaterial3D:
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = rough
		m.metallic = metal
		_mats[key] = m
	return _mats[key]


static func emit(key: String, color: Color, energy: float) -> StandardMaterial3D:
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = energy
		m.roughness = 0.45
		_mats[key] = m
	return _mats[key]


static func box(parent: Node3D, size: Vector3, pos: Vector3, material: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = material
	mi.position = pos
	parent.add_child(mi)
	return mi


static func sphere(parent: Node3D, radius: float, pos: Vector3, material: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 28
	mesh.rings = 14
	mi.mesh = mesh
	mi.material_override = material
	mi.position = pos
	parent.add_child(mi)
	return mi


static func cyl(parent: Node3D, radius: float, height: float, pos: Vector3, material: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 20
	mi.mesh = mesh
	mi.material_override = material
	mi.position = pos
	parent.add_child(mi)
	return mi


static func cone(parent: Node3D, top: float, bottom: float, height: float, pos: Vector3, material: Material, segments: int = 18) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = segments
	mi.mesh = mesh
	mi.material_override = material
	mi.position = pos
	parent.add_child(mi)
	return mi


static func environment() -> WorldEnvironment:
	var env := Environment.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.02, 0.025, 0.045)
	sky_mat.sky_horizon_color = Color(0.07, 0.08, 0.13)
	sky_mat.ground_bottom_color = Color(0.012, 0.014, 0.022)
	sky_mat.ground_horizon_color = Color(0.05, 0.06, 0.1)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.62
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.05
	env.glow_enabled = true
	env.glow_intensity = 1.0
	env.glow_bloom = 0.1
	env.ssao_enabled = true
	env.ssao_intensity = 2.4
	env.ssao_radius = 1.5
	env.fog_enabled = true
	env.fog_light_color = Color(0.05, 0.06, 0.1)
	env.fog_density = 0.008
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.12
	env.adjustment_contrast = 1.05
	var we := WorldEnvironment.new()
	we.environment = env
	return we


static func lights(parent: Node3D) -> void:
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-58, -42, 0)
	key.light_color = Color(1.0, 0.97, 0.93)
	key.light_energy = 2.9
	key.shadow_enabled = true
	key.directional_shadow_max_distance = 90.0
	parent.add_child(key)

	var fill := OmniLight3D.new()
	fill.position = Vector3(2, 14, 22)
	fill.light_color = Color(0.4, 0.55, 1.0)
	fill.light_energy = 2.2
	fill.omni_range = 52.0
	parent.add_child(fill)

	var rim_a := OmniLight3D.new()
	rim_a.position = Vector3(-6, 5, 3)
	rim_a.light_color = Color(1.0, 0.3, 0.6)
	rim_a.light_energy = 3.6
	rim_a.omni_range = 24.0
	parent.add_child(rim_a)

	var rim_b := OmniLight3D.new()
	rim_b.position = Vector3(36, 4.5, 20)
	rim_b.light_color = Color(0.25, 0.85, 1.0)
	rim_b.light_energy = 3.2
	rim_b.omni_range = 24.0
	parent.add_child(rim_b)


static func grass_material() -> ShaderMaterial:
	if not _mats.has("grass_shader"):
		var sh: Shader = load("res://src/grass.gdshader")
		var m := ShaderMaterial.new()
		m.shader = sh
		_mats["grass_shader"] = m
	return _mats["grass_shader"] as ShaderMaterial
