class_name Choir
extends Node2D
## Band 3. Blind, sound-hunting. Speed is noise; stillness is a hymn they
## can't hear. Doused and slow, you are nothing to them.

const HEAR_RADIUS := 250.0
const HUNT_SPEED := 150.0
const DRIFT_SPEED := 14.0

var species := "choir"
var home := Vector2.ZERO
var _vel := Vector2.ZERO
var _heard_at := Vector2.ZERO
var _alert := 0.0     # rises with heard noise; hunts above 1.0
var _hunt_time := 0.0
var _stagger := 0.0
var _sing_timer := 3.0
var sprite: AnimatedSprite2D
var rings: Array = []  # [{radius, alpha}]

static func make(at: Vector2) -> Choir:
	var c := Choir.new()
	c.position = at
	c.home = at
	return c

func _ready() -> void:
	add_to_group("scannable")
	z_index = 6
	sprite = Sprites.animated("res://assets/choir.png", 4, 4.0)
	add_child(sprite)
	var area := Area2D.new()
	area.collision_layer = 0
	area.collision_mask = 2
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 10.0
	shape.shape = circle
	area.add_child(shape)
	add_child(area)
	area.body_entered.connect(_on_body)
	_sing_timer = randf_range(2.0, 5.0)

func stagger(t: float) -> void:
	_stagger = maxf(_stagger, t)
	_alert = 0.0
	_hunt_time = 0.0

func _process(delta: float) -> void:
	_update_rings(delta)
	_sing_timer -= delta
	if _sing_timer <= 0.0:
		_sing_timer = randf_range(3.5, 7.0)
		_sing()
	if _stagger > 0.0:
		_stagger -= delta
		return

	var player := get_tree().get_first_node_in_group("player") as Player
	if player and not player.dead:
		var dist := position.distance_to(player.global_position)
		var hear_radius := HEAR_RADIUS
		if player.doused:
			hear_radius *= 0.5
		if dist < hear_radius:
			# they hear speed, and they lunge at the splash of a dash
			var loudness: float = player.velocity.length() / Game.swim_speed()
			if loudness > 0.45:
				_alert += (loudness - 0.45) * 3.2 * delta * (hear_radius - dist) / hear_radius * 2.0
				_heard_at = player.global_position
		# flares fizz — the choir turns toward the sound
		for f in get_tree().get_nodes_in_group("flares"):
			var fd := position.distance_to((f as Node2D).global_position)
			if fd < hear_radius * 0.8:
				_alert += 0.8 * delta
				_heard_at = (f as Node2D).global_position

	_alert = maxf(0.0, _alert - 0.25 * delta)
	if _alert >= 1.0:
		_hunt_time = 2.6
		_alert = 0.0
		_sing()
		if player and player.has_method("add_panic"):
			var burst := 0.5
			if Game.has_scan(species):
				burst *= 0.5
			player.add_panic(burst)

	var target := home + Vector2(sin(Time.get_ticks_msec() / 1300.0 + home.y) * 24.0,
			sin(Time.get_ticks_msec() / 900.0 + home.x) * 14.0)
	var speed := DRIFT_SPEED
	if _hunt_time > 0.0:
		_hunt_time -= delta
		target = _heard_at
		speed = HUNT_SPEED * Game.fauna_speed_scale()
	var desired := (target - position)
	desired = desired.normalized() * speed if desired.length() > 6.0 else Vector2.ZERO
	_vel = _vel.lerp(desired, 1.0 - exp(-2.0 * delta))
	position += _vel * delta

func _sing() -> void:
	rings.append({"radius": 6.0, "alpha": 0.9})
	var player := get_tree().get_first_node_in_group("player") as Player
	if player and position.distance_to(player.global_position) < 420.0:
		Sfx.play("choir", -14.0)
	queue_redraw()

func _update_rings(delta: float) -> void:
	var alive := []
	for ring in rings:
		ring.radius += 90.0 * delta
		ring.alpha -= 0.5 * delta
		if ring.alpha > 0.0:
			alive.append(ring)
	rings = alive
	queue_redraw()

## The song is drawn as visible rings — sound-cue accessibility is built in;
## scanning the species makes the rings carry farther/brighter.
func _draw() -> void:
	var boost := 1.35 if Game.has_scan(species) else 1.0
	for ring in rings:
		draw_arc(Vector2.ZERO, ring.radius * boost, 0, TAU, 40,
				Color(0.75, 0.85, 0.9, ring.alpha * 0.5 * boost), 1.5)

func _on_body(body: Node2D) -> void:
	if body is Player:
		(body as Player).hurt(global_position, 11.0, species)
