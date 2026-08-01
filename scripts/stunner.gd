class_name Stunner
extends Node2D
## Arena props that stun a charging Keeper:
## - "anemone": always armed; consumed on use, regrows after a while
## - "vent": armed for a few seconds after its valve is opened
## - "pipe": always armed; consumed on use, resonates back after a while

var kind := "anemone"
var armed := true
var stun_radius := 16.0
var _regrow := 0.0
var sprite: AnimatedSprite2D
var static_sprite: Sprite2D
var particles: CPUParticles2D

static func make(prop_kind: String, at: Vector2) -> Stunner:
	var s := Stunner.new()
	s.kind = prop_kind
	s.position = at
	return s

func _ready() -> void:
	add_to_group("stunners")
	z_index = 3
	match kind:
		"anemone":
			sprite = Sprites.animated("res://assets/anemone.png", 2, 2.5)
			add_child(sprite)
			stun_radius = 18.0
		"pipe":
			static_sprite = Sprite2D.new()
			static_sprite.texture = load("res://assets/organ_pipe.png")
			add_child(static_sprite)
			stun_radius = 20.0
		"vent":
			armed = false
			stun_radius = 24.0
			particles = CPUParticles2D.new()
			particles.texture = load("res://assets/bubble.png")
			particles.amount = 40
			particles.lifetime = 0.7
			particles.direction = Vector2.UP
			particles.initial_velocity_min = 180.0
			particles.initial_velocity_max = 260.0
			particles.spread = 8.0
			particles.emitting = false
			particles.emission_rect_extents = Vector2(14, 4)
			add_child(particles)

func arm_vent(duration: float) -> void:
	armed = true
	particles.emitting = true
	get_tree().create_timer(duration).timeout.connect(func() -> void:
		armed = false
		particles.emitting = false)

func consume() -> void:
	if kind == "vent":
		return  # vents stay live until their timer ends
	armed = false
	_regrow = 16.0
	if sprite:
		sprite.modulate.a = 0.25
	if static_sprite:
		static_sprite.modulate.a = 0.25

func _process(delta: float) -> void:
	if _regrow > 0.0:
		_regrow -= delta
		if _regrow <= 0.0:
			armed = true
			if sprite:
				sprite.modulate.a = 1.0
			if static_sprite:
				static_sprite.modulate.a = 1.0
