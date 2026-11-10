extends Node
## 无头验证手柄支持：先查映射表，再注入虚拟手柄事件，确认角色真的动了、真的放了弹。
## 用法: godot --headless --path game -- padtest

var failures: Array[String] = []


func _ready() -> void:
	run.call_deferred()


func check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)
		print("  [FAIL] ", msg)


func _axis(device: int, axis: int, value: float) -> void:
	var ev := InputEventJoypadMotion.new()
	ev.device = device
	ev.axis = axis as JoyAxis
	ev.axis_value = value
	Input.parse_input_event(ev)


func _button(device: int, button: int, pressed: bool) -> void:
	var ev := InputEventJoypadButton.new()
	ev.device = device
	ev.button_index = button as JoyButton
	ev.pressed = pressed
	ev.pressure = 1.0 if pressed else 0.0
	Input.parse_input_event(ev)


func run() -> void:
	print("=== PADPROBE START ===")
	_mapping_checks()
	await _functional_checks()
	print("=== PADPROBE RESULT ===")
	if failures.is_empty():
		print("PADPROBE PASS")
		get_tree().quit(0)
	else:
		print("PADPROBE FAIL (%d)" % failures.size())
		get_tree().quit(1)


func _joy_events(action: String) -> Array:
	var out := []
	for ev in InputMap.action_get_events(action):
		if ev is InputEventJoypadMotion or ev is InputEventJoypadButton:
			out.append(ev)
	return out


func _mapping_checks() -> void:
	var motion_actions := ["p1_left", "p1_right", "p1_up", "p1_down", "p2_left", "p2_right", "p2_up", "p2_down"]
	var button_actions := ["p1_bomb", "p2_bomb", "pause"]
	for a in motion_actions:
		var ok := false
		for ev in _joy_events(a):
			if ev is InputEventJoypadMotion:
				ok = true
		check(ok, "%s 缺少摇杆绑定" % a)
	for a in button_actions:
		var ok := false
		for ev in _joy_events(a):
			if ev is InputEventJoypadButton:
				ok = true
		check(ok, "%s 缺少手柄按键绑定" % a)
	# 设备隔离：P1 的按键只接受 0 号手柄，P2 只接受 1 号
	for action in ["p1_bomb", "p2_bomb"]:
		var want := 0 if action.begins_with("p1") else 1
		for ev in _joy_events(action):
			if ev is InputEventJoypadButton:
				check(ev.device == want, "%s 的设备号是 %d，应为 %d" % [action, ev.device, want])
	# START 应该对任意手柄生效
	var pause_any := false
	for ev in _joy_events("pause"):
		if ev is InputEventJoypadButton and ev.device == -1:
			pause_any = true
	check(pause_any, "pause 没有绑定“任意手柄 START”")
	# 引擎内置的 ui_accept / ui_cancel 原本不带手柄，App 里应已补上
	for a in ["ui_accept", "ui_cancel"]:
		check(_joy_events(a).size() > 0, "%s 没有手柄绑定，菜单只能选不能确认" % a)
	print("  映射检查完成，手柄绑定数：p1=%d p2=%d ui_accept=%d" % [
		_joy_events("p1_bomb").size(), _joy_events("p2_bomb").size(), _joy_events("ui_accept").size()
	])


func _functional_checks() -> void:
	# duel 模式 = 两名真人、无 AI，避免 AI 干扰判定
	var battle := Battle.new()
	battle.configure({"mode": "duel", "difficulty": 0, "seed": 31337})
	add_child(battle)

	var guard := 0
	while battle.state != Battle.State.PLAYING and guard < 900:
		await get_tree().process_frame
		guard += 1
	check(battle.state == Battle.State.PLAYING, "还没进入战斗状态")

	# 清出一条向右的通道，避免木箱挡住导致误判
	for x in range(2, 7):
		var c := Vector2i(x, 1)
		battle.arena.kinds[battle.arena.idx(c)] = Arena.Kind.FLOOR

	var fighter := battle.fighters[0]
	var start_cell := fighter.cell

	_axis(0, JOY_AXIS_LEFT_X, 1.0)
	await _wait(0.5)
	var moved_cell := fighter.cell
	_axis(0, JOY_AXIS_LEFT_X, 0.0)
	await _wait(0.2)
	check(moved_cell.x > start_cell.x, "1 号手柄右推没有让人物右移（%s → %s）" % [start_cell, moved_cell])

	var bombs_before := battle.bombs.size()
	_button(0, JOY_BUTTON_A, true)
	await _wait(0.15)
	_button(0, JOY_BUTTON_A, false)
	await _wait(0.2)
	check(battle.bombs.size() > bombs_before, "1 号手柄 A 键没有放下炸弹")

	# 设备隔离：2 号手柄不该驱动 1 号玩家
	var p1_intent := fighter.intent_dir
	_axis(1, JOY_AXIS_LEFT_X, 1.0)
	await _wait(0.25)
	var p2 := battle.fighters[1]
	check(fighter.intent_dir == Vector2i.ZERO or fighter.intent_dir == p1_intent,
		"2 号手柄串到了 1 号玩家（intent=%s）" % fighter.intent_dir)
	check(p2.intent_dir == Vector2i.RIGHT, "2 号手柄没有驱动 2 号玩家（intent=%s）" % p2.intent_dir)
	_axis(1, JOY_AXIS_LEFT_X, 0.0)
	await _wait(0.2)

	# 菜单：聚焦的按钮应能被 A 键确认
	var fired := [false]
	var btn := Button.new()
	btn.text = "pad-confirm"
	btn.pressed.connect(func() -> void: fired[0] = true)
	add_child(btn)
	btn.grab_focus()
	await _wait(0.15)
	_button(0, JOY_BUTTON_A, true)
	await _wait(0.08)
	_button(0, JOY_BUTTON_A, false)
	await _wait(0.15)
	check(fired[0], "聚焦按钮没有被手柄 A 键确认")
	btn.queue_free()

	print("  功能检查完成：移动 %s → %s，炸弹 %d → %d" % [start_cell, moved_cell, bombs_before, battle.bombs.size()])
	battle.queue_free()
	await get_tree().process_frame


func _wait(seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		await get_tree().process_frame
		t += get_process_delta_time()
