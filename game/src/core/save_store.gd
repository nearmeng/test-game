class_name SaveStore
extends RefCounted
## 存档：优先 user://，不可写时回落到 res://userdata/ 或可执行文件旁的 userdata/。

const FILE_SETTINGS := "settings.cfg"
const FILE_PROFILE := "profile.cfg"

var dir: String = "res://userdata/"
var settings := {
	"music": 0.7,
	"sfx": 0.85,
	"fullscreen": false,
	"shake": true,
	"difficulty": 1,
}
var profile := {
	"wins": 0,
	"losses": 0,
	"draws": 0,
	"best_streak": 0,
	"streak": 0,
	"rounds": 0,
	"kills": 0,
}
var writable := false


func _init() -> void:
	dir = _resolve_dir()
	writable = _can_write(dir)
	load_all()


func _candidates() -> Array[String]:
	var list: Array[String] = ["user://"]
	list.append("res://userdata/")
	var exe_dir := OS.get_executable_path().get_base_dir()
	if exe_dir != "":
		list.append(exe_dir.path_join("userdata") + "/")
	return list


func _resolve_dir() -> String:
	for cand in _candidates():
		var abs_path := ProjectSettings.globalize_path(cand) if cand.begins_with("res://") else cand
		DirAccess.make_dir_recursive_absolute(abs_path)
		if _can_write(cand):
			return cand
	return "res://userdata/"


func _can_write(base: String) -> bool:
	var probe := base.path_join(".probe")
	var f := FileAccess.open(probe, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string("ok")
	f.close()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(probe))
	return true


func path_for(name: String) -> String:
	return dir.path_join(name)


func load_all() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(path_for(FILE_SETTINGS)) == OK:
		for k in settings.keys():
			if cfg.has_section_key("settings", k):
				settings[k] = cfg.get_value("settings", k)
	var cfg2 := ConfigFile.new()
	if cfg2.load(path_for(FILE_PROFILE)) == OK:
		for k in profile.keys():
			if cfg2.has_section_key("profile", k):
				profile[k] = cfg2.get_value("profile", k)


func save_settings() -> void:
	var cfg := ConfigFile.new()
	for k in settings.keys():
		cfg.set_value("settings", k, settings[k])
	cfg.save(path_for(FILE_SETTINGS))


func save_profile() -> void:
	var cfg := ConfigFile.new()
	for k in profile.keys():
		cfg.set_value("profile", k, profile[k])
	cfg.save(path_for(FILE_PROFILE))


func record_win(score: int, kills: int) -> void:
	profile["wins"] = int(profile["wins"]) + 1
	profile["streak"] = int(profile["streak"]) + 1
	profile["best_streak"] = maxi(int(profile["best_streak"]), int(profile["streak"]))
	profile["kills"] = int(profile["kills"]) + kills
	save_profile()


func record_loss(kills: int) -> void:
	profile["losses"] = int(profile["losses"]) + 1
	profile["streak"] = 0
	profile["kills"] = int(profile["kills"]) + kills
	save_profile()


func record_draw() -> void:
	profile["draws"] = int(profile["draws"]) + 1
	save_profile()


func record_rounds(n: int) -> void:
	profile["rounds"] = int(profile["rounds"]) + n
	save_profile()
