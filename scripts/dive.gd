extends Node2D
## A dive: assembles Band 1 from authored chunks, runs the loop, resolves
## banking or death, and manages the corpse-run net.

const TILE := 32
const WORLD_COLS := Chunks.COLS
const SURFACE_Y := 24.0

var rng := RandomNumberGenerator.new()
var grid: Array[String] = []
var world_rows := 0
var player: Player
var hud: CanvasLayer
var tether: Line2D
var tether_glow: Line2D
var net_pickup: Pickup = null
var net_was_pending := false
var net_recovered := false
var max_depth_m := 0.0
var dive_time := 0.0
var ending := false
var _shot_timer := -1.0

func _ready() -> void:
	rng.seed = hash("lightline") + Game.dive_count * 7919 + int(Time.get_ticks_usec() % 100000)
	_assemble_grid()
	_build_backdrop()
	_build_tiles_and_collision()
	_spawn_player()
	_spawn_entities()
	_spawn_net_if_pending()
	_build_tether()
	hud = preload("res://scripts/hud.gd").new()
	hud.setup(player, self)
	add_child(hud)
	Sfx.start_ambience()
	Sfx.play("splash", -4.0)
	if Game.autoplay:
		player.autopilot = true
	if Game.timescale != 1.0:
		Engine.time_scale = Game.timescale
	if Game.shot_path != "":
		_shot_timer = Game.shot_delay

# ---------- world assembly ----------
func _assemble_grid() -> void:
	var upper := Chunks.UPPER.duplicate()
	var lower := Chunks.LOWER.duplicate()
	_shuffle(upper)
	_shuffle(lower)
	var stack: Array = [Chunks.SURFACE]
	for i in range(3):
		stack.append(upper[i % upper.size()])
	for i in range(4):
		stack.append(lower[i % lower.size()])
	stack.append(Chunks.FLOOR)

	for chunk in stack:
		var mirror: bool = rng.randf() < 0.5 and chunk != Chunks.SURFACE
		for row_string in chunk:
			var row: String = row_string
			if mirror:
				row = _reverse(row)
			# enforce side walls
			row = "#" + row.substr(1, WORLD_COLS - 2) + "#"
			grid.append(row)
	world_rows = grid.size()
	_carve_seams()

