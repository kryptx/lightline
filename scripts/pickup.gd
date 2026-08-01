class_name Pickup
extends Area2D
## Anything the diver can grab: salvage, relics, air pockets, the corpse net.

var kind := "salvage"  # salvage | relic | air | net
var item := {}         # cargo entry for salvage/relic/net
var air_amount := 0.0
var _base_y := 0.0
var _phase := 0.0
var _taken := false

static func make_salvage(value: int, variant: int) -> Pickup:
	var p := Pickup.new()
	p.kind = "salvage"
	var names := ["scrap gear", "coin purse", "sealed bottle"]
	p.item = {"name": names[variant % 3], "weight": 1.0 + (variant % 2),
			"salvage": value, "relics": 0}
	var tex := AtlasTexture.new()
	tex.atlas = load("res://assets/salvage.png")
	tex.region = Rect2((variant % 3) * 14, 0, 14, 14)
	var spr := Sprite2D.new()
	spr.texture = tex
	p.add_child(spr)
	return p

static func make_relic() -> Pickup:
	var p := Pickup.new()
	p.kind = "relic"
	p.item = {"name": "relic", "weight": 5.0, "salvage": 0, "relics": 1}
	p.add_child(Sprites.animated("res://assets/relic.png", 4, 6.0))
	var light := PointLight2D.new()
	light.texture = load("res://assets/halo.png")
	light.scale = Vector2(0.35, 0.35)
	light.energy = 0.7
	light.color = Color(0.5, 0.95, 0.85)
	p.add_child(light)
	return p

static func make_air() -> Pickup:
	var p := Pickup.new()
	p.kind = "air"
	p.air_amount = 999.0  # resolved as a fraction on grab
	p.add_child(Sprites.animated("res://assets/air_pocket.png", 3, 4.0))
	var light := PointLight2D.new()
	light.texture = load("res://assets/halo.png")
	light.scale = Vector2(0.2, 0.2)
	light.energy = 0.4
	light.color = Color(0.65, 0.85, 1.0)
	p.add_child(light)
	return p

static func make_net(salvage: int, relics: int) -> Pickup:
	var p := Pickup.new()
	p.kind = "net"
	p.item = {"name": "your cargo net", "weight": 4.0, "salvage": salvage, "relics": relics}
	var spr := Sprite2D.new()
	spr.texture = load("res://assets/net.png")
	p.add_child(spr)
	var light := PointLight2D.new()
	light.texture = load("res://assets/halo.png")
	light.scale = Vector2(0.4, 0.4)
	light.energy = 0.6
	light.color = Color(1.0, 0.7, 0.5)
	p.add_child(light)
	return p

## Re-spawn for plain salvage the diver drops (relics and nets are rebuilt
## with their own factories by the dive scene).
static func make_dropped(dropped_item: Dictionary) -> Pickup:
	var p := Pickup.new()
	p.kind = "salvage"
	p.item = dropped_item
	var tex := AtlasTexture.new()
	tex.atlas = load("res://assets/salvage.png")
	tex.region = Rect2(0, 0, 14, 14)
	var spr := Sprite2D.new()
	spr.texture = tex
	p.add_child(spr)
	return p

func _ready() -> void:
	add_to_group("pickups")
	z_index = 5
	monitoring = true
	# Rosefin passive: you notice what they nose at — plain salvage glints
	if kind == "salvage" and Game.has_scan("fish_rose"):
		var glint := PointLight2D.new()
		glint.texture = load("res://assets/halo.png")
		glint.scale = Vector2(0.14, 0.14)
		glint.energy = 0.4
		glint.color = Color(1.0, 0.9, 0.7)
		add_child(glint)
	collision_layer = 0
	collision_mask = 2
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 13.0 if kind != "net" else 16.0
	shape.shape = circle
	add_child(shape)
	_base_y = position.y
	_phase = randf() * TAU
	body_entered.connect(_on_body)

func _process(delta: float) -> void:
	_phase += delta * 1.8
	position.y = _base_y + sin(_phase) * 2.0

func _on_body(body: Node2D) -> void:
	if _taken or not body is Player:
		return
	var player := body as Player
	if player.dead:
		return
	_taken = true
	match kind:
		"air":
			player.restore_light(Game.max_light() * 0.18)
			player.event_message.emit("Air pocket — the line brightens")
			Sfx.play("air")
		"relic":
			player.add_cargo(item.duplicate())
			player.event_message.emit("Relic secured — the light dims under its weight")
			Sfx.play("relic")
		"net":
			player.add_cargo(item.duplicate())
			player.event_message.emit("Cargo net recovered! (%d salvage, %d relics)"
					% [item.salvage, item.relics])
			Sfx.play("relic")
		_:
			player.add_cargo(item.duplicate())
			player.event_message.emit("+%d salvage (%s)" % [item.salvage, item.name])
			Sfx.play("pickup")
	queue_free()
