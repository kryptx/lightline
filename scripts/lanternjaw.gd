class_name Lanternjaw
extends Node2D
## Band 2 predator. Hides in the dark showing only a warm false light —
## indistinguishable from a friendly glow until you're close. Scanning it
## permanently tints its lure red for you.

const REVEAL_DIST := 78.0
const CHASE_SPEED := 118.0
const LOSE_DIST := 240.0

var species := "lanternjaw"
var home := Vector2.ZERO
var _vel := Vector2.ZERO
var _chasing := false
var _stagger := 0.0
var sprite: AnimatedSprite2D
var lure: PointLight2D
var body_area: Area2D

static func make(at: Vector2) -> Lanternjaw:
	var jaw := Lanternjaw.new()
	jaw.position = at
	jaw.home = at
	return jaw

func _ready() -> void:
	add_to_group("scannable")
	z_index = 6
	sprite = Sprites.animated("res://assets/lanternjaw.png", 4, 6.0)
	add_child(sprite)
	lure = PointLight2D.new()
	lure.texture = load("res://assets/halo.png")
	lure.scale = Vector2(0.24, 0.24)
	lure.energy = 0.65
	lure.position = Vector2(11, -6)
	add_child(lure)
	body_area = Area2D.new()
	body_area.collision_layer = 0
	body_area.collision_mask = 2
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 10.0
	shape.shape = circle
	body_area.add_child(shape)
	add_child(body_area)
	body_area.body_entered.connect(_on_body)

func stagger(t: float) -> void:
	_stagger = maxf(_stagger, t)
	_chasing = false

func _process(delta: float) -> void:
	# the lie: scanned divers see the lure burn red
	lure.color = Color(1.0, 0.35, 0.25) if Game.has_scan(species) else Color(1.0, 0.85, 0.55)
	lure.energy = 0.55 + 0.2 * sin(Time.get_ticks_msec() / 300.0)

	if _stagger > 0.0:
		_stagger -= delta
		_vel = _vel.lerp(Vector2.ZERO, 1.0 - exp(-4.0 * delta))
		position += _vel * delta
		return

	var player := get_tree().get_first_node_in_group("player") as Player
	var target := home
	var speed := 26.0
	if player and not player.dead:
		var dist := position.distance_to(player.global_position)
		# a flare is a better lie than the diver's lamp
		var flare := _nearest_flare()
		if flare != null:
			var fd := position.distance_to(flare.global_position)
			if fd < 300.0:
				if flare.repels:
					target = position + (position - flare.global_position)
					speed = CHASE_SPEED
				else:
					target = flare.global_position
					speed = CHASE_SPEED * 0.8
				_chasing = false
				_steer(target, speed, delta)
				return
		var sense_dist := REVEAL_DIST * (0.55 if player.doused else 1.0)
		if not _chasing and dist < sense_dist:
			_chasing = true
			if player.has_method("add_panic"):
				player.add_panic(0.20 if Game.has_scan(species) else 0.45)
		if _chasing:
			if dist > LOSE_DIST:
				_chasing = false
			else:
				target = player.global_position
				speed = CHASE_SPEED * Game.fauna_speed_scale()
	if not _chasing:
		target = home + Vector2(sin(Time.get_ticks_msec() / 900.0 + home.x) * 30.0, 0)
	_steer(target, speed, delta)

func _steer(target: Vector2, speed: float, delta: float) -> void:
	var desired := (target - position)
	desired = desired.normalized() * speed if desired.length() > 4.0 else Vector2.ZERO
	_vel = _vel.lerp(desired, 1.0 - exp(-2.2 * delta))
	position += _vel * delta
	if absf(_vel.x) > 4.0:
		sprite.flip_h = _vel.x < 0.0
		lure.position.x = -11 if sprite.flip_h else 11

func _nearest_flare() -> Node2D:
	var best: Node2D = null
	var best_d := 1e9
	for f in get_tree().get_nodes_in_group("flares"):
		var d: float = position.distance_to((f as Node2D).global_position)
		if d < best_d:
			best_d = d
			best = f
	return best

func _on_body(body: Node2D) -> void:
	if body is Player:
		(body as Player).hurt(global_position, 8.0, species)
