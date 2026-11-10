class_name AudioDirector
extends Node
## 音频总控：音乐淡入淡出、音效池、音量总线。

const SFX_NAMES := [
	"ui_move", "ui_click", "bomb_place", "explosion", "brick", "powerup",
	"shield", "hurt", "death", "countdown", "round_start", "win", "lose",
]
const MUSIC_NAMES := ["music_menu", "music_battle"]

var music_volume := 0.7
var sfx_volume := 0.85

var _sfx_streams := {}
var _music_streams := {}
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_index := 0
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _music_active: AudioStreamPlayer
var _current_music := ""
var _tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_buses()
	for name in SFX_NAMES:
		var s := _load_stream("res://assets/audio/%s.wav" % name)
		if s != null:
			_sfx_streams[name] = s
	for name in MUSIC_NAMES:
		var s := _load_stream("res://assets/audio/%s.wav" % name)
		if s != null:
			_music_streams[name] = _as_loop(s)
	for i in 8:
		var p := AudioStreamPlayer.new()
		p.bus = "Sfx"
		add_child(p)
		_sfx_players.append(p)
	_music_a = AudioStreamPlayer.new()
	_music_a.bus = "Music"
	add_child(_music_a)
	_music_b = AudioStreamPlayer.new()
	_music_b.bus = "Music"
	add_child(_music_b)
	_music_active = _music_a
	apply_volumes()


func _setup_buses() -> void:
	for bus_name in ["Music", "Sfx"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			var idx := AudioServer.bus_count
			AudioServer.add_bus(idx)
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")


func _load_stream(path: String) -> AudioStream:
	if not ResourceLoader.exists(path):
		return null
	var res := load(path)
	if res == null:
		return null
	return res


func _as_loop(stream: AudioStream) -> AudioStream:
	if stream is AudioStreamWAV:
		var w := stream.duplicate() as AudioStreamWAV
		var channels := 2 if w.stereo else 1
		var frames := int(w.data.size() / (2 * channels))
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = frames
		return w
	return stream


func apply_volumes() -> void:
	_set_bus_linear("Music", music_volume)
	_set_bus_linear("Sfx", sfx_volume)


func _set_bus_linear(bus_name: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	AudioServer.set_bus_mute(idx, linear <= 0.001)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(linear, 0.0001)))


func loaded_counts() -> Dictionary:
	return {
		"sfx": _sfx_streams.size(),
		"music": _music_streams.size(),
		"buses": AudioServer.bus_count,
		"music_playing": _music_active != null and _music_active.playing,
	}


func set_music_volume(v: float) -> void:
	music_volume = v
	apply_volumes()


func set_sfx_volume(v: float) -> void:
	sfx_volume = v
	apply_volumes()


func play_sfx(name: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if not _sfx_streams.has(name):
		return
	var p := _sfx_players[_sfx_index]
	_sfx_index = (_sfx_index + 1) % _sfx_players.size()
	p.stream = _sfx_streams[name]
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.play()


func play_music(name: String, fade: float = 0.6) -> void:
	if _current_music == name and _music_active.playing:
		return
	if not _music_streams.has(name):
		return
	_current_music = name
	var old := _music_active
	var new_player := _music_b if old == _music_a else _music_a
	new_player.stream = _music_streams[name]
	new_player.volume_db = -60.0
	new_player.play()
	_music_active = new_player
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(new_player, "volume_db", 0.0, fade)
	if old.playing:
		_tween.tween_property(old, "volume_db", -60.0, fade)
		_tween.chain().tween_callback(old.stop)


func stop_music(fade: float = 0.5) -> void:
	_current_music = ""
	var old := _music_active
	if not old.playing:
		return
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(old, "volume_db", -60.0, fade)
	_tween.tween_callback(old.stop)
