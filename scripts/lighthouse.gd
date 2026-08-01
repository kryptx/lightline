extends Control
## The hub: spend salvage on the five body stats, read the dive ledger,
## and kit up for the next descent.

var stat_rows := {}
var salvage_label: Label
var relic_label: Label
var record_label: Label
var net_label: Label
var hint_label: Label
var dive_button: Button
var respec_button: Button
var lamp_glow: TextureRect
var _time := 0.0

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var bg := TextureRect.new()
	bg.texture = load("res://assets/lighthouse_bg.png")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	add_child(bg)

	lamp_glow = TextureRect.new()
	lamp_glow.texture = load("res://assets/halo.png")
	lamp_glow.custom_minimum_size = Vector2(220, 220)
	lamp_glow.position = Vector2(640 - 110, 170 - 110)
	lamp_glow.stretch_mode = TextureRect.STRETCH_SCALE
	lamp_glow.size = Vector2(220, 220)
	lamp_glow.modulate = Color(1.0, 0.9, 0.6, 0.5)
	add_child(lamp_glow)

	_build_panel()
	_build_ledger()
	_refresh()

	Engine.time_scale = 1.0
	if Game.shot_hub_path != "" and (Game.dive_count > 0 or not Game.autoplay):
		var timer := get_tree().create_timer(1.2)
		timer.timeout.connect(func() -> void:
			var img := get_viewport().get_texture().get_image()
			img.save_png(Game.shot_hub_path)
			get_tree().quit())
	elif Game.autoplay:
		var timer := get_tree().create_timer(0.6)
		timer.timeout.connect(_start_dive)

func _process(delta: float) -> void:
	_time += delta
	lamp_glow.modulate.a = 0.42 + sin(_time * 1.7) * 0.1

# ---------- layout ----------
func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.05, 0.10, 0.86)
	style.border_color = Color(0.85, 0.72, 0.45, 0.35)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(18)
	return style

func _build_panel() -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style())
	panel.position = Vector2(36, 36)
	panel.custom_minimum_size = Vector2(430, 648)
	add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)

	var title := Label.new()
	title.text = "L I G H T L I N E"
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.6))
	box.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "The lighthouse holds. The trench waits."
	subtitle.add_theme_font_size_override("font_size", 13)
	subtitle.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85))
	box.add_child(subtitle)

	box.add_child(HSeparator.new())

	salvage_label = _label(box, 17, Color(1.0, 0.88, 0.6))
	relic_label = _label(box, 17, Color(0.6, 0.95, 0.85))
	record_label = _label(box, 13, Color(0.7, 0.75, 0.85))

	box.add_child(HSeparator.new())

	var body_title := Label.new()
	body_title.text = "BODY — spend salvage"
	body_title.add_theme_font_size_override("font_size", 15)
	body_title.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95))
	box.add_child(body_title)

	for stat in Game.STAT_ORDER:
		box.add_child(_stat_row(stat))

	respec_button = Button.new()
	respec_button.text = "Respec (refund all, fee 10)"
	respec_button.add_theme_font_size_override("font_size", 12)
	respec_button.pressed.connect(func() -> void:
		if Game.respec():
			Sfx.play("ui")
			_refresh())
	box.add_child(respec_button)

	box.add_child(HSeparator.new())
	net_label = _label(box, 13, Color(1.0, 0.7, 0.5))
	net_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_label = _label(box, 13, Color(0.75, 0.85, 0.8))
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)

	dive_button = Button.new()
	dive_button.text = "▼   D I V E"
	dive_button.custom_minimum_size = Vector2(0, 52)
	dive_button.add_theme_font_size_override("font_size", 22)
	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = Color(0.72, 0.5, 0.16)
	btn_style.set_corner_radius_all(6)
	dive_button.add_theme_stylebox_override("normal", btn_style)
	var btn_hover := btn_style.duplicate()
	btn_hover.bg_color = Color(0.85, 0.62, 0.22)
	dive_button.add_theme_stylebox_override("hover", btn_hover)
	dive_button.pressed.connect(_start_dive)
	box.add_child(dive_button)

