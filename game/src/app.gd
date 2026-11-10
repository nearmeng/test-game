extends Node
## 全局服务：主题、存档、音频、输入映射。

var save: SaveStore
var audio: AudioDirector
var theme: Theme
var difficulty_names := ["简单", "普通", "困难"]

const ACTION_KEYS := {
	"p1_left": [KEY_A],
	"p1_right": [KEY_D],
	"p1_up": [KEY_W],
	"p1_down": [KEY_S],
	"p1_bomb": [KEY_SPACE, KEY_J],
	"p2_left": [KEY_LEFT],
	"p2_right": [KEY_RIGHT],
	"p2_up": [KEY_UP],
	"p2_down": [KEY_DOWN],
	"p2_bomb": [KEY_ENTER, KEY_KP_ENTER, KEY_SLASH],
	"pause": [KEY_ESCAPE],
	"toggle_fullscreen": [KEY_F11],
	"toggle_mute": [KEY_M],
	"restart_round": [KEY_R],
}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = UiKit.build_theme()
	_register_inputs()
	save = SaveStore.new()
	audio = AudioDirector.new()
	audio.name = "Audio"
	add_child(audio)
	audio.set_music_volume(float(save.settings["music"]))
	audio.set_sfx_volume(float(save.settings["sfx"]))
	apply_window_settings()
	audio.play_music("music_menu")


func _register_inputs() -> void:
	for action in ACTION_KEYS.keys():
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.2)
		InputMap.action_erase_events(action)
		for key in ACTION_KEYS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)


func apply_window_settings() -> void:
	var want_fullscreen := bool(save.settings["fullscreen"])
	var is_fullscreen := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	if want_fullscreen != is_fullscreen:
		DisplayServer.window_set_mode(
			DisplayServer.WINDOW_MODE_FULLSCREEN if want_fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
		)


func toggle_fullscreen() -> void:
	save.settings["fullscreen"] = not bool(save.settings["fullscreen"])
	apply_window_settings()
	save.save_settings()


func set_difficulty(idx: int) -> void:
	save.settings["difficulty"] = clampi(idx, 0, 2)
	save.save_settings()


func difficulty() -> int:
	return clampi(int(save.settings["difficulty"]), 0, 2)


func shake_enabled() -> bool:
	return bool(save.settings["shake"])


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_fullscreen"):
		toggle_fullscreen()
	elif event.is_action_pressed("toggle_mute"):
		var muted := AudioServer.is_bus_mute(0)
		AudioServer.set_bus_mute(0, not muted)
