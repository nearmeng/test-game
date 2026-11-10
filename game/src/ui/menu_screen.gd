class_name MenuScreen
extends Control
## 主菜单：模式选择、难度、玩法说明、设置入口。

signal open_settings

const CARD_W := 300.0

var _title: Label
var _deco: Array[Dictionary] = []
var _t := 0.0
var _tip_index := 0
var _tip_label: Label
var _tip_timer := 0.0
var _difficulty_buttons: Array[Button] = []
var _settings_panel: Node = null

const TIPS := [
	"炸掉木箱有概率掉落强化道具，先手抢到炸弹数很关键。",
	"贴着木箱放弹后立刻后撤，爆炸会沿直线延伸 1 格以上。",
	"连锁引信：被爆炸扫到的炸弹会立刻引爆，慎走弹链。",
	"护盾可以硬吃一次爆炸，但不会帮你挡住自己的失误。",
	"对手被逼到角落时，优先封住他的逃生路线而不是直接炸。",
	"三局两胜：赢了第一局也别浪，第二局对手会更凶。",
]


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	size = Pal.VIEW
	theme = App.theme
	mouse_filter = Control.MOUSE_FILTER_PASS
	_build()


func _build() -> void:
	# --- 背景 ---
	var bg := ColorRect.new()
	bg.color = Pal.BG_DEEP
	_place(bg, Rect2(Vector2.ZERO, Pal.VIEW))

	var backdrop := TextureRect.new()
	backdrop.texture = Art.tex("backdrop")
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_SCALE
	backdrop.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	backdrop.modulate = Color(1, 1, 1, 0.55)
	_place(backdrop, Rect2(Vector2.ZERO, Pal.VIEW))

	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	grad.colors = PackedColorArray([Color(0.05, 0.05, 0.09, 0.1), Color(0.05, 0.05, 0.09, 0.75), Color(0.03, 0.03, 0.06, 1.0)])
	var grow := GradientTexture2D.new()
	grow.gradient = grad
	grow.width = 8
	grow.height = 256
	grow.fill_from = Vector2(0, 0)
	grow.fill_to = Vector2(0, 1)
	var grad_rect := TextureRect.new()
	grad_rect.texture = grow
	grad_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	grad_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_place(grad_rect, Rect2(Vector2.ZERO, Pal.VIEW))

	# --- 漂浮装饰 ---
	var deco_pos := [
		Vector2(120, 520), Vector2(1080, 470), Vector2(210, 210), Vector2(1010, 190),
	]
	for i in deco_pos.size():
		var s := Sprite2D.new()
		s.texture = Art.tex("bomb")
		s.hframes = 4
		s.frame = i % 4
		s.scale = Vector2(3, 3)
		s.position = deco_pos[i]
		s.modulate = Color(1, 1, 1, 0.28)
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(s)
		_deco.append({"node": s, "base": deco_pos[i], "phase": i * 1.7, "frame_t": 0.0})

	# --- 标题 ---
	_title = UiKit.shadowed("火拼炸弹堂", 88, Pal.AMBER, 16)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_place(_title, Rect2(0, 46, 1280, 112))

	var sub := UiKit.label("B O M B   B L I T Z   A R E N A", 17, Pal.TEXT_DIM)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(sub, Rect2(0, 158, 1280, 26))

	var rule := ColorRect.new()
	rule.color = Pal.LINE
	_place(rule, Rect2(540, 196, 200, 2))

	var tag := UiKit.label("三局两胜 · 1–4 名玩家 · 原创像素竞技", 16, Pal.TEXT_DIM)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(tag, Rect2(0, 206, 1280, 24))

	# --- 难度 ---
	var diff_row := HBoxContainer.new()
	diff_row.add_theme_constant_override("separation", 8)
	diff_row.alignment = BoxContainer.ALIGNMENT_CENTER
	var diff_label := UiKit.label("难度", 16, Pal.TEXT_DIM)
	diff_label.custom_minimum_size = Vector2(48, 40)
	diff_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	diff_row.add_child(diff_label)
	var names := ["简单", "普通", "困难"]
	for i in 3:
		var b := UiKit.button(names[i], 16)
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(86, 40)
		b.focus_mode = Control.FOCUS_ALL
		b.set_meta("idx", i)
		b.pressed.connect(_on_difficulty.bind(i))
		diff_row.add_child(b)
		_difficulty_buttons.append(b)
	_place(diff_row, Rect2(490, 246, 300, 40))

	# --- 主按钮 ---
	var entries := [
		["单人闯关", "1 名玩家 · 3 名 AI 对手", Callable(self, "_start").bind("single")],
		["双人同屏", "2 名玩家 · 2 名 AI 对手", Callable(self, "_start").bind("versus")],
		["双人对战", "2 名玩家 · 单挑", Callable(self, "_start").bind("duel")],
		["设置", "音量 · 画面 · 手感", Callable(self, "_on_settings")],
		["退出", "离开游戏", Callable(self, "_on_quit")],
	]
	var y := 296.0
	var desc_label := UiKit.label("选择模式后开始对战", 15, Pal.TEXT_DIM)
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for entry in entries:
		var b := UiKit.button(entry[0], 24)
		b.custom_minimum_size = Vector2(360, 52)
		_place(b, Rect2(460, y, 360, 52))
		b.pressed.connect(entry[2])
		b.set_meta("desc", entry[1])
		var desc: String = entry[1]
		b.focus_entered.connect(func() -> void:
			desc_label.text = desc
		)
		b.mouse_entered.connect(func() -> void:
			desc_label.text = desc
		)
		y += 66.0
	_place(desc_label, Rect2(0, 632, 1280, 24))

	# --- 左侧提示卡 ---
	var tip_card := PanelContainer.new()
	_place(tip_card, Rect2(40, 300, CARD_W, 250))
	var tip_margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		tip_margin.add_theme_constant_override("margin_" + side, 18)
	tip_card.add_child(tip_margin)
	var tip_box := VBoxContainer.new()
	tip_box.add_theme_constant_override("separation", 10)
	tip_margin.add_child(tip_box)
	tip_box.add_child(UiKit.label("攻略提示", 15, Pal.AMBER))
	_tip_label = UiKit.label(TIPS[0], 15, Pal.TEXT)
	_tip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip_label.custom_minimum_size = Vector2(CARD_W - 36, 96)
	tip_box.add_child(_tip_label)
	var stat := UiKit.label(_profile_line(), 14, Pal.TEXT_DIM)
	stat.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip_box.add_child(stat)
	var diff_hint := UiKit.label("难度影响 AI 的反应速度与放弹积极性。", 12, Color("6a7290"))
	diff_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip_box.add_child(diff_hint)

	# --- 右侧规则卡 ---
	var rule_card := PanelContainer.new()
	_place(rule_card, Rect2(940, 300, CARD_W, 250))
	var rm := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		rm.add_theme_constant_override("margin_" + side, 18)
	rule_card.add_child(rm)
	var rb := VBoxContainer.new()
	rb.add_theme_constant_override("separation", 8)
	rm.add_child(rb)
	rb.add_child(UiKit.label("玩法", 15, Pal.AMBER))
	for line in [
		"· 炸开木箱，抢在对手前吃到道具",
		"· 用炸弹把对手逼进死角",
		"· 被炸到即出局，最后一人获胜",
		"· 先赢两局者拿下整场",
	]:
		var l := UiKit.label(line, 14, Pal.TEXT)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(CARD_W - 36, 0)
		rb.add_child(l)

	# --- 页脚 ---
	var version := UiKit.label("v%s  ·  Godot 4.7" % str(ProjectSettings.get_setting("application/config/version", "1.0.0")), 13, Pal.TEXT_DIM)
	_place(version, Rect2(32, 690, 400, 20))

	var controls := UiKit.label("WASD / 方向键 / 手柄 移动    空格 / 回车 / A 放弹    Esc / START 暂停    F11 全屏", 13, Pal.TEXT_DIM)
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(controls, Rect2(0, 690, 1280, 20))

	var save_hint := UiKit.label("存档：%s" % _save_dir_text(), 12, Color("5a6180"))
	save_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_place(save_hint, Rect2(880, 690, 380, 20))

	_refresh_difficulty()
	_first_button_focus.call_deferred()