func _stat_row(stat: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var name_label := Label.new()
	name_label.text = Game.STAT_INFO[stat].title
	name_label.custom_minimum_size = Vector2(64, 0)
	name_label.add_theme_font_size_override("font_size", 15)
	row.add_child(name_label)

	var pips := HBoxContainer.new()
	pips.add_theme_constant_override("separation", 3)
	pips.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var pip_rects: Array = []
	for i in range(Game.MAX_RANK):
		var pip := ColorRect.new()
		pip.custom_minimum_size = Vector2(9, 12)
		pips.add_child(pip)
		pip_rects.append(pip)
	row.add_child(pips)

	var buy := Button.new()
	buy.custom_minimum_size = Vector2(96, 0)
	buy.add_theme_font_size_override("font_size", 13)
	buy.tooltip_text = Game.STAT_INFO[stat].desc
	buy.pressed.connect(func() -> void:
		if Game.buy_stat(stat):
			Sfx.play("upgrade")
			_refresh())
	row.add_child(buy)

	stat_rows[stat] = {"pips": pip_rects, "buy": buy}
	return row

func _label(parent: Control, size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	parent.add_child(l)
	return l

# ---------- ledger ----------
func _build_ledger() -> void:
	if Game.last_result.is_empty():
		return
	var result: Dictionary = Game.last_result
	Game.last_result = {}

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style())
	panel.custom_minimum_size = Vector2(480, 0)
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)

	var title := Label.new()
	title.add_theme_font_size_override("font_size", 24)
	if result.died:
		title.text = "THE LIGHT WENT OUT"
		title.add_theme_color_override("font_color", Color(1.0, 0.45, 0.35))
	else:
		title.text = "SURFACED — CARGO BANKED"
		title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.6))
	box.add_child(title)

	if result.died:
		var reason := _label(box, 14, Color(0.9, 0.85, 0.8))
		reason.text = result.reason
		reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_label(box, 14, Color(0.9, 0.9, 0.95)).text = "Lost with the net: %d salvage, %d relics" % [result.lost_salvage, result.lost_relics]
		_label(box, 14, Color(1.0, 0.88, 0.6)).text = "Survivor's stipend: +%d salvage" % result.salvage
		if not Game.pending_net.is_empty():
			var net_line := _label(box, 14, Color(1.0, 0.7, 0.5))
			net_line.text = "Your cargo net lies at %dm. It will hold for exactly one more dive." % int(Game.pending_net.depth_m)
			net_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	else:
		_label(box, 15, Color(1.0, 0.88, 0.6)).text = "+%d salvage banked" % result.salvage
		if result.relics > 0:
			_label(box, 15, Color(0.6, 0.95, 0.85)).text = "+%d relic%s banked" % [result.relics, "s" if result.relics != 1 else ""]
		if result.get("net_recovered", false):
			_label(box, 14, Color(1.0, 0.7, 0.5)).text = "Cargo net recovered — nothing left behind."
		_label(box, 13, Color(0.7, 0.75, 0.85)).text = "Deepest point: %dm   ·   dive time %d:%02d" % [int(result.depth_m), int(result.duration) / 60, int(result.duration) % 60]

	var hint := _label(box, 13, Color(0.75, 0.85, 0.8))
	hint.text = Game.next_goal_hint()
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var cont := Button.new()
	cont.text = "Back to the lamp room"
	cont.pressed.connect(func() -> void:
		Sfx.play("ui")
		dim.queue_free()
		center.queue_free())
	box.add_child(cont)

# ---------- state ----------
func _refresh() -> void:
	salvage_label.text = "Salvage  %d" % Game.salvage
	relic_label.text = "Relics  %d" % Game.relics
	record_label.text = "Dives %d   ·   deepest %dm   ·   lifetime banked %d" % [Game.dive_count, int(Game.best_depth_m), Game.total_banked]

	for stat in Game.STAT_ORDER:
		var rank: int = Game.stats[stat]
		var row: Dictionary = stat_rows[stat]
		for i in range(Game.MAX_RANK):
			var pip: ColorRect = row.pips[i]
			pip.color = Color(1.0, 0.84, 0.5) if i < rank else Color(1, 1, 1, 0.14)
		var buy: Button = row.buy
		if rank >= Game.MAX_RANK:
			buy.text = "MAX"
			buy.disabled = true
		else:
			buy.text = "▲ %d" % Game.stat_cost(stat)
			buy.disabled = not Game.can_buy(stat)

	respec_button.visible = Game.spent_on_stats() > 0
	respec_button.disabled = Game.salvage < Game.respec_cost()

	if Game.pending_net.is_empty():
		net_label.text = ""
		net_label.visible = false
	else:
		net_label.visible = true
		net_label.text = "⚓ Your cargo net waits at %dm with %d salvage and %d relics — it holds for one more dive." % [
			int(Game.pending_net.depth_m), int(Game.pending_net.salvage), int(Game.pending_net.relics)]

	hint_label.text = Game.next_goal_hint()

func _start_dive() -> void:
	Sfx.play("splash", -6.0)
	get_tree().change_scene_to_file("res://scenes/Dive.tscn")
