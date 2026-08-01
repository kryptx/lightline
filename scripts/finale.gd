extends Node2D
## The floor of the Throat: a fixed, authored final descent. The Warden herds
## you down; at the bottom, the chamber offers a genuine choice:
##   relight the lamp  ·  cut the line  ·  go down with it

const TILE := 32

const ENDINGS := {
	"relight": {
		"title": "THE LAMP, RELIT",
		"color": Color(0.32, 0.2, 0.05),
		"sting": "ending_relight",
		"text": "You set your light into the old socket, and the anchor drinks it the way dry rope drinks water. Far above, the great lamp stutters — then holds, brighter than you have ever seen it.\n\nThe leash is fed. The trench settles. The Warden circles once, slowly, like a dog lying back down.\n\nYou climb the line in darkness, hand over hand, and the lighthouse takes you in. Some keepers keep ships off the rocks. You keep something else, now, and the ledger has your name in it.\n\nFED. HELD.",
	},
	"cut": {
		"title": "THE LINE, CUT",
		"color": Color(0.04, 0.14, 0.16),
		"sting": "ending_cut",
		"text": "The knife takes three strokes. The last strand parts with a sound like a bell heard from underwater, and the line — your oxygen, your light, your way home — goes dark from the bottom up, a lamp dying floor by floor.\n\nAbove you, for the first time in three hundred years, the lighthouse goes out.\n\nSomething vast below exhales. Unheld. Unfed. Free — and so, at last, are you. You surface by feel, lungs burning, under stars you have never seen from this water, and the tower on the rock is only a tower.\n\nWhatever it does next, it does not do it on a leash. Neither do you.",
	},
	"descend": {
		"title": "DOWN, WITH IT",
		"color": Color(0.16, 0.03, 0.05),
		"sting": "ending_descend",
		"text": "Marlowe wrote that the mouth was patient the way only the very large are patient. She never wrote what it was waiting FOR.\n\nYou go down with your lamp still burning — the first light it has ever been offered freely — and the dark accepts.\n\nThe trench does not eat you. It reads you, the way you read her logs: slowly, out of order, keeping what it needs. Somewhere very far above, a bell rings in a drowned church, and the Choir sings the note they have always been holding, and the water forgets it was ever a wall.\n\nThe lighthouse stands empty. The lamp stays lit. Nobody feeds it anymore, and it wants for nothing, because the light it loved best is home.",
	},
}

var grid: Array[String] = []
var world_rows := 0
var player: Player
var hud: CanvasLayer
var warden: Warden
var tether: Line2D
var anchor_pos := Vector2.ZERO
var line_pos := Vector2.ZERO
var maw_pos := Vector2.ZERO
var maw_rect := Rect2()
var ending_running := false
# duck-typed surface the shared HUD expects
var current_band := 5
var max_depth_m := 1560.0
var sonar_pings: Array = []
var net_pickup: Pickup = null
var valves: Array = []
var rated_max_y := 1e12
var _hint_t := 0.0

func _ready() -> void:
	for chunk in Chunks.FINALE:
		for row in chunk:
			grid.append(row)
	world_rows = grid.size()
	var row_source: Array[int] = []
	for r in range(world_rows):
		row_source.append(4)  # throat basalt all the way down
	Worldgen.build_backdrop(self, world_rows, Chunks.COLS, false, Color(0.045, 0.055, 0.095))
	Worldgen.build_tiles_and_collision(self, grid, row_source)
	_spawn_set_pieces()
	_spawn_player()
	_build_tether()
	hud = preload("res://scripts/hud.gd").new()
	hud.setup(player, self)
	add_child(hud)
	hud.show_band_splash("THE FLOOR OF THE THROAT")
	Sfx.play_music("music_finale")
	Sfx.start_ambience()
	warden = Warden.make(player.position + Vector2(0, -240), true)
	add_child(warden)
	if Game.test_finale != "":
		player.autopilot = true
		player.auto_mode = "finale"
	if Game.shot_path != "":
		get_tree().create_timer(Game.shot_delay).timeout.connect(func() -> void:
			get_viewport().get_texture().get_image().save_png(Game.shot_path)
			get_tree().quit())

