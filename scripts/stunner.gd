class_name Stunner
extends Node2D
## Arena props that stun a charging Keeper:
## - "anemone": always armed; consumed on use, regrows after a while
## - "vent": armed for a few seconds after its valve is opened
## - "pipe": always armed; consumed on use, resonates back after a while
## - "bloom": opens/closes on its own slow heartbeat; a flare nearby snaps it
##   open at once. Armed only while open.

var kind := "anemone"
var armed := true
var stun_radius := 16.0
var _regrow := 0.0
var _bloom_t := 0.0
var _bloom_open := false
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
		"bloom":
			sprite = AnimatedSprite2D.new()
			var sf := SpriteFrames.new()
			sf.remove_animation("default")
			sf.add_animation("closed")
			sf.add_animation("open")
			var tex: Texture2D = load("res://assets/bloom.png")
			for i in range(2):
				var at_tex := AtlasTexture.new()
				at_tex.atlas = tex
				at_tex.region = Rect2(i * 26, 0, 26, 26)
				sf.add_frame(["closed", "open"][i], at_tex)
			sprite.sprite_frames = sf
			sprite.play("closed")
			add_child(sprite)
			var glow := PointLight2D.new()
			glow.texture = load("res://assets/halo.png")
			glow.scale = Vector2(0.22, 0.22)
			glow.energy = 0.0
			glow.color = Color(1.0, 0.75, 0.55)
			glow.name = "Glow"
			add_child(glow)
			armed = false
			stun_radius = 17.0
			_bloom_t = randf_range(0.0, 5.0)
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
	if kind == "bloom":
		_set_bloom(false)
		_bloom_t = 6.0  # dazed shut for a while
		return
	armed = false
	_regrow = 16.0
	if sprite:
		sprite.modulate.a = 0.25
	if static_sprite:
		static_sprite.modulate.a = 0.25

func _set_bloom(open: bool) -> void:
	_bloom_open = open
	armed = open
	sprite.play("open" if open else "closed")
	(get_node("Glow") as PointLight2D).energy = 0.6 if open else 0.0
	if open:
		Sfx.play("bloom", -10.0)

func _process(delta: float) -> void:
	if kind == "bloom":
		# a flare nearby forces it open at once
		var flared := false
		for f in get_tree().get_nodes_in_group("flares"):
			if position.distance_to((f as Node2D).global_position) < 130.0:
				flared = true
				break
		if flared and not _bloom_open:
			_set_bloom(true)
			_bloom_t = 6.0
			return
		_bloom_t -= delta
		if _bloom_t <= 0.0:
			_set_bloom(not _bloom_open)
			_bloom_t = 4.0 if _bloom_open else 5.5
		return
	if _regrow > 0.0:
		_regrow -= delta
		if _regrow <= 0.0:
			armed = true
			if sprite:
				sprite.modulate.a = 1.0
			if static_sprite:
				static_sprite.modulate.a = 1.0
