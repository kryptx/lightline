class_name Eel
extends Node2D
## Band 2 pipe-dweller. Coils (a readable telegraph), then lunges out of its
## hole. Scanning it lengthens the telegraph — you learn to count to two.

var species := "eel"
var facing := 1  # +1 strikes rightward, -1 leftward
var _state := "lurk"  # lurk | coil | strike | retract
var _timer := 0.0
var _stagger := 0.0
var _hit_this_strike := false
var sprite: AnimatedSprite2D
var strike_area: Area2D

static func make(at: Vector2, face: int) -> Eel:
	var eel := Eel.new()
	eel.position = at
	eel.facing = face
	return eel

func _ready() -> void:
	add_to_group("scannable")
	z_index = 6
	sprite = AnimatedSprite2D.new()
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	for anim in ["lurk", "coil", "strike"]:
		sf.add_animation(anim)
	var tex: Texture2D = load("res://assets/eel.png")
	for i in range(3):
		var at_tex := AtlasTexture.new()
		at_tex.atlas = tex
		at_tex.region = Rect2(i * 28, 0, 28, 14)
		sf.add_frame(["lurk", "coil", "strike"][i], at_tex)
	sprite.sprite_frames = sf
	sprite.play("lurk")
	sprite.flip_h = facing < 0
	sprite.offset = Vector2(6 * facing, 0)
	add_child(sprite)

	strike_area = Area2D.new()
	strike_area.collision_layer = 0
	strike_area.collision_mask = 2
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(44, 14)
	shape.shape = rect
	shape.position = Vector2(22.0 * facing, 0)
	strike_area.add_child(shape)
	add_child(strike_area)

func stagger(t: float) -> void:
	_stagger = maxf(_stagger, t)
	if _state != "lurk":
		_state = "retract"
		_timer = 0.3

func _process(delta: float) -> void:
	if _stagger > 0.0:
		_stagger -= delta
		sprite.play("lurk")
		return
	var player := get_tree().get_first_node_in_group("player") as Player
	_timer -= delta
	match _state:
		"lurk":
			sprite.play("lurk")
			if player and not player.dead:
				var to_p := player.global_position - global_position
				if absf(to_p.y) < 26.0 and to_p.x * facing > 0 and absf(to_p.x) < 78.0:
					_state = "coil"
					# the scanned eel telegraphs half again as long
					_timer = (0.85 if Game.has_scan(species) else 0.55) / Game.fauna_speed_scale()
					sprite.play("coil")
		"coil":
			if _timer <= 0.0:
				_state = "strike"
				_timer = 0.32
				_hit_this_strike = false
				sprite.play("strike")
				Sfx.play("eel", -8.0)
		"strike":
			if not _hit_this_strike and player and not player.dead:
				for body in strike_area.get_overlapping_bodies():
					if body is Player:
						(body as Player).hurt(global_position, 7.0, species)
						_hit_this_strike = true
			if _timer <= 0.0:
				_state = "retract"
				_timer = 0.5
				sprite.play("coil")
		"retract":
			if _timer <= 0.0:
				_state = "lurk"
