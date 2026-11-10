class_name BattleScreen
extends Node
## 战斗场景装配：Battle（世界）+ Hud（界面）+ 浮层。

var cfg := {}
var battle: Battle
var hud: Hud
var overlay: CanvasLayer
var _settings: Node = null


func configure(c: Dictionary) -> void:
	cfg = c


func _ready() -> void:
	overlay = CanvasLayer.new()
	overlay.layer = 30
	add_child(overlay)

	_build_battle()
	App.audio.play_music("music_battle", 0.8)


func _build_battle() -> void:
	battle = Battle.new()
	battle.configure(cfg)
	add_child(battle)

	hud = Hud.new()
	hud.setup(battle, {
		"resume": func() -> void: _toggle_pause(),
		"restart": func() -> void: _restart_round(),
		"menu": func() -> void: _to_menu(),
		"rematch": func() -> void: _rematch(),
		"settings": func() -> void: _open_settings(),
	})
	add_child(hud)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		_toggle_pause()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("restart_round"):
		_restart_round()
		get_viewport().set_input_as_handled()


func _toggle_pause() -> void:
	if _settings != null:
		return
	if battle.state == Battle.State.MATCH_END:
		return
	battle.toggle_pause()


func _restart_round() -> void:
	if battle.state == Battle.State.MATCH_END:
		return
	battle.restart_round()
	hud.hide_result()


func _to_menu() -> void:
	if App.audio != null:
		App.audio.play_music("music_menu", 0.6)
	var main := get_tree().current_scene
	if main != null and main.has_method("show_menu"):
		main.show_menu()


func _rematch() -> void:
	if is_instance_valid(battle):
		battle.queue_free()
	if is_instance_valid(hud):
		hud.queue_free()
	await get_tree().process_frame
	_build_battle()


func _open_settings() -> void:
	if _settings != null:
		return
	_settings = load("res://src/ui/settings_panel.gd").new()
	overlay.add_child(_settings)
	_settings.closed.connect(func() -> void:
		_settings.queue_free()
		_settings = null
	)
