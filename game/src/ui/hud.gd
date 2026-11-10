class_name Hud
extends CanvasLayer
## 战斗界面：玩家信息条、计时、比分、提示横幅、暂停与结算。

var battle: Battle
var on_resume: Callable
var on_restart: Callable
var on_menu: Callable
var on_rematch: Callable
var on_settings: Callable

var cards: Array[Dictionary] = []
var _timer_label: Label
var _time_bar: ProgressBar
var _alive_label: Label
var _pad_label: Label
var _round_label: Label
var _score_box: VBoxContainer
var _banner: Label
var _banner_tween: Tween
var _count_label: Label
var _pause_root: Control
var _result_root: Control
var _result_title: Label
var _result_score: Label
var _result_grid: GridContainer
var _hint_label: Label
var _hint_timer := 0.0
var _result_shown := false
var _last_banner_round := -1


func setup(p_battle: Battle, callbacks: Dictionary) -> void:
	battle = p_battle
	on_resume = callbacks.get("resume", Callable())
	on_restart = callbacks.get("restart", Callable())
	on_menu = callbacks.get("menu", Callable())
	on_rematch = callbacks.get("rematch", Callable())
	on_settings = callbacks.get("settings", Callable())


func _ready() -> void:
	layer = 10
	_build()


func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.size = Pal.VIEW
	root.theme = App.theme
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# --- 玩家卡片 ---
	for i in 4:
		var card := PanelContainer.new()
		card.position = Vector2(18 + i * 311, 10)
		card.size = Vector2(300, 92)
		var sb := UiKit.box(Pal.PANEL, Pal.LINE_SOFT, 12, 2)
		card.add_theme_stylebox_override("panel", sb)
		root.add_child(card)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		card.add_child(row)

		var chip := ColorRect.new()
		chip.color = Pal.P_COLORS[i]
		chip.custom_minimum_size = Vector2(8, 60)
		row.add_child(chip)

		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 0)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(col)

		var name_label := UiKit.label("玩家", 18, Pal.TEXT)
		col.add_child(name_label)
		var sub := UiKit.label("", 11, Pal.TEXT_DIM)
		col.add_child(sub)
		var power := UiKit.label("", 12, Color("8fa0c8"))
		col.add_child(power)
		var stats := UiKit.label("", 12, Pal.TEXT_DIM)
		col.add_child(stats)

		var wins := UiKit.label("○ ○", 16, Pal.AMBER)
		wins.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		wins.custom_minimum_size = Vector2(64, 0)
		row.add_child(wins)

		cards.append({
			"card": card, "name": name_label, "sub": sub, "stats": stats, "wins": wins,
			"chip": chip, "power": power,
		})

	# --- 左侧信息面板 ---
	var left := PanelContainer.new()
	left.position = Vector2(16, 108)
	left.size = Vector2(248, 524)
	root.add_child(left)
	var lm := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		lm.add_theme_constant_override("margin_" + side, 16)
	left.add_child(lm)
	var lbox := VBoxContainer.new()
	lbox.add_theme_constant_override("separation", 6)
	lm.add_child(lbox)

	_round_label = UiKit.label("第 1 局 / 共 3 局", 17, Pal.AMBER)
	lbox.add_child(_round_label)
	_timer_label = UiKit.label("01:50", 46, Pal.TEXT)
	lbox.add_child(_timer_label)
	_time_bar = ProgressBar.new()
	_time_bar.max_value = 1.0
	_time_bar.value = 1.0
	_time_bar.show_percentage = false
	_time_bar.custom_minimum_size = Vector2(210, 8)
	lbox.add_child(_time_bar)
	_alive_label = UiKit.label("存活 4 / 4", 13, Pal.TEXT_DIM)
	lbox.add_child(_alive_label)
	lbox.add_child(UiKit.hsep(Pal.LINE_SOFT, 4))
	lbox.add_child(UiKit.label("比分", 13, Pal.TEXT_DIM))
	_score_box = VBoxContainer.new()
	_score_box.add_theme_constant_override("separation", 4)
	lbox.add_child(_score_box)
	var fill := Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lbox.add_child(fill)
	lbox.add_child(UiKit.hsep(Pal.LINE_SOFT, 2))
	_hint_label = UiKit.label("按 Esc 暂停", 12, Color("6a7290"))
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_label.custom_minimum_size = Vector2(210, 0)
	lbox.add_child(_hint_label)

	# --- 右侧道具说明 ---
	var right := PanelContainer.new()
	right.position = Vector2(1016, 108)
	right.size = Vector2(248, 524)
	root.add_child(right)
	var rm := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		rm.add_theme_constant_override("margin_" + side, 16)
	right.add_child(rm)
	var rbox := VBoxContainer.new()
	rbox.add_theme_constant_override("separation", 8)
	rm.add_child(rbox)
	rbox.add_child(UiKit.label("道具", 17, Pal.AMBER))
	var legend := [
		[0, "炸弹 +1", "同时放置上限提升"],
		[1, "火力 +1", "爆炸延伸更远"],
		[2, "速度 +1", "移动更快"],
		[3, "护盾 5s", "免疫一次爆炸"],
	]
	for item in legend:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var icon := TextureRect.new()
		icon.texture = Art.icon_atlas(item[0])
		icon.custom_minimum_size = Vector2(26, 26)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		row.add_child(icon)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 0)
		v.add_child(UiKit.label(item[1], 14, Pal.TEXT))
		v.add_child(UiKit.label(item[2], 11, Pal.TEXT_DIM))
		row.add_child(v)
		rbox.add_child(row)
	rbox.add_child(UiKit.hsep(Pal.LINE_SOFT, 4))
	rbox.add_child(UiKit.label("操作", 15, Pal.AMBER))
	var ctrl := UiKit.label("P1  WASD / 手柄    空格 / A 放弹\nP2  方向键 / 2 号手柄    回车放弹\nEsc / START 暂停    R 重开本局", 12, Pal.TEXT_DIM)
	ctrl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ctrl.custom_minimum_size = Vector2(210, 0)
	rbox.add_child(ctrl)
	_pad_label = UiKit.label("手柄：检测中…", 11, Color("6a7290"))
	_pad_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_pad_label.custom_minimum_size = Vector2(210, 0)
	rbox.add_child(_pad_label)

	# --- 横幅 ---
	_banner = UiKit.shadowed("", 40, Pal.AMBER, 14)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.position = Vector2(280, 640)
	_banner.size = Vector2(720, 64)
	_banner.modulate = Color(1, 1, 1, 0)
	root.add_child(_banner)

	# --- 倒计时 ---
	_count_label = UiKit.shadowed("", 120, Pal.TEXT, 18)
	_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_count_label.position = Vector2(280, 200)
	_count_label.size = Vector2(720, 260)
	_count_label.pivot_offset = Vector2(360, 130)
	_count_label.modulate = Color(1, 1, 1, 0)
	root.add_child(_count_label)

	_build_pause(root)
	_build_result(root)


