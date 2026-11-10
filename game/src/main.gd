extends Node
## 入口：装配主题、分发界面、处理命令行测试钩子。

var current_screen: Node = null
var dev_mode := ""


func _ready() -> void:
	get_tree().root.theme = App.theme
	var args := OS.get_cmdline_user_args()
	for a in args:
		if a == "selftest":
			dev_mode = "selftest"
		elif a.begins_with("shot="):
			dev_mode = a.substr(5)
	if dev_mode == "selftest":
		if not ResourceLoader.exists("res://src/dev/selftest.gd"):
			push_error("selftest script missing")
			show_menu()
			return
		var runner: Node = load("res://src/dev/selftest.gd").new()
		add_child(runner)
		return
	if dev_mode != "":
		if not ResourceLoader.exists("res://src/dev/screenshot_runner.gd"):
			show_menu()
			return
		var shot_runner: Node = load("res://src/dev/screenshot_runner.gd").new(dev_mode)
		add_child(shot_runner)
		return
	show_menu()


func show_menu() -> void:
	if App != null and App.audio != null:
		App.audio.play_music("music_menu", 0.6)
	_swap(MenuScreen.new())


func start_battle(config: Dictionary) -> void:
	var path := "res://src/game/battle_screen.gd"
	if not ResourceLoader.exists(path):
		push_error("battle screen missing")
		return
	var screen: Node = load(path).new()
	screen.configure(config)
	_swap(screen)


func _swap(node: Node) -> void:
	if current_screen != null:
		remove_child(current_screen)
		current_screen.queue_free()
		current_screen = null
	add_child(node)
	current_screen = node


func current_screen_node() -> Node:
	return current_screen
