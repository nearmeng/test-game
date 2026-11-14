extends Node3D
## 火拼炸弹堂 3D（可玩版）：场景、回合、输入、爆炸、隐蔽、AI 调度。

const ROUND_TIME := 120.0
const COUNTDOWN := 3.0

var world: TileWorld
var arena_root: Node3D
var heroes: Array[Hero3D] = []
var bots: Array = []
var bombs: Array[Bomb3D] = []
var bombs_by_cell := {}
var blasts: Array[Blast3D] = []
var blast_cells := {}
var powerups := {}
var grass_nodes := {}
var grass_flat := {}
var crate_nodes := {}
var _powerup_nodes := {}

var player_index := 0
var hud: Hud3D
var cam: Camera3D
const CAM_NAMES := ["全场 正交 45°（推荐）", "跟随 65° 正交", "跟随 78° 近俯视", "跟随 55° 透视", "全场 透视 55°"]
var cam_mode := 1
var _cam_snap := true
var state := "ready"
var countdown := COUNTDOWN
var time_left := ROUND_TIME
var winner := -1
var shake := 0.0
var demo := false
var selftest := false
var manual := false
var shot_mode := false
var input_test := false
var cam_shot_mode := false
var round_stats := {"bombs": 0, "explosions": 0, "crates": 0, "kills": 0}

var _t := 0.0
var _sfx_cache := {}
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_idx := 0
var _cam_pos := Vector3(28, 19, 34)


func _ready() -> void:
	_parse_args()
	_register_input()
	add_child(Look.environment())
	Look.lights(self)
	_build_camera()
	hud = Hud3D.new()
	add_child(hud)
	_start_round()
	if selftest:
		_run_selftest.call_deferred()
	elif shot_mode:
		_run_shots.call_deferred()
	elif input_test:
		_run_input_test.call_deferred()
	elif cam_shot_mode:
		_run_cam_shots.call_deferred()


func _parse_args() -> void:
	for a in OS.get_cmdline_user_args():
		if a == "selftest":
			selftest = true
			demo = true
			manual = true
		elif a == "demo":
			demo = true
		elif a == "shot":
			demo = true
			shot_mode = true
		elif a == "camshots":
			demo = true
			cam_shot_mode = true
		elif a == "inputtest":
			manual = false
			input_test = true


