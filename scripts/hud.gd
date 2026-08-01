extends CanvasLayer
## In-dive HUD: the Lightline meter, depth, weight, cargo, return budget,
## panic vignette, event messages, corpse-net marker.

var player: Player
var dive: Node2D

var light_fill: ColorRect
var light_label: Label
var depth_label: Label
var weight_label: Label
var cargo_label: Label
var return_label: Label
var message_label: Label
var vignette: TextureRect
var net_marker: TextureRect
var hint_label: Label
var _msg_tween: Tween

const BAR_W := 260.0

func setup(p: Player, d: Node2D) -> void:
	player = p
	dive = d

func _ready() -> void:
	layer = 10

	vignette = TextureRect.new()
	vignette.texture = load("res://assets/vignette.png")
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.stretch_mode = TextureRect.STRETCH_SCALE
	vignette.modulate.a = 0.0
	add_child(vignette)

	var top := VBoxContainer.new()
	top.position = Vector2(16, 12)
	add_child(top)

	var bar_row := HBoxContainer.new()
	top.add_child(bar_row)
	var icon := TextureRect.new()
	icon.texture = load("res://assets/icon_light.png")
	icon.custom_minimum_size = Vector2(24, 24)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	bar_row.add_child(icon)
	var bar_bg := Panel.new()
	bar_bg.custom_minimum_size = Vector2(BAR_W + 4, 18)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.05, 0.09, 0.85)
	style.border_color = Color(0.9, 0.8, 0.55, 0.5)
	style.set_border_width_all(1)
	bar_bg.add_theme_stylebox_override("panel", style)
	bar_row.add_child(bar_bg)
	light_fill = ColorRect.new()
	light_fill.position = Vector2(2, 2)
	light_fill.size = Vector2(BAR_W, 14)
	light_fill.color = Color(1.0, 0.84, 0.5)
	bar_bg.add_child(light_fill)
	light_label = _label(bar_row, 14)

	depth_label = _label(top, 13)
	weight_label = _label(top, 13)
	cargo_label = _label(top, 13)
	return_label = _label(top, 13)

	message_label = Label.new()
	message_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	message_label.position = Vector2(0, 90)
	message_label.anchor_left = 0.5
	message_label.anchor_right = 0.5
	message_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.add_theme_font_size_override("font_size", 16)
	message_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.7))
	message_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	message_label.add_theme_constant_override("outline_size", 4)
	message_label.modulate.a = 0.0
	add_child(message_label)

	net_marker = TextureRect.new()
	net_marker.texture = load("res://assets/icon_net_marker.png")
	net_marker.custom_minimum_size = Vector2(28, 28)
	net_marker.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	net_marker.pivot_offset = Vector2(14, 14)
	net_marker.visible = false
	add_child(net_marker)

	hint_label = Label.new()
	hint_label.text = "WASD swim   ·   SHIFT dash   ·   hold SPACE reel in & surface   ·   G drop heaviest"
	hint_label.add_theme_font_size_override("font_size", 12)
	hint_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.45))
	hint_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	hint_label.position = Vector2(16, -30)
	hint_label.anchor_top = 1.0
	hint_label.anchor_bottom = 1.0
	add_child(hint_label)

	player.event_message.connect(show_message)

func _label(parent: Control, size: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 3)
	parent.add_child(l)
	return l

func show_message(text: String) -> void:
	message_label.text = text
	if _msg_tween:
		_msg_tween.kill()
	message_label.modulate.a = 1.0
	_msg_tween = create_tween()
	_msg_tween.tween_interval(1.4)
	_msg_tween.tween_property(message_label, "modulate:a", 0.0, 0.8)

func _process(_delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	var max_light := Game.max_light()
	var frac: float = clampf(player.light / max_light, 0.0, 1.0)
	light_fill.size.x = BAR_W * frac
	light_fill.color = Color(1.0, 0.84, 0.5).lerp(Color(1.0, 0.25, 0.2), 1.0 - frac)
	light_label.text = "%ds" % int(ceil(player.light))
	light_label.add_theme_color_override("font_color",
			Color(1, 1, 1) if frac > 0.25 else Color(1.0, 0.4, 0.35))

	depth_label.text = "Depth  %dm   (deepest %dm)" % [int(player.depth_m()), int(dive.max_depth_m)]

	var w := player.total_weight()
	var cap := Game.carry_capacity()
	weight_label.text = "Weight  %.0f / %d%s" % [w, cap, "   OVERLOADED — the light strains" if w > cap else ""]
	weight_label.add_theme_color_override("font_color",
			Color(1.0, 0.45, 0.35) if w > cap else Color(1, 1, 1))

	cargo_label.text = "Cargo  %d salvage   %d relics" % [player.carried_salvage(), player.carried_relics()]

	var cost := player.return_cost_s()
	return_label.text = "Return budget  ≈%ds of light" % int(ceil(cost))
	if cost > player.light:
		return_label.text += "   — TOO DEEP, SHED WEIGHT"
		return_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.25))
	elif cost > player.light * 0.6:
		return_label.add_theme_color_override("font_color", Color(1.0, 0.75, 0.4))
	else:
		return_label.add_theme_color_override("font_color", Color(0.75, 0.95, 0.85))

	# panic + dying light close in on the screen
	var low_light := clampf(1.0 - player.light / 20.0, 0.0, 1.0)
	vignette.modulate.a = clampf(player.panic * 0.85 + low_light * 0.55, 0.0, 1.0)

	_update_net_marker()

func _update_net_marker() -> void:
	var net: Node2D = dive.net_pickup
	if net == null or not is_instance_valid(net):
		net_marker.visible = false
		return
	net_marker.visible = true
	var screen_size := get_viewport().get_visible_rect().size
	var to_net := net.global_position - player.global_position
	var center := screen_size / 2.0
	var pos := center + to_net * 2.0  # camera zoom is 2x: screen px = world px * 2
	var margin := 40.0
	if pos.x < margin or pos.x > screen_size.x - margin or pos.y < margin or pos.y > screen_size.y - margin:
		pos = center + to_net.normalized() * (minf(center.x, center.y) - margin)
	net_marker.position = pos - Vector2(14, 14)
	net_marker.rotation = to_net.angle() - PI / 2.0