func _shuffle(arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp

func _reverse(s: String) -> String:
	var out := ""
	for i in range(s.length() - 1, -1, -1):
		out += s[i]
	return out

func _is_open(ch: String) -> bool:
	return ch != "#"

## Guarantee a vertical passage at every chunk boundary.
func _carve_seams() -> void:
	for boundary in range(1, world_rows / Chunks.ROWS):
		var top_row := boundary * Chunks.ROWS - 1
		var bottom_row := boundary * Chunks.ROWS
		var connected := false
		for c in range(6, WORLD_COLS - 6):
			if _is_open(grid[top_row][c]) and _is_open(grid[bottom_row][c]):
				connected = true
				break
		if not connected:
			for c in range(17, 23):
				grid[top_row] = grid[top_row].substr(0, c) + "." + grid[top_row].substr(c + 1)
				grid[bottom_row] = grid[bottom_row].substr(0, c) + "." + grid[bottom_row].substr(c + 1)

func _build_backdrop() -> void:
	var world_h := world_rows * TILE
	# deep-water gradient behind everything
	var bg := Sprite2D.new()
	bg.texture = load("res://assets/water_gradient.png")
	bg.centered = false
	bg.scale = Vector2(WORLD_COLS * TILE / 16.0, (world_h + 400) / 1024.0)
	bg.z_index = -20
	add_child(bg)
	# night sky above the waterline
	var sky := ColorRect.new()
	sky.color = Color(0.09, 0.06, 0.16)
	sky.position = Vector2(-200, -420)
	sky.size = Vector2(WORLD_COLS * TILE + 400, 420 + SURFACE_Y - 8)
	sky.z_index = -19
	add_child(sky)
	# waterline shimmer
	var surf_tex: Texture2D = load("res://assets/surface.png")
	for i in range(WORLD_COLS * TILE / 64 + 1):
		var s := Sprite2D.new()
		s.texture = surf_tex
		s.centered = false
		s.position = Vector2(i * 64, SURFACE_Y - 8)
		s.z_index = -18
		add_child(s)
	# darkness — the beam is the game
	var cm := CanvasModulate.new()
	cm.color = Color(0.055, 0.075, 0.13)
	add_child(cm)
	# warm glow bleeding down from the surface, gone within the first chunk
	var sun := PointLight2D.new()
	sun.texture = load("res://assets/halo.png")
	sun.position = Vector2(WORLD_COLS * TILE / 2.0, -160)
	sun.scale = Vector2(9, 4.5)
	sun.energy = 0.75
	sun.color = Color(0.8, 0.76, 0.88)
	add_child(sun)

func _build_tiles_and_collision() -> void:
	var tiles := TileMapLayer.new()
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE, TILE)
	var src := TileSetAtlasSource.new()
	src.texture = load("res://assets/rock_tiles.png")
	src.texture_region_size = Vector2i(TILE, TILE)
	for i in range(4):
		src.create_tile(Vector2i(i, 0))
	ts.add_source(src, 0)
	tiles.tile_set = ts
	tiles.z_index = 0
	add_child(tiles)

	var body := StaticBody2D.new()
	body.collision_layer = 1
	add_child(body)

	for r in range(world_rows):
		var run_start := -1
		for c in range(WORLD_COLS + 1):
			var solid: bool = c < WORLD_COLS and grid[r][c] == "#"
			if solid:
				var open_above: bool = r > 0 and _is_open(grid[r - 1][c])
				var variant := 1 if open_above else (0 if (c * 7 + r * 13) % 3 != 0 else 2)
				if open_above and (c + r) % 5 == 0:
					variant = 3
				tiles.set_cell(Vector2i(c, r), 0, Vector2i(variant, 0))
				if run_start < 0:
					run_start = c
			elif run_start >= 0:
				var shape := CollisionShape2D.new()
				var rect := RectangleShape2D.new()
				var width := (c - run_start) * TILE
				rect.size = Vector2(width, TILE)
				shape.shape = rect
				shape.position = Vector2(run_start * TILE + width / 2.0, r * TILE + TILE / 2.0)
				body.add_child(shape)
				run_start = -1

func _spawn_player() -> void:
	player = Player.new()
	player.position = Vector2(WORLD_COLS * TILE / 2.0, 56)
	player.surface_y = SURFACE_Y
	player.add_to_group("player")
	player.player_died.connect(_on_player_died)
	add_child(player)

	var cam := Camera2D.new()
	cam.zoom = Vector2(2, 2)
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 6.0
	cam.limit_left = 0
	cam.limit_right = WORLD_COLS * TILE
	cam.limit_top = -260
	cam.limit_bottom = world_rows * TILE
	player.add_child(cam)
	cam.make_current()

func _spawn_entities() -> void:
	var species := ["fish_teal", "fish_rose"]
	for r in range(world_rows):
		for c in range(WORLD_COLS):
			var ch := grid[r][c]
			var pos := Vector2(c * TILE + TILE / 2.0, r * TILE + TILE / 2.0)
			var depth_frac := float(r) / world_rows
			match ch:
				"s":
					if rng.randf() < 0.65:
						var value := rng.randi_range(3, 6) + int(depth_frac * 8.0)
						var p := Pickup.make_salvage(value, rng.randi_range(0, 2))
						p.position = pos
						add_child(p)
				"r":
					if rng.randf() < 0.55:
						var p := Pickup.make_relic()
						p.position = pos
						add_child(p)
				"a":
					if rng.randf() < 0.7:
						var p := Pickup.make_air()
						p.position = pos
						add_child(p)
				"u":
					if rng.randf() < 0.8:
						var u := Urchin.new()
						u.position = pos
						add_child(u)
				"k":
					if rng.randf() < 0.9:
						var kelp := Sprites.animated("res://assets/kelp.png", 4, 4.0)
						kelp.position = pos + Vector2(rng.randf_range(-6, 6), TILE / 2.0 - 24)
						kelp.z_index = 2
						kelp.speed_scale = rng.randf_range(0.7, 1.2)
						add_child(kelp)
				"f":
					var count := rng.randi_range(3, 5)
					var kind: String = species[rng.randi_range(0, 1)]
					for i in range(count):
						add_child(Fish.make(kind, pos + Vector2(rng.randf_range(-40, 40), rng.randf_range(-24, 24))))

