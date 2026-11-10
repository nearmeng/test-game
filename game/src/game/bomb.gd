class_name Bomb
extends Node2D
## 炸弹：引信计时由 Battle 统一驱动，这里只管表现。

const FUSE := 2.45

var cell := Vector2i.ZERO
var power := 1
var owner_index := -1
var time_left := FUSE
var exploded_flag := false
var sprite: AnimatedSprite2D

var _pulse_t := 0.0


func setup(p_cell: Vector2i, p_power: int, p_owner: int) -> void:
	cell = p_cell
	power = p_power
	owner_index = p_owner
	position = Vector2(cell.x * Pal.TILE + Pal.TILE * 0.5, cell.y * Pal.TILE + Pal.TILE * 0.5)
	z_index = 5
	sprite = Art.make_animated("BombSprite", Art.anim_frames("bomb", 4, 8.0, true))
	sprite.offset = Vector2(0, 4)
	add_child(sprite)
	sprite.play("anim")
	scale = Vector2(0.4, 0.4)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.0, 1.0), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	_pulse_t += delta
	if sprite == null:
		return
	var urgency := clampf(1.0 - time_left / FUSE, 0.0, 1.0)
	var rate := 8.0 + urgency * 14.0
	sprite.speed_scale = rate / 8.0
	var pulse := 1.0 + sin(_pulse_t * (6.0 + urgency * 12.0)) * (0.03 + urgency * 0.06)
	sprite.scale = Vector2(2, 2) * pulse
	sprite.modulate = Color(1, 1, 1, 1).lerp(Color(1.6, 0.7, 0.7, 1), urgency * 0.8)


func visual_center() -> Vector2:
	return position
