class_name Fighter
extends Node2D
## 参战角色：格子移动、属性、护盾、死亡表现。

const BASE_SPEED := 4.3
const SPEED_STEP := 0.55

var index := 0
var display_name := "玩家"
var is_bot := false
var alive := true
var cell := Vector2i(1, 1)
var target_cell := Vector2i(1, 1)
var moving := false
var facing := "down"

var bombs_max := 1
var bombs_out := 0
var power := 1
var speed_level := 0
var shield_until := 0.0

var bricks := 0
var kills := 0
var deaths := 0
var round_wins := 0

var intent_dir := Vector2i.ZERO
var intent_bomb := false

var sprite: AnimatedSprite2D
var _time := 0.0
var _hurt_flash := 0.0
var _spawn_anim := 0.0


func setup(p_index: int, p_name: String, bot: bool) -> void:
	index = p_index
	display_name = p_name
	is_bot = bot
	sprite = Art.make_animated("Char", Art.char_frames(p_index))
	sprite.offset = Vector2(0, 2)
	add_child(sprite)
	sprite.play("down")
	sprite.frame = 0
	z_index = 10


func place_at(c: Vector2i) -> void:
	cell = c
	target_cell = c
	moving = false
	position = cell_center(c)
	alive = true
	modulate = Color(1, 1, 1, 1)
	_spawn_anim = 0.0


func cell_center(c: Vector2i) -> Vector2:
	return Vector2(c.x * Pal.TILE + Pal.TILE * 0.5, c.y * Pal.TILE + Pal.TILE * 0.5)


func current_cell() -> Vector2i:
	if not moving:
		return cell
	var local := position / Pal.TILE
	return Vector2i(int(floor(local.x + 0.5)), int(floor(local.y + 0.5)))


func speed_cells() -> float:
	return BASE_SPEED + speed_level * SPEED_STEP


func reset_stats() -> void:
	bombs_max = 1
	bombs_out = 0
	power = 1
	speed_level = 0
	shield_until = 0.0
	alive = true
	moving = false
	intent_dir = Vector2i.ZERO
	intent_bomb = false


func is_shielded() -> bool:
	return _time < shield_until


func grant_shield(seconds: float) -> void:
	shield_until = _time + seconds


## 由 Battle 每帧调用；walkable 由战场判定。
func step(delta: float, walkable: Callable) -> void:
	if not alive:
		return
	_time += delta
	if _spawn_anim < 1.0:
		_spawn_anim = minf(1.0, _spawn_anim + delta * 4.0)
		scale = Vector2(1, 1) * (0.7 + 0.3 * _spawn_anim)

	if moving:
		var goal := cell_center(target_cell)
		var spd := speed_cells() * Pal.TILE
		position = position.move_toward(goal, spd * delta)
		if position.distance_to(goal) < 0.5:
			position = goal
			cell = target_cell
			moving = false
		else:
			_update_facing(target_cell - cell)
			_animate(true)
	else:
		_animate(false)
		if intent_dir != Vector2i.ZERO:
			var next: Vector2i = cell + intent_dir
			if walkable.call(next, self):
				target_cell = next
				moving = true
				_update_facing(intent_dir)
				_animate(true)

	if _hurt_flash > 0.0:
		_hurt_flash = maxf(0.0, _hurt_flash - delta)
		modulate = modulate.lerp(Color(1, 1, 1, 1), delta * 6.0)
	queue_redraw()


func _update_facing(d: Vector2i) -> void:
	if d.x > 0:
		facing = "right"
	elif d.x < 0:
		facing = "left"
	elif d.y < 0:
		facing = "up"
	elif d.y > 0:
		facing = "down"


func _animate(is_moving: bool) -> void:
	if sprite == null:
		return
	if is_moving:
		if not sprite.is_playing():
			sprite.play(facing)
		elif sprite.animation != facing:
			sprite.play(facing)
		sprite.speed_scale = 1.0 + speed_level * 0.12
	else:
		if sprite.animation != facing:
			sprite.animation = facing
		sprite.pause()
		sprite.frame = 0


func flash_hurt() -> void:
	modulate = Color(1.8, 0.6, 0.6, 1)
	_hurt_flash = 0.25


func die() -> void:
	alive = false
	deaths += 1
	visible = false
	moving = false
	intent_dir = Vector2i.ZERO


func revive_at(c: Vector2i) -> void:
	visible = true
	alive = true
	place_at(c)
	shield_until = _time + 1.6
	_spawn_anim = 0.6
	scale = Vector2(0.6, 0.6)


func _draw() -> void:
	if not alive:
		return
	if is_shielded():
		var a := 0.35 + 0.25 * sin(_time * 10.0)
		draw_arc(Vector2(0, 0), Pal.TILE * 0.52, 0, TAU, 28, Color(0.35, 0.85, 1.0, a), 3.0)
		draw_circle(Vector2(0, 0), Pal.TILE * 0.5, Color(0.35, 0.8, 1.0, 0.06))
