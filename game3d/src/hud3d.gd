class_name Hud3D
extends CanvasLayer
## 极简 HUD：状态、计时、存活数、隐蔽提示、横幅。

var _timer: Label
var _status: Label
var _alive: Label
var _hide: Label
var _banner: Label
var _hint: Label
var _cam: Label
var _banner_tween: Tween


func _ready() -> void:
	layer = 10
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei", "SimHei"])
	font.allow_system_fallback = true

	var root := Control.new()
	root.size = Vector2(1280, 720)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_timer = _label(font, 40, Color(0.95, 0.97, 1.0))
	_timer.position = Vector2(40, 24)
	_timer.size = Vector2(240, 54)
	root.add_child(_timer)

	_status = _label(font, 17, Color(0.85, 0.9, 1.0))
	_status.position = Vector2(40, 84)
	_status.size = Vector2(420, 26)
	root.add_child(_status)

	_alive = _label(font, 17, Color(0.85, 0.9, 1.0))
	_alive.position = Vector2(1040, 28)
	_alive.size = Vector2(210, 26)
	_alive.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(_alive)

	_hide = _label(font, 20, Color(0.55, 0.95, 0.7))
	_hide.position = Vector2(500, 640)
	_hide.size = Vector2(280, 30)
	_hide.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_hide)

	_banner = _label(font, 64, Color(1, 0.85, 0.35))
	_banner.position = Vector2(0, 250)
	_banner.size = Vector2(1280, 110)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_banner.modulate = Color(1, 1, 1, 0)
	root.add_child(_banner)

	_hint = _label(font, 14, Color(0.6, 0.65, 0.78))
	_hint.position = Vector2(0, 686)
	_hint.size = Vector2(1280, 22)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.text = "WASD / 方向键 移动    空格 放弹    C 切换视角    [ ] 缩放    R 重开    手柄：左摇杆 + A"
	root.add_child(_hint)

	_cam = _label(font, 15, Color(0.62, 0.85, 1.0))
	_cam.position = Vector2(980, 660)
	_cam.size = Vector2(270, 24)
	_cam.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(_cam)


func _label(font: Font, size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", 6)
	l.add_theme_color_override("outline_color", Color(0.02, 0.02, 0.04, 0.85))
	return l


func update_hud(main) -> void:
	_timer.text = "%02d:%02d" % [int(maxf(main.time_left, 0.0)) / 60, int(maxf(main.time_left, 0.0)) % 60]
	var h: Hero3D = main.player_hero()
	_status.text = "炸弹 %d / 火力 %d / 速度 %d" % [h.bombs_max, h.power, h.speed_level]
	_alive.text = "存活 %d / 4" % main.alive_count()
	_hide.text = "隐蔽中 · 对手看不见你" if h.hidden else ""
	_cam.text = "视角：%s（C 切换）" % main.CAM_NAMES[main.cam_mode]


func show_banner(text: String, color: Color, hold: float = 2.0) -> void:
	_banner.text = text
	_banner.add_theme_color_override("font_color", color)
	_banner.modulate = Color(1, 1, 1, 1)
	_banner.scale = Vector2(1.15, 1.15)
	_banner.pivot_offset = _banner.size * 0.5
	if _banner_tween != null and _banner_tween.is_valid():
		_banner_tween.kill()
	_banner_tween = create_tween()
	_banner_tween.set_parallel(true)
	_banner_tween.tween_property(_banner, "scale", Vector2.ONE, 0.25)
	_banner_tween.tween_property(_banner, "modulate:a", 0.0, 0.5).set_delay(hold)


func clear_banner() -> void:
	_banner.modulate = Color(1, 1, 1, 0)
