class_name TileWorld
extends RefCounted
## 3D 版场地数据：石柱 / 木箱 / 草丛，以及视线与爆炸判定。

enum Kind { FLOOR, WALL, CRATE, GRASS }

const COLS := 15
const ROWS := 11
const SPAWNS: Array[Vector2i] = [
	Vector2i(1, 1), Vector2i(13, 1), Vector2i(1, 9), Vector2i(13, 9),
]

var kinds := PackedByteArray()
var grass_variant := PackedByteArray()
var rng := RandomNumberGenerator.new()


func gen(seed_value: int) -> void:
	rng.seed = seed_value
	kinds.resize(COLS * ROWS)
	grass_variant.resize(COLS * ROWS)
	for z in ROWS:
		for x in COLS:
			var i := z * COLS + x
			var edge := x == 0 or z == 0 or x == COLS - 1 or z == ROWS - 1
			var pillar := x % 2 == 0 and z % 2 == 0
			kinds[i] = Kind.WALL if (edge or pillar) else Kind.FLOOR
			grass_variant[i] = rng.randi_range(0, 3)
	# 混搭：箱子 22%、草 19%（与 2D 概念稿同一套 hash 规则）
	for z in range(1, ROWS - 1):
		for x in range(1, COLS - 1):
			var i := z * COLS + x
			if kinds[i] != Kind.FLOOR:
				continue
			if in_spawn_safe(Vector2i(x, z)):
				continue
			var h := _hash(x, z)
			if h < 22:
				kinds[i] = Kind.CRATE
			elif h < 48:
				kinds[i] = Kind.GRASS


func _hash(x: int, z: int) -> int:
	var v := (x * 73856093) ^ (z * 19349663)
	v = v & 0xFFFFFFFF
	v = ((v ^ (v >> 13)) * 1274126177) & 0xFFFFFFFF
	v = v ^ (v >> 16)
	return v % 100


func in_spawn_safe(cell: Vector2i) -> bool:
	for s in SPAWNS:
		if absi(cell.x - s.x) + absi(cell.y - s.y) <= 2:
			return true
	return false


func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < COLS and c.y < ROWS


func kind(c: Vector2i) -> int:
	if not in_bounds(c):
		return Kind.WALL
	return kinds[c.y * COLS + c.x]


func set_kind(c: Vector2i, k: int) -> void:
	if in_bounds(c):
		kinds[c.y * COLS + c.x] = k


func blocks_move(c: Vector2i) -> bool:
	var k := kind(c)
	return k == Kind.WALL or k == Kind.CRATE


func blocks_blast(c: Vector2i) -> bool:
	return kind(c) == Kind.WALL


func blocks_vision(c: Vector2i) -> bool:
	var k := kind(c)
	return k == Kind.WALL or k == Kind.CRATE or k == Kind.GRASS


## 两格之间是否通视（不含两端所在格的遮挡判定用）
func has_los(a: Vector2i, b: Vector2i) -> bool:
	var dx := absi(b.x - a.x)
	var dz := absi(b.y - a.y)
	var sx := 1 if b.x > a.x else -1
	var sz := 1 if b.y > a.y else -1
	var err := dx - dz
	var cur := a
	var guard := 0
	while cur != b and guard < 64:
		guard += 1
		if cur != a and blocks_vision(cur):
			return false
		var e2 := err * 2
		if e2 > -dz:
			err -= dz
			cur.x += sx
		if e2 < dx:
			err += dx
			cur.y += sz
	return true


func blast_cells(origin: Vector2i, power: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = [origin]
	for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		for i in range(1, power + 1):
			var c: Vector2i = origin + d * i
			if not in_bounds(c):
				break
			if kind(c) == Kind.WALL:
				break
			out.append(c)
			if kind(c) == Kind.CRATE:
				break
	return out


func cell_pos(c: Vector2i) -> Vector3:
	return Vector3(c.x * 2.0 + 1.0, 0.0, c.y * 2.0 + 1.0)


func all_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for z in ROWS:
		for x in COLS:
			out.append(Vector2i(x, z))
	return out
