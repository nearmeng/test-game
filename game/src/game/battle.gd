class_name Battle
extends Node2D
## 战斗核心：回合流程、输入、爆炸判定、道具、AI 调度。

enum State { IDLE, COUNTDOWN, PLAYING, ROUND_END, MATCH_END, PAUSED }

const ROUND_TIME := 110.0
const COUNTDOWN_TIME := 3.0
const ROUND_END_TIME := 2.8
const MAX_ROUNDS := 3
const WINS_NEEDED := 2
const SPAWN_CELLS: Array[Vector2i] = [
	Vector2i(1, 1), Vector2i(13, 1), Vector2i(1, 9), Vector2i(13, 9),
]
const MODE_HUMANS := {
	"single": [0],
	"versus": [0, 1],
	"duel": [0, 1],
}
const MODE_BOTS := {
	"single": [1, 2, 3],
	"versus": [2, 3],
	"duel": [],
}

var config := {}
var mode := "single"
var difficulty := 1

var arena: Arena
var field: Node2D
var fx: FxLayer
var camera: Camera2D
var fighters: Array[Fighter] = []
var brains: Array = []  # index -> BotBrain or null
var bombs: Array[Bomb] = []
var bombs_by_cell := {}
var flame_cells := {}
var human_indices: Array[int] = []

var state := State.IDLE
var round_index := 0
var wins := [0, 0, 0, 0]
var time_left := ROUND_TIME
var countdown_left := 0.0
var round_end_left := 0.0
var last_round_winner := -1
var last_round_reason := ""
var match_winner := -1
var total_rounds := MAX_ROUNDS
var seed_base := 0
var rng := RandomNumberGenerator.new()
var stats_serial := 0

var shake_amount := 0.0
var shake_time := 0.0
var paused := false

# 统计（自测 / 结算用）
var stat_bombs := 0
var stat_explosions := 0
var stat_crates := 0

signal round_started(idx: int)
signal round_finished(winner: int, reason: String)
signal match_finished(winner: int)


func configure(cfg: Dictionary) -> void:
	config = cfg
	mode = str(cfg.get("mode", "single"))
	difficulty = int(cfg.get("difficulty", 1))


func _ready() -> void:
	mode = str(config.get("mode", "single"))
	difficulty = int(config.get("difficulty", 1))
	seed_base = int(config.get("seed", randi()))
	rng.seed = seed_base
	_build_world()
	if manual_step:
		return
	_start_match()


var manual_step := false
var flame_nodes: Array[Flame] = []


func _build_world() -> void:
	camera = Camera2D.new()
	camera.position = Pal.VIEW * 0.5
	camera.enabled = true
	add_child(camera)

	field = Node2D.new()
	field.name = "Field"
	field.position = Pal.ARENA_POS
	add_child(field)

	arena = Arena.new()
	arena.name = "Arena"
	field.add_child(arena)

	fx = FxLayer.new()
	fx.name = "Fx"
	field.add_child(fx)

	var humans: Array = MODE_HUMANS.get(mode, [0])
	var bots: Array = MODE_BOTS.get(mode, [1, 2, 3])
	if bool(config.get("autoplay", false)):
		humans = []
		bots = [0, 1, 2, 3]
	human_indices.clear()
	for i in humans:
		human_indices.append(int(i))
	brains.clear()
	fighters.clear()
	for i in 4:
		var f := Fighter.new()
		f.name = "Fighter%d" % i
		var label := ""
		if human_indices.has(i):
			label = "玩家 %d" % (i + 1) if human_indices.size() > 1 else "玩家"
		else:
			label = ["AI 赤", "AI 蓝", "AI 绿", "AI 黄"][i]
		f.setup(i, label, not human_indices.has(i))
		field.add_child(f)
		fighters.append(f)
		brains.append(null)
	for b in bots:
		var idx := int(b)
		var brain := BotBrain.new()
		brain.setup(fighters[idx], self, difficulty, seed_base + idx * 977 + 13)
		brains[idx] = brain


# ------------------------------------------------------------------ 回合流程
func _start_match() -> void:
	round_index = 0
	wins = [0, 0, 0, 0]
	match_winner = -1
	total_rounds = MAX_ROUNDS
	stat_bombs = 0
	stat_explosions = 0
	stat_crates = 0
	_next_round()


func _next_round() -> void:
	round_index += 1
	_build_arena()
	_reset_fighters()
	bombs.clear()
	bombs_by_cell.clear()
	flame_cells.clear()
	time_left = ROUND_TIME
	countdown_left = COUNTDOWN_TIME
	state = State.COUNTDOWN
	last_round_winner = -1
	last_round_reason = ""
	round_started.emit(round_index)


