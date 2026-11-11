extends Node3D
## 3D 概念图渲染：程序化搭建竞技场、角色、炸弹、爆炸，逐镜头出图。
## 用法: godot --path concept3d   （窗口模式，末尾自动退出）

const OUT_DIR := "C:/Users/huangxin/Documents/deepseek-harness/default-workspace/docs/concept3d"
const COLS := 15
const ROWS := 11
const TILE := 2.0

var camera: Camera3D
var rng := RandomNumberGenerator.new()
var fighters: Array[Node3D] = []
var heroes: Array[Node3D] = []
var bomb_group: Array[Node3D] = []
var flame_group: Array[Node3D] = []
var wall_nodes: Array[Node3D] = []
var crate_nodes: Array[Node3D] = []
var grass_nodes: Array[Node3D] = []
var grass_cells: Array[Vector2i] = []


func _ready() -> void:
	rng.seed = 20261111
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	_setup_environment()
	_setup_lights()
	_build_floor()
	_build_walls()
	_build_crates()
	_build_grass()
	_build_fighters()
	_build_heroes()
	_build_bombs()
	_build_stage()
	_build_explosion()
	await _render_all()


# ---------------------------------------------------------------- 环境
func _setup_environment() -> void:
	var env := Environment.new()

	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.022, 0.028, 0.05)
	sky_mat.sky_horizon_color = Color(0.075, 0.085, 0.14)
	sky_mat.ground_bottom_color = Color(0.012, 0.014, 0.022)
	sky_mat.ground_horizon_color = Color(0.05, 0.06, 0.1)
	sky_mat.sun_angle_max = 12.0
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky

	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.05

	env.glow_enabled = true
	env.glow_intensity = 1.0
	env.glow_strength = 1.0
	env.glow_bloom = 0.1
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.glow_hdr_threshold = 1.0

	env.ssao_enabled = true
	env.ssao_intensity = 2.6
	env.ssao_radius = 1.5
	env.ssao_power = 1.8

	env.fog_enabled = true
	env.fog_light_color = Color(0.055, 0.07, 0.12)
	env.fog_density = 0.012
	env.fog_sky_affect = 0.6

	env.adjustment_enabled = true
	env.adjustment_saturation = 1.1
	env.adjustment_contrast = 1.06
	env.adjustment_brightness = 1.0

	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)


func _setup_lights() -> void:
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-58, -42, 0)
	key.light_color = Color(1.0, 0.97, 0.93)
	key.light_energy = 2.6
	key.shadow_enabled = true
	key.directional_shadow_max_distance = 90.0
	key.directional_shadow_blend_splits = true
	add_child(key)

	var fill := OmniLight3D.new()
	fill.position = Vector3(2, 12, 22)
	fill.light_color = Color(0.4, 0.55, 1.0)
	fill.light_energy = 2.4
	fill.omni_range = 48.0
	fill.omni_attenuation = 1.5
	add_child(fill)

	var rim_a := OmniLight3D.new()
	rim_a.position = Vector3(-6, 4.5, 3)
	rim_a.light_color = Color(1.0, 0.3, 0.6)
	rim_a.light_energy = 4.5
	rim_a.omni_range = 22.0
	add_child(rim_a)

	var rim_b := OmniLight3D.new()
	rim_b.position = Vector3(36, 4.2, 20)
	rim_b.light_color = Color(0.25, 0.85, 1.0)
	rim_b.light_energy = 4.0
	rim_b.omni_range = 22.0
	add_child(rim_b)

	# 顶部背光，勾出箱子与角色的轮廓
	var top := SpotLight3D.new()
	top.position = Vector3(15, 24, -8)
	top.rotation_degrees = Vector3(-58, 0, 0)
	top.light_color = Color(0.6, 0.75, 1.0)
	top.light_energy = 6.0
	top.spot_range = 60.0
	top.spot_angle = 42.0
	add_child(top)


