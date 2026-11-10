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

## 手柄固定分配：1 号手柄 = 玩家 1，2 号手柄 = 玩家 2
const PAD_FOR_PLAYER := {"p1": 0, "p2": 1}
var _rumble_until := 0


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
	_register_joypad()


## 手柄：左摇杆 + 十字键移动，A/X 放弹，START 暂停。
func _register_joypad() -> void:
	for prefix in PAD_FOR_PLAYER.keys():
		var device: int = PAD_FOR_PLAYER[prefix]
		_add_joy_motion(prefix + "_left", device, JOY_AXIS_LEFT_X, -1.0)
		_add_joy_motion(prefix + "_right", device, JOY_AXIS_LEFT_X, 1.0)
		_add_joy_motion(prefix + "_up", device, JOY_AXIS_LEFT_Y, -1.0)
		_add_joy_motion(prefix + "_down", device, JOY_AXIS_LEFT_Y, 1.0)
		_add_joy_button(prefix + "_left", device, [JOY_BUTTON_DPAD_LEFT])
		_add_joy_button(prefix + "_right", device, [JOY_BUTTON_DPAD_RIGHT])
		_add_joy_button(prefix + "_up", device, [JOY_BUTTON_DPAD_UP])
		_add_joy_button(prefix + "_down", device, [JOY_BUTTON_DPAD_DOWN])
		_add_joy_button(prefix + "_bomb", device, [JOY_BUTTON_A, JOY_BUTTON_X])
	# 任意手柄的 START 暂停 / BACK 重开
	_add_joy_button("pause", -1, [JOY_BUTTON_START])
	_add_joy_button("restart_round", -1, [JOY_BUTTON_BACK])
	# 引擎内置的 ui_accept / ui_cancel 默认不带手柄，菜单会“能选不能确认”，这里补上
	_add_joy_button("ui_accept", -1, [JOY_BUTTON_A])
	_add_joy_button("ui_cancel", -1, [JOY_BUTTON_B])


func _add_joy_motion(action: String, device: int, axis: int, value: float) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.25)
	var ev := InputEventJoypadMotion.new()
	ev.device = device
	ev.axis = axis as JoyAxis
	ev.axis_value = value
	InputMap.action_add_event(action, ev)


func _add_joy_button(action: String, device: int, buttons: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.25)
	for b in buttons:
		var ev := InputEventJoypadButton.new()
		ev.device = device
		ev.button_index = b as JoyButton
		InputMap.action_add_event(action, ev)


func pad_count() -> int:
	return Input.get_connected_joypads().size()


func pad_status_text() -> String:
	var pads := Input.get_connected_joypads()
	if pads.is_empty():
		return "手柄：未检测到（插上即用）"
	var first := Input.get_joy_name(pads[0])
	if pads.size() == 1:
		return "手柄：%s → 玩家 1" % first
	return "手柄：%s → 玩家 1   ·   %s → 玩家 2" % [first, Input.get_joy_name(pads[1])]


## 爆炸/被炸时的手柄震动（无手柄时静默）。
func rumble(strength: float = 0.6) -> void:
	var now := Time.get_ticks_msec()
	if now < _rumble_until:
		return
	_rumble_until = now + 90
	for id in Input.get_connected_joypads():
		Input.start_joy_vibration(id, clampf(strength * 0.7, 0.0, 1.0), clampf(strength, 0.0, 1.0), 0.16)


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
