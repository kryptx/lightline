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
# alpha systems
var doused := false          # lamp killed on purpose (F)
var strained := false        # below the suit's pressure rating
var dark_pockets := 0        # inside N darkness pockets (beam suppressed)
var scan_species := ""       # current scan target
var scan_progress := 0.0
var ability_cd := {"sonar": 0.0, "flare": 0.0, "anchor": 0.0}

var _dash_cd := 0.0
var _iframes := 0.0
var _warn_tick := 0.0
var _time := 0.0
var _auto_drift := 0.0
var _scan_tick_t := 0.0

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

func add_panic(amount: float) -> void:
	panic = minf(1.0, panic + amount * Game.panic_gain_scale())

func hurt(from_pos: Vector2, cost: float = HURT_LIGHT_COST, species := "") -> void:
	if _iframes > 0.0 or dead:
		return
	# knowing a creature blunts its worst surprise
	if species == "urchin" and Game.has_scan("urchin"):
		cost *= 0.5
	_iframes = 0.9
	light -= cost
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

	# momentum swimming: constant drag, input acceleration, soft cap.
	# The cap bleeds off gradually so dash bursts genuinely carry speed.
	velocity *= exp(-DRAG * delta)
	velocity += dir * ACCEL * delta
	var max_speed := Game.swim_speed()
	if velocity.length() > max_speed:
		velocity = velocity.lerp(velocity.normalized() * max_speed, 1.0 - exp(-2.6 * delta))

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

	if Input.is_action_just_pressed("douse"):
		doused = not doused
		Sfx.play("douse" if doused else "relight", -6.0)
		event_message.emit("You kill the light." if doused else "The light returns.")

	for slot in range(2):
		if Input.is_action_just_pressed("ability_%d" % (slot + 1)):
			_use_ability(slot)
	for id in ability_cd:
		ability_cd[id] = maxf(0.0, ability_cd[id] - delta)

	_update_scan(delta)

	move_and_slide()

	# the Lightline drains; cargo weight dims it faster.
	# a doused lamp sips a little less.
	var drain := drain_rate()
	if doused:
		drain *= 0.85
	light -= drain * delta
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
	# doused on purpose, or swallowed by a darkness pocket
	if doused:
		lamp.energy *= 0.05
		glow.energy = 0.12
	elif dark_pockets > 0:
		lamp.energy *= 0.16
		glow.energy = 0.3
	else:
		glow.energy = 0.55
	lamp.color = Color(1.0, lerpf(0.72, 0.94, frac), lerpf(0.5, 0.82, frac))
	bubbles.emitting = velocity.length() > 26.0 or reeling

func _die() -> void:
	if dead:
		return
	dead = true
	var reason: String
	if strained:
		reason = "The pressure crushed the light at %dm — the suit wasn't rated for it." % int(depth_m())
	elif total_weight() > Game.carry_capacity():
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

# ---------- abilities ----------
func _use_ability(slot: int) -> void:
	var id: String = Game.equipped[slot]
	if id == "" or Game.ability_rank(id) <= 0 or ability_cd.get(id, 0.0) > 0.0:
		return
	var rank := Game.ability_rank(id)
	match id:
		"sonar":
			ability_cd[id] = 8.0 if rank == 1 else 6.0
			light -= 1.5
			Sfx.play("sonar", -4.0)
			get_parent().do_sonar(rank)
		"flare":
			ability_cd[id] = 6.0
			light -= 1.0
			var dir := Vector2(-1.0 if sprite.flip_h else 1.0, -0.4)
			var flare := Flare.make(global_position + dir * 10.0, dir * 180.0 + velocity * 0.5, rank)
			get_parent().add_child(flare)
		"anchor":
			ability_cd[id] = 0.8
			get_parent().use_anchor(rank)

## Hold E in light range of a creature to scan it. Risky by design: you have
## to stay close, and a doused lamp can barely read anything.
func _update_scan(delta: float) -> void:
	var scanning := Input.is_action_pressed("interact") or (autopilot and auto_mode == "loot")
	if not scanning:
		_reset_scan()
		return
	var scan_range := Game.beam_radius() * 0.55
	if doused:
		scan_range = 34.0
	elif dark_pockets > 0:
		scan_range *= 0.4
	var target: Node2D = null
	var best := scan_range
	for node in get_tree().get_nodes_in_group("scannable"):
		var creature := node as Node2D
		if creature == null or not is_instance_valid(creature):
			continue
		if Game.has_scan(creature.species):
			continue
		var d := global_position.distance_to(creature.global_position)
		if d < best:
			best = d
			target = creature
	if target == null:
		_reset_scan()
		return
	if target.species != scan_species:
		scan_species = target.species
		scan_progress = 0.0
	scan_progress += delta / 1.6
	_scan_tick_t -= delta
	if _scan_tick_t <= 0.0:
		Sfx.play("scan_tick", -10.0)
		_scan_tick_t = 0.25
	if scan_progress >= 1.0:
		Game.record_scan(scan_species)
		Sfx.play("scan_done")
		event_message.emit("%s logged — %s" % [
			Game.SPECIES[scan_species].title, Game.SPECIES[scan_species].passive])
		_reset_scan()

