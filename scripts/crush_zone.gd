class_name CrushZone
extends Node2D
## The Throat's crushing timers: open water that clenches on a slow count.
## Warn, then crush — count the pulse, move between clenches.

var rect := Rect2()
var _phase := "safe"  # safe | warn | crush
var _timer := 0.0
var overlay: ColorRect

static func make(zone_rect: Rect2) -> CrushZone:
	var z := CrushZone.new()
	z.rect = zone_rect
	z.position = zone_rect.position
	return z

func _ready() -> void:
	overlay = ColorRect.new()
	overlay.size = rect.size
	overlay.color = Color(0.9, 0.2, 0.18, 0.0)
	overlay.z_index = 13
	add_child(overlay)
	_timer = randf_range(0.0, 3.2)  # desynchronize zones

func _process(delta: float) -> void:
	_timer -= delta
	var player := get_tree().get_first_node_in_group("player") as Player
	var player_near: bool = player != null and not player.dead \
			and rect.grow(380.0).has_point(player.global_position)
	match _phase:
		"safe":
			overlay.color.a = 0.0
			if _timer <= 0.0:
				_phase = "warn"
				_timer = 1.3
				if player_near:
					Sfx.play("crush_warn", -8.0)
		"warn":
			overlay.color.a = 0.10 + 0.10 * sin(Time.get_ticks_msec() / 40.0)
			if _timer <= 0.0:
				_phase = "crush"
				_timer = 0.7
				if player != null and not player.dead and rect.has_point(player.global_position):
					player.hurt(rect.get_center(), 16.0, "")
					player.add_panic(0.6)
					Sfx.play("crush_hit")
		"crush":
			overlay.color.a = 0.42
			if _timer <= 0.0:
				_phase = "safe"
				_timer = randf_range(2.8, 3.8)