func _save_dir_text() -> String:
	var d := App.save.dir
	if d.begins_with("user:"):
		return "系统用户目录"
	if d.begins_with("res:"):
		return "游戏目录/userdata"
	return d


func _profile_line() -> String:
	var p := App.save.profile
	return "战绩 %d 胜 / %d 负 / %d 平   最高连胜 %d" % [
		int(p["wins"]), int(p["losses"]), int(p["draws"]), int(p["best_streak"])
	]


func _place(node: Control, rect: Rect2) -> void:
	node.position = rect.position
	node.size = rect.size
	add_child(node)


func _first_button_focus() -> void:
	for child in get_children():
		if child is Button and child.text == "单人闯关":
			child.grab_focus()
			return


func _refresh_difficulty() -> void:
	var d := App.difficulty()
	for i in _difficulty_buttons.size():
		_difficulty_buttons[i].button_pressed = (i == d)


func _on_difficulty(idx: int) -> void:
	App.set_difficulty(idx)
	_refresh_difficulty()


func _start(mode: String) -> void:
	var config := {
		"mode": mode,
		"difficulty": App.difficulty(),
	}
	var main := get_tree().current_scene
	if main != null and main.has_method("start_battle"):
		main.start_battle(config)


func _on_settings() -> void:
	if _settings_panel != null:
		return
	_settings_panel = load("res://src/ui/settings_panel.gd").new()
	add_child(_settings_panel)
	_settings_panel.closed.connect(func() -> void:
		_settings_panel.queue_free()
		_settings_panel = null
	)


func _on_quit() -> void:
	get_tree().quit(0)


func _process(delta: float) -> void:
	_t += delta
	if _title != null:
		_title.scale = Vector2.ONE
		_title.modulate = Color(1, 1, 1, 0.94 + 0.06 * sin(_t * 2.0))
	for d in _deco:
		var s: Sprite2D = d["node"]
		var base: Vector2 = d["base"]
		s.position = base + Vector2(0, sin(_t * 1.3 + float(d["phase"])) * 10.0)
		d["frame_t"] += delta
		if float(d["frame_t"]) > 0.16:
			d["frame_t"] = 0.0
			s.frame = (s.frame + 1) % 4
	# 提示轮换
	_tip_timer += delta
	if _tip_timer > 7.0 and _tip_label != null:
		_tip_timer = 0.0
		_tip_index = (_tip_index + 1) % TIPS.size()
		_tip_label.text = TIPS[_tip_index]
