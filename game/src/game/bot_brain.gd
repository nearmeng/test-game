class_name BotBrain
extends RefCounted
## AI：危险图 + 安全寻路 + 抢道具 + 贴箱放弹 + 追击。


class Bfs:
	var dist := {}
	var parent := {}

	func has(cell: Vector2i) -> bool:
		return dist.has(cell)

	func t(cell: Vector2i) -> float:
		return float(dist.get(cell, 1e9))

	func path_to(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
		var out: Array[Vector2i] = []
		if not dist.has(to):
			return out
		var cur := to
		var guard := 0
		while cur != from and guard < 256:
			out.push_front(cur)
			if not parent.has(cur):
				return []
			cur = parent[cur]
			guard += 1
		if cur != from:
			return []
		out.push_front(from)
		return out


var fighter: Fighter
var battle: Battle
var difficulty := 1
var think_timer := 0.0
var interval := 0.3
var path: Array[Vector2i] = []
var chosen_goal := ""
var rng := RandomNumberGenerator.new()
var _hesitation := [0.22, 0.07, 0.0]
var _escape_margin := [1.95, 1.6, 1.3]
var _last_bomb_tick := -100.0
var _tick := 0.0


func setup(p_fighter: Fighter, p_battle: Battle, p_difficulty: int, seed_value: int) -> void:
	fighter = p_fighter
	battle = p_battle
	difficulty = clampi(p_difficulty, 0, 2)
	interval = [0.52, 0.30, 0.17][difficulty]
	rng.seed = seed_value
	think_timer = rng.randf() * interval


func update(delta: float) -> void:
	if fighter == null or not fighter.alive:
		return
	_tick += delta
	fighter.intent_bomb = false
	think_timer -= delta
	if think_timer <= 0.0:
		think_timer = interval * rng.randf_range(0.8, 1.25)
		var hesitation: float = _hesitation[difficulty]
		if rng.randf() > hesitation:
			_think()
	if path.size() >= 2:
		var from: Vector2i = fighter.target_cell if fighter.moving else fighter.cell
		var d: Vector2i = path[1] - from
		if absi(d.x) + absi(d.y) != 1:
			path.clear()
			fighter.intent_dir = Vector2i.ZERO
			return
		fighter.intent_dir = d
	else:
		fighter.intent_dir = Vector2i.ZERO


func _think() -> void:
	var danger: Dictionary = battle.danger_map()
	var here: Vector2i = fighter.cell

	# 0) 脚下马上就要炸：先跑
	if danger.has(here) and float(danger[here]) < 0.55:
		var escape := _safe_bfs(here, danger)
		var target := _best_escape(escape, danger, here)
		if target != here:
			path = escape.path_to(here, target)
			chosen_goal = "flee"
			return

	# 1) 抢道具（安全可达）
	var safe := _safe_bfs(here, danger)
	var power_target := _nearest_powerup(safe)
	if power_target != Vector2i(-1, -1):
		path = safe.path_to(here, power_target)
		chosen_goal = "powerup"
		return

	# 2) 贴箱放弹
	if _should_bomb_crate(here, danger):
		_place_and_flee(danger)
		return

	# 3) 追击：与对手同轴且距离在火力范围内
	var enemy := _nearest_enemy()
	if enemy != null:
		var ec: Vector2i = enemy.cell
		var dx := ec.x - here.x
		var dy := ec.y - here.y
		var aligned := dx == 0 or dy == 0
		var dist := absi(dx) + absi(dy)
		if aligned and dist > 0 and dist <= fighter.power + 1 and _can_bomb_here() and _escape_after_bomb(here, danger):
			_place_and_flee(danger)
			return
		if dist > 1:
			var plain := _plain_bfs(here, ec)
			if plain.has(ec) and plain.path_to(here, ec).size() >= 2:
				path = plain.path_to(here, ec)
				chosen_goal = "chase"
				return

	# 4) 巡逻：朝远离危险的方向走走
	var wander := _wander_cell(safe, danger)
	if wander != here:
		path = safe.path_to(here, wander)
		chosen_goal = "wander"
		if path.size() < 2:
			path = _first_step_path(here, danger)
	else:
		path = _first_step_path(here, danger)


func _place_and_flee(danger: Dictionary) -> void:
	fighter.intent_bomb = true
	fighter.intent_dir = Vector2i.ZERO
	path.clear()
	chosen_goal = "bomb"
	_last_bomb_tick = _tick


func _can_bomb_here() -> bool:
	if fighter.moving:
		return false
	if fighter.bombs_out >= fighter.bombs_max:
		return false
	if battle.has_bomb(fighter.cell):
		return false
	return true


func _should_bomb_crate(here: Vector2i, danger: Dictionary) -> bool:
	if not _can_bomb_here():
		return false
	if not _near_crate(here):
		return false
	# 同一位置 1.2 秒内不重复放
	if _tick - _last_bomb_tick < 1.2:
		return false
	return _escape_after_bomb(here, danger)


func _near_crate(cell: Vector2i) -> bool:
	for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		if battle.arena.kind_at(cell + d) == Arena.Kind.CRATE:
			return true
	return false


func _escape_after_bomb(cell: Vector2i, danger: Dictionary) -> bool:
	var projected: Dictionary = danger.duplicate()
	for c in battle.simulate_blast(cell, fighter.power):
		if not projected.has(c) or float(projected[c]) > Bomb.FUSE:
			projected[c] = Bomb.FUSE
	var reach := _safe_bfs(cell, projected, cell)
	var need: float = _escape_margin[difficulty]
	for c in reach.dist.keys():
		var t := float(reach.dist[c])
		if t <= 0.0 or t > need:
			continue
		if not battle.has_bomb(c) and not projected.has(c):
			return true
	return false


func _safe_bfs(from: Vector2i, danger: Dictionary, extra_block := Vector2i(-1, -1)) -> Bfs:
	var out := Bfs.new()
	var speed := maxf(fighter.speed_cells(), 0.1)
	out.dist[from] = 0.0
	var queue: Array[Vector2i] = [from]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		var t: float = float(out.dist[c])
		for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var n: Vector2i = c + d
			if n == extra_block or out.dist.has(n):
				continue
			if not battle.arena.in_bounds(n):
				continue
			if battle.arena.kind_at(n) != Arena.Kind.FLOOR:
				continue
			if battle.has_bomb(n) and n != from:
				continue
			var arrive := t + 1.0 / speed
			if danger.has(n) and float(danger[n]) <= arrive + 0.12:
				continue
			out.dist[n] = arrive
			out.parent[n] = c
			queue.append(n)
	return out


func _plain_bfs(from: Vector2i, goal: Vector2i) -> Bfs:
	var out := Bfs.new()
	var speed := maxf(fighter.speed_cells(), 0.1)
	out.dist[from] = 0.0
	var queue: Array[Vector2i] = [from]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		if c == goal:
			break
		var t: float = float(out.dist[c])
		for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var n: Vector2i = c + d
			if out.dist.has(n) or not battle.arena.in_bounds(n):
				continue
			if battle.arena.kind_at(n) != Arena.Kind.FLOOR:
				continue
			if battle.has_bomb(n):
				continue
			out.dist[n] = t + 1.0 / speed
			out.parent[n] = c
			queue.append(n)
	return out


func _best_escape(bfs: Bfs, danger: Dictionary, here: Vector2i) -> Vector2i:
	var best := here
	var best_score := -1e9
	for c in bfs.dist.keys():
		var t: float = float(bfs.dist[c])
		var score: float
		if not danger.has(c):
			score = 1000.0 - t
		else:
			score = float(danger[c]) - t * 0.3
		if score > best_score:
			best_score = score
			best = c
	return best


func _nearest_powerup(bfs: Bfs) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_d := 1e9
	for cell in battle.arena.powerups.keys():
		if not bfs.has(cell):
			continue
		var d := bfs.t(cell)
		if d < best_d:
			best_d = d
			best = cell
	return best


func _nearest_enemy() -> Fighter:
	var best: Fighter = null
	var best_d := 1e9
	var here := fighter.cell
	for f in battle.fighters:
		if f == fighter or not f.alive:
			continue
		var d := absi(f.cell.x - here.x) + absi(f.cell.y - here.y)
		if d < best_d:
			best_d = d
			best = f
	return best


func _wander_cell(bfs: Bfs, danger: Dictionary) -> Vector2i:
	var cells: Array = bfs.dist.keys()
	if cells.is_empty():
		return fighter.cell
	var best := fighter.cell
	var best_d := -1.0
	for _i in 6:
		var c: Vector2i = cells[rng.randi_range(0, cells.size() - 1)]
		var d := absf(float(c.x - fighter.cell.x)) + absf(float(c.y - fighter.cell.y))
		if d > best_d and not danger.has(c):
			best_d = d
			best = c
	return best


func _first_step_path(here: Vector2i, danger: Dictionary) -> Array[Vector2i]:
	var best := Vector2i.ZERO
	var best_margin := -1e9
	for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var n: Vector2i = here + d
		if battle.arena.kind_at(n) != Arena.Kind.FLOOR or battle.has_bomb(n):
			continue
		var margin := 9.0 if not danger.has(n) else float(danger[n])
		margin -= rng.randf() * 0.4
		if margin > best_margin:
			best_margin = margin
			best = n
	if best == Vector2i.ZERO:
		return []
	var out: Array[Vector2i] = [here, best]
	return out
