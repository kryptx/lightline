class_name Warden
extends Node2D
## The stalker of the Throat, present in every band-5 dive. It cannot be
## fought — only evaded. It sees light: a burning lamp is a road drawn
## straight to you; doused and slow you are a cold current. In the finale it
## herds you downward.

var species := "warden"
var mode := "stalk"  # stalk | chase (finale)
var _state := "circle"  # circle | approach | strike | retreat
var _timer := 0.0
var _vel := Vector2.ZERO
var _angle := 0.0
var _heart_t := 0.0
var sprite: AnimatedSprite2D
var eyes: PointLight2D

static func make(at: Vector2, chase := false) -> Warden:
	var w := Warden.new()
	w.position = at
	w.mode = "chase" if chase else "stalk"
	return w

func _ready() -> void:
	add_to_group("scannable")
	add_to_group("warden")
	z_index = 9
	sprite = AnimatedSprite2D.new()
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	var tex: Texture2D = load("res://assets/warden.png")
	var anims := ["a", "b", "strike"]
	for i in range(3):
		sf.add_animation(anims[i])
		var at_tex := AtlasTexture.new()
		at_tex.atlas = tex
		at_tex.region = Rect2(i * 72, 0, 72, 44)
		sf.add_frame(anims[i], at_tex)
	sprite.sprite_frames = sf
	sprite.play("a")
	add_child(sprite)
	eyes = PointLight2D.new()
	eyes.texture = load("res://assets/halo.png")
	eyes.scale = Vector2(0.2, 0.2)
	eyes.energy = 0.5
	eyes.color = Color(0.8, 0.95, 0.9)
	eyes.position = Vector2(28, 0)
	add_child(eyes)
	_timer = randf_range(4.0, 7.0)

## How clearly it can see you: the lamp is the giveaway.
func _visibility(player: Player) -> float:
	if player.doused:
		return 0.3
	if player.dark_pockets > 0:
		return 0.55
	return 1.0

func _process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Player
	if player == null or player.dead:
		return
	_timer -= delta
	var speed_scale := Game.fauna_speed_scale()
	var dist := position.distance_to(player.global_position)

	# an unmistakable heartbeat when it is near
	_heart_t -= delta
	var hear_range: float = 480.0 * (2.0 if Game.has_scan(species) else 1.0)
	if dist < hear_range and _heart_t <= 0.0:
		_heart_t = lerpf(0.7, 1.6, clampf(dist / hear_range, 0.0, 1.0))
		Sfx.play("warden_heart", lerpf(0.0, -18.0, clampf(dist / hear_range, 0.0, 1.0)))

	# animate: slow undulation, eyes toward prey
	sprite.play("strike" if _state == "strike" else ("a" if int(Time.get_ticks_msec() / 400.0) % 2 == 0 else "b"))
	var facing_left := player.global_position.x < position.x
	sprite.flip_h = facing_left
	eyes.position.x = -28 if facing_left else 28

	if mode == "chase":
		_chase(player, delta, speed_scale)
		return

	match _state:
		"circle":
			_angle += delta * 0.35
			var ring := player.global_position + Vector2(cos(_angle), sin(_angle) * 0.6) * 340.0
			_steer(ring, 90.0 * speed_scale, delta)
			if _timer <= 0.0:
				_state = "approach"
				_timer = 7.0
		"approach":
			# a flare is a brighter road than you are
			var target := player.global_position
			for f in get_tree().get_nodes_in_group("flares"):
				if position.distance_to((f as Node2D).global_position) < 320.0:
					target = (f as Node2D).global_position
					break
			var speed: float = 165.0 * _visibility(player) * speed_scale
			_steer(target, speed, delta)
			if dist < 30.0:
				_state = "strike"
				_timer = 0.4
			elif _timer <= 0.0:
				_state = "retreat"
				_timer = 3.0
		"strike":
			if _timer <= 0.0:
				if dist < 44.0:
					player.hurt(position, 22.0, species)
					player.add_panic(0.8)
					player.velocity += (player.global_position - position).normalized() * 420.0
					Sfx.play("warden_hit")
				_state = "retreat"
				_timer = 4.0
		"retreat":
			var away := player.global_position + (position - player.global_position).normalized() * 560.0
			_steer(away, 190.0 * speed_scale, delta)
			if _timer <= 0.0:
				_state = "circle"
				_timer = randf_range(5.0, 9.0)

## Finale: it descends behind you, always. Climbing back up means meeting it.
func _chase(player: Player, delta: float, speed_scale: float) -> void:
	var above := player.global_position + Vector2(sin(Time.get_ticks_msec() / 800.0) * 60.0, -170.0)
	var speed: float = 95.0 * speed_scale
	if position.y > above.y:
		speed = 40.0  # it never overtakes downward — it herds
	_steer(above, speed, delta)
	if position.distance_to(player.global_position) < 40.0:
		player.hurt(position, 18.0, species)
		player.add_panic(0.7)
		player.velocity += Vector2(0, 380.0)  # driven DOWN
		Sfx.play("warden_hit")
		position += Vector2(0, -140)

func _steer(target: Vector2, speed: float, delta: float) -> void:
	var desired := (target - position)
	desired = desired.normalized() * speed if desired.length() > 8.0 else Vector2.ZERO
	_vel = _vel.lerp(desired, 1.0 - exp(-1.4 * delta))
	position += _vel * delta
