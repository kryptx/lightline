class_name Keeper
extends Node2D
## Set-piece band boss: 70% environment puzzle, 30% combat.
## It only exposes its weakpoint when a charge carries it into an armed
## "stunner" prop (anemone bed / live vent / organ pipe). While it's stunned,
## hit the weakpoint at dash speed. Three hits. Drops the pressure core.
##
## id 1 — the Dredge (charges at you; anemones stun it)
## id 2 — the Bellringer (valve-triggered vent columns stun it)
## id 3 — the Cantor (blind: charges your last NOISE; pipes stun it)

signal defeated(id: int)

const CONFIG := {
	1: {"sheet": "keeper_dredge.png", "w": 64, "h": 40, "hp": 3,
		"charge_speed": 340.0, "idle_speed": 46.0, "target": "player",
		"name": "THE DREDGE", "radius": 24.0},
	2: {"sheet": "keeper_bell.png", "w": 56, "h": 60, "hp": 3,
		"charge_speed": 300.0, "idle_speed": 40.0, "target": "player",
		"name": "THE BELLRINGER", "radius": 26.0},
	3: {"sheet": "keeper_cantor.png", "w": 40, "h": 60, "hp": 3,
		"charge_speed": 380.0, "idle_speed": 34.0, "target": "noise",
		"name": "THE CANTOR", "radius": 22.0},
}

var id := 1
var hp := 3
var arena := Rect2()
var state := "idle"  # idle | telegraph | charge | stunned | dying
var _timer := 0.0
var _vel := Vector2.ZERO
var _charge_dir := Vector2.ZERO
var _noise_pos := Vector2.ZERO
var _noise_fresh := false
var _hit_iframes := 0.0
var sprite: AnimatedSprite2D
var eye_light: PointLight2D

static func make(keeper_id: int, at: Vector2, arena_rect: Rect2) -> Keeper:
	var k := Keeper.new()
	k.id = keeper_id
	k.position = at
	k.arena = arena_rect
	return k

func _ready() -> void:
	add_to_group("keepers")
	var cfg: Dictionary = CONFIG[id]
	hp = cfg.hp
	z_index = 7
	sprite = AnimatedSprite2D.new()
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	var tex: Texture2D = load("res://assets/" + cfg.sheet)
	var anims := ["idle", "charge", "stunned"]
	for i in range(anims.size()):
		var anim: String = anims[i]
		sf.add_animation(anim)
		var at_tex := AtlasTexture.new()
		at_tex.atlas = tex
		at_tex.region = Rect2(i * cfg.w, 0, cfg.w, cfg.h)
		sf.add_frame(anim, at_tex)
	sprite.sprite_frames = sf
	sprite.play("idle")
	add_child(sprite)

	eye_light = PointLight2D.new()
	eye_light.texture = load("res://assets/halo.png")
	eye_light.scale = Vector2(0.3, 0.3)
	eye_light.color = Color(0.6, 1.0, 0.9)
	eye_light.energy = 0.0
	add_child(eye_light)

	# a faint presence-light so the boss reads in the dark
	var presence := PointLight2D.new()
	presence.texture = load("res://assets/halo.png")
	presence.scale = Vector2(0.8, 0.6)
	presence.energy = 0.35
	presence.color = Color(0.8, 0.6, 0.5) if id != 3 else Color(0.7, 0.75, 0.85)
	add_child(presence)

## The Cantor is blind — it charges the last loud thing it heard.
func hear_noise(at: Vector2) -> void:
	_noise_pos = at
	_noise_fresh = true

func _radius() -> float:
	return CONFIG[id].radius

func _process(delta: float) -> void:
	if state == "dying":
		return
	_hit_iframes = maxf(0.0, _hit_iframes - delta)
	var player := get_tree().get_first_node_in_group("player") as Player
	if player == null or player.dead:
		return
	_timer -= delta

	match state:
		"idle":
			sprite.play("idle")
			# leashed to its arena: stalks the intruder inside, guards otherwise
			var player_in_arena := arena.grow(60.0).has_point(player.global_position)
			var target := player.global_position if player_in_arena else arena.get_center()
			var desired: Vector2 = (target - position).normalized() * CONFIG[id].idle_speed
			if position.distance_to(target) < 30.0:
				desired = Vector2.ZERO
			_vel = _vel.lerp(desired, 1.0 - exp(-1.6 * delta))
			position += _vel * delta
			var ready_to_charge: bool = _timer <= 0.0 and player_in_arena
			if CONFIG[id].target == "noise":
				ready_to_charge = ready_to_charge and _noise_fresh
			if ready_to_charge and position.distance_to(player.global_position) < 420.0:
				_set_state("telegraph")
				_timer = 0.75
				Sfx.play("roar", -6.0)
		"telegraph":
			sprite.play("charge")
			sprite.offset.x = sin(Time.get_ticks_msec() / 30.0) * 2.0
			if _timer <= 0.0:
				sprite.offset.x = 0
				var target: Vector2 = player.global_position
				if CONFIG[id].target == "noise":
					target = _noise_pos
					_noise_fresh = false
				_charge_dir = (target - position).normalized()
				_set_state("charge")
				_timer = 1.5
		"charge":
			position += _charge_dir * CONFIG[id].charge_speed * delta
			sprite.flip_h = _charge_dir.x < 0.0
			# armed stunner in the path?
			for prop in get_tree().get_nodes_in_group("stunners"):
				if not prop.armed:
					continue
				if position.distance_to(prop.global_position) < _radius() + prop.stun_radius:
					prop.consume()
					_get_stunned()
					break
			if state == "charge" and (_timer <= 0.0 or not arena.grow(-8.0).has_point(position)):
				position = position.clamp(arena.position + Vector2.ONE * 20.0,
						arena.end - Vector2.ONE * 20.0)
				_set_state("idle")
				_timer = randf_range(0.8, 1.6)
		"stunned":
			sprite.play("stunned")
			eye_light.energy = 0.8 + sin(Time.get_ticks_msec() / 90.0) * 0.3
			if _timer <= 0.0:
				_set_state("idle")
				_timer = randf_range(0.6, 1.2)
				eye_light.energy = 0.0

	# contact
	var dist := position.distance_to(player.global_position)
	if dist < _radius() + 9.0:
		if state == "stunned":
			if player.velocity.length() > 240.0 and _hit_iframes <= 0.0:
				_take_hit(player)
		elif state != "telegraph":
			player.hurt(global_position, 9.0, "")

func _set_state(s: String) -> void:
	if Game.test_keeper > 0 and s != state:
		print("[keeper %d] %s -> %s  hp=%d" % [id, state, s, hp])
	state = s

func _get_stunned() -> void:
	_set_state("stunned")
	_timer = 5.0
	_vel = Vector2.ZERO
	Sfx.play("stun")
	if id == 2:
		Sfx.play("bell")

func _take_hit(player: Player) -> void:
	hp -= 1
	_hit_iframes = 1.0
	player.velocity = -player.velocity * 0.6
	Sfx.play("roar")
	sprite.modulate = Color(1.8, 1.0, 1.0)
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.4)
	player.event_message.emit("The keeper reels! (%d)" % hp)
	if hp <= 0:
		_die()
	else:
		_set_state("idle")
		_timer = 0.4
		eye_light.energy = 0.0

func _die() -> void:
	_set_state("dying")
	Sfx.play("roar", 2.0)
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color(0.3, 0.3, 0.35, 0.0), 1.6)
	tween.parallel().tween_property(self, "position",
			position + Vector2(0, 30), 1.6)
	tween.tween_callback(func() -> void:
		defeated.emit(id)
		queue_free())
