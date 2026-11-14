class_name Bomb3D
extends Node3D
## 3D 炸弹：引信倒计时 + 脉冲 + 地面能量环 + 点光源。

const FUSE := 2.45

var cell := Vector2i.ZERO
var power := 1
var owner_index := -1
var time_left := FUSE
var exploded := false

var _spark: MeshInstance3D
var _ring: MeshInstance3D
var _light: OmniLight3D
var _t := 0.0


func setup(p_cell: Vector2i, p_power: int, p_owner: int, world: TileWorld) -> void:
	cell = p_cell
	power = p_power
	owner_index = p_owner
	position = world.cell_pos(cell)

	var shell := Look.mat("bomb", Color(0.035, 0.035, 0.05), 0.16, 0.65)
	Look.sphere(self, 0.46, Vector3(0, 0.46, 0), shell)
	Look.cyl(self, 0.1, 0.14, Vector3(0, 0.9, 0), Look.mat("fuse_cap", Color(0.1, 0.1, 0.12), 0.5, 0.4))
	var fuse := Look.cyl(self, 0.035, 0.32, Vector3(0.05, 1.04, 0.02), Look.mat("fuse", Color(0.45, 0.36, 0.2), 0.9))
	fuse.rotation_degrees = Vector3(0, 0, 18)
	_spark = Look.sphere(self, 0.08, Vector3(0.13, 1.18, 0.02), Look.emit("spark", Color(1.0, 0.72, 0.25), 12.0))
	_ring = Look.cyl(self, 0.74, 0.02, Vector3(0, 0.05, 0), Look.emit("bomb_ring", Color(1.0, 0.45, 0.15), 2.2))
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	_light = OmniLight3D.new()
	_light.position = Vector3(0.13, 1.25, 0.02)
	_light.light_color = Color(1.0, 0.62, 0.22)
	_light.light_energy = 2.2
	_light.omni_range = 6.0
	add_child(_light)

	scale = Vector3(0.3, 0.3, 0.3)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3.ONE, 0.14)


func tick(delta: float) -> void:
	_t += delta
	time_left -= delta
	var urgency := clampf(1.0 - time_left / FUSE, 0.0, 1.0)
	var pulse := 1.0 + sin(_t * (8.0 + urgency * 16.0)) * (0.05 + urgency * 0.1)
	if _spark != null:
		_spark.scale = Vector3.ONE * pulse
	if _ring != null:
		_ring.scale = Vector3(pulse, 1, pulse)
	if _light != null:
		_light.light_energy = 2.0 + urgency * 3.0
