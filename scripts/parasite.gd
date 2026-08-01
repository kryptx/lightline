class_name Parasite
extends Node2D
## Band 4 wick louse: drawn to a lit lamp, attaches, and drinks the Lightline.
## Dash to shake them off; a flare pulls the whole swarm away to burn.

const SEEK_RANGE := 130.0
const ATTACH_DIST := 12.0
const DRAIN_PER_S := 0.35

var species := "parasite"
var home := Vector2.ZERO
var state := "drift"  # drift | seek | attached | burn | scatter
var _vel := Vector2.ZERO
var _offset := Vector2.ZERO
var _scatter_t := 0.0
var _stagger := 0.0
var sprite: AnimatedSprite2D

static func make(at: Vector2) -> Parasite:
	var p := Parasite.new()
	p.position = at
	p.home = at
	return p

func _ready() -> void:
	add_to_group("scannable")
	z_index = 8
	sprite = Sprites.animated("res://assets/parasite.png", 4, 6.0)
	add_child(sprite)

func stagger(t: float) -> void:
	_stagger = maxf(_stagger, t)
	if state == "attached":
		_detach()

func _detach() -> void:
	var player := get_tree().get_first_node_in_group("player") as Player
	if player:
		player.parasites = maxi(0, player.parasites - 1)
	state = "scatter"
	_scatter_t = 3.0
	_vel = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized() * 120.0

func _process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Player
	if _stagger > 0.0:
		_stagger -= delta
		return
	var speed_scale := Game.fauna_speed_scale()

	# a flare outshines any diver: the swarm streams to it and burns
	if state != "burn":
		for f in get_tree().get_nodes_in_group("flares"):
			if position.distance_to((f as Node2D).global_position) < 220.0:
				if state == "attached":
					_detach()
				state = "burn"
				break

	match state:
		"drift":
			var target := home + Vector2(sin(Time.get_ticks_msec() / 700.0 + home.x) * 26.0,
					cos(Time.get_ticks_msec() / 900.0 + home.y) * 18.0)
			_steer(target, 22.0 * speed_scale, delta)
			if player and not player.dead and not player.doused \
					and position.distance_to(player.global_position) < SEEK_RANGE \
					and player.parasites < 5:
				state = "seek"
		"seek":
			if player == null or player.dead or player.doused:
				state = "drift"
				return
			_steer(player.global_position, 85.0 * speed_scale, delta)
			if position.distance_to(player.global_position) < ATTACH_DIST:
				state = "attached"
				_offset = Vector2(randf_range(-10, 10), randf_range(-8, 8))
				player.parasites += 1
				Sfx.play("parasite_on", -8.0)
				if player.parasites == 1:
					player.event_message.emit("Something is drinking the line — dash to shake it!")
		"attached":
			if player == null or player.dead:
				state = "drift"
				return
			position = player.global_position + _offset
			var sip := DRAIN_PER_S * (0.5 if Game.has_scan(species) else 1.0)
			player.light -= sip * Game.drain_scale() * delta
			# a hard kick throws them clear
			if player.velocity.length() > 300.0:
				_detach()
				Sfx.play("parasite_off", -8.0)
		"scatter":
			_scatter_t -= delta
			position += _vel * delta
			_vel *= exp(-1.2 * delta)
			if _scatter_t <= 0.0:
				home = position
				state = "drift"
		"burn":
			var flare: Node2D = null
			var best := 1e9
			for f in get_tree().get_nodes_in_group("flares"):
				var d: float = position.distance_to((f as Node2D).global_position)
				if d < best:
					best = d
					flare = f
			if flare == null:
				state = "drift"
				home = position
				return
			_steer(flare.global_position, 160.0, delta)
			if best < 12.0:
				queue_free()

func _steer(target: Vector2, speed: float, delta: float) -> void:
	var desired := (target - position)
	desired = desired.normalized() * speed if desired.length() > 3.0 else Vector2.ZERO
	_vel = _vel.lerp(desired, 1.0 - exp(-3.0 * delta))
	position += _vel * delta
