class_name Player
extends CharacterBody2D
## The diver: momentum swimming, the Lightline meter, cargo, reeling, panic.

signal light_changed(light: float, max_light: float)
signal cargo_changed
signal player_died(reason: String)
signal event_message(text: String)

const ACCEL := 950.0
const DRAG := 2.1
const DASH_IMPULSE := 330.0
const DASH_COOLDOWN := 0.9
const DASH_LIGHT_COST := 0.7
const HURT_LIGHT_COST := 6.0
const LOW_LIGHT_S := 14.0

var light: float
var panic := 0.0
var cargo: Array[Dictionary] = []
var reeling := false
var dead := false
var frozen := false
var autopilot := false
var surface_y := 24.0

var _dash_cd := 0.0
var _iframes := 0.0
var _warn_tick := 0.0
var _time := 0.0
var _auto_drift := 0.0

var sprite: AnimatedSprite2D
var lamp: PointLight2D
var glow: PointLight2D
var bubbles: CPUParticles2D

func _ready() -> void:
	light = Game.max_light()
	z_index = 10

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 9.0
	shape.shape = circle
	add_child(shape)
	collision_layer = 2
	collision_mask = 1

	sprite = AnimatedSprite2D.new()
	var sf := Sprites.frames_from_strip("res://assets/diver_swim.png", 6, 10.0, "swim")
	Sprites.frames_from_strip("res://assets/diver_idle.png", 4, 5.0, "idle", sf)
	Sprites.frames_from_strip("res://assets/diver_reel.png", 4, 9.0, "reel", sf)
	sprite.sprite_frames = sf
	sprite.play("idle")
	add_child(sprite)

	lamp = PointLight2D.new()
	lamp.texture = load("res://assets/halo.png")
	lamp.energy = 1.15
	add_child(lamp)
	_update_lamp_scale()

	glow = PointLight2D.new()
	glow.texture = load("res://assets/halo.png")
	glow.scale = Vector2(0.22, 0.22)
	glow.energy = 0.55
	glow.color = Color(1.0, 0.92, 0.75)
	add_child(glow)

	bubbles = CPUParticles2D.new()
	bubbles.texture = load("res://assets/bubble.png")
	bubbles.amount = 10
	bubbles.lifetime = 2.2
	bubbles.direction = Vector2.UP
	bubbles.gravity = Vector2(0, -34)
	bubbles.initial_velocity_min = 8.0
	bubbles.initial_velocity_max = 22.0
	bubbles.spread = 22.0
	bubbles.scale_amount_min = 0.4
	bubbles.scale_amount_max = 1.0
	bubbles.position = Vector2(-8, -6)
	add_child(bubbles)

func _update_lamp_scale() -> void:
	lamp.scale = Vector2.ONE * (Game.beam_radius() / 80.0)

# ---------- cargo ----------
func total_weight() -> float:
	var w := 0.0
	for item in cargo:
		w += item.weight
	return w

func carried_salvage() -> int:
	var v := 0
	for item in cargo:
		v += int(item.get("salvage", 0))
	return v

func carried_relics() -> int:
	var v := 0
	for item in cargo:
		v += int(item.get("relics", 0))
	return v

func add_cargo(item: Dictionary) -> void:
	cargo.append(item)
	cargo_changed.emit()

func drop_heaviest() -> Dictionary:
	if cargo.is_empty():
		return {}
	var heaviest_idx := 0
	for i in range(cargo.size()):
		if cargo[i].weight > cargo[heaviest_idx].weight:
			heaviest_idx = i
	var item: Dictionary = cargo[heaviest_idx]
	cargo.remove_at(heaviest_idx)
	cargo_changed.emit()
	Sfx.play("drop")
	return item

## Drain multiplier from cargo weight: every pickup is a bet.
func weight_factor() -> float:
	var w := total_weight()
	var cap := float(Game.carry_capacity())
	var f := 1.0 + 0.9 * w / cap
	if w > cap:
		f += 1.3 * (w - cap) / cap
	return f

func drain_rate() -> float:
	return weight_factor()

func depth_m() -> float:
	return maxf(0.0, (global_position.y - surface_y) / Game.PX_PER_M)

## Estimated seconds of light needed to reel back to the surface from here.
func return_cost_s() -> float:
	var dist := maxf(0.0, global_position.y - surface_y)
	return dist / Game.reel_speed() * drain_rate()

# ---------- light ----------
func restore_light(amount: float) -> void:
	light = minf(Game.max_light(), light + amount)
	light_changed.emit(light, Game.max_light())

func hurt(from_pos: Vector2) -> void:
	if _iframes > 0.0 or dead:
		return
	_iframes = 0.9
	light -= HURT_LIGHT_COST
	panic = minf(1.0, panic + 0.55 * Game.panic_gain_scale())
	velocity += (global_position - from_pos).normalized() * 240.0
	Sfx.play("hurt")
	sprite.modulate = Color(1.6, 0.7, 0.7)
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.35)

