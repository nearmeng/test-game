class_name Blast3D
extends Node3D
## 3D 爆炸格：分层火球 + 火舌 + 点光源，短暂后自动缩小消失。

var life := 0.42
var age := 0.0
var _meshes: Array[MeshInstance3D] = []
var _light: OmniLight3D
var _tongue: MeshInstance3D


func setup(cell: Vector2i, world: TileWorld, center: bool) -> void:
	position = world.cell_pos(cell)
	var core := Look.emit("flame_core", Color(0.8, 0.14, 0.08), 2.2)
	var mid := Look.emit("flame_mid", Color(1.0, 0.42, 0.1), 4.5)
	var hot := Look.emit("flame_hot", Color(1.0, 0.9, 0.6), 9.0)
	var r := 1.0 if center else 0.86
	_meshes.append(Look.sphere(self, 0.62 * r, Vector3(0, 0.6, 0), core))
	_meshes.append(Look.sphere(self, 0.45 * r, Vector3(0, 0.66, 0), mid))
	_meshes.append(Look.sphere(self, 0.27 * r, Vector3(0, 0.72, 0), hot))
	_tongue = Look.cone(self, 0.03, 0.2, 0.9, Vector3(0, 1.35, 0), Look.emit("flame_tongue", Color(1.0, 0.6, 0.2), 5.0))
	_tongue.rotation_degrees = Vector3(randf_range(-10, 10), randf_range(0, 180), randf_range(-10, 10))
	_light = OmniLight3D.new()
	_light.position = Vector3(0, 0.9, 0)
	_light.light_color = Color(1.0, 0.5, 0.16)
	_light.light_energy = 6.0 if center else 3.0
	_light.omni_range = 9.0
	add_child(_light)


func tick(delta: float) -> void:
	age += delta
	var k := clampf(age / life, 0.0, 1.0)
	var s := 1.15 - 0.5 * k
	for m in _meshes:
		if is_instance_valid(m):
			m.scale = Vector3(s, s, s)
			m.transparency = k * 0.85
	if _tongue != null and is_instance_valid(_tongue):
		_tongue.transparency = k * 0.9
	if _light != null:
		_light.light_energy = maxf(0.0, (6.0 if age < 0.1 else 3.0) * (1.0 - k))
	if age >= life:
		queue_free()
