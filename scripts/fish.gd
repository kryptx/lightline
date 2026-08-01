class_name Fish
extends Node2D
## Passive Band 1 fauna: drifts around its home point, flees the diver a little.

var home := Vector2.ZERO
var species := "fish_teal"
var _target := Vector2.ZERO
var _speed := 40.0
var _vel := Vector2.ZERO
var _timer := 0.0
var sprite: AnimatedSprite2D

static func make(kind: String, at: Vector2) -> Fish:
	var f := Fish.new()
	f.position = at
	f.home = at
	f.species = kind
	f.sprite = Sprites.animated("res://assets/%s.png" % kind, 4, 7.0)
	f.add_child(f.sprite)
	f._speed = randf_range(30.0, 55.0)
	return f

func _ready() -> void:
	add_to_group("scannable")
	z_index = 4
	_pick_target()

func _pick_target() -> void:
	_target = home + Vector2(randf_range(-110, 110), randf_range(-50, 50))
	_timer = randf_range(1.5, 4.0)

func _process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0 or position.distance_to(_target) < 8.0:
		_pick_target()
	var desired := (_target - position).normalized() * _speed
	# shy: drift away from the diver when the beam gets close
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player and position.distance_to(player.global_position) < 70.0:
		desired += (position - player.global_position).normalized() * 70.0
	_vel = _vel.lerp(desired, 1.0 - exp(-2.5 * delta))
	position += _vel * delta
	if absf(_vel.x) > 4.0:
		sprite.flip_h = _vel.x < 0.0
