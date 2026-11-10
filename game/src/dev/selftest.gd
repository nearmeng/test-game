extends Node
## 无头自测：固定步长跑完整场对战，检查核心规则是否成立。
## 用法: godot --headless --path game -- selftest

var failures: Array[String] = []


func _ready() -> void:
	run.call_deferred()


func check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)
		print("  [FAIL] ", msg)


func run() -> void:
	print("=== SELFTEST START ===")
	if App != null and App.audio != null:
		print("  audio: ", App.audio.loaded_counts())
		print("  save dir: ", App.save.dir, " writable=", App.save.writable)
	for diff in 3:
		await _simulate(diff)
	await _simulate_mode("versus", 1, true)
	await _simulate_mode("duel", 1, false)
	print("=== SELFTEST RESULT ===")
	if failures.is_empty():
		print("SELFTEST PASS")
		get_tree().quit(0)
	else:
		print("SELFTEST FAIL (%d)" % failures.size())
		for f in failures:
			print("  - ", f)
		get_tree().quit(1)


func _simulate_mode(mode: String, difficulty: int, need_bombs: bool) -> void:
	print("-- mode %s --" % mode)
	var battle := Battle.new()
	battle.manual_step = true
	battle.configure({"mode": mode, "difficulty": difficulty, "seed": 9090})
	add_child(battle)
	battle._start_match()

	var dt := 1.0 / 60.0
	var frames := 0
	var max_frames := int(700.0 / dt)
	while battle.state != Battle.State.MATCH_END and frames < max_frames:
		battle._step(dt)
		frames += 1
	print("   sim %.1fs, rounds=%d, bombs=%d, explosions=%d, winner=%d" % [
		frames * dt, battle.round_index, battle.stat_bombs, battle.stat_explosions, battle.match_winner
	])
	check(battle.state == Battle.State.MATCH_END, "[%s] 对战未结束" % mode)
	check(battle.round_index <= Battle.MAX_ROUNDS, "[%s] 局数超限" % mode)
	check(battle.fighters.size() == 4, "[%s] 角色数量异常" % mode)
	if need_bombs:
		check(battle.stat_bombs > 0, "[%s] AI 未放弹" % mode)
	battle.queue_free()
	await get_tree().process_frame


func _simulate(diff: int) -> void:
	print("-- difficulty %d --" % diff)
	var battle := Battle.new()
	battle.manual_step = true
	battle.configure({"mode": "single", "difficulty": diff, "seed": 4242 + diff})
	add_child(battle)
	battle._start_match()

	var dt := 1.0 / 60.0
	var frames := 0
	var max_frames := int(400.0 / dt)
	var saw_explosion := false
	var round_seen := 1
	var max_bombs := 0

	while battle.state != Battle.State.MATCH_END and frames < max_frames:
		battle._step(dt)
		frames += 1
		max_bombs = maxi(max_bombs, battle.bombs.size())
		if battle.stat_explosions > 0:
			saw_explosion = true
		round_seen = maxi(round_seen, battle.round_index)
		# 位置合法性
		if frames % 600 == 0:
			for f in battle.fighters:
				check(battle.arena.in_bounds(f.cell), "角色越界 %s" % f.cell)

	var secs := frames * dt
	print("   sim %.1fs, rounds=%d, bombs=%d, explosions=%d, crates=%d, winner=%d" % [
		secs, battle.round_index, battle.stat_bombs, battle.stat_explosions, battle.stat_crates, battle.match_winner
	])
	check(saw_explosion, "整场没有任何爆炸（AI 没放弹？）")
	check(battle.stat_bombs >= 3, "炸弹数量过少：%d" % battle.stat_bombs)
	check(battle.stat_crates >= 2, "木箱破坏过少：%d" % battle.stat_crates)
	check(battle.state == Battle.State.MATCH_END, "对战未在 400 秒内结束")
	check(battle.round_index <= Battle.MAX_ROUNDS, "局数超出上限：%d" % battle.round_index)
	check(battle.wins.max() >= Battle.WINS_NEEDED or battle.round_index == Battle.MAX_ROUNDS, "没有产生冠军")
	check(battle.alive_indices().size() <= 1 or battle.state == Battle.State.MATCH_END, "结束时有多个存活角色")
	check(battle.stat_bombs >= 3 and max_bombs > 0, "炸弹峰值异常")

	battle.queue_free()
	await get_tree().process_frame
