class_name Bot3D
extends RefCounted
## 3D 版 AI：危险图 + 安全寻路 + 视线感知 + 蹲草 / 探草。

const MOVE_KEYS := [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]

var hero: Hero3D
var difficulty := 1
var think_timer := 0.0
var interval := 0.28
var path: Array[Vector2i] = []
var rng := RandomNumberGenerator.new()

var _t := 0.0
var _last_bomb := -99.0
var _hide_until := 0.0
var _suspect := Vector2i(-1, -1)
var _suspect_until := 0.0
var _next_hide := 0.0
var _parent := {}


func setup(h: Hero3D, diff: int, seed_value: int) -> void:
	hero = h
	difficulty = clampi(diff, 0, 2)
	interval = [0.5, 0.28, 0.16][difficulty]
	rng.seed = seed_value
	think_timer = rng.randf() * interval


func update(delta: float, main) -> void:
	if hero == null or not hero.alive:
		return
	_t += delta
	hero.intent_bomb = false
	think_timer -= delta
	if think_timer <= 0.0:
		think_timer = interval * rng.randf_range(0.85, 1.2)
		_think(main)
	if path.size() >= 2:
		var from := hero.target_cell if hero.moving else hero.cell
		var d: Vector2i = path[1] - from
		if absi(d.x) + absi(d.y) != 1:
			path.clear()
			hero.intent_dir = Vector2i.ZERO
			return
		hero.intent_dir = d
	else:
		hero.intent_dir = Vector2i.ZERO


# ------------------------------------------------------------------ 决策
func _think(main) -> void:
	var danger: Dictionary = main.danger_map()
	var here := hero.cell

	# 0) 脚下要炸了：跑
	if danger.has(here) and float(danger[here]) < 0.6:
		var reach := _safe_bfs(main, here, danger)
		var target := _best_escape(reach, danger, here)
		if target != here:
			path = _path_to(main, reach, here, target)
			return

	# 1) 看到人了：打或者追
	var enemy: Hero3D = _visible_enemy(main)
	if enemy != null:
		var d := manhattan(here, enemy.cell)
		var aligned := here.x == enemy.cell.x or here.y == enemy.cell.y
		if aligned and d <= hero.power + 1 and _can_bomb(main) and _escape_ok(main, danger, here):
			_bomb()
			return
		var bfs := _plain_bfs(main, here, enemy.cell)
		if bfs.has(enemy.cell):
			path = _path_to(main, bfs, here, enemy.cell)
			return

	# 2) 刚看见的人进了草：往草里丢弹（探草）
	if _suspect != Vector2i(-1, -1) and _t < _suspect_until and manhattan(here, _suspect) <= 1:
		if _can_bomb(main) and _escape_ok(main, danger, here):
			_bomb()
			return

	# 3) 抢道具
	var loot := _reachable_powerup(main, here, danger)
	if loot != Vector2i(-1, -1):
		var reach2 := _safe_bfs(main, here, danger)
		path = _path_to(main, reach2, here, loot)
		return

	# 4) 贴箱放弹开路
	if _adjacent_crate(main) and _can_bomb(main) and _escape_ok(main, danger, here):
		_bomb()
		return

	# 5) 在草里且还在蹲草窗口内：留好，等人送上门
	if _in_grass(main, here) and _t < _hide_until:
		path.clear()
		return
	# 蹲够了就出来，并进入冷却，避免反复进出同一片草
	if _in_grass(main, here) and _t >= _hide_until:
		_hide_until = 0.0
		_next_hide = _t + rng.randf_range(7.0, 11.0)

	# 6) 想蹲草：30% 概率，且有冷却
	if _t >= _next_hide and _t >= _hide_until and rng.randf() < 0.3:
		var bush := _nearest_grass(main, here)
		if bush != Vector2i(-1, -1):
			var reach3 := _safe_bfs(main, here, danger)
			if reach3.has(bush):
				_hide_until = _t + rng.randf_range(3.0, 6.0)
				_next_hide = _hide_until + rng.randf_range(6.0, 9.0)
				path = _path_to(main, reach3, here, bush)
				return

	# 7) 找最近的对手压过去（就算看不见，也往那个方向走）
	var prey := _nearest_enemy(main)
	if prey != null:
		var hunt := _plain_bfs(main, here, prey.cell)
		if hunt.has(prey.cell):
			path = _path_to(main, hunt, here, prey.cell)
			return

	# 8) 巡逻
	var wander := _wander(main, here, danger)
	if wander != here:
		var reach4 := _safe_bfs(main, here, danger)
		if reach4.has(wander):
			path = _path_to(main, reach4, here, wander)


func _bomb() -> void:
	hero.intent_bomb = true
	hero.intent_dir = Vector2i.ZERO
	path.clear()
	_last_bomb = _t


func _can_bomb(main) -> bool:
	if hero.bombs_out >= hero.bombs_max:
		return false
	if main.has_bomb(hero.cell):
		return false
	return _t - _last_bomb > 0.8