func _build_arena() -> void:
	for b in bombs:
		if is_instance_valid(b):
			b.queue_free()
	bombs.clear()
	bombs_by_cell.clear()
	flame_cells.clear()
	for f in flame_nodes:
		if is_instance_valid(f):
			f.queue_free()
	flame_nodes.clear()
	for child in fx.get_children():
		child.queue_free()
	arena.generate(seed_base + round_index * 7919, SPAWN_CELLS)


func _reset_fighters() -> void:
	var order := _spawn_order()
	for i in fighters.size():
		var f := fighters[i]
		f.reset_stats()
		f.bricks = 0
		f.kills = 0
		f.deaths = 0
		var c: Vector2i = SPAWN_CELLS[order[i]]
		f.place_at(c)
		f.visible = true
		f.z_index = 10 + c.y
		if brains[i] != null:
			brains[i].path.clear()


func _spawn_order() -> Array[int]:
	match mode:
		"duel":
			return [0, 3, 1, 2]
		"versus":
			return [0, 1, 2, 3]
		_:
			return [0, 1, 2, 3]


# ------------------------------------------------------------------ 主循环
func _physics_process(delta: float) -> void:
	if paused or manual_step:
		return
	_step(delta)


func _step(delta: float) -> void:
	match state:
		State.COUNTDOWN:
			_tick_countdown(delta)
		State.PLAYING:
			_tick_play(delta)
		State.ROUND_END:
			round_end_left -= delta
			_tick_fighters(delta, false)
			if round_end_left <= 0.0:
				_after_round()
		State.MATCH_END:
			pass
		_:
			pass
	_update_camera(delta)


func _tick_countdown(delta: float) -> void:
	var before := ceili(countdown_left)
	countdown_left -= delta
	var now := ceili(countdown_left)
	if before != now and now >= 1 and now <= 3:
		App.audio.play_sfx("countdown", -4.0)
	_tick_fighters(delta, false)
	if countdown_left <= 0.0:
		state = State.PLAYING
		App.audio.play_sfx("round_start", -2.0)
		App.audio.play_music("music_battle", 0.5)


func _tick_play(delta: float) -> void:
	time_left -= delta
	_gather_input()
	_tick_fighters(delta, true)
	_tick_bombs(delta)
	_tick_flames(delta)
	_check_pickups()
	_prune_dead_bombs()
	_check_round_end()


func _tick_fighters(delta: float, allow_input: bool) -> void:
	for i in fighters.size():
		var f := fighters[i]
		if not f.alive:
			continue
		if allow_input and brains[i] != null:
			brains[i].update(delta)
		f.step(delta, _can_walk)
		if allow_input and f.intent_bomb:
			f.intent_bomb = false
			_try_place_bomb(f)
		f.z_index = 10 + int(f.position.y / Pal.TILE)


func _gather_input() -> void:
	for i in human_indices:
		var f := fighters[i]
		if not f.alive:
			continue
		var prefix := "p1_" if i == 0 else "p2_"
		var d := Vector2i.ZERO
		if Input.is_action_pressed(prefix + "left"):
			d = Vector2i.LEFT
		elif Input.is_action_pressed(prefix + "right"):
			d = Vector2i.RIGHT
		elif Input.is_action_pressed(prefix + "up"):
			d = Vector2i.UP
		elif Input.is_action_pressed(prefix + "down"):
			d = Vector2i.DOWN
		f.intent_dir = d
		if Input.is_action_just_pressed(prefix + "bomb"):
			f.intent_bomb = true


func _can_walk(cell: Vector2i, _who: Fighter) -> bool:
	if arena.kind_at(cell) != Arena.Kind.FLOOR:
		return false
	if bombs_by_cell.has(cell):
		return false
	return true


# ------------------------------------------------------------------ 炸弹
func _try_place_bomb(f: Fighter) -> void:
	if not f.alive:
		return
	if f.bombs_out >= f.bombs_max:
		return
	var c := f.current_cell()
	if bombs_by_cell.has(c) or arena.kind_at(c) != Arena.Kind.FLOOR:
		return
	var b := Bomb.new()
	b.setup(c, f.power, f.index)
	field.add_child(b)
	bombs.append(b)
	bombs_by_cell[c] = b
	f.bombs_out += 1
	stat_bombs += 1
	App.audio.play_sfx("bomb_place", -4.0)


func _tick_bombs(delta: float) -> void:
	for b in bombs:
		if b.exploded_flag:
			continue
		b.time_left -= delta
		if b.time_left <= 0.0:
			_explode(b)


func _prune_dead_bombs() -> void:
	if bombs.is_empty():
		return
	var survivors: Array[Bomb] = []
	for b in bombs:
		if b.exploded_flag:
			if bombs_by_cell.has(b.cell) and bombs_by_cell[b.cell] == b:
				bombs_by_cell.erase(b.cell)
			if is_instance_valid(b) and not b.is_queued_for_deletion():
				b.queue_free()
		else:
			survivors.append(b)
	bombs = survivors


