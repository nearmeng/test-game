class_name FxLayer
extends Node2D
## 轻量特效层：粒子碎片 + 漂浮文字。

var particles: Array[Dictionary] = []
var floaters: Array[Dictionary] = []
var _font: Font


func _ready() -> void:
	z_index = 60
	_font = App.theme.default_font if App != null and App.theme != null else ThemeDB.fallback_font


func burst(pos: Vector2, color: Color, count: int = 14, speed: float = 190.0, life: float = 0.55, size: float = 5.0) -> void:
	for i in count:
		var a := randf() * TAU
		var s := speed * randf_range(0.35, 1.0)
		particles.append({
			"pos": pos,
			"vel": Vector2(cos(a), sin(a)) * s,
			"life": life * randf_range(0.6, 1.25),
			"age": 0.0,
			"color": color,
			"size": size * randf_range(0.6, 1.3),
			"grav": 380.0,
		})


func debris(pos: Vector2, base: Color, count: int = 10) -> void:
	for i in count:
		var a := randf() * TAU
		var s := randf_range(60, 220)
		particles.append({
			"pos": pos + Vector2(randf_range(-8, 8), randf_range(-8, 8)),
			"vel": Vector2(cos(a), sin(a) * 0.7 - 0.5) * s,
			"life": randf_range(0.4, 0.9),
			"age": 0.0,
			"color": base.lerp(Color(0.2, 0.1, 0.05), randf() * 0.5),
			"size": randf_range(3, 7),
			"grav": 700.0,
		})


func float_text(pos: Vector2, text: String, color: Color = Color.WHITE, size: int = 22) -> void:
	floaters.append({"pos": pos, "text": text, "age": 0.0, "life": 0.9, "color": color, "size": size})


func _process(delta: float) -> void:
	var i := particles.size() - 1
	while i >= 0:
		var p := particles[i]
		p["age"] = float(p["age"]) + delta
		if float(p["age"]) >= float(p["life"]):
			particles.remove_at(i)
		else:
			var v: Vector2 = p["vel"]
			v.y += float(p["grav"]) * delta
			p["vel"] = v * 0.985
			p["pos"] = Vector2(p["pos"]) + v * delta
		i -= 1
	i = floaters.size() - 1
	while i >= 0:
		var f := floaters[i]
		f["age"] = float(f["age"]) + delta
		if float(f["age"]) >= float(f["life"]):
			floaters.remove_at(i)
		i -= 1
	queue_redraw()


func _draw() -> void:
	for p in particles:
		var k := clampf(float(p["age"]) / float(p["life"]), 0.0, 1.0)
		var col: Color = p["color"]
		col.a = 1.0 - k
		var sz: float = float(p["size"]) * (1.0 - k * 0.5)
		draw_rect(Rect2(Vector2(p["pos"]) - Vector2(sz, sz) * 0.5, Vector2(sz, sz)), col)
	for f in floaters:
		var k2 := clampf(float(f["age"]) / float(f["life"]), 0.0, 1.0)
		var col2: Color = f["color"]
		col2.a = 1.0 - k2 * k2
		var fpos: Vector2 = Vector2(f["pos"]) + Vector2(0, -46.0 * k2)
		var fsize: int = int(float(f["size"]) * (1.0 + 0.15 * sin(k2 * PI)))
		if _font != null:
			draw_string(_font, fpos - Vector2(40, 0), str(f["text"]), HORIZONTAL_ALIGNMENT_CENTER, 80, fsize, col2)