# ------------------------------------------------------------------ 感知
func _visible_enemy(main) -> Hero3D:
	var best: Hero3D = null
	var best_d := 999
	for h in main.heroes:
		if h == hero or not h.alive:
			continue
		if h.hidden:
			# 看不见，但记住最后位置
			_suspect = h.cell
			_suspect_until = _t + 4.0
			continue
		if not main.world.has_los(hero.cell, h.cell):
			continue
		var d := manhattan(hero.cell, h.cell)
		if d < best_d:
			best_d = d
			best = h
	return best


func _in_grass(main, cell: Vector2i) -> bool:
	return main.world.kind(cell) == TileWorld.Kind.GRASS


func _nearest_grass(main, here: Vector2i) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_d := 99
	for c in main.world.all_cells():
		if main.world.kind(c) != TileWorld.Kind.GRASS:
			continue
		if main.has_bomb(c):
			continue
		var d := manhattan(here, c)
		if d < best_d:
			best_d = d
			best = c
	return best


func _adjacent_crate(main) -> bool:
	for d in MOVE_KEYS:
		if main.world.kind(hero.cell + d) == TileWorld.Kind.CRATE:
			return true
	return false


func _reachable_powerup(main, here: Vector2i, danger: Dictionary) -> Vector2i:
	if main.powerups.is_empty():
		return Vector2i(-1, -1)
	var reach := _safe_bfs(main, here, danger)
	var best := Vector2i(-1, -1)
	var best_d := 999.0
	for c in main.powerups.keys():
		if reach.has(c) and float(reach[c]) < best_d:
			best_d = float(reach[c])
			best = c
	return best


func manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


# ------------------------------------------------------------------ 寻路
func _passable(main, c: Vector2i) -> bool:
	if not main.world.in_bounds(c):
		return false
	if main.world.blocks_move(c):
		return false
	if main.has_bomb(c):
		return false
	return true


func _safe_bfs(main, from: Vector2i, danger: Dictionary) -> Dictionary:
	var dist := {from: 0.0}
	var parent := {}
	var queue: Array[Vector2i] = [from]
	var speed := 4.3 + hero.speed_level * 0.55
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		var t: float = dist[c]
		for d in MOVE_KEYS:
			var n: Vector2i = c + d
			if dist.has(n) or not _passable(main, n):
				continue
			var arrive := t + 1.0 / speed
			if danger.has(n) and float(danger[n]) <= arrive + 0.12:
				continue
			dist[n] = arrive
			parent[n] = c
			queue.append(n)
	_parent = parent
	return dist


func _plain_bfs(main, from: Vector2i, goal: Vector2i) -> Dictionary:
	var dist := {from: 0.0}
	var parent := {}
	var queue: Array[Vector2i] = [from]
	var speed := 4.3 + hero.speed_level * 0.55
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		if c == goal:
			break
		for d in MOVE_KEYS:
			var n: Vector2i = c + d
			if dist.has(n) or not _passable(main, n):
				continue
			dist[n] = float(dist[c]) + 1.0 / speed
			parent[n] = c
			queue.append(n)
	_parent = parent
	return dist


func _path_to(main, dist: Dictionary, from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if not dist.has(to):
		return out
	var parent: Dictionary = _parent
	var cur := to
	var guard := 0
	while cur != from and guard < 128:
		out.push_front(cur)
		if not parent.has(cur):
			return []
		cur = parent[cur]
		guard += 1
	out.push_front(from)
	return out


func _best_escape(reach: Dictionary, danger: Dictionary, here: Vector2i) -> Vector2i:
	var best := here
	var best_score := -1e9
	for c in reach.keys():
		var t: float = reach[c]
		var score := (1000.0 if not danger.has(c) else float(danger[c])) - t * 0.3
		if score > best_score:
			best_score = score
			best = c
	return best


func _escape_ok(main, danger: Dictionary, bomb_cell: Vector2i) -> bool:
	var projected: Dictionary = danger.duplicate()
	for c in main.world.blast_cells(bomb_cell, hero.power):
		projected[c] = minf(float(projected.get(c, 99.0)), Bomb3D.FUSE)
	var reach := _safe_bfs(main, bomb_cell, projected)
	for c in reach.keys():
		var t: float = reach[c]
		if t > 0.0 and t <= 1.7 and not projected.has(c):
			return true
	return false


func _wander(main, here: Vector2i, danger: Dictionary) -> Vector2i:
	var reach := _safe_bfs(main, here, danger)
	var cells: Array = reach.keys()
	if cells.size() <= 1:
		return here
	for _i in 5:
		var c: Vector2i = cells[rng.randi_range(0, cells.size() - 1)]
		if not danger.has(c):
			return c
	return here


func _nearest_enemy(main) -> Hero3D:
	var best: Hero3D = null
	var best_d := 999
	for h in main.heroes:
		if h == hero or not h.alive:
			continue
		var d := manhattan(hero.cell, h.cell)
		if d < best_d:
			best_d = d
			best = h
	return best