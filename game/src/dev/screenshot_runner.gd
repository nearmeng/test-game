extends Node
## 开发用：按脚本驱动游戏状态并截图，验证界面与特效。
## 用法: godot --path game -- shot=menu|battle|all

var mode := ""
var _main: Node


func _init(p_mode: String = "") -> void:
	mode = p_mode


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_main = get_tree().current_scene
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots"))
	run.call_deferred()


func _capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img == null:
		print("CAPTURE FAILED: no image")
		return
	var dir := "res://shots"
	var err := img.save_png("%s/%s.png" % [dir, name])
	if err != OK:
		dir = OS.get_executable_path().get_base_dir().path_join("shots")
		DirAccess.make_dir_recursive_absolute(dir)
		err = img.save_png("%s/%s.png" % [dir, name])
	print("CAPTURE %s -> err=%d size=%dx%d dir=%s" % [name, err, img.get_width(), img.get_height(), dir])


func _wait_until(cond: Callable, timeout: float) -> bool:
	var t := 0.0
	while t < timeout:
		if cond.call():
			return true
		await get_tree().process_frame
		t += get_process_delta_time()
	return false


func _battle_screen() -> Node:
	return _main.current_screen_node() if _main.has_method("current_screen_node") else null


func run() -> void:
	if mode == "menu" or mode == "all":
		if _main.has_method("show_menu"):
			_main.show_menu()
		await get_tree().create_timer(0.8).timeout
		await _capture("01_menu")
		var menu := _battle_screen()
		if menu == null:
			menu = _main.current_screen_node() if _main.has_method("current_screen_node") else null
		if menu != null:
			var panel: Node = load("res://src/ui/settings_panel.gd").new()
			menu.add_child(panel)
			await get_tree().create_timer(0.4).timeout
			await _capture("01b_settings")
			panel.queue_free()

	if mode == "battle" or mode == "all":
		if _main.has_method("start_battle"):
			_main.start_battle({"mode": "single", "difficulty": 1, "autoplay": true, "seed": 20261110})
		await get_tree().create_timer(1.0).timeout
		await _capture("02_countdown")

		var screen := _battle_screen()
		if screen != null and screen.get("battle") != null:
			var battle: Battle = screen.battle
			var got_fire := await _wait_until(func() -> bool: return battle.flame_nodes.size() > 0, 25.0)
			print("flames seen: ", got_fire)
			await _capture("03_battle")

			battle.toggle_pause()
			await get_tree().create_timer(0.4).timeout
			await _capture("04_pause")
			battle.toggle_pause()
			await get_tree().create_timer(0.3).timeout

			# 加速跑完一场真实对局，验证结算界面
			Engine.time_scale = 4.0
			var guard := 0
			while battle.state != Battle.State.MATCH_END and guard < 600:
				await get_tree().create_timer(0.25, true, false, true).timeout
				guard += 1
			Engine.time_scale = 1.0
			await get_tree().create_timer(0.8).timeout
			await _capture("05_result")
	print("DEMO DONE")
	get_tree().quit(0)
