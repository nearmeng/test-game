class_name Arena
extends Node2D
## 场地数据与绘制：钢墙、木箱、地面、道具。

enum Kind { FLOOR, WALL, CRATE }

const POWERUP_KINDS := ["bomb", "fire", "speed", "shield"]

var kinds := PackedByteArray()
var stages := PackedByteArray()
var powerups := {}  # Vector2i -> int(kind index)
var spawns: Array[Vector2i] = []
var t := 0.0
var rng := RandomNumberGenerator.new()

var _tex_floor: Texture2D
var _tex_wall: Texture2D
var _tex_floor_alt: Texture2D
var _tex_crate: Array[Texture2D] = []


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	position = Vector2.ZERO
	_tex_floor = Art.tex("tile_floor_0")
	_tex_wall = Art.tex("tile_wall")
	_tex_floor_alt = Art.tex("tile_floor_1")
	for i in 3:
		_tex_crate.append(Art.tex("tile_crate_%d" % i))


func generate(seed_value: int, spawn_cells: Array[Vector2i]) -> void:
	rng.seed = seed_value
	spawns = spawn_cells
	var attempts := 0
	var density := 0.62
	while attempts < 8:
		attempts += 1
		_fill(0)
		_place_structure()
		_scatter_crates(density)
		if _is_connected():
			break
		density -= 0.06
	queue_redraw()


func _fill(v: int) -> void:
	kinds.resize(Pal.COLS * Pal.ROWS)
	stages.resize(Pal.COLS * Pal.ROWS)
	for i in kinds.size():
		kinds[i] = v
		stages[i] = 0
	powerups.clear()


func _place_structure() -> void:
	for y in Pal.ROWS:
		for x in Pal.COLS:
			var edge := x == 0 or y == 0 or x == Pal.COLS - 1 or y == Pal.ROWS - 1
			var pillar := x % 2 == 0 and y % 2 == 0
			if edge or pillar:
				kinds[y * Pal.COLS + x] = Kind.WALL


func _in_spawn_safe(cell: Vector2i) -> bool:
	for s in spawns:
		if absi(cell.x - s.x) + absi(cell.y - s.y) <= 2:
			return true
	return false


func _scatter_crates(density: float) -> void:
	for y in Pal.ROWS:
		for x in Pal.COLS:
			var c := Vector2i(x, y)
			if kinds[y * Pal.COLS + x] != Kind.FLOOR:
				continue
			if _in_spawn_safe(c):
				continue
			if rng.randf() < density:
				kinds[y * Pal.COLS + x] = Kind.CRATE
				stages[y * Pal.COLS + x] = rng.randi_range(0, 2)


func _is_connected() -> bool:
	if spawns.is_empty():
		return true
	var start := spawns[0]
	var seen := {}
	var queue: Array[Vector2i] = [start]
	seen[start] = true
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var n: Vector2i = c + d
			if not in_bounds(n) or seen.has(n):
				continue
			if kinds[idx(n)] != Kind.FLOOR:
				continue
			seen[n] = true
			queue.append(n)
	for s in spawns:
		if not seen.has(s):
			return false
	return true


func idx(cell: Vector2i) -> int:
	return cell.y * Pal.COLS + cell.x


func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < Pal.COLS and cell.y < Pal.ROWS


func kind_at(cell: Vector2i) -> int:
	if not in_bounds(cell):
		return Kind.WALL
	return kinds[idx(cell)]


func is_free(cell: Vector2i) -> bool:
	return kind_at(cell) == Kind.FLOOR


func destroy_crate(cell: Vector2i) -> void:
	if kind_at(cell) != Kind.CRATE:
		return
	kinds[idx(cell)] = Kind.FLOOR
	queue_redraw()


## 爆炸沿直线前进时，返回 true 表示火焰到此为止。
func blocks_blast(cell: Vector2i) -> bool:
	return kind_at(cell) == Kind.WALL


func add_powerup(cell: Vector2i, kind_index: int) -> void:
	powerups[cell] = kind_index
	queue_redraw()


func take_powerup(cell: Vector2i) -> int:
	if not powerups.has(cell):
		return -1
	var k: int = powerups[cell]
	powerups.erase(cell)
	queue_redraw()
	return k


func random_floor_cell() -> Vector2i:
	for _i in 200:
		var c := Vector2i(rng.randi_range(1, Pal.COLS - 2), rng.randi_range(1, Pal.ROWS - 2))
		if is_free(c):
			return c
	return Vector2i(1, 1)


func _process(delta: float) -> void:
	t += delta
	if not powerups.is_empty():
		queue_redraw()


func _draw() -> void:
	# 场地外框
	draw_rect(Rect2(-10, -10, Pal.ARENA_SIZE.x + 20, Pal.ARENA_SIZE.y + 20), Color(0.08, 0.09, 0.14, 1.0))
	draw_rect(Rect2(-10, -10, Pal.ARENA_SIZE.x + 20, Pal.ARENA_SIZE.y + 20), Color(0.33, 0.36, 0.52, 0.9), false, 2.0)
	draw_rect(Rect2(-4, -4, Pal.ARENA_SIZE.x + 8, Pal.ARENA_SIZE.y + 8), Color(0.16, 0.18, 0.28, 0.85))

	for y in Pal.ROWS:
		for x in Pal.COLS:
			var cell := Vector2i(x, y)
			var k := kinds[y * Pal.COLS + x]
			var rect := Rect2(x * Pal.TILE, y * Pal.TILE, Pal.TILE, Pal.TILE)
			var floor_tex := _tex_floor if (x + y) % 2 == 0 else _tex_floor_alt
			if floor_tex == null:
				floor_tex = _tex_floor
			if floor_tex != null:
				draw_texture_rect(floor_tex, rect, false)
			if k == Kind.WALL:
				# 接触阴影
				draw_rect(Rect2(rect.position + Vector2(4, 8), rect.size), Color(0, 0, 0, 0.28))
				if _tex_wall != null:
					draw_texture_rect(_tex_wall, rect, false)
			elif k == Kind.CRATE:
				var idxm := mini(stages[y * Pal.COLS + x], _tex_crate.size() - 1)
				draw_rect(Rect2(rect.position + Vector2(3, 6), rect.size), Color(0, 0, 0, 0.25))
				if idxm >= 0 and _tex_crate[idxm] != null:
					draw_texture_rect(_tex_crate[idxm], rect, false)

	# 道具
	for cell in powerups.keys():
		var k_index: int = powerups[cell]
		var tex := Art.powerup_atlas(k_index)
		if tex == null:
			continue
		var bob := sin(t * 4.0 + float(cell.x) * 0.7) * 3.0
		var cpos := Vector2(cell.x * Pal.TILE + Pal.TILE * 0.5, cell.y * Pal.TILE + Pal.TILE * 0.5 + bob)
		var pulse := 1.0 + 0.06 * sin(t * 6.0 + float(cell.y))
		var size := Pal.TILE * 0.86 * pulse
		draw_texture_rect(tex, Rect2(cpos - Vector2(size, size) * 0.5, Vector2(size, size)), false)
		# 光晕
		draw_circle(cpos, Pal.TILE * 0.42, Color(1, 0.85, 0.45, 0.06 + 0.03 * sin(t * 6.0)))