func _explode(bomb: Bomb) -> void:
	if bomb.exploded_flag:
		return
	bomb.exploded_flag = true
	if bombs_by_cell.has(bomb.cell) and bombs_by_cell[bomb.cell] == bomb:
		bombs_by_cell.erase(bomb.cell)
	var owner_idx := bomb.owner_index
	if owner_idx >= 0 and owner_idx < fighters.size():
		fighters[owner_idx].bombs_out = maxi(0, fighters[owner_idx].bombs_out - 1)
	stat_explosions += 1

	var cells := simulate_blast(bomb.cell, bomb.power)
	_apply_blast(cells, bomb)
	App.audio.play_sfx("explosion", -1.0, randf_range(0.94, 1.06))
	_add_shake(7.0, 0.35)

	# 连锁引爆
	for other in bombs:
		if other.exploded_flag or not is_instance_valid(other):
			continue
		if cells.has(other.cell):
			other.time_left = 0.0
			_explode(other)


func simulate_blast(origin: Vector2i, power: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = [origin]
	for dir in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		for i in range(1, power + 1):
			var c: Vector2i = origin + dir * i
			if not arena.in_bounds(c):
				break
			var k := arena.kind_at(c)
			if k == Arena.Kind.WALL:
				break
			cells.append(c)
			if k == Arena.Kind.CRATE:
				break
	return cells


func _apply_blast(cells: Array[Vector2i], bomb: Bomb) -> void:
	var origin: Vector2i = bomb.cell
	for c in cells:
		_spawn_flame_visual(origin, c, cells)
		flame_cells[c] = 0.34
		# 已有道具被烧掉
		if arena.powerups.has(c):
			arena.take_powerup(c)
			fx.burst(_cell_pos(c), Color("ffd24a"), 8, 120.0, 0.4, 4.0)
		# 木箱
		if arena.kind_at(c) == Arena.Kind.CRATE:
			arena.destroy_crate(c)
			stat_crates += 1
			fx.debris(_cell_pos(c), Color("b06b3a"), 9)
			App.audio.play_sfx("brick", -6.0, randf_range(0.9, 1.1))
			if bomb.owner_index >= 0 and bomb.owner_index < fighters.size():
				fighters[bomb.owner_index].bricks += 1
			if rng.randf() < 0.38:
				arena.add_powerup(c, _roll_powerup())
	# 角色判定
	for f in fighters:
		if not f.alive:
			continue
		if cells.has(f.current_cell()):
			_hit_fighter(f, bomb.owner_index)
	fx.burst(_cell_pos(origin), Color("ffb347"), 16, 210.0, 0.5, 6.0)


func _spawn_flame_visual(origin: Vector2i, c: Vector2i, cells: Array[Vector2i]) -> void:
	var node := Flame.new()
	var kind := "center"
	var flip_h := false
	var flip_v := false
	if c != origin:
		var d := c - origin
		var horizontal := d.x != 0
		# 是否是本方向最末端
		var tip := true
		var next := c + Vector2i(signi(d.x), signi(d.y))
		if cells.has(next):
			tip = false
		if horizontal:
			kind = "tip_h" if tip else "arm_h"
			flip_h = d.x < 0
		else:
			kind = "tip_v" if tip else "arm_v"
			flip_v = d.y < 0
	node.position = _cell_pos(c)
	field.add_child(node)
	node.setup(kind, flip_h, flip_v, 0.46)
	flame_nodes.append(node)
	if flame_nodes.size() > 48:
		var alive_nodes: Array[Flame] = []
		for n in flame_nodes:
			if is_instance_valid(n):
				alive_nodes.append(n)
		flame_nodes = alive_nodes


func _tick_flames(delta: float) -> void:
	var expired: Array[Vector2i] = []
	for c in flame_cells.keys():
		flame_cells[c] = float(flame_cells[c]) - delta
		if float(flame_cells[c]) <= 0.0:
			expired.append(c)
	for c in expired:
		flame_cells.erase(c)
	# 站在火上的角色
	if flame_cells.is_empty():
		return
	for f in fighters:
		if not f.alive:
			continue
		if flame_cells.has(f.current_cell()):
			_hit_fighter(f, -1)


func _hit_fighter(f: Fighter, source_index: int) -> void:
	if not f.alive:
		return
	if f.is_shielded():
		f.shield_until = 0.0
		f.flash_hurt()
		fx.burst(_cell_pos(f.current_cell()), Color("55d6ff"), 12, 160.0, 0.4, 4.0)
		App.audio.play_sfx("shield", -3.0)
		return
	f.die()
	fx.burst(_cell_pos(f.current_cell()), Pal.P_COLORS[f.index], 22, 240.0, 0.7, 6.0)
	fx.float_text(_cell_pos(f.current_cell()), "OUT", Pal.P_COLORS[f.index], 26)
	App.audio.play_sfx("death", -2.0)
	_add_shake(5.0, 0.3)
	if source_index >= 0 and source_index < fighters.size() and source_index != f.index:
		fighters[source_index].kills += 1


func _roll_powerup() -> int:
	var roll := rng.randf()
	if roll < 0.34:
		return 0
	elif roll < 0.66:
		return 1
	elif roll < 0.9:
		return 2
	return 3


func _check_pickups() -> void:
	for f in fighters:
		if not f.alive:
			continue
		var c := f.current_cell()
		if not arena.powerups.has(c):
			continue
		var kind := arena.take_powerup(c)
		_apply_powerup(f, kind)


func _apply_powerup(f: Fighter, kind: int) -> void:
	match kind:
		0:
			f.bombs_max = mini(6, f.bombs_max + 1)
			fx.float_text(_cell_pos(f.current_cell()), "炸弹 +1", Pal.AMBER, 20)
		1:
			f.power = mini(6, f.power + 1)
			fx.float_text(_cell_pos(f.current_cell()), "火力 +1", Color("ff8a50"), 20)
		2:
			f.speed_level = mini(4, f.speed_level + 1)
			fx.float_text(_cell_pos(f.current_cell()), "速度 +1", Pal.LIME, 20)
		3:
			f.grant_shield(5.0)
			fx.float_text(_cell_pos(f.current_cell()), "护盾 5s", Pal.CYAN, 20)
	App.audio.play_sfx("powerup", -3.0)
	fx.burst(_cell_pos(f.current_cell()), Color("ffe9a8"), 12, 140.0, 0.45, 4.0)


# ------------------------------------------------------------------ 结算
func alive_indices() -> Array[int]:
	var out: Array[int] = []
	for f in fighters:
		if f.alive:
			out.append(f.index)
	return out


func _check_round_end() -> void:
	var alive := alive_indices()
	if alive.size() <= 1:
		_finish_round(alive[0] if alive.size() == 1 else -1, "淘汰")
		return
	if time_left <= 0.0:
		var best := -1
		var best_key := Vector2i(-1, -1)
		var tie := false
		for i in alive:
			var f := fighters[i]
			var key := Vector2i(f.bricks, f.kills)
			if key.x > best_key.x or (key.x == best_key.x and key.y > best_key.y):
				best = i
				best_key = key
				tie = false
			elif best >= 0 and key == best_key:
				tie = true
		_finish_round(-1 if tie else best, "时间到")


func _finish_round(winner: int, reason: String) -> void:
	if winner >= 0:
		wins[winner] += 1
	last_round_winner = winner
	last_round_reason = reason
	state = State.ROUND_END
	round_end_left = ROUND_END_TIME
	round_finished.emit(winner, reason)
	App.audio.play_sfx("win" if winner >= 0 and winner in human_indices else "lose", -3.0)


func _after_round() -> void:
	var top := -1
	var top_wins := 0
	var tie := false
	for i in 4:
		if wins[i] > top_wins:
			top_wins = wins[i]
			top = i
			tie = false
		elif wins[i] == top_wins and wins[i] > 0:
			tie = true
	if top_wins >= WINS_NEEDED or round_index >= MAX_ROUNDS:
		match_winner = -1 if tie else top
		state = State.MATCH_END
		match_finished.emit(match_winner)
		return
	_next_round()


# ------------------------------------------------------------------ 工具
func danger_map() -> Dictionary:
	var d := {}
	for b in bombs:
		if b.exploded_flag:
			continue
		for c in simulate_blast(b.cell, b.power):
			var t := maxf(b.time_left, 0.0)
			if not d.has(c) or float(d[c]) > t:
				d[c] = t
	return d


func has_bomb(cell: Vector2i) -> bool:
	return bombs_by_cell.has(cell)


func _cell_pos(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * Pal.TILE + Pal.TILE * 0.5, cell.y * Pal.TILE + Pal.TILE * 0.5)


func _add_shake(amount: float, duration: float) -> void:
	if App != null and not App.shake_enabled():
		return
	shake_amount = maxf(shake_amount, amount)
	shake_time = maxf(shake_time, duration)


func _update_camera(delta: float) -> void:
	if shake_time > 0.0:
		shake_time -= delta
		var k := clampf(shake_time / 0.35, 0.0, 1.0)
		camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake_amount * k
		if shake_time <= 0.0:
			camera.offset = Vector2.ZERO


func toggle_pause() -> void:
	if paused:
		paused = false
		state = _resume_state
	elif state == State.PLAYING or state == State.COUNTDOWN:
		_resume_state = state
		paused = true
		state = State.PAUSED


var _resume_state := State.PLAYING


func restart_round() -> void:
	if round_index < 1:
		return
	round_index -= 1
	paused = false
	_next_round()