func _build_pause(root: Control) -> void:
	_pause_root = Control.new()
	_pause_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_root.size = Pal.VIEW
	_pause_root.visible = false
	_pause_root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(_pause_root)

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.04, 0.7)
	dim.size = Pal.VIEW
	_pause_root.add_child(dim)

	var panel := PanelContainer.new()
	panel.position = Vector2(410, 170)
	panel.size = Vector2(460, 380)
	_pause_root.add_child(panel)
	var m := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 26)
	panel.add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	m.add_child(v)
	var t := UiKit.label("已暂停", 34, Pal.AMBER)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	v.add_child(UiKit.hsep(Pal.LINE_SOFT, 4))
	var resume := UiKit.button("继续战斗", 20)
	resume.pressed.connect(func() -> void:
		if on_resume.is_valid():
			on_resume.call()
	)
	v.add_child(resume)
	var settings := UiKit.button("设置", 20)
	settings.pressed.connect(func() -> void:
		if on_settings.is_valid():
			on_settings.call()
	)
	v.add_child(settings)
	var restart := UiKit.button("重开本局", 20)
	restart.pressed.connect(func() -> void:
		if on_restart.is_valid():
			on_restart.call()
	)
	v.add_child(restart)
	var quit := UiKit.button("返回菜单", 20)
	quit.pressed.connect(func() -> void:
		if on_menu.is_valid():
			on_menu.call()
	)
	v.add_child(quit)
	resume.grab_focus.call_deferred()


