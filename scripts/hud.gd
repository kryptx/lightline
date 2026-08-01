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
var suit_label: Label
var message_label: Label
var vignette: TextureRect
var net_marker: TextureRect
var hint_label: Label
var scan_label: Label
var pressure_label: Label
var band_label: Label
var log_panel: PanelContainer
var log_title: Label
var log_text: Label
var ability_slots: Array = []  # [{panel, icon, key, cd_rect, rank}]
var ping_layer: Control
var _msg_tween: Tween
var _band_tween: Tween

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
	suit_label = _label(top, 13)

	# sonar pings draw under the labels
	ping_layer = Control.new()
	ping_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	ping_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ping_layer.draw.connect(_draw_pings)
	add_child(ping_layer)
	move_child(ping_layer, 1)

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
	hint_label.text = "WASD swim · SHIFT dash · hold SPACE reel & surface · G drop · E scan/use · F douse lamp · Q/R abilities"
	hint_label.add_theme_font_size_override("font_size", 12)
	hint_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.45))
	hint_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	hint_label.position = Vector2(16, -30)
	hint_label.anchor_top = 1.0
	hint_label.anchor_bottom = 1.0
	add_child(hint_label)

	scan_label = Label.new()
	scan_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	scan_label.anchor_top = 1.0
	scan_label.anchor_bottom = 1.0
	scan_label.position = Vector2(-140, -120)
	scan_label.custom_minimum_size = Vector2(280, 0)
	scan_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	scan_label.add_theme_font_size_override("font_size", 14)
	scan_label.add_theme_color_override("font_color", Color(0.6, 0.95, 0.85))
	scan_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	scan_label.add_theme_constant_override("outline_size", 3)
	add_child(scan_label)

	pressure_label = Label.new()
	pressure_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	pressure_label.anchor_left = 0.5
	pressure_label.anchor_right = 0.5
	pressure_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	pressure_label.position = Vector2(0, 52)
	pressure_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pressure_label.add_theme_font_size_override("font_size", 18)
	pressure_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.25))
	pressure_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	pressure_label.add_theme_constant_override("outline_size", 4)
	pressure_label.visible = false
	pressure_label.text = "HULL STRAINING — THE SUIT ISN'T RATED FOR THIS DEPTH"
	add_child(pressure_label)

	band_label = Label.new()
	band_label.set_anchors_preset(Control.PRESET_CENTER)
	band_label.anchor_left = 0.5
	band_label.anchor_right = 0.5
	band_label.anchor_top = 0.5
	band_label.anchor_bottom = 0.5
	band_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	band_label.position = Vector2(0, -120)
	band_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	band_label.add_theme_font_size_override("font_size", 34)
	band_label.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95))
	band_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	band_label.add_theme_constant_override("outline_size", 6)
	band_label.modulate.a = 0.0
	add_child(band_label)

	_build_ability_slots()
	_build_log_panel()

	player.event_message.connect(show_message)

func _build_ability_slots() -> void:
	var box := HBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	box.anchor_left = 1.0
	box.anchor_top = 1.0
	box.position = Vector2(-150, -76)
	box.add_theme_constant_override("separation", 10)
	add_child(box)
	for slot in range(2):
		var panel := Panel.new()
		panel.custom_minimum_size = Vector2(56, 56)
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.04, 0.05, 0.09, 0.85)
		style.border_color = Color(0.9, 0.8, 0.55, 0.4)
		style.set_border_width_all(1)
		style.set_corner_radius_all(6)
		panel.add_theme_stylebox_override("panel", style)
		box.add_child(panel)
		var icon := TextureRect.new()
		icon.position = Vector2(12, 8)
		icon.custom_minimum_size = Vector2(32, 32)
		icon.size = Vector2(32, 32)
		icon.stretch_mode = TextureRect.STRETCH_SCALE
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		panel.add_child(icon)
		var cd_rect := ColorRect.new()
		cd_rect.color = Color(0, 0, 0, 0.65)
		cd_rect.position = Vector2(2, 2)
		cd_rect.size = Vector2(52, 0)
		panel.add_child(cd_rect)
		var key := Label.new()
		key.text = "Q" if slot == 0 else "R"
		key.position = Vector2(4, 36)
		key.add_theme_font_size_override("font_size", 12)
		key.add_theme_color_override("font_color", Color(1.0, 0.88, 0.6))
		panel.add_child(key)
		var rank := Label.new()
		rank.position = Vector2(34, 36)
		rank.add_theme_font_size_override("font_size", 11)
		rank.add_theme_color_override("font_color", Color(0.6, 0.95, 0.85))
		panel.add_child(rank)
		ability_slots.append({"panel": panel, "icon": icon, "cd": cd_rect, "rank": rank})