# ---------------------------------------------------------------- 材质
func _mat(color: Color, roughness: float = 0.7, metallic: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	return m


func _emit_mat(color: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	m.roughness = 0.4
	return m


func _box(size: Vector3, pos: Vector3, mat: Material, parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	(parent if parent != null else self).add_child(mi)
	return mi


func _sphere(radius: float, pos: Vector3, mat: Material, parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 32
	mesh.rings = 16
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	(parent if parent != null else self).add_child(mi)
	return mi


func _cyl(radius: float, height: float, pos: Vector3, mat: Material, parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 20
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	(parent if parent != null else self).add_child(mi)
	return mi


func _cone(top_r: float, bottom_r: float, height: float, pos: Vector3, mat: Material, parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_r
	mesh.bottom_radius = bottom_r
	mesh.height = height
	mesh.radial_segments = 24
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	(parent if parent != null else self).add_child(mi)
	return mi


# ---------------------------------------------------------------- 场地
func _cell_pos(x: int, z: int) -> Vector3:
	return Vector3(x * TILE + TILE * 0.5, 0.0, z * TILE + TILE * 0.5)


func _is_wall(x: int, z: int) -> bool:
	var edge := x == 0 or z == 0 or x == COLS - 1 or z == ROWS - 1
	var pillar := x % 2 == 0 and z % 2 == 0
	return edge or pillar


func _build_floor() -> void:
	var base := _box(
		Vector3(COLS * TILE + 3.0, 0.5, ROWS * TILE + 3.0),
		Vector3(COLS * TILE * 0.5, -0.26, ROWS * TILE * 0.5),
		_mat(Color(0.075, 0.085, 0.12), 0.5, 0.2)
	)
	base.name = "FloorBase"
	# 台面四周的霓虹描边
	var trim := _emit_mat(Color(0.3, 0.78, 1.0), 1.8)
	var half_w := COLS * TILE * 0.5 + 1.6
	var half_d := ROWS * TILE * 0.5 + 1.6
	var cx := COLS * TILE * 0.5
	var cz := ROWS * TILE * 0.5
	_box(Vector3(half_w * 2.0 + 0.2, 0.1, 0.16), Vector3(cx, -0.02, cz - half_d), trim)
	_box(Vector3(half_w * 2.0 + 0.2, 0.1, 0.16), Vector3(cx, -0.02, cz + half_d), trim)
	_box(Vector3(0.16, 0.1, half_d * 2.0), Vector3(cx - half_w, -0.02, cz), trim)
	_box(Vector3(0.16, 0.1, half_d * 2.0), Vector3(cx + half_w, -0.02, cz), trim)

	var mat_a := _mat(Color(0.115, 0.13, 0.175), 0.62, 0.15)
	var mat_b := _mat(Color(0.135, 0.15, 0.2), 0.58, 0.15)
	for z in ROWS:
		for x in COLS:
			var m := mat_a if (x + z) % 2 == 0 else mat_b
			var tile := _box(Vector3(TILE - 0.06, 0.08, TILE - 0.06), _cell_pos(x, z) + Vector3(0, 0.0, 0), m)
			tile.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _build_walls() -> void:
	var body := _mat(Color(0.13, 0.15, 0.21), 0.42, 0.55)
	var top := _mat(Color(0.21, 0.24, 0.32), 0.32, 0.6)
	for z in ROWS:
		for x in COLS:
			if not _is_wall(x, z):
				continue
			var p := _cell_pos(x, z)
			var is_edge := x == 0 or z == 0 or x == COLS - 1 or z == ROWS - 1
			var node := Node3D.new()
			node.position = p
			add_child(node)
			_box(Vector3(TILE - 0.04, 1.34, TILE - 0.04), Vector3(0, 0.67, 0), body, node)
			_box(Vector3(TILE - 0.16, 0.12, TILE - 0.16), Vector3(0, 1.4, 0), top, node)
			if not is_edge:
				wall_nodes.append(node)


func _build_crates() -> void:
	var wood := _mat(Color(0.27, 0.16, 0.085), 0.88, 0.0)
	var wood_top := _mat(Color(0.33, 0.2, 0.11), 0.82, 0.0)
	var band := _mat(Color(0.1, 0.09, 0.09), 0.55, 0.65)
	for z in ROWS:
		for x in COLS:
			if _is_wall(x, z):
				continue
			# 出生区与中央走廊留空
			var near_spawn := false
			for s in [Vector2i(1, 1), Vector2i(13, 1), Vector2i(1, 9), Vector2i(13, 9)]:
				if absi(x - s.x) + absi(z - s.y) <= 2:
					near_spawn = true
			if near_spawn:
				continue
			if x >= 4 and x <= 10 and z >= 4 and z <= 9:
				continue
			if rng.randf() > 0.46:
				continue
			var p := _cell_pos(x, z)
			var h := rng.randf_range(1.12, 1.3)
			var node := Node3D.new()
			node.position = p
			node.rotation_degrees = Vector3(0, rng.randf_range(-5, 5), 0)
			add_child(node)
			_box(Vector3(1.68, h, 1.68), Vector3(0, h * 0.5, 0), wood, node)
			_box(Vector3(1.74, 0.09, 0.1), Vector3(0, h * 0.5 + h * 0.28, 0.85), band, node)
			_box(Vector3(1.74, 0.09, 0.1), Vector3(0, h * 0.5 - h * 0.28, 0.85), band, node)
			_box(Vector3(1.74, 0.05, 1.74), Vector3(0, h + 0.01, 0), wood_top, node)
			crate_nodes.append(node)


# ---------------------------------------------------------------- 角色
func _build_fighter_body(color: Color, parent: Node3D) -> void:
	var skin := _mat(Color(0.78, 0.62, 0.5), 0.95, 0.0)
	var cloth := _mat(color, 0.72, 0.04)
	var cloth_dark := _mat(color.darkened(0.5), 0.78, 0.04)
	var ink := _mat(Color(0.03, 0.03, 0.05), 0.45, 0.25)

	# 脚
	_box(Vector3(0.3, 0.16, 0.42), Vector3(-0.2, 0.08, 0.02), cloth_dark, parent)
	_box(Vector3(0.3, 0.16, 0.42), Vector3(0.2, 0.08, 0.02), cloth_dark, parent)
	# 身体（胶囊）
	var body := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.36
	cap.height = 1.0
	body.mesh = cap
	body.material_override = cloth
	body.position = Vector3(0, 0.62, 0)
	parent.add_child(body)
	# 腰带
	_cyl(0.38, 0.1, Vector3(0, 0.42, 0), cloth_dark, parent)
	# 手套
	_sphere(0.13, Vector3(-0.42, 0.72, 0.04), cloth_dark, parent)
	_sphere(0.13, Vector3(0.42, 0.72, 0.04), cloth_dark, parent)
	# 头
	_sphere(0.43, Vector3(0, 1.3, 0), skin, parent)
	# 面罩/头发
	_sphere(0.44, Vector3(0, 1.4, -0.02), cloth, parent).scale = Vector3(1.0, 0.6, 1.0)
	# 眼睛（深色，避免高光吃掉）
	_sphere(0.062, Vector3(-0.15, 1.28, 0.38), ink, parent)
	_sphere(0.062, Vector3(0.15, 1.28, 0.38), ink, parent)
	# 帽檐 / 头盔
	_cyl(0.47, 0.07, Vector3(0, 1.52, 0), cloth_dark, parent)
	_sphere(0.33, Vector3(0, 1.59, 0), cloth, parent).scale = Vector3(1.0, 0.72, 1.0)
	# 胸口徽记
	_box(Vector3(0.14, 0.14, 0.04), Vector3(0, 0.78, 0.34), ink, parent)


func _build_fighters() -> void:
	var colors := [
		Color(0.86, 0.24, 0.22), Color(0.24, 0.52, 0.9),
		Color(0.28, 0.74, 0.36), Color(0.94, 0.76, 0.22),
	]
	var spots := [Vector2i(1, 1), Vector2i(13, 1), Vector2i(1, 9), Vector2i(13, 9)]
	var facings := [0.0, 180.0, 0.0, 180.0]
	for i in 4:
		var root := Node3D.new()
		root.position = _cell_pos(spots[i].x, spots[i].y)
		root.rotation_degrees = Vector3(0, facings[i], 0)
		root.scale = Vector3.ONE * 1.45
		add_child(root)
		_build_fighter_body(colors[i], root)
		fighters.append(root)


func _build_heroes() -> void:
	# 特写用的两名角色：挪到独立的“摄影棚”里，避免被柱子挡住
	var stage_x := 62.0
	var red := Node3D.new()
	red.position = Vector3(stage_x - 1.9, 0, 11.4)
	red.rotation_degrees = Vector3(0, 16, 0)
	red.scale = Vector3.ONE * 1.55
	add_child(red)
	_build_fighter_body(Color(0.86, 0.24, 0.22), red)
	red.visible = false
	heroes.append(red)

	var blue := Node3D.new()
	blue.position = Vector3(stage_x + 2.1, 0, 12.4)
	blue.rotation_degrees = Vector3(0, -34, 0)
	blue.scale = Vector3.ONE * 1.55
	add_child(blue)
	_build_fighter_body(Color(0.24, 0.52, 0.9), blue)
	blue.visible = false
	heroes.append(blue)


## 草丛：把“石头/箱子”换成一簇簇齐胸高的草，只挡视线、不挡路
func _build_grass() -> void:
	var palette := [
		Color(0.07, 0.16, 0.08), Color(0.1, 0.22, 0.1),
		Color(0.14, 0.3, 0.13), Color(0.19, 0.38, 0.16),
	]
	for z in range(2, ROWS - 2):
		for x in range(2, COLS - 2):
			if _is_wall(x, z):
				continue
			var near_spawn := false
			for s in [Vector2i(1, 1), Vector2i(13, 1), Vector2i(1, 9), Vector2i(13, 9)]:
				if absi(x - s.x) + absi(z - s.y) <= 2:
					near_spawn = true
			if near_spawn:
				continue
			if rng.randf() > 0.4:
				continue
			var cell := Vector2i(x, z)
			grass_cells.append(cell)
			var root := Node3D.new()
			root.position = _cell_pos(x, z)
			root.visible = false
			add_child(root)
			var r2 := RandomNumberGenerator.new()
			r2.seed = x * 977 + z * 31
			# 环绕一圈的草团，做出“齐腰深”的体积感
			for i in 11:
				var a := r2.randf() * TAU
				var r := r2.randf_range(0.15, 0.86)
				var h := r2.randf_range(0.55, 1.15)
				var mat := _mat(palette[r2.randi_range(0, palette.size() - 1)], 0.92, 0.0)
				var blob := _sphere(r2.randf_range(0.32, 0.52), Vector3(cos(a) * r, h, sin(a) * r), mat, root)
				blob.scale = Vector3(1.0, r2.randf_range(1.5, 2.3), 1.0)
			# 顶端草叶
			for i in 6:
				var a2 := r2.randf() * TAU
				var rr := r2.randf_range(0.2, 0.7)
				var blade := _cone(0.0, r2.randf_range(0.04, 0.08), r2.randf_range(0.5, 1.0),
					Vector3(cos(a2) * rr, r2.randf_range(1.5, 1.85), sin(a2) * rr),
					_mat(Color(0.24, 0.46, 0.2), 0.85), root)
				blade.rotation_degrees = Vector3(r2.randf_range(-14, 14), 0, r2.randf_range(-14, 14))
			grass_nodes.append(root)


func _set_arena_style(style: String) -> void:
	var grass := style == "grass"
	for n in grass_nodes:
		n.visible = grass
	for n in wall_nodes:
		n.visible = not grass
	for n in crate_nodes:
		n.visible = not grass


func _center_grass_cell() -> Vector2i:
	var best := Vector2i(7, 6)
	var best_d := 1e9
	for c in grass_cells:
		var dx := float(c.x - 7)
		var dy := float(c.y - 6)
		var d := dx * dx + dy * dy
		if d < best_d:
			best_d = d
			best = c
	return best


func _is_grass(cell: Vector2i) -> bool:
	return grass_cells.has(cell)


## 找一块“孤立”的草：四周都没草，方便拍出「一个人蹲在草里」的画面
func _isolated_grass_cell() -> Vector2i:
	var best := _center_grass_cell()
	var best_d := 1e9
	for c in grass_cells:
		var lonely := true
		for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			if _is_grass(c + d):
				lonely = false
		if not lonely:
			continue
		var dx := float(c.x - 7)
		var dy := float(c.y - 6)
		var dd := dx * dx + dy * dy
		if dd < best_d:
			best_d = dd
			best = c
	return best


## 从草丛出发，挑一个连续两格都没有草的方向，作为镜头方向
func _clear_direction(cell: Vector2i) -> Vector2i:
	for d in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1)]:
		var step: Vector2i = d
		var c1: Vector2i = cell + step
		var c2: Vector2i = cell + step * 2
		if not _is_grass(c1) and not _is_grass(c2) and not _is_wall(c1.x, c1.y) and not _is_wall(c2.x, c2.y):
			return step
	return Vector2i(0, 1)
func _build_stage() -> void:
	var cx := 62.0
	var cz := 11.0
	var base := _mat(Color(0.09, 0.1, 0.14), 0.55, 0.25)
	_box(Vector3(16.0, 0.4, 10.0), Vector3(cx, -0.2, cz), base)
	var mat_a := _mat(Color(0.13, 0.145, 0.19), 0.6, 0.2)
	var mat_b := _mat(Color(0.15, 0.165, 0.215), 0.55, 0.2)
	for z in 5:
		for x in 8:
			var m := mat_a if (x + z) % 2 == 0 else mat_b
			var tile := _box(
				Vector3(1.94, 0.06, 1.94),
				Vector3(cx - 8.0 + 1.0 + x * 2.0, 0.0, cz - 5.0 + 1.0 + z * 2.0),
				m
			)
			tile.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# 背景箱子
	var wood := _mat(Color(0.27, 0.16, 0.085), 0.88, 0.0)
	for p in [Vector3(cx + 5.2, 0.62, cz - 1.4), Vector3(cx + 5.2, 0.62, cz + 0.4), Vector3(cx + 3.4, 0.6, cz - 2.6)]:
		_box(Vector3(1.5, 1.24, 1.5), p, wood)
	_box(Vector3(1.44, 0.05, 1.44), Vector3(cx + 5.2, 1.27, cz - 1.4), _mat(Color(0.33, 0.2, 0.11), 0.82))

	# 台面上的炸弹
	_make_bomb(Vector3(cx - 0.2, 0, cz + 0.6), 1.25)

	# 摄影棚打光
	var key := SpotLight3D.new()
	key.position = Vector3(cx - 4.0, 7.5, cz + 6.0)
	key.rotation_degrees = Vector3(-52, -20, 0)
	key.light_color = Color(1.0, 0.95, 0.88)
	key.light_energy = 9.0
	key.spot_range = 26.0
	key.spot_angle = 34.0
	key.shadow_enabled = true
	add_child(key)

	var back_a := OmniLight3D.new()
	back_a.position = Vector3(cx + 4.6, 3.2, cz - 2.6)
	back_a.light_color = Color(1.0, 0.34, 0.55)
	back_a.light_energy = 6.0
	back_a.omni_range = 12.0
	add_child(back_a)

	var back_b := OmniLight3D.new()
	back_b.position = Vector3(cx - 4.4, 3.0, cz - 1.6)
	back_b.light_color = Color(0.3, 0.8, 1.0)
	back_b.light_energy = 5.0
	back_b.omni_range = 12.0
	add_child(back_b)


# ---------------------------------------------------------------- 炸弹 / 爆炸
func _make_bomb(pos: Vector3, scale: float = 1.0) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	root.scale = Vector3.ONE * scale
	add_child(root)

	var shell := _mat(Color(0.035, 0.035, 0.05), 0.16, 0.65)
	_sphere(0.46, Vector3(0, 0.46, 0), shell, root)
	# 引信口
	_cyl(0.1, 0.14, Vector3(0, 0.9, 0), _mat(Color(0.1, 0.1, 0.12), 0.5, 0.4), root)
	# 引信
	var fuse := _cyl(0.035, 0.34, Vector3(0.05, 1.05, 0.02), _mat(Color(0.45, 0.36, 0.2), 0.9), root)
	fuse.rotation_degrees = Vector3(0, 0, 18)
	# 火花
	var spark := _sphere(0.075, Vector3(0.13, 1.2, 0.02), _emit_mat(Color(1.0, 0.72, 0.25), 12.0), root)
	spark.name = "Spark"

	var light := OmniLight3D.new()
	light.position = Vector3(0.13, 1.25, 0.02)
	light.light_color = Color(1.0, 0.62, 0.22)
	light.light_energy = 2.6
	light.omni_range = 6.0
	light.shadow_enabled = false
	root.add_child(light)

	# 地面能量环
	var ring := _cyl(0.75, 0.02, Vector3(0, 0.06, 0), _emit_mat(Color(1.0, 0.45, 0.15), 2.4), root)
	ring.name = "Ring"
	bomb_group.append(root)
	return root


func _build_bombs() -> void:
	_make_bomb(_cell_pos(7, 5), 1.18)
	_make_bomb(_cell_pos(8, 6), 1.05)
	_make_bomb(_cell_pos(6, 7), 1.22)


func _make_flame_cell(pos: Vector3) -> void:
	var root := Node3D.new()
	root.position = pos
	add_child(root)
	_sphere(0.6, Vector3(0, 0.58, 0), _emit_mat(Color(0.8, 0.14, 0.08), 2.2), root)
	_sphere(0.44, Vector3(0, 0.64, 0), _emit_mat(Color(1.0, 0.42, 0.1), 4.5), root)
	_sphere(0.27, Vector3(0, 0.7, 0), _emit_mat(Color(1.0, 0.9, 0.6), 9.0), root)
	# 向上窜的火舌
	var tongue := _cone(0.04, 0.26, 0.85, Vector3(0, 1.2, 0), _emit_mat(Color(1.0, 0.62, 0.2), 5.0), root)
	tongue.rotation_degrees = Vector3(rng.randf_range(-8, 8), rng.randf_range(0, 180), rng.randf_range(-8, 8))
	var light := OmniLight3D.new()
	light.position = Vector3(0, 0.9, 0)
	light.light_color = Color(1.0, 0.5, 0.16)
	light.light_energy = 10.0
	light.omni_range = 10.0
	root.add_child(light)
	flame_group.append(root)


func _build_explosion() -> void:
	# 选在 (7,7)：行与列都是奇数格，天然没有石柱，视线和火柱都不会被挡
	var origin := Vector2i(7, 7)
	_make_flame_cell(_cell_pos(origin.x, origin.y))
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var c: Vector2i = origin + d
		var root := Node3D.new()
		root.position = _cell_pos(c.x, c.y)
		add_child(root)
		_sphere(0.52, Vector3(0, 0.52, 0), _emit_mat(Color(0.8, 0.14, 0.08), 2.0), root)
		_sphere(0.37, Vector3(0, 0.57, 0), _emit_mat(Color(1.0, 0.4, 0.1), 4.2), root)
		_sphere(0.2, Vector3(0, 0.62, 0), _emit_mat(Color(1.0, 0.88, 0.6), 8.0), root)
		var tongue := _cone(0.035, 0.18, 0.6, Vector3(0, 0.98, 0), _emit_mat(Color(1.0, 0.55, 0.18), 4.0), root)
		tongue.rotation_degrees = Vector3(rng.randf_range(-10, 10), rng.randf_range(0, 180), rng.randf_range(-10, 10))
		var l := OmniLight3D.new()
		l.position = Vector3(0, 0.8, 0)
		l.light_color = Color(1.0, 0.45, 0.14)
		l.light_energy = 4.0
		l.omni_range = 7.0
		root.add_child(l)
		flame_group.append(root)


# ---------------------------------------------------------------- 出图
func _setup_camera(pos: Vector3, target: Vector3, fov: float, dof: bool = false) -> void:
	if camera == null:
		camera = Camera3D.new()
		add_child(camera)
	camera.position = pos
	camera.fov = fov
	camera.look_at(target, Vector3.UP)
	if dof:
		var attrs := CameraAttributesPractical.new()
		attrs.dof_blur_far_enabled = true
		attrs.dof_blur_far_distance = 9.0
		attrs.dof_blur_far_transition = 14.0
		attrs.dof_blur_near_enabled = true
		attrs.dof_blur_near_distance = 3.0
		attrs.dof_blur_amount = 0.12
		camera.attributes = attrs
	else:
		camera.attributes = null


func _capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := OUT_DIR.path_join(name + ".png")
	var err := img.save_png(path)
	print("SHOT %s err=%d %dx%d" % [name, err, img.get_width(), img.get_height()])


func _set_heroes(v: bool) -> void:
	for h in heroes:
		h.visible = v


func _set_flames(v: bool) -> void:
	for f in flame_group:
		f.visible = v


func _render_all() -> void:
	_set_arena_style("blocks")
	# 1. 全场 3/4 视角
	_set_heroes(false)
	_set_flames(true)
	_setup_camera(Vector3(31.0, 19.5, 38.0), Vector3(15.0, 0.4, 11.6), 34.0)
	await _capture("c3d_01_arena")

	# 2. 俯视玩法视角
	_setup_camera(Vector3(15.0, 21.5, 26.5), Vector3(15.0, 0.0, 10.6), 38.0)
	await _capture("c3d_02_topdown")

	# 3. 低角度英雄特写（摄影棚）
	_set_heroes(true)
	_set_flames(false)
	_setup_camera(Vector3(61.2, 0.72, 15.6), Vector3(61.95, 1.15, 11.7), 30.0, true)
	await _capture("c3d_03_hero")

	# 4. 对决赛海报
	_setup_camera(Vector3(62.0, 1.35, 18.6), Vector3(62.0, 1.45, 11.6), 38.0, true)
	await _capture("c3d_04_poster")

	# 5. 爆炸瞬间
	_set_heroes(false)
	_set_flames(true)
	_setup_camera(Vector3(21.5, 6.2, 20.5), Vector3(15.0, 0.9, 14.5), 40.0, true)
	await _capture("c3d_05_blast")

	# 6. 草丛版场地：掩体换成齐腰深的草，只挡视线不挡路
	_set_arena_style("grass")
	_set_flames(true)
	_setup_camera(Vector3(31.0, 19.5, 38.0), Vector3(15.0, 0.4, 11.6), 34.0)
	await _capture("c3d_06_grass")

	# 7. 草丛伏击：草里蹲人，外面的人看不见
	_set_flames(false)
	var hide := _isolated_grass_cell()
	var cam_dir := _clear_direction(hide)
	var p_hide := _cell_pos(hide.x, hide.y)
	fighters[0].position = p_hide
	fighters[0].rotation_degrees = Vector3(0, rad_to_deg(atan2(cam_dir.x, cam_dir.y)), 0)
	var perp := Vector2i(cam_dir.y, -cam_dir.x)
	# 敌人从草的另一侧逼近，草里的人正对着镜头
	fighters[1].position = _cell_pos(hide.x - cam_dir.x * 3, hide.y - cam_dir.y * 3)
	fighters[1].rotation_degrees = Vector3(0, rad_to_deg(atan2(cam_dir.x, cam_dir.y)), 0)
	fighters[2].position = _cell_pos(hide.x + perp.x * 4, hide.y + perp.y * 4)
	fighters[2].rotation_degrees = Vector3(0, 45, 0)
	_setup_camera(
		p_hide + Vector3(cam_dir.x, 0, cam_dir.y) * 8.6 + Vector3(0, 2.3, 0),
		p_hide + Vector3(0, 1.0, 0),
		30.0,
		true
	)
	await _capture("c3d_07_ambush")

	print("CONCEPT DONE")
	get_tree().quit(0)

	print("CONCEPT DONE")
	get_tree().quit(0)
