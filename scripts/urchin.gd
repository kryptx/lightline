class_name Urchin
extends Area2D
## Static hazard: brushing it costs light and spikes panic.

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 9.0
	shape.shape = circle
	add_child(shape)
	add_child(Sprites.animated("res://assets/urchin.png", 2, 2.0))
	body_entered.connect(_on_body)
	z_index = 5

func _on_body(body: Node2D) -> void:
	if body is Player:
		(body as Player).hurt(global_position)