func _reset_scan() -> void:
	scan_species = ""
	scan_progress = 0.0

# Demo/soak-test autopilot: plays the real loop — seeks pickups (the corpse
# net first), and reels for the surface when the return budget gets tight.
# "fight" mode plays a keeper arena: lure the charge across an armed stunner,
# then dash the exposed weakpoint.
var _auto_reel := false
var auto_mode := "loot"
var _valve_pressed := false
var _stuck_t := 0.0
var _unstick_until := 0.0
var _unstick_dir := Vector2.ZERO

func _autopilot_dir(delta: float) -> Vector2:
	if auto_mode == "fight":
		return _autopilot_fight(delta)
	return _autopilot_loot(delta)

func _autopilot_fight(delta: float) -> Vector2:
	_auto_drift += delta
	# blunder out of corners when wedged against geometry
	_stuck_t = _stuck_t + delta if velocity.length() < 14.0 else 0.0
	if _unstick_until > 0.0:
		_unstick_until -= delta
		return _unstick_dir
	if _stuck_t > 1.4:
		_stuck_t = 0.0
		_unstick_until = 0.6
		_unstick_dir = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
		return _unstick_dir
	if _valve_pressed:
		Input.action_release("interact")
		_valve_pressed = false
	# occasionally ping to exercise sonar in fight tests too
	if Game.ability_rank("sonar") > 0 and ability_cd.get("sonar", 0.0) <= 0.0:
		_use_ability(Game.equipped.find("sonar"))
	var keeper: Node2D = null
	var keeper_d := 1e12
	for k in get_tree().get_nodes_in_group("keepers"):
		var d: float = global_position.distance_to((k as Node2D).global_position)
		if d < keeper_d:
			keeper_d = d
			keeper = k
	if keeper == null:
		_auto_reel = true
		return Vector2(0, -1)
	if keeper.state == "stunned":
		var to_boss := (keeper.global_position - global_position)
		if to_boss.length() < 130.0 and _dash_cd <= 0.0:
			velocity += to_boss.normalized() * DASH_IMPULSE * 1.2
			_dash_cd = DASH_COOLDOWN
		return to_boss.normalized()
	# find an armed stunner in THIS keeper's arena; if none (bellringer), go
	# work a valve
	var prop: Node2D = null
	var best := 1e9
	for s in get_tree().get_nodes_in_group("stunners"):
		if not s.armed:
			continue
		if not (keeper as Keeper).arena.grow(80.0).has_point((s as Node2D).global_position):
			continue
		var d: float = keeper.global_position.distance_to(s.global_position)
		if d < best:
			best = d
			prop = s
	if prop == null:
		var dive := get_parent()
		if not dive.valves.is_empty():
			var valve: Node2D = null
			var vd := 1e12
			for v in dive.valves:
				var d: float = global_position.distance_to((v.node as Node2D).position)
				if d < vd:
					vd = d
					valve = v.node
			var to_valve := valve.position - global_position
			if to_valve.length() < 32.0:
				Input.action_press("interact")
				_valve_pressed = true
				return Vector2.ZERO
			return to_valve.normalized()
		return Vector2(sin(_auto_drift * 2.0), cos(_auto_drift * 1.7)).normalized() * 0.6
	# hover just past the prop so the charge crosses it
	var lure_pos: Vector2 = prop.global_position \
			+ (prop.global_position - keeper.global_position).normalized() * 46.0
	var to_lure := lure_pos - global_position
	if to_lure.length() <= 14.0:
		# the Cantor hunts noise: kick up a burst right here by the pipe
		if Keeper.CONFIG[keeper.id].target == "noise" and keeper.state == "idle" \
				and _dash_cd <= 0.0:
			velocity += (global_position - keeper.global_position).normalized() * DASH_IMPULSE
			_dash_cd = DASH_COOLDOWN
		return Vector2.ZERO
	return to_lure.normalized()

func _autopilot_loot(delta: float) -> Vector2:
	_auto_drift += delta
	if Game.ability_rank("sonar") > 0 and ability_cd.get("sonar", 0.0) <= 0.0 \
			and depth_m() > 30.0 and "sonar" in Game.equipped:
		_use_ability(Game.equipped.find("sonar"))
	# don't dive below the suit rating (greedy mode ignores even this)
	if not Game.greedy and global_position.y > get_parent().rated_max_y - 100.0:
		_auto_reel = true
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
			if p.is_in_group("logs"):
				d *= 0.35  # a recording is worth a detour
			if d < best:
				best = d
				target = p
	if target:
		return (target.global_position - global_position).normalized()
	var x := sin(_auto_drift * 1.4) * 0.8
	return Vector2(x, 1.0).normalized()