# ---------- main loop ----------
func _physics_process(delta: float) -> void:
	if dead or frozen:
		return
	_time += delta
	_dash_cd = maxf(0.0, _dash_cd - delta)
	_iframes = maxf(0.0, _iframes - delta)

	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	reeling = Input.is_action_pressed("tether")
	if autopilot:
		dir = _autopilot_dir(delta)
		reeling = _auto_reel

	# momentum swimming: constant drag, input acceleration, soft cap
	velocity *= exp(-DRAG * delta)
	velocity += dir * ACCEL * delta
	var max_speed := Game.swim_speed()
	if velocity.length() > max_speed:
		velocity = velocity.normalized() * max_speed

	if reeling:
		# pulling the tether: strong steady lift, reduced steering
		velocity.y = lerpf(velocity.y, -Game.reel_speed(), 1.0 - exp(-6.0 * delta))
		velocity.x = lerpf(velocity.x, dir.x * max_speed * 0.45, 1.0 - exp(-3.0 * delta))

	if Input.is_action_just_pressed("dash") and _dash_cd <= 0.0 and dir != Vector2.ZERO:
		velocity += dir * DASH_IMPULSE
		_dash_cd = DASH_COOLDOWN
		light -= DASH_LIGHT_COST
		Sfx.play("dash", -6.0)

	if Input.is_action_just_pressed("drop") and not cargo.is_empty():
		var item := drop_heaviest()
		event_message.emit("Dropped %s" % item.get("name", "cargo"))
		get_parent().spawn_dropped(item, global_position + Vector2(0, 14))

	move_and_slide()

	# the Lightline drains; cargo weight dims it faster
	light -= drain_rate() * delta
	light_changed.emit(light, Game.max_light())

	# panic creeps in when the light gutters low
	if light < LOW_LIGHT_S:
		panic = minf(1.0, panic + 0.16 * Game.panic_gain_scale() * delta)
		_warn_tick -= delta
		if _warn_tick <= 0.0:
			Sfx.play("warn", -8.0)
			_warn_tick = clampf(light / LOW_LIGHT_S, 0.15, 1.0)
	panic = maxf(0.0, panic - (0.10 + 0.018 * Game.stats.nerve) * delta)

	_animate(dir)

	if light <= 0.0:
		light = 0.0
		_die()

func _animate(dir: Vector2) -> void:
	var anim := "idle"
	if reeling and velocity.y < -40.0:
		anim = "reel"
	elif velocity.length() > 34.0:
		anim = "swim"
	if sprite.animation != anim:
		sprite.play(anim)
	if absf(velocity.x) > 12.0:
		sprite.flip_h = velocity.x < 0.0
	sprite.rotation = clampf(velocity.y * 0.0012, -0.35, 0.35) * (-1.0 if sprite.flip_h else 1.0)

	# the lamp flickers as the light dies
	var frac := light / Game.max_light()
	if frac < 0.2:
		lamp.energy = 0.6 + 0.65 * frac / 0.2 + randf_range(-0.18, 0.18)
	else:
		lamp.energy = 1.25 + sin(_time * 3.0) * 0.05
	lamp.color = Color(1.0, lerpf(0.72, 0.94, frac), lerpf(0.5, 0.82, frac))
	bubbles.emitting = velocity.length() > 26.0 or reeling

func _die() -> void:
	if dead:
		return
	dead = true
	var reason: String
	if total_weight() > Game.carry_capacity():
		reason = "Cargo weight exceeded your return budget at %dm." % int(depth_m())
	elif reeling:
		reason = "The line went dark on the way up, %dm short of the surface." % int(depth_m())
	else:
		reason = "The light ran out at %dm." % int(depth_m())
	sprite.play("idle")
	velocity = Vector2.ZERO
	var tween := create_tween()
	tween.tween_property(lamp, "energy", 0.0, 1.0)
	tween.parallel().tween_property(glow, "energy", 0.05, 1.0)
	player_died.emit(reason)

# Demo/soak-test autopilot: plays the real loop — seeks pickups (the corpse
# net first), and reels for the surface when the return budget gets tight.
var _auto_reel := false

func _autopilot_dir(delta: float) -> Vector2:
	_auto_drift += delta
	# bank when the margin closes (greedy mode never turns back, on purpose)
	if Game.greedy:
		_auto_reel = false
	elif _auto_reel or return_cost_s() > light - 14.0:
		_auto_reel = true
		return Vector2(sin(_auto_drift * 2.0) * 0.3, -1.0)
	var dive := get_parent()
	var target: Node2D = null
	if dive.net_pickup != null and is_instance_valid(dive.net_pickup):
		target = dive.net_pickup
	else:
		var best := 320.0
		for node in get_tree().get_nodes_in_group("pickups"):
			var p := node as Node2D
			if p == null or not is_instance_valid(p):
				continue
			var d := global_position.distance_to(p.global_position)
			if d < best:
				best = d
				target = p
	if target:
		return (target.global_position - global_position).normalized()
	var x := sin(_auto_drift * 1.4) * 0.8
	return Vector2(x, 1.0).normalized()