func _spawn_set_pieces() -> void:
	var maw_min_c := Chunks.COLS
	var maw_max_c := -1
	var maw_r := -1
	for r in range(world_rows):
		for c in range(Chunks.COLS):
			var pos := Vector2(c * TILE + TILE / 2.0, r * TILE + TILE / 2.0)
			match grid[r][c]:
				"x":
					pass  # merged below
				"v":
					add_child(GravityWell.make(pos))
				"a":
					var p := Pickup.make_air()
					p.position = pos
					add_child(p)
				"T":
					anchor_pos = pos
					var spr := Sprite2D.new()
					spr.texture = load("res://assets/lamp_anchor.png")
					spr.position = pos + Vector2(0, 6)
					spr.z_index = 4
					add_child(spr)
					var glow := PointLight2D.new()
					glow.texture = load("res://assets/halo.png")
					glow.position = pos
					glow.scale = Vector2(0.3, 0.3)
					glow.energy = 0.25
					glow.color = Color(0.9, 0.6, 0.4)
					add_child(glow)
				"Y":
					line_pos = pos
				"M":
					maw_min_c = mini(maw_min_c, c)
					maw_max_c = maxi(maw_max_c, c)
					maw_r = r
	# crush pinches
	for r in range(world_rows):
		var c := 0
		while c < Chunks.COLS:
			if grid[r][c] == "x":
				var start := c
				while c < Chunks.COLS and grid[r][c] == "x":
					c += 1
				add_child(CrushZone.make(Rect2(start * TILE, (r - 1) * TILE,
						(c - start) * TILE, TILE * 3)))
			else:
				c += 1
	# the taut line: runs from the ceiling down to the chamber floor
	if line_pos != Vector2.ZERO:
		var tex: Texture2D = load("res://assets/taut_line.png")
		var y := line_pos.y - 480.0
		while y < line_pos.y + 96.0:
			var seg := Sprite2D.new()
			seg.texture = tex
			seg.position = Vector2(line_pos.x, y)
			seg.z_index = 6
			add_child(seg)
			y += 32.0
		var hum := PointLight2D.new()
		hum.texture = load("res://assets/halo.png")
		hum.position = line_pos
		hum.scale = Vector2(0.5, 0.5)
		hum.energy = 0.5
		hum.color = Color(1.0, 0.85, 0.55)
		add_child(hum)
	# the maw
	if maw_r >= 0:
		maw_pos = Vector2((maw_min_c + maw_max_c + 1) * TILE / 2.0, maw_r * TILE + TILE / 2.0)
		maw_rect = Rect2((maw_min_c - 1) * TILE, maw_r * TILE - 20,
				(maw_max_c - maw_min_c + 3) * TILE, TILE + 40)
		var spr := Sprite2D.new()
		spr.texture = load("res://assets/maw.png")
		spr.position = maw_pos + Vector2(0, 10)
		spr.scale = Vector2((maw_max_c - maw_min_c + 3) * TILE / 128.0, 1.4)
		spr.z_index = 5
		add_child(spr)

func _spawn_player() -> void:
	player = Player.new()
	var spawn := Vector2(Chunks.COLS * TILE / 2.0, 72)
	for r in range(world_rows):
		var done := false
		for c in range(Chunks.COLS):
			if Worldgen.is_open(grid[r][c]):
				spawn = Vector2(c * TILE + TILE / 2.0, r * TILE + TILE / 2.0 + 8)
				done = true
				break
		if done:
			break
	player.position = spawn
	player.surface_y = -12480.0  # depth reads as continuing from the dive
	player.can_reel = false
	player.add_to_group("player")
	player.player_died.connect(_on_player_died)
	add_child(player)
	player.light = Game.max_light()
	player.event_message.emit("The line is too taut to reel. It only goes down now.")
	var cam := Camera2D.new()
	cam.zoom = Vector2(2, 2)
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 6.0
	cam.limit_left = 0
	cam.limit_right = Chunks.COLS * TILE
	cam.limit_top = -80
	cam.limit_bottom = world_rows * TILE
	player.add_child(cam)
	cam.make_current()

func _build_tether() -> void:
	tether = Line2D.new()
	tether.width = 2.0
	tether.default_color = Color(1.0, 0.87, 0.55, 0.8)
	tether.z_index = 9
	add_child(tether)

