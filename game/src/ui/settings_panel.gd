class_name SettingsPanel
extends Control
## 设置面板：音量、画面、手感。可在菜单或暂停界面复用。

signal closed

var _music_value: Label
var _sfx_value: Label
var _music_slider: HSlider
var _sfx_slider: HSlider
var _fullscreen: CheckButton
var _shake: CheckButton
var _focus_btn: Button


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	size = Pal.VIEW
	theme = App.theme
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.04, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.size = Pal.VIEW
	add_child(dim)

	var panel := PanelContainer.new()
	panel.position = Vector2(340, 96)
	panel.size = Vector2(600, 528)
	add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	margin.add_child(box)

	var title := UiKit.label("设置", 34, Pal.AMBER)
	box.add_child(title)
	box.add_child(UiKit.hsep(Pal.LINE_SOFT, 2))

	# 音乐
	var music_row := HBoxContainer.new()
	music_row.add_theme_constant_override("separation", 16)
	var ml := UiKit.label("音乐音量", 18, Pal.TEXT)
	ml.custom_minimum_size = Vector2(120, 32)
	ml.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	music_row.add_child(ml)
	_music_slider = _slider(float(App.save.settings["music"]))
	music_row.add_child(_music_slider)
	_music_value = UiKit.label("%d%%" % int(float(App.save.settings["music"]) * 100), 16, Pal.TEXT_DIM)
	_music_value.custom_minimum_size = Vector2(56, 32)
	_music_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_music_value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	music_row.add_child(_music_value)
	box.add_child(music_row)

	# 音效
	var sfx_row := HBoxContainer.new()
	sfx_row.add_theme_constant_override("separation", 16)
	var sl := UiKit.label("音效音量", 18, Pal.TEXT)
	sl.custom_minimum_size = Vector2(120, 32)
	sl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sfx_row.add_child(sl)
	_sfx_slider = _slider(float(App.save.settings["sfx"]))
	sfx_row.add_child(_sfx_slider)
	_sfx_value = UiKit.label("%d%%" % int(float(App.save.settings["sfx"]) * 100), 16, Pal.TEXT_DIM)
	_sfx_value.custom_minimum_size = Vector2(56, 32)
	_sfx_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_sfx_value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sfx_row.add_child(_sfx_value)
	box.add_child(sfx_row)

	box.add_child(UiKit.hsep(Pal.LINE_SOFT, 4))

	_fullscreen = _check("全屏显示", bool(App.save.settings["fullscreen"]))
	box.add_child(_fullscreen)
	_shake = _check("爆炸屏幕震动", bool(App.save.settings["shake"]))
	box.add_child(_shake)

	box.add_child(UiKit.hsep(Pal.LINE_SOFT, 4))

	var path_hint := UiKit.label("存档目录：%s" % App.save.dir, 12, Pal.TEXT_DIM)
	path_hint.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	box.add_child(path_hint)

	var filler := Control.new()
	filler.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(filler)

	_focus_btn = UiKit.button("返回", 22)
	_focus_btn.custom_minimum_size = Vector2(0, 52)
	_focus_btn.pressed.connect(close)
	box.add_child(_focus_btn)

	_music_slider.value_changed.connect(_on_music)
	_sfx_slider.value_changed.connect(_on_sfx)
	_fullscreen.toggled.connect(_on_fullscreen)
	_shake.toggled.connect(_on_shake)
	_focus_btn.grab_focus.call_deferred()


func _slider(value: float) -> HSlider:
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = value
	s.custom_minimum_size = Vector2(300, 32)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.custom_minimum_size.y = 32
	return s


func _check(text: String, value: bool) -> CheckButton:
	var c := CheckButton.new()
	c.text = text
	c.button_pressed = value
	c.add_theme_font_size_override("font_size", 18)
	c.focus_mode = Control.FOCUS_ALL
	return c


func _on_music(v: float) -> void:
	App.save.settings["music"] = v
	App.audio.set_music_volume(v)
	_music_value.text = "%d%%" % int(v * 100)


func _on_sfx(v: float) -> void:
	App.save.settings["sfx"] = v
	App.audio.set_sfx_volume(v)
	_sfx_value.text = "%d%%" % int(v * 100)
	App.audio.play_sfx("ui_move", -6.0)


func _on_fullscreen(v: bool) -> void:
	App.save.settings["fullscreen"] = v
	App.apply_window_settings()


func _on_shake(v: bool) -> void:
	App.save.settings["shake"] = v


func close() -> void:
	App.save.save_settings()
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