func _register_input() -> void:
	var keys := {
		"p1_left": [KEY_A, KEY_LEFT],
		"p1_right": [KEY_D, KEY_RIGHT],
		"p1_up": [KEY_W, KEY_UP],
		"p1_down": [KEY_S, KEY_DOWN],
		"p1_bomb": [KEY_SPACE, KEY_J],
		"restart": [KEY_R],
		"cycle_cam": [KEY_C],
	}
	for action in keys.keys():
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.2)
		InputMap.action_erase_events(action)
		for k in keys[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(action, ev)
	# 手柄：左摇杆 + 十字键 + A
	_joy_motion("p1_left", JOY_AXIS_LEFT_X, -1.0)
	_joy_motion("p1_right", JOY_AXIS_LEFT_X, 1.0)
	_joy_motion("p1_up", JOY_AXIS_LEFT_Y, -1.0)
	_joy_motion("p1_down", JOY_AXIS_LEFT_Y, 1.0)
	_joy_button("p1_left", JOY_BUTTON_DPAD_LEFT)
	_joy_button("p1_right", JOY_BUTTON_DPAD_RIGHT)
	_joy_button("p1_up", JOY_BUTTON_DPAD_UP)
	_joy_button("p1_down", JOY_BUTTON_DPAD_DOWN)
	_joy_button("p1_bomb", JOY_BUTTON_A)
	_joy_button("cycle_cam", JOY_BUTTON_Y)


func _joy_motion(action: String, axis: int, value: float) -> void:
	var ev := InputEventJoypadMotion.new()
	ev.device = 0
	ev.axis = axis as JoyAxis
	ev.axis_value = value
	InputMap.action_add_event(action, ev)


func _joy_button(action: String, button: int) -> void:
	var ev := InputEventJoypadButton.new()
	ev.device = 0
	ev.button_index = button as JoyButton
	InputMap.action_add_event(action, ev)


# ------------------------------------------------------------------ 场景
func _build_camera() -> void:
	cam = Camera3D.new()
	cam.fov = 35.0
	cam.position = _cam_pos
	add_child(cam)
	cam.look_at(Vector3(15, 0.6, 11.5))


func _start_round() -> void:
	if arena_root != null and is_instance_valid(arena_root):
		arena_root.queue_free()
	bombs.clear()
	bombs_by_cell.clear()
	blasts.clear()
	blast_cells.clear()
	powerups.clear()
	grass_nodes.clear()
	grass_flat.clear()
	crate_nodes.clear()
	for h in heroes:
		h.queue_free()
	heroes.clear()
	bots.clear()

	world = TileWorld.new()
	world.gen(20261114 if (selftest or shot_mode) else 20261114 + randi_range(0, 9999))

	arena_root = Node3D.new()
	add_child(arena_root)
	_build_arena()
	_spawn_heroes()

	state = "ready"
	countdown = COUNTDOWN
	time_left = ROUND_TIME
	winner = -1
	round_stats = {"bombs": 0, "explosions": 0, "crates": 0, "kills": 0}
	hud.clear_banner()


func _build_arena() -> void:
	var floor_mat := Look.mat("floor_base", Color(0.075, 0.085, 0.12), 0.55, 0.2)
	Look.box(arena_root, Vector3(TileWorld.COLS * 2.0 + 2.6, 0.5, TileWorld.ROWS * 2.0 + 2.6), Vector3(15, -0.26, 11), floor_mat)
	var tile_a := Look.mat("tile_a", Color(0.115, 0.13, 0.175), 0.62, 0.15)
	var tile_b := Look.mat("tile_b", Color(0.135, 0.15, 0.2), 0.58, 0.15)


	for z in TileWorld.ROWS:
		for x in TileWorld.COLS:
			var c := Vector2i(x, z)
			var p := world.cell_pos(c)
			var m := tile_a if (x + z) % 2 == 0 else tile_b
			var tile := Look.box(arena_root, Vector3(1.94, 0.08, 1.94), p, m)
			tile.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			match world.kind(c):
				TileWorld.Kind.WALL:
					_build_wall(p)
				TileWorld.Kind.CRATE:
					_build_crate(c, p)
				TileWorld.Kind.GRASS:
					_build_grass(c, p)


func _build_wall(p: Vector3) -> void:
	var body := Look.mat("wall", Color(0.13, 0.15, 0.21), 0.42, 0.55)
	var top := Look.mat("wall_top", Color(0.21, 0.24, 0.32), 0.32, 0.6)
	Look.box(arena_root, Vector3(1.96, 1.16, 1.96), p + Vector3(0, 0.58, 0), body)
	Look.box(arena_root, Vector3(1.84, 0.12, 1.84), p + Vector3(0, 1.22, 0), top)


func _build_crate(cell: Vector2i, p: Vector3) -> void:
	var node := Node3D.new()
	node.position = p
	arena_root.add_child(node)
	var h := 1.06
	Look.box(node, Vector3(1.66, h, 1.66), Vector3(0, h * 0.5, 0), Look.mat("wood", Color(0.27, 0.16, 0.085), 0.88))
	Look.box(node, Vector3(1.72, 0.09, 0.1), Vector3(0, h * 0.78, 0.84), Look.mat("band", Color(0.1, 0.09, 0.09), 0.55, 0.65))
	Look.box(node, Vector3(1.72, 0.09, 0.1), Vector3(0, h * 0.22, 0.84), Look.mat("band", Color(0.1, 0.09, 0.09), 0.55, 0.65))
	Look.box(node, Vector3(1.7, 0.05, 1.7), Vector3(0, h + 0.01, 0), Look.mat("wood_top", Color(0.33, 0.2, 0.11), 0.82))
	crate_nodes[cell] = node


func _build_grass(cell: Vector2i, p: Vector3) -> void:
	var palette := [
		Color(0.07, 0.16, 0.08), Color(0.1, 0.22, 0.1),
		Color(0.14, 0.3, 0.13), Color(0.19, 0.38, 0.16),
	]
	var root := Node3D.new()
	root.position = p
	arena_root.add_child(root)
	var r := RandomNumberGenerator.new()
	r.seed = cell.x * 977 + cell.y * 31
	for i in 10:
		var a := r.randf() * TAU
		var rr := r.randf_range(0.15, 0.82)
		var hh := r.randf_range(0.55, 1.1)
		var mat := Look.mat("grass_%d" % r.randi_range(0, 3), palette[r.randi_range(0, 3)], 0.92)
		var blob := Look.sphere(root, r.randf_range(0.32, 0.5), Vector3(cos(a) * rr, hh, sin(a) * rr), mat)
		blob.scale = Vector3(1, r.randf_range(1.5, 2.2), 1)
	for i in 5:
		var a2 := r.randf() * TAU
		var r2 := r.randf_range(0.2, 0.65)
		var blade := Look.cone(root, 0.0, 0.06, r.randf_range(0.5, 0.95), Vector3(cos(a2) * r2, r.randf_range(1.45, 1.8), sin(a2) * r2), Look.mat("grass_blade", Color(0.24, 0.46, 0.2), 0.85))
		blade.rotation_degrees = Vector3(r.randf_range(-14, 14), 0, r.randf_range(-14, 14))
	grass_nodes[cell] = root


func _spawn_heroes() -> void:
	var colors := [
		Color(0.86, 0.24, 0.22), Color(0.24, 0.52, 0.9),
		Color(0.28, 0.74, 0.36), Color(0.94, 0.76, 0.22),
	]
	var names := ["你", "AI 蓝", "AI 绿", "AI 黄"]
	for i in 4:
		var h := Hero3D.new()
		h.setup(i, names[i], colors[i], i != player_index or demo)
		add_child(h)
		h.place_at(TileWorld.SPAWNS[i], world)
		heroes.append(h)
		if h.is_bot:
			var b := Bot3D.new()
			b.setup(h, 1, 1000 + i * 37)
			bots.append(b)
		else:
			bots.append(null)


func player_hero() -> Hero3D:
	return heroes[player_index]


func alive_count() -> int:
	var n := 0
	for h in heroes:
		if h.alive:
			n += 1
	return n


# ------------------------------------------------------------------ 主循环
func _process(delta: float) -> void:
	if manual:
		return
	_step(delta)


func _step(delta: float) -> void:
	_t += delta
	if Input.is_action_just_pressed("restart"):
		_start_round()
		return
	if Input.is_action_just_pressed("cycle_cam"):
		_cycle_camera()

	match state:
		"ready":
			countdown -= delta
			if countdown <= 0.0:
				state = "play"
				hud.show_banner("开始！", Color(1, 0.85, 0.35), 0.6)
			elif int(ceil(countdown)) != int(ceil(countdown + delta)):
				hud.show_banner(str(int(ceil(countdown))), Color(0.95, 0.97, 1.0), 0.5)
				_play_sfx("countdown", -10.0)
		"play":
			time_left -= delta
			_gather_input()
			_tick_bots(delta)
			_tick_heroes(delta)
			_tick_bombs(delta)
			_tick_blasts(delta)
			_check_pickups()
			_check_deaths()
			_check_round_end()
		"over":
			_tick_blasts(delta)
			_tick_heroes(delta)

	_update_hidden()
	_update_camera(delta)
	hud.update_hud(self)


func _gather_input() -> void:
	if demo:
		return
	var h := player_hero()
	if not h.alive:
		return
	var d := Vector2i.ZERO
	if Input.is_action_pressed("p1_left"):
		d = Vector2i.LEFT
	elif Input.is_action_pressed("p1_right"):
		d = Vector2i.RIGHT
	elif Input.is_action_pressed("p1_up"):
		d = Vector2i.UP
	elif Input.is_action_pressed("p1_down"):
		d = Vector2i.DOWN
	h.intent_dir = d
	if Input.is_action_just_pressed("p1_bomb"):
		h.intent_bomb = true


func _tick_bots(delta: float) -> void:
	for i in heroes.size():
		var b = bots[i]
		if b != null and heroes[i].alive:
			b.update(delta, self)


func _tick_heroes(delta: float) -> void:
	for h in heroes:
		if not h.alive:
			continue
		h.step(delta, world, bombs_by_cell)
		if h.intent_bomb:
			h.intent_bomb = false
			_try_bomb(h)


func _try_bomb(h: Hero3D) -> void:
	if h.bombs_out >= h.bombs_max:
		return
	var c := h.current_cell()
	if bombs_by_cell.has(c):
		return
	if world.blocks_move(c):
		return
	var b := Bomb3D.new()
	b.setup(c, h.power, h.index, world)
	add_child(b)
	bombs.append(b)
	bombs_by_cell[c] = b
	h.bombs_out += 1
	h.reveal_until = _t + 1.4
	round_stats["bombs"] += 1
	_make_blast_preview(b, c, h.power)
	_play_sfx("bomb_place", -8.0)


func _tick_bombs(delta: float) -> void:
	var ready: Array[Bomb3D] = []
	for b in bombs:
		if b.exploded:
			continue
		b.tick(delta)
		if b.time_left <= 0.0:
			ready.append(b)
	for b in ready:
		if is_instance_valid(b):
			_explode(b)


func _explode(bomb: Bomb3D) -> void:
	if bomb.exploded:
		return
	bomb.exploded = true
	_clear_preview(bomb)
	bombs_by_cell.erase(bomb.cell)
	if bomb.owner_index >= 0 and bomb.owner_index < heroes.size():
		heroes[bomb.owner_index].bombs_out = maxi(0, heroes[bomb.owner_index].bombs_out - 1)
	var cells := world.blast_cells(bomb.cell, bomb.power)
	for c in cells:
		_spawn_blast(c, c == bomb.cell)
		blast_cells[c] = 0.38
		match world.kind(c):
			TileWorld.Kind.CRATE:
				_destroy_crate(c, bomb.owner_index)
			TileWorld.Kind.GRASS:
				_flatten_grass(c)
	shake = maxf(shake, 0.45)
	_play_sfx("explosion", -5.0)
	round_stats["explosions"] += 1
	bomb.queue_free()
	bombs.erase(bomb)
	for other in bombs:
		if not other.exploded and cells.has(other.cell):
			other.time_left = 0.0
			_explode(other)


func _spawn_blast(c: Vector2i, center: bool) -> void:
	var b := Blast3D.new()
	b.setup(c, world, center)
	add_child(b)
	blasts.append(b)


func _tick_blasts(delta: float) -> void:
	var alive: Array[Blast3D] = []
	for b in blasts:
		if not is_instance_valid(b):
			continue
		b.tick(delta)
		if is_instance_valid(b) and not b.is_queued_for_deletion():
			alive.append(b)
	blasts = alive
	var dead: Array[Vector2i] = []
	for c in blast_cells.keys():
		blast_cells[c] = float(blast_cells[c]) - delta
		if float(blast_cells[c]) <= 0.0:
			dead.append(c)
	for c in dead:
		blast_cells.erase(c)


func _destroy_crate(c: Vector2i, owner: int) -> void:
	if crate_nodes.has(c):
		var node: Node3D = crate_nodes[c]
		crate_nodes.erase(c)
		node.queue_free()
	world.set_kind(c, TileWorld.Kind.FLOOR)
	round_stats["crates"] += 1
	if owner >= 0 and owner < heroes.size():
		heroes[owner].bricks += 1
	# 38% 掉道具
	if randf() < 0.38:
		powerups[c] = randi_range(0, 2)
		_spawn_powerup_visual(c)


func _spawn_powerup_visual(c: Vector2i) -> void:
	var root := Node3D.new()
	root.position = world.cell_pos(c) + Vector3(0, 0.55, 0)
	arena_root.add_child(root)
	var colors := [Color(1.0, 0.72, 0.25), Color(1.0, 0.4, 0.15), Color(0.35, 0.85, 1.0)]
	var kind: int = powerups[c]
	Look.box(root, Vector3(0.44, 0.44, 0.44), Vector3.ZERO, Look.emit("pickup_%d" % kind, colors[kind], 2.4))
	var l := OmniLight3D.new()
	l.light_color = colors[kind]
	l.light_energy = 1.6
	l.omni_range = 4.0
	root.add_child(l)
	_powerup_nodes[c] = root


func _flatten_grass(c: Vector2i) -> void:
	if not grass_nodes.has(c) or grass_flat.has(c):
		return
	grass_flat[c] = _t + 3.0
	world.set_kind(c, TileWorld.Kind.FLOOR)
	var node: Node3D = grass_nodes[c]
	node.scale = Vector3(1.1, 0.22, 1.1)


func _tick_grass() -> void:
	var restore: Array[Vector2i] = []
	for c in grass_flat.keys():
		if _t >= float(grass_flat[c]):
			restore.append(c)
	for c in restore:
		grass_flat.erase(c)
		if grass_nodes.has(c):
			grass_nodes[c].scale = Vector3.ONE
			world.set_kind(c, TileWorld.Kind.GRASS)


func _check_pickups() -> void:
	for h in heroes:
		if not h.alive:
			continue
		var c := h.current_cell()
		if not powerups.has(c):
			continue
		var kind: int = powerups[c]
		powerups.erase(c)
		if _powerup_nodes.has(c):
			_powerup_nodes[c].queue_free()
			_powerup_nodes.erase(c)
		_play_sfx("powerup", -6.0)
		match kind:
			0:
				h.bombs_max = mini(6, h.bombs_max + 1)
			1:
				h.power = mini(6, h.power + 1)
			2:
				h.speed_level = mini(4, h.speed_level + 1)


func _check_deaths() -> void:
	for h in heroes:
		if not h.alive:
			continue
		if blast_cells.has(h.current_cell()):
			h.die()
			_play_sfx("death", -5.0)
			round_stats["kills"] += 1
			shake = maxf(shake, 0.6)


func _check_round_end() -> void:
	if alive_count() <= 1:
		var w := -1
		for h in heroes:
			if h.alive:
				w = h.index
		_finish(w)
		return
	if time_left <= 0.0:
		var best := -1
		var best_bricks := -1
		var tie := false
		for h in heroes:
			if not h.alive:
				continue
			if h.bricks > best_bricks:
				best_bricks = h.bricks
				best = h.index
				tie = false
			elif h.bricks == best_bricks:
				tie = true
		_finish(-1 if tie else best)


func _finish(w: int) -> void:
	state = "over"
	winner = w
	_play_sfx("win" if w == player_index and not demo else "lose", -6.0)
	if w < 0:
		hud.show_banner("平局", Color(0.8, 0.85, 0.95), 99.0)
	elif w == player_index and not demo:
		hud.show_banner("你赢了！", Color(1, 0.85, 0.35), 99.0)
	else:
		hud.show_banner("%s 获胜" % heroes[w].display_name, Color(0.9, 0.6, 0.55), 99.0)


# ------------------------------------------------------------------ 表现
func _update_hidden() -> void:
	for h in heroes:
		if not h.alive:
			continue
		var in_grass := world.kind(h.current_cell()) == TileWorld.Kind.GRASS
		h.hidden = in_grass and _t > h.reveal_until
		if h.hidden:
			h.set_hide_visual("self" if h.index == player_index else "invisible")
		else:
			h.set_hide_visual("none")
	_tick_grass()


func _cycle_camera() -> void:
	cam_mode = (cam_mode + 1) % CAM_NAMES.size()
	_cam_snap = true
	hud.show_banner("视角：%s" % CAM_NAMES[cam_mode], Color(0.6, 0.9, 1.0), 1.4)


func _update_camera(delta: float) -> void:
	var h := player_hero()
	var raw := h.position if h.alive else Vector3(15, 0, 11)
	# 跟随模式下把焦点夹在场地内，避免画面一半是空的
	var follow := Vector3(clampf(raw.x, 8.5, 21.5), raw.y, clampf(raw.z, 7.0, 15.0))
	var center := Vector3(15.0, 0.4, 11.6)
	var cam_center := Vector3(15.0, 0.4, 11.0)

	match cam_mode:
		0:
			# 全场正交，拉近到填满画面：4 人混战最需要“看得全”
			cam.projection = Camera3D.PROJECTION_ORTHOGONAL
			cam.size = 20.5
			cam.position = cam_center + Vector3(23.0, 21.0, 25.0)
			cam.look_at(cam_center, Vector3.UP)
		1:
			# 跟随 + 正交：格子等距，身边约 8 格
			cam.projection = Camera3D.PROJECTION_ORTHOGONAL
			cam.size = 19.0
			if _cam_snap:
				_cam_pos = follow
			_cam_pos = _cam_pos.lerp(follow, minf(1.0, delta * 6.0))
			cam.position = _cam_pos + Vector3(0.0, 23.0, 13.5)
			cam.look_at(_cam_pos + Vector3(0, 2.6, 0.4), Vector3.UP)
		2:
			# 跟随 + 近俯视：遮挡最少
			cam.projection = Camera3D.PROJECTION_ORTHOGONAL
			cam.size = 17.5
			if _cam_snap:
				_cam_pos = follow
			_cam_pos = _cam_pos.lerp(follow, minf(1.0, delta * 6.0))
			cam.position = _cam_pos + Vector3(0.0, 27.0, 5.5)
			cam.look_at(_cam_pos + Vector3(0, 0.4, 0.4), Vector3.UP)
		3:
			# 跟随 + 透视：有纵深，像动作游戏
			cam.projection = Camera3D.PROJECTION_PERSPECTIVE
			cam.fov = 42.0
			if _cam_snap:
				_cam_pos = follow
			_cam_pos = _cam_pos.lerp(follow, minf(1.0, delta * 6.0))
			cam.position = _cam_pos + Vector3(0.0, 16.0, 14.5)
			cam.look_at(_cam_pos + Vector3(0, 0.6, 1.2), Vector3.UP)
		_:
			# 全场透视
			cam.projection = Camera3D.PROJECTION_PERSPECTIVE
			cam.fov = 32.0
			cam.position = Vector3(28.5, 18.5, 37.0)
			cam.look_at(cam_center, Vector3.UP)
	_cam_snap = false

	if shake > 0.0:
		shake = maxf(0.0, shake - delta * 2.2)
		cam.position += Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * shake


# ------------------------------------------------------------------ AI 需要的查询
func has_bomb(c: Vector2i) -> bool:
	return bombs_by_cell.has(c)


func danger_map() -> Dictionary:
	var d := {}
	for b in bombs:
		if b.exploded:
			continue
		for c in world.blast_cells(b.cell, b.power):
			var t := maxf(b.time_left, 0.0)
			if not d.has(c) or float(d[c]) > t:
				d[c] = t
	return d


# ------------------------------------------------------------------ 自测
func _run_selftest() -> void:
	print("=== 3D SELFTEST START ===")
	var frames := 0
	var max_frames := int(300.0 * 60.0)
	while state != "over" and frames < max_frames:
		_step(1.0 / 60.0)
		frames += 1
	print("  模拟 %.1fs  炸弹=%d 爆炸=%d 木箱=%d 击杀=%d 赢家=%d" % [
		frames / 60.0, round_stats["bombs"], round_stats["explosions"],
		round_stats["crates"], round_stats["kills"], winner,
	])
	var ok := true
	if round_stats["bombs"] < 3:
		print("  [FAIL] 炸弹太少"); ok = false
	if round_stats["explosions"] < 2:
		print("  [FAIL] 爆炸太少"); ok = false
	if round_stats["crates"] < 1:
		print("  [FAIL] 没炸掉木箱"); ok = false
	if state != "over":
		print("  [FAIL] 对局没结束"); ok = false
	print("3D SELFTEST ", "PASS" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)


# ------------------------------------------------------------------ 截图
func _run_shots() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots"))
	await get_tree().create_timer(1.4).timeout
	await _capture("g3d_01_start")
	await get_tree().create_timer(3.2).timeout
	await _capture("g3d_02_fight")
	await get_tree().create_timer(4.0).timeout
	await _capture("g3d_03_mid")
	await get_tree().create_timer(5.0).timeout
	await _capture("g3d_04_late")
	print("SHOTS DONE")
	get_tree().quit(0)


func _capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := "res://shots/%s.png" % name
	var err := img.save_png(path)
	print("CAPTURE %s err=%d %dx%d" % [name, err, img.get_width(), img.get_height()])

# ------------------------------------------------------------------ 输入通路自检
func _run_input_test() -> void:
	await get_tree().create_timer(3.6).timeout
	var h := player_hero()
	var start := h.cell
	var key := InputEventKey.new()
	key.physical_keycode = KEY_D
	key.pressed = true
	Input.parse_input_event(key)
	await get_tree().create_timer(0.7).timeout
	var key_up := InputEventKey.new()
	key_up.physical_keycode = KEY_D
	key_up.pressed = false
	Input.parse_input_event(key_up)
	await get_tree().create_timer(0.2).timeout
	var moved := h.cell
	var ok := moved.x > start.x

	var space := InputEventKey.new()
	space.physical_keycode = KEY_SPACE
	space.pressed = true
	Input.parse_input_event(space)
	await get_tree().create_timer(0.15).timeout
	var space_up := InputEventKey.new()
	space_up.physical_keycode = KEY_SPACE
	space_up.pressed = false
	Input.parse_input_event(space_up)
	await get_tree().create_timer(0.2).timeout
	var bomb_ok := bombs.size() > 0

	print("INPUTTEST 移动 %s -> %s (%s) · 放弹 %s" % [start, moved, "OK" if ok else "FAIL", "OK" if bomb_ok else "FAIL"])
	print("3D INPUTTEST ", "PASS" if (ok and bomb_ok) else "FAIL")
	get_tree().quit(0 if (ok and bomb_ok) else 1)

# ------------------------------------------------------------------ 音效
func _play_sfx(name: String, vol: float = -6.0) -> void:
	if not _sfx_cache.has(name):
		var path := "res://assets/audio/%s.wav" % name
		_sfx_cache[name] = load(path) if ResourceLoader.exists(path) else null
	var stream = _sfx_cache[name]
	if stream == null:
		return
	if _sfx_players.is_empty():
		for i in 6:
			var p := AudioStreamPlayer.new()
			add_child(p)
			_sfx_players.append(p)
	var player := _sfx_players[_sfx_idx]
	_sfx_idx = (_sfx_idx + 1) % _sfx_players.size()
	player.stream = stream
	player.volume_db = vol
	player.play()

# ------------------------------------------------------------------ 视角对比截图
func _run_cam_shots() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots"))
	await get_tree().create_timer(5.0).timeout
	manual = true
	for i in CAM_NAMES.size():
		cam_mode = i
		_update_camera(1.0)
		hud.update_hud(self)
		await get_tree().create_timer(0.15).timeout
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.save_png("res://shots/cam_%d.png" % i)
		print("CAMSHOT %d %s" % [i, CAM_NAMES[i]])
	print("CAMSHOTS DONE")
	get_tree().quit(0)

# ------------------------------------------------------------------ 爆炸范围预演
func _make_blast_preview(bomb: Bomb3D, origin: Vector2i, power: int) -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 0.32, 0.2, 0.18)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.3, 0.15)
	mat.emission_energy_multiplier = 0.9
	var nodes: Array[Node3D] = []
	for c in world.blast_cells(origin, power):
		var quad := Look.box(arena_root, Vector3(1.9, 0.02, 1.9), world.cell_pos(c) + Vector3(0, 0.05, 0), mat)
		quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		nodes.append(quad)
	bomb.set_meta("preview", nodes)


func _clear_preview(bomb: Bomb3D) -> void:
	if not is_instance_valid(bomb) or not bomb.has_meta("preview"):
		return
	for n in bomb.get_meta("preview"):
		if is_instance_valid(n):
			n.queue_free()
