class_name Art
extends RefCounted
## 资源加载与 SpriteFrames 构建（纹理均为 24x24，引擎内放大 2 倍）。

const SCALE := 2

static var _tex_cache := {}
static var _frames_cache := {}
static var _char_frames := {}


static func tex(name: String) -> Texture2D:
	if _tex_cache.has(name):
		return _tex_cache[name]
	var path := "res://assets/%s.png" % name
	var t: Texture2D = null
	if ResourceLoader.exists(path):
		t = load(path) as Texture2D
	_tex_cache[name] = t
	return t


static func icon_atlas(index: int) -> AtlasTexture:
	var a := AtlasTexture.new()
	a.atlas = tex("icons")
	a.region = Rect2(index * 16, 0, 16, 16)
	return a


static func powerup_atlas(index: int) -> AtlasTexture:
	var a := AtlasTexture.new()
	a.atlas = tex("powerup")
	a.region = Rect2(index * 24, 0, 24, 24)
	return a


static func anim_frames(name: String, count: int, fps: float, loop: bool = true) -> SpriteFrames:
	var key := "%s|%d|%.1f|%s" % [name, count, fps, str(loop)]
	if _frames_cache.has(key):
		return _frames_cache[key]
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	sf.add_animation("anim")
	sf.set_animation_speed("anim", fps)
	sf.set_animation_loop("anim", loop)
	var sheet := tex(name)
	if sheet != null:
		for i in count:
			var a := AtlasTexture.new()
			a.atlas = sheet
			a.region = Rect2(i * 24, 0, 24, 24)
			sf.add_frame("anim", a)
	_frames_cache[key] = sf
	return sf


static func char_frames(idx: int) -> SpriteFrames:
	if _char_frames.has(idx):
		return _char_frames[idx]
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	var sheet := tex("char_%d" % idx)
	var dirs := ["down", "left", "right", "up"]
	for row in dirs.size():
		sf.add_animation(dirs[row])
		sf.set_animation_speed(dirs[row], 8.0)
		sf.set_animation_loop(dirs[row], true)
		if sheet == null:
			continue
		for col in 3:
			var a := AtlasTexture.new()
			a.atlas = sheet
			a.region = Rect2(col * 24, row * 24, 24, 24)
			sf.add_frame(dirs[row], a)
	_char_frames[idx] = sf
	return sf


static func make_sprite(node_name: String, tex_name: String) -> Sprite2D:
	var s := Sprite2D.new()
	s.name = node_name
	s.texture = tex(tex_name)
	s.scale = Vector2(SCALE, SCALE)
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return s


static func make_animated(node_name: String, frames: SpriteFrames) -> AnimatedSprite2D:
	var a := AnimatedSprite2D.new()
	a.name = node_name
	a.sprite_frames = frames
	a.scale = Vector2(SCALE, SCALE)
	a.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return a