func _spawn_net_if_pending() -> void:
	var net := Game.take_pending_net()
	if net.is_empty():
		return
	net_was_pending = true
	net_pickup = Pickup.make_net(int(net.salvage), int(net.relics))
	net_pickup.position = Vector2(net.x, net.y)
	net_pickup.tree_exited.connect(func() -> void: net_recovered = true; net_pickup = null)
	add_child(net_pickup)

func _build_tether() -> void:
	tether_glow = Line2D.new()
	tether_glow.width = 7.0
	tether_glow.default_color = Color(1.0, 0.85, 0.5, 0.16)
	tether_glow.z_index = 8
	add_child(tether_glow)
	tether = Line2D.new()
	tether.width = 2.0
	tether.default_color = Color(1.0, 0.87, 0.55, 0.9)
	tether.z_index = 9
	add_child(tether)

func spawn_dropped(item: Dictionary, at: Vector2) -> void:
	if item.get("name", "") == "relic":
		var p := Pickup.make_relic()
		p.position = at
		add_child(p)
		return
	if item.get("name", "") == "your cargo net":
		var p := Pickup.make_net(int(item.salvage), int(item.relics))
		p.position = at
		add_child(p)
		return
	var p := Pickup.make_dropped(item)
	p.position = at
	add_child(p)

# ---------- per-frame ----------
func _process(delta: float) -> void:
	if ending:
		return
	dive_time += delta
	max_depth_m = maxf(max_depth_m, player.depth_m())
	_update_tether()

	if _shot_timer > 0.0:
		_shot_timer -= delta
		if _shot_timer <= 0.0:
			_take_shot()

	# surfacing with the tether pulled banks everything
	if player.global_position.y < SURFACE_Y + 12.0 and dive_time > 2.0 and not player.dead:
		_bank()

func _update_tether() -> void:
	var anchor := Vector2(Chunks.COLS * TILE / 2.0, -220)
	var attach := player.global_position + Vector2(-4, -8)
	var points := PackedVector2Array()
	var n := 14
	for i in range(n + 1):
		var t := float(i) / n
		var p := anchor.lerp(attach, t)
		# gentle sag and sway
		p.x += sin(t * PI) * 18.0 * sin(Time.get_ticks_msec() / 1400.0)
		p.x += sin(t * 9.0 + Time.get_ticks_msec() / 500.0) * 3.0 * t
		points.append(p)
	tether.points = points
	tether_glow.points = points
	var frac: float = player.light / Game.max_light()
	tether.default_color = Color(1.0, 0.6 + 0.3 * frac, 0.35 + 0.3 * frac, 0.35 + 0.6 * frac)
	tether_glow.default_color = Color(1.0, 0.8, 0.5, 0.05 + 0.18 * frac)

# ---------- outcomes ----------
func _bank() -> void:
	ending = true
	player.frozen = true
	Sfx.play("bank")
	Sfx.stop_ambience()
	Game.bank_dive(player.carried_salvage(), player.carried_relics(),
			max_depth_m, dive_time, net_recovered)
	_end_dive()

func _on_player_died(reason: String) -> void:
	ending = true
	Sfx.play("death")
	Sfx.stop_ambience()
	Game.record_death(player.global_position, player.carried_salvage(),
			player.carried_relics(), max_depth_m, dive_time, reason)
	_end_dive(1.6)

func _end_dive(delay := 1.0) -> void:
	var timer := get_tree().create_timer(delay)
	timer.timeout.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/Lighthouse.tscn"))

func _take_shot() -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png(Game.shot_path)
	get_tree().quit()
