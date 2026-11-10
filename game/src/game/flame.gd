class_name Flame
extends Node2D
## 单格火焰：淡入、抖动、淡出。

var life := 0.46
var age := 0.0
var sprite: AnimatedSprite2D
var base_scale := 2.0


func setup(kind: String, flip_h: bool, flip_v: bool, duration: float) -> void:
	life = duration
	var frames := Art.anim_frames("flame_" + kind, 4, 16.0, false)
	sprite = Art.make_animated("FlameSprite", frames)
	sprite.play("anim")
	sprite.flip_h = flip_h
	sprite.flip_v = flip_v
	sprite.z_index = 40
	add_child(sprite)
	base_scale = 2.0
	sprite.scale = Vector2(base_scale, base_scale) * 1.15


func _process(delta: float) -> void:
	age += delta
	var k := age / life
	if k >= 1.0:
		queue_free()
		return
	var wob := 1.0 + 0.10 * sin(age * 40.0)
	var grow := 1.25 - 0.35 * minf(k * 2.4, 1.0)
	if sprite != null:
		sprite.scale = Vector2(base_scale, base_scale) * grow * wob
		sprite.modulate.a = 1.0 - maxf(0.0, (k - 0.55) / 0.45)
