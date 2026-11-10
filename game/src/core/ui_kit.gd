class_name UiKit
extends RefCounted
## 统一的 UI 主题与控件工厂。

const FONT_NAMES := [
	"Microsoft YaHei UI", "Microsoft YaHei", "微软雅黑",
	"Noto Sans CJK SC", "Source Han Sans SC", "PingFang SC", "SimHei", "SimSun",
]


static func cjk_font() -> Font:
	var sf := SystemFont.new()
	sf.font_names = PackedStringArray(FONT_NAMES)
	sf.allow_system_fallback = true
	sf.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	return sf


static func box(bg: Color, border: Color, radius: int = 10, width: int = 2) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(width)
	sb.set_corner_radius_all(radius)
	return sb


static func build_theme() -> Theme:
	var t := Theme.new()
	t.default_font = cjk_font()
	t.default_font_size = 20

	# 按钮
	var normal := box(Pal.PANEL_SOFT, Pal.LINE, 12, 2)
	normal.content_margin_left = 22
	normal.content_margin_right = 22
	normal.content_margin_top = 12
	normal.content_margin_bottom = 12
	var hover := box(Color("2c3047"), Pal.AMBER, 12, 2)
	hover.content_margin_left = 22
	hover.content_margin_right = 22
	hover.content_margin_top = 12
	hover.content_margin_bottom = 12
	var pressed := box(Color("14161f"), Pal.AMBER, 12, 2)
	pressed.content_margin_left = 22
	pressed.content_margin_right = 22
	pressed.content_margin_top = 12
	pressed.content_margin_bottom = 12
	var focus := box(Color(0, 0, 0, 0), Pal.CYAN, 12, 2)
	focus.draw_center = false
	var disabled := box(Color("181a25"), Pal.LINE_SOFT, 12, 2)
	disabled.content_margin_left = 22
	disabled.content_margin_right = 22
	disabled.content_margin_top = 12
	disabled.content_margin_bottom = 12

	t.set_stylebox("normal", "Button", normal)
	t.set_stylebox("hover", "Button", hover)
	t.set_stylebox("pressed", "Button", pressed)
	t.set_stylebox("focus", "Button", focus)
	t.set_stylebox("disabled", "Button", disabled)
	t.set_color("font_color", "Button", Pal.TEXT)
	t.set_color("font_hover_color", "Button", Color("fff6e0"))
	t.set_color("font_pressed_color", "Button", Pal.AMBER)
	t.set_color("font_disabled_color", "Button", Color("5a6180"))
	t.set_font_size("font_size", "Button", 22)

	# 文本
	t.set_color("font_color", "Label", Pal.TEXT)
	t.set_font_size("font_size", "Label", 20)
	t.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.55))
	t.set_constant("shadow_offset_x", "Label", 0)
	t.set_constant("shadow_offset_y", "Label", 2)

	# 面板
	t.set_stylebox("panel", "PanelContainer", box(Pal.PANEL, Pal.LINE, 16, 2))
	t.set_stylebox("panel", "Panel", box(Pal.PANEL, Pal.LINE, 16, 2))

	# 进度条
	t.set_stylebox("background", "ProgressBar", box(Color("14161f"), Pal.LINE_SOFT, 6, 1))
	t.set_stylebox("fill", "ProgressBar", box(Pal.AMBER, Pal.AMBER, 6, 1))
	t.set_color("font_color", "ProgressBar", Pal.TEXT)
	t.set_font_size("font_size", "ProgressBar", 14)

	# 滚动条（设置面板用不到，但保持一致）
	t.set_stylebox("scroll", "VScrollBar", box(Color("14161f"), Pal.LINE_SOFT, 4, 0))
	t.set_stylebox("grabber", "VScrollBar", box(Pal.LINE, Pal.LINE, 4, 0))

	return t


static func label(text: String, size: int = 20, color: Color = Pal.TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func shadowed(text: String, size: int, color: Color, outline: int = 10) -> Label:
	var l := label(text, size, color)
	l.add_theme_constant_override("outline_size", outline)
	l.add_theme_color_override("outline_color", Color(0.05, 0.04, 0.08, 0.9))
	return l


static func button(text: String, size: int = 22) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.focus_mode = Control.FOCUS_ALL
	_attach_click_sound(b)
	return b


static func _attach_click_sound(b: Button) -> void:
	b.mouse_entered.connect(func() -> void:
		if App != null and App.audio != null:
			App.audio.play_sfx("ui_move", -8.0)
	)
	b.pressed.connect(func() -> void:
		if App != null and App.audio != null:
			App.audio.play_sfx("ui_click", -2.0)
	)


static func spacer(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c


static func hsep(line_color: Color = Pal.LINE_SOFT, margin: int = 10) -> Control:
	var r := ColorRect.new()
	r.color = line_color
	r.custom_minimum_size = Vector2(0, 2)
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var wrap := MarginContainer.new()
	wrap.add_theme_constant_override("margin_top", margin)
	wrap.add_theme_constant_override("margin_bottom", margin)
	wrap.add_child(r)
	return wrap