# duck-typed API the player/HUD expect from their parent world
func spawn_dropped(item: Dictionary, at: Vector2) -> void:
	var p := Pickup.make_dropped(item)
	p.position = at
	add_child(p)

func do_sonar(_rank: int) -> void:
	pass  # nothing down here answers a ping

func use_anchor(_rank: int) -> void:
	player.event_message.emit("The anchor line won't bite this deep.")

func _process(delta: float) -> void:
	if ending_running:
		return
	# taut tether: dead straight up and out of sight
	tether.points = PackedVector2Array([
		Vector2(player.global_position.x - 2, -200),
		player.global_position + Vector2(-2, -8),
	])
	_hint_t -= delta
	if player.dead:
		return
	# the three choices
	if line_pos != Vector2.ZERO and player.global_position.distance_to(line_pos) < 46.0:
		_offer("The line hums against the knife. Press E to cut it.", "cut")
	elif anchor_pos != Vector2.ZERO and player.global_position.distance_to(anchor_pos) < 46.0:
		_offer("The socket is cold and waiting. Press E to give the lamp your light.", "relight")
	if maw_rect.has_point(player.global_position):
		_run_ending("descend")

func _offer(hint: String, id: String) -> void:
	if _hint_t <= 0.0:
		player.event_message.emit(hint)
		_hint_t = 2.5
	if Input.is_action_just_pressed("interact"):
		_run_ending(id)

func _on_player_died(_reason: String) -> void:
	# death in the finale is not an ending: the line hauls you back wholesale.
	# Any dropped net snags at the iris — real dive-world coordinates, not
	# this scene's own map.
	Sfx.play("death")
	var net_pos := Vector2(Chunks.COLS * TILE / 2.0, maxf(Game.dive_floor_y - 96.0, 400.0))
	Game.record_death(net_pos, player.carried_salvage(),
			player.carried_relics(), max_depth_m, 0.0,
			"The floor of the Throat kept its counsel. The line dragged you home.")
	get_tree().create_timer(1.6).timeout.connect(func() -> void:
		Sfx.stop_music(0.5)
		get_tree().change_scene_to_file("res://scenes/Lighthouse.tscn"))

func _run_ending(id: String) -> void:
	if ending_running:
		return
	ending_running = true
	player.frozen = true
	Game.record_ending(id)
	Sfx.stop_music(1.0)
	Sfx.stop_ambience()
	var data: Dictionary = ENDINGS[id]
	Sfx.play(data.sting)

	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	var wash := ColorRect.new()
	wash.color = Color(data.color.r, data.color.g, data.color.b, 0.0)
	wash.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(wash)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.modulate.a = 0.0
	layer.add_child(center)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(640, 0)
	box.add_theme_constant_override("separation", 16)
	center.add_child(box)
	var title := Label.new()
	title.text = data.title
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.7))
	box.add_child(title)
	var text := Label.new()
	text.text = data.text
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_theme_font_size_override("font_size", 14)
	text.add_theme_color_override("font_color", Color(0.92, 0.92, 0.95))
	box.add_child(text)
	var credits := Label.new()
	credits.text = "\nL I G H T L I N E\n\na descent, for Marlowe\nendings found: %d of 3\n\n— the light —" % Game.endings_seen.size()
	credits.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	credits.add_theme_font_size_override("font_size", 12)
	credits.add_theme_color_override("font_color", Color(0.75, 0.8, 0.85))
	box.add_child(credits)
	var cont := Button.new()
	cont.text = "Surface, one way or another"
	cont.pressed.connect(func() -> void:
		Sfx.stop_music(0.5)
		get_tree().change_scene_to_file("res://scenes/Lighthouse.tscn"))
	box.add_child(cont)

	var tween := create_tween()
	tween.tween_property(wash, "color:a", 0.9, 2.2)
	tween.parallel().tween_property(center, "modulate:a", 1.0, 2.6)
	tween.tween_callback(func() -> void: Sfx.play_music("music_credits"))
	# demo runs pick their ending and leave on their own
	if Game.autoplay or Game.test_finale != "":
		get_tree().create_timer(4.0).timeout.connect(func() -> void:
			if Game.shot_path != "":
				get_viewport().get_texture().get_image().save_png(Game.shot_path)
			Sfx.stop_music(0.2)
			get_tree().change_scene_to_file("res://scenes/Lighthouse.tscn"))