func _build_result(root: Control) -> void:
	_result_root = Control.new()
	_result_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_result_root.size = Pal.VIEW
	_result_root.visible = false
	_result_root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(_result_root)

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.04, 0.78)
	dim.size = Pal.VIEW
	_result_root.add_child(dim)

	var panel := PanelContainer.new()
	panel.position = Vector2(340, 120)
	panel.size = Vector2(600, 480)
	_result_root.add_child(panel)
	var m := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 28)
	panel.add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	m.add_child(v)
	_result_title = UiKit.label("", 40, Pal.AMBER)
	_result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_result_title)
	v.add_child(UiKit.hsep(Pal.LINE_SOFT, 4))
	_result_score = UiKit.label("", 18, Pal.TEXT)
	_result_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_result_score)
	var grid_wrap := MarginContainer.new()
	grid_wrap.add_theme_constant_override("margin_left", 46)
	grid_wrap.add_theme_constant_override("margin_right", 46)
	v.add_child(grid_wrap)
	_result_grid = GridContainer.new()
	_result_grid.columns = 5
	_result_grid.add_theme_constant_override("h_separation", 10)
	_result_grid.add_theme_constant_override("v_separation", 8)
	grid_wrap.add_child(_result_grid)
	var rematch := UiKit.button("再来一场", 20)
	rematch.pressed.connect(func() -> void:
		if on_rematch.is_valid():
			on_rematch.call()
	)
	v.add_child(rematch)
	var menu := UiKit.button("返回菜单", 20)
	menu.pressed.connect(func() -> void:
		if on_menu.is_valid():
			on_menu.call()
	)
	v.add_child(menu)


func _process(delta: float) -> void:
	if battle == null:
		return
	_sync_cards()
	_sync_round_panel()
	_sync_countdown(delta)
	_sync_state()
	if _pad_label != null and App != null:
		_pad_label.text = App.pad_status_text()
	if _banner.modulate.a > 0.0 and _banner_tween == null:
		pass


func _sync_cards() -> void:
	for i in cards.size():
		var c := cards[i]
		var f: Fighter = battle.fighters[i]
		var sub: String = "AI · " + App.difficulty_names[battle.difficulty] if f.is_bot else "玩家"
		if battle.human_indices.size() == 1 and not f.is_bot:
			sub = "你"
		c["name"].text = f.display_name
		c["sub"].text = sub
		c["power"].text = "炸弹 %d   火力 %d   速度 %d" % [f.bombs_max, f.power, f.speed_level]
		c["stats"].text = "砖块 %d   击杀 %d" % [f.bricks, f.kills]
		var dots := ""
		for w in Battle.WINS_NEEDED:
			dots += "●" if battle.wins[i] > w else "○"
			if w < Battle.WINS_NEEDED - 1:
				dots += " "
		c["wins"].text = dots
		if not f.alive:
			c["name"].modulate = Color(1, 1, 1, 0.4)
			c["stats"].text = "已出局"
			c["stats"].modulate = Color(1, 0.4, 0.4, 0.9)
			c["power"].modulate = Color(1, 1, 1, 0.25)
			c["chip"].color = Pal.P_COLORS[i].darkened(0.55)
		else:
			c["name"].modulate = Color(1, 1, 1, 1)
			c["stats"].modulate = Color(1, 1, 1, 1)
			c["power"].modulate = Color(1, 1, 1, 1)
			c["chip"].color = Pal.P_COLORS[i]


func _sync_round_panel() -> void:
	_round_label.text = "第 %d 局 / 共 %d 局" % [maxi(battle.round_index, 1), Battle.MAX_ROUNDS]
	var t := maxf(battle.time_left, 0.0)
	_timer_label.text = "%02d:%02d" % [int(t) / 60, int(t) % 60]
	if battle.state == Battle.State.COUNTDOWN:
		_timer_label.text = "00:%02d" % int(ceil(battle.countdown_left))
	_timer_label.add_theme_color_override("font_color", Pal.TEXT_WARN if t < 20.0 else Pal.TEXT)
	if _time_bar != null:
		_time_bar.value = clampf(battle.time_left / Battle.ROUND_TIME, 0.0, 1.0)
		_time_bar.modulate = Color(1, 0.55, 0.35) if t < 20.0 else Color(1, 1, 1, 1)
	if _alive_label != null:
		var alive_count := battle.alive_indices().size()
		var text := "存活 %d / %d" % [alive_count, battle.fighters.size()]
		if not battle.human_indices.is_empty() and battle.state == Battle.State.PLAYING:
			var any_human_alive := false
			for hi in battle.human_indices:
				if battle.fighters[hi].alive:
					any_human_alive = true
			if not any_human_alive:
				text += "   观战中（R 重开本局）"
		_alive_label.text = text

	var children := _score_box.get_children()
	for child in children:
		child.queue_free()
	for i in 4:
		var f: Fighter = battle.fighters[i]
		var row := HBoxContainer.new()
		var name_l := UiKit.label(f.display_name, 13, Pal.P_COLORS[i])
		name_l.custom_minimum_size = Vector2(120, 0)
		row.add_child(name_l)
		var wins_l := UiKit.label("%d 胜" % battle.wins[i], 13, Pal.TEXT)
		row.add_child(wins_l)
		_score_box.add_child(row)


