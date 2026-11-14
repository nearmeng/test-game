class_name Hero3D
extends Node3D
## 3D 角色：格子移动 + Q 版模型 + 隐蔽表现 + 脚下标记。

const SPEED_BASE := 4.3
const SPEED_STEP := 0.55

var index := 0
var display_name := "玩家"
var is_bot := false
var alive := true
var cell := Vector2i(1, 1)
var target_cell := Vector2i(1, 1)
var moving := false
var facing := 0.0

var bombs_max := 1
var bombs_out := 0
var power := 1
var speed_level := 0
var bricks := 0
var kills := 0
var hidden := false
var reveal_until := 0.0

var intent_dir := Vector2i.ZERO
var intent_bomb := false

var meshes: Array[MeshInstance3D] = []
var marker: MeshInstance3D
var color := Color.WHITE
var visual_scale := 1.28
var _t := 0.0
var _spawn_t := 0.0


func setup(p_index: int, p_name: String, p_color: Color, p_bot: bool) -> void:
	index = p_index
	display_name = p_name
	color = p_color
	is_bot = p_bot
	_build()


func _build() -> void:
	var skin := Look.mat("skin", Color(0.78, 0.62, 0.5), 0.95)
	var cloth := Look.mat("cloth_%d" % index, color, 0.72, 0.04)
	var dark := Look.mat("cloth_dark_%d" % index, color.darkened(0.5), 0.78, 0.04)
	var ink := Look.mat("ink", Color(0.03, 0.03, 0.05), 0.5, 0.2)

	meshes.append(Look.box(self, Vector3(0.3, 0.16, 0.42), Vector3(-0.2, 0.08, 0.02), dark))
	meshes.append(Look.box(self, Vector3(0.3, 0.16, 0.42), Vector3(0.2, 0.08, 0.02), dark))

	var body := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.36
	cap.height = 1.0
	body.mesh = cap
	body.material_override = cloth
	body.position = Vector3(0, 0.62, 0)
	add_child(body)
	meshes.append(body)

	meshes.append(Look.cyl(self, 0.38, 0.1, Vector3(0, 0.42, 0), dark))
	meshes.append(Look.sphere(self, 0.13, Vector3(-0.42, 0.72, 0.04), dark))
	meshes.append(Look.sphere(self, 0.13, Vector3(0.42, 0.72, 0.04), dark))
	meshes.append(Look.sphere(self, 0.43, Vector3(0, 1.3, 0), skin))
	var hair := Look.sphere(self, 0.44, Vector3(0, 1.4, -0.02), cloth)
	hair.scale = Vector3(1, 0.6, 1)
	meshes.append(hair)
	meshes.append(Look.sphere(self, 0.062, Vector3(-0.15, 1.28, 0.38), ink))
	meshes.append(Look.sphere(self, 0.062, Vector3(0.15, 1.28, 0.38), ink))
	meshes.append(Look.cyl(self, 0.47, 0.07, Vector3(0, 1.52, 0), dark))
	var cap_ball := Look.sphere(self, 0.33, Vector3(0, 1.59, 0), cloth)
	cap_ball.scale = Vector3(1, 0.72, 1)
	meshes.append(cap_ball)

	# 脚下光圈：3D 里最容易丢的就是“我在哪”
	marker = Look.cyl(self, 0.78, 0.02, Vector3(0, 0.04, 0), Look.emit("marker_%d" % index, color, 2.2))
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func place_at(c: Vector2i, world: TileWorld) -> void:
	cell = c
	target_cell = c
	position = world.cell_pos(c)
	moving = false
	alive = true
	visible = true
	_spawn_t = 0.0
	scale = Vector3.ONE * (0.7 * visual_scale)


func face_towards(d: Vector2i) -> void:
	if d == Vector2i.ZERO:
		return
	facing = atan2(float(d.x), float(d.y))


func step(delta: float, world: TileWorld, occupied: Dictionary) -> void:
	_t += delta
	if not alive:
		return
	if _spawn_t < 1.0:
		_spawn_t = minf(1.0, _spawn_t + delta * 4.0)
		scale = Vector3.ONE * (0.7 + 0.3 * _spawn_t) * visual_scale

	if moving:
		var goal := world.cell_pos(target_cell)
		var spd := (SPEED_BASE + speed_level * SPEED_STEP) * 2.0
		position = position.move_toward(goal, spd * delta)
		if position.distance_to(goal) < 0.02:
			position = goal
			cell = target_cell
			moving = false
	else:
		if intent_dir != Vector2i.ZERO:
			var next := cell + intent_dir
			if not world.blocks_move(next) and not occupied.has(next):
				target_cell = next
				moving = true
				face_towards(intent_dir)

	# 朝向平滑
	if moving:
		var want := atan2(float(target_cell.x - cell.x), float(target_cell.y - cell.y))
		rotation.y = lerp_angle(rotation.y, want, minf(1.0, delta * 14.0))

	# 光圈呼吸
	if marker != null:
		var s := 1.0 + 0.06 * sin(_t * 5.0)
		marker.scale = Vector3(s, 1, s)


func current_cell() -> Vector2i:
	if not moving:
		return cell
	var local := position / 2.0
	return Vector2i(int(floor(local.x + 0.5)), int(floor(local.z + 0.5)))


func set_hide_visual(mode: String) -> void:
	# mode: "none" / "self" / "invisible"
	var t := 0.0
	if mode == "self":
		t = 0.55
	elif mode == "invisible":
		t = 1.0
	for m in meshes:
		m.transparency = t
	if marker != null:
		marker.transparency = 0.0 if mode != "invisible" else 0.7


func die() -> void:
	alive = false
	visible = false
	moving = false
	intent_dir = Vector2i.ZERO
