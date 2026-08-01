class_name Flare
extends Node2D
## Thrown light: burns for a while, restores nothing, but predators are drawn
## to it (rank 3 "white flare": they flee it instead).

var repels := false
var _vel := Vector2.ZERO
var _life := 8.0
var light: PointLight2D
var sprite: AnimatedSprite2D
var _rises := false

static func make(at: Vector2, throw_vel: Vector2, rank: int) -> Flare:
	var f := Flare.new()
	f.position = at
	f._vel = throw_vel
	f._life = 8.0 if rank < 2 else 16.0
	f._rises = rank >= 2
	f.repels = rank >= 3
	return f

func _ready() -> void:
	add_to_group("flares")
	z_index = 7
	sprite = Sprites.animated("res://assets/flare.png", 3, 8.0)
	add_child(sprite)
	light = PointLight2D.new()
	light.texture = load("res://assets/halo.png")
	light.scale = Vector2(0.9, 0.9)
	add_child(light)
	Sfx.play("flare", -4.0)

func _process(delta: float) -> void:
	_life -= delta
	if _life <= 0.0:
		queue_free()
		return
	_vel *= exp(-1.6 * delta)
	_vel.y += (-14.0 if _rises else 26.0) * delta
	position += _vel * delta
	var frac := clampf(_life / 4.0, 0.0, 1.0)
	light.energy = (0.9 + randf_range(-0.1, 0.1)) * frac + 0.1
	light.color = Color(1.0, 1.0, 0.95) if repels else Color(1.0, 0.8, 0.5)
	sprite.modulate.a = clampf(_life, 0.0, 1.0)