func _sync_countdown(_delta: float) -> void:
	if battle.state == Battle.State.COUNTDOWN:
		var n := int(ceil(battle.countdown_left))
		_count_label.text = "GO!" if n <= 0 else str(n)
		_count_label.modulate.a = 1.0
		_count_label.scale = Vector2.ONE * (1.0 + 0.2 * (ceil(battle.countdown_left) - battle.countdown_left))
	elif _count_label.modulate.a > 0.0:
		_count_label.modulate.a = maxf(0.0, _count_label.modulate.a - 0.08)
		_count_label.scale = Vector2.ONE


func _sync_state() -> void:
	# 暂停面板
	var want_pause: bool = battle.paused
	if _pause_root.visible != want_pause:
		_pause_root.visible = want_pause

	# 回合结束横幅
	if battle.state == Battle.State.ROUND_END and _last_banner_round != battle.round_index:
		_last_banner_round = battle.round_index
		var w := battle.last_round_winner
		if w >= 0:
			show_banner("%s 赢下本局" % battle.fighters[w].display_name, Pal.P_COLORS[w])
		else:
			show_banner("平局", Pal.TEXT_DIM)

	# 整场结束
	if battle.state == Battle.State.MATCH_END and not _result_shown:
		_result_shown = true
		_banner.modulate.a = 0.0
		_show_match_result()


func show_banner(text: String, color: Color = Pal.AMBER) -> void:
	if _banner == null:
		return
	_banner.text = text
	_banner.add_theme_color_override("font_color", color)
	_banner.modulate = Color(1, 1, 1, 1)
	_banner.scale = Vector2(1.2, 1.2)
	_banner.pivot_offset = _banner.size * 0.5
	if _banner_tween != null and _banner_tween.is_valid():
		_banner_tween.kill()
	_banner_tween = create_tween()
	_banner_tween.set_parallel(true)
	_banner_tween.tween_property(_banner, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_banner_tween.tween_property(_banner, "modulate:a", 0.0, 1.4).set_delay(1.0)
	_banner_tween.chain().tween_callback(func() -> void:
		_banner_tween = null
	)


func _show_match_result() -> void:
	var w := battle.match_winner
	_result_root.visible = true
	if w < 0:
		_result_title.text = "平局"
		_result_title.add_theme_color_override("font_color", Pal.TEXT_DIM)
	else:
		var f: Fighter = battle.fighters[w]
		var is_player := not f.is_bot
		_result_title.text = ("你赢了！" if is_player else "%s 获胜" % f.display_name)
		_result_title.add_theme_color_override("font_color", Pal.P_COLORS[w])

	var lines: Array[String] = []
	_result_score.text = "比分   %d : %d : %d : %d" % [battle.wins[0], battle.wins[1], battle.wins[2], battle.wins[3]]
	for child in _result_grid.get_children():
		child.queue_free()
	for h in ["角色", "胜局", "砖块", "击杀", "存活"]:
		var hl := UiKit.label(h, 13, Pal.TEXT_DIM)
		hl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hl.custom_minimum_size = Vector2(96, 0)
		_result_grid.add_child(hl)
	for i in 4:
		var f: Fighter = battle.fighters[i]
		var name_l := UiKit.label(f.display_name, 16, Pal.P_COLORS[i])
		name_l.custom_minimum_size = Vector2(96, 0)
		_result_grid.add_child(name_l)
		for value in [str(battle.wins[i]), str(f.bricks), str(f.kills)]:
			var vl := UiKit.label(value, 16, Pal.TEXT)
			vl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			vl.custom_minimum_size = Vector2(96, 0)
			_result_grid.add_child(vl)
		var alive_l := UiKit.label("是" if f.alive else "否", 16, Pal.LIME if f.alive else Pal.TEXT_DIM)
		alive_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		alive_l.custom_minimum_size = Vector2(96, 0)
		_result_grid.add_child(alive_l)

	# 记录战绩
	if w >= 0 and not battle.fighters[w].is_bot:
		App.save.record_win(0, battle.fighters[w].kills)
	elif w >= 0:
		App.save.record_loss(0)
	else:
		App.save.record_draw()
	App.save.record_rounds(battle.round_index)
	App.audio.play_sfx("win" if w >= 0 and not battle.fighters[w].is_bot else "lose", -2.0)


func hide_result() -> void:
	_result_shown = false
	_result_root.visible = false
	if _banner != null:
		_banner.modulate.a = 0.0