## A small corner toast — never over the action; the Archive is for reading.
func _build_log_panel() -> void:
	log_panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.05, 0.10, 0.9)
	style.border_color = Color(0.5, 0.95, 0.85, 0.5)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(10)
	log_panel.add_theme_stylebox_override("panel", style)
	log_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	log_panel.anchor_left = 1.0
	log_panel.anchor_right = 1.0
	log_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	log_panel.position = Vector2(-336, 14)
	log_panel.custom_minimum_size = Vector2(320, 0)
	log_panel.visible = false
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	log_panel.add_child(box)
	log_title = Label.new()
	log_title.add_theme_font_size_override("font_size", 13)
	log_title.add_theme_color_override("font_color", Color(0.5, 0.95, 0.85))
	log_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(log_title)
	log_text = Label.new()
	log_text.add_theme_font_size_override("font_size", 11)
	log_text.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	log_text.text = "Recording archived — play it back at the lighthouse."
	log_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(log_text)
	add_child(log_panel)

func show_log(id: int) -> void:
	log_title.text = "⏺ " + Logs.ENTRIES[id].title
	log_panel.visible = true
	log_panel.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_interval(5.0)
	tween.tween_property(log_panel, "modulate:a", 0.0, 1.2)
	tween.tween_callback(func() -> void: log_panel.visible = false)

func show_band_splash(band_name: String) -> void:
	band_label.text = band_name
	if _band_tween:
		_band_tween.kill()
	_band_tween = create_tween()
	_band_tween.tween_property(band_label, "modulate:a", 1.0, 0.6)
	_band_tween.tween_interval(1.8)
	_band_tween.tween_property(band_label, "modulate:a", 0.0, 1.2)

func flash_message(text: String) -> void:
	show_message(text)

func _draw_pings() -> void:
	if player == null or dive == null:
		return
	var center := ping_layer.size / 2.0
	for ping in dive.sonar_pings:
		var pos: Vector2 = center + (ping.pos - player.global_position) * 2.0
		if pos.x < -20 or pos.y < -20 or pos.x > ping_layer.size.x + 20 or pos.y > ping_layer.size.y + 20:
			continue
		var alpha: float = clampf(ping.ttl / 3.5, 0.0, 1.0)
		var color := Color(1.0, 0.85, 0.5, alpha)
		if ping.kind == "threat":
			color = Color(1.0, 0.4, 0.35, alpha)
		elif ping.kind == "fauna":
			color = Color(0.6, 0.9, 0.85, alpha)
		ping_layer.draw_circle(pos, 3.0, color)
		ping_layer.draw_arc(pos, 6.0 + (1.0 - alpha) * 6.0, 0, TAU, 16, color, 1.0)

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

	if not player.can_reel:
		return_label.text = "The line only goes down now."
		return_label.add_theme_color_override("font_color", Color(1.0, 0.75, 0.4))
	else:
		var cost := player.return_cost_s()
		return_label.text = "Return budget  ≈%ds of light" % int(ceil(cost))
		if cost > player.light:
			return_label.text += "   — TOO DEEP, SHED WEIGHT"
			return_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.25))
		elif cost > player.light * 0.6:
			return_label.add_theme_color_override("font_color", Color(1.0, 0.75, 0.4))
		else:
			return_label.add_theme_color_override("font_color", Color(0.75, 0.95, 0.85))

	# wick lice on the line
	if player.parasites > 0:
		weight_label.text += "   ·   %d wick %s drinking — dash!" % [
			player.parasites, "louse" if player.parasites == 1 else "lice"]

	suit_label.text = "Suit %s   ·   %s" % [
		["", "I", "II", "III", "IV", "V"][Game.suit_tier],
		Game.BANDS[dive.current_band].name.capitalize()]

	# panic + dying light close in on the screen; the Warden reddens it
	var low_light := clampf(1.0 - player.light / 20.0, 0.0, 1.0)
	vignette.modulate.a = clampf(player.panic * 0.85 + low_light * 0.55, 0.0, 1.0)
	var dread := 0.0
	for warden_node in get_tree().get_nodes_in_group("warden"):
		var sense: float = 420.0 * (2.0 if Game.has_scan("warden") else 1.0)
		var d: float = player.global_position.distance_to((warden_node as Node2D).global_position)
		dread = maxf(dread, clampf(1.0 - d / sense, 0.0, 1.0))
	vignette.modulate = Color(1.0, 1.0 - dread * 0.6, 1.0 - dread * 0.6, vignette.modulate.a)
	if dread > 0.0:
		vignette.modulate.a = maxf(vignette.modulate.a, dread * 0.5 + sin(Time.get_ticks_msec() / 300.0) * 0.06)

	# scanning readout
	if player.scan_species != "":
		scan_label.text = "Scanning %s  %d%%" % [
			Game.SPECIES[player.scan_species].title, int(player.scan_progress * 100)]
	else:
		scan_label.text = ""

	# hull strain warning flashes
	pressure_label.visible = player.strained and int(Time.get_ticks_msec() / 260.0) % 2 == 0

	# ability slots
	for slot in range(2):
		var data: Dictionary = ability_slots[slot]
		var id: String = Game.equipped[slot]
		if id == "" or Game.ability_rank(id) <= 0:
			data.icon.texture = null
			data.rank.text = ""
			data.cd.size.y = 0
			continue
		data.icon.texture = load("res://assets/icon_%s.png" % id)
		data.rank.text = "★%d" % Game.ability_rank(id)
		var cd: float = player.ability_cd.get(id, 0.0)
		var cd_max := 8.0
		data.cd.size.y = 52.0 * clampf(cd / cd_max, 0.0, 1.0)

	ping_layer.queue_redraw()
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
