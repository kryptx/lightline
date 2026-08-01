extends Node2D
## A dive: assembles Bands 1–3 from authored chunks, runs the loop, resolves
## banking or death, and manages corpse net, keepers, logs, and the anchor.

const TILE := 32
const WORLD_COLS := Chunks.COLS
const SURFACE_Y := 24.0

var rng := RandomNumberGenerator.new()
var grid: Array[String] = []
var row_band: Array[int] = []   # band (1..3) per row
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
var current_band := 1
var strain_time := 0.0
var rated_max_y := 1e9
var sonar_pings: Array = []     # [{pos, kind, ttl}]
var anchor_node: Node2D = null
var gates := {}                 # keeper id -> StaticBody2D
var beacons := {}               # keeper id -> beacon dict
var _creak_t := 0.0
var _shot_timer := -1.0

func _ready() -> void:
	rng.seed = hash("lightline") + Game.dive_count * 7919 + int(Time.get_ticks_usec() % 100000)
	_assemble_grid()
	_build_backdrop()
	_build_tiles_and_collision()
	_spawn_player()
	_spawn_entities()
	_spawn_net_if_pending()
	_spawn_anchor_cache()
	_build_tether()
	hud = preload("res://scripts/hud.gd").new()
	hud.setup(player, self)
	add_child(hud)
	Sfx.start_ambience()
	Sfx.play("splash", -4.0)
	if Game.autoplay:
		player.autopilot = true
	if Game.test_keeper > 0:
		print("[dive] vents=%d valves=%d stunners=%d keepers=%d rated_max_y=%.0f player=%s" % [
			get_tree().get_nodes_in_group("vents").size(), valves.size(),
			get_tree().get_nodes_in_group("stunners").size(),
			get_tree().get_nodes_in_group("keepers").size(), rated_max_y,
			str(player.position)])
	if Game.timescale != 1.0:
		Engine.time_scale = Game.timescale
	if Game.shot_path != "":
		_shot_timer = Game.shot_delay

# ---------- world assembly ----------
func _assemble_grid() -> void:
	var upper := Chunks.UPPER.duplicate()
	var lower := Chunks.LOWER.duplicate()
	var band2 := Chunks.BAND2.duplicate()
	var band3 := Chunks.BAND3.duplicate()
	_shuffle(upper)
	_shuffle(lower)
	_shuffle(band2)
	_shuffle(band3)

	var stack: Array = []
	stack.append({"rows": Chunks.SURFACE, "band": 1, "mirror": false})
	for i in range(2):
		stack.append({"rows": upper[i % upper.size()], "band": 1, "mirror": true})
	for i in range(3):
		stack.append({"rows": lower[i % lower.size()], "band": 1, "mirror": true})
	stack.append({"rows": Chunks.ARENA1, "band": 1, "mirror": false})
	for i in range(4):
		stack.append({"rows": band2[i % band2.size()], "band": 2, "mirror": true})
	stack.append({"rows": Chunks.ARENA2, "band": 2, "mirror": false})
	for i in range(4):
		stack.append({"rows": band3[i % band3.size()], "band": 3, "mirror": true})
	stack.append({"rows": Chunks.ARENA3, "band": 3, "mirror": false})
	stack.append({"rows": Chunks.FLOOR3, "band": 3, "mirror": false})

	for entry in stack:
		var mirror: bool = entry.mirror and rng.randf() < 0.5
		for row_string in entry.rows:
			var row: String = row_string
			if mirror:
				row = _reverse(row)
			row = "#" + row.substr(1, WORLD_COLS - 2) + "#"
			grid.append(row)
			row_band.append(entry.band)
	world_rows = grid.size()
	_carve_seams()

	# how deep the suit is rated to go
	rated_max_y = 1e9
	for r in range(world_rows):
		if row_band[r] > Game.suit_tier:
			rated_max_y = r * TILE
			break

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
	var bg := Sprite2D.new()
	bg.texture = load("res://assets/water_gradient.png")
	bg.centered = false
	bg.scale = Vector2(WORLD_COLS * TILE / 16.0, (world_h + 400) / 1024.0)
	bg.z_index = -20
	add_child(bg)
	var sky := ColorRect.new()
	sky.color = Color(0.09, 0.06, 0.16)
	sky.position = Vector2(-200, -420)
	sky.size = Vector2(WORLD_COLS * TILE + 400, 420 + SURFACE_Y - 8)
	sky.z_index = -19
	add_child(sky)
	var surf_tex: Texture2D = load("res://assets/surface.png")
	for i in range(WORLD_COLS * TILE / 64 + 1):
		var s := Sprite2D.new()
		s.texture = surf_tex
		s.centered = false
		s.position = Vector2(i * 64, SURFACE_Y - 8)
		s.z_index = -18
		add_child(s)
	var cm := CanvasModulate.new()
	cm.color = Color(0.055, 0.075, 0.13)
	add_child(cm)
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
	var sheets := ["rock_tiles.png", "town_tiles.png", "cathedral_tiles.png"]
	for si in range(3):
		var src := TileSetAtlasSource.new()
		src.texture = load("res://assets/" + sheets[si])
		src.texture_region_size = Vector2i(TILE, TILE)
		for i in range(4):
			src.create_tile(Vector2i(i, 0))
		ts.add_source(src, si)
	tiles.tile_set = ts
	tiles.z_index = 0
	add_child(tiles)

	var body := StaticBody2D.new()
	body.collision_layer = 1
	add_child(body)

	for r in range(world_rows):
		var source := row_band[r] - 1
		var run_start := -1
		for c in range(WORLD_COLS + 1):
			var solid: bool = c < WORLD_COLS and grid[r][c] == "#"
			if solid:
				var open_above: bool = r > 0 and _is_open(grid[r - 1][c])
				var variant := 1 if open_above else (0 if (c * 7 + r * 13) % 3 != 0 else 2)
				if open_above and (c + r) % 5 == 0:
					variant = 3
				tiles.set_cell(Vector2i(c, r), source, Vector2i(variant, 0))
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
	if Game.test_keeper > 0:
		Game.spawn_depth_m = {1: 380.0, 2: 682.0, 3: 982.0}[Game.test_keeper]
	if Game.spawn_depth_m > 0.0:
		player.position.y = Game.spawn_depth_m * Game.PX_PER_M
		player.position = _nearest_open(player.position)
	if Game.test_keeper > 0:
		player.auto_mode = "fight"
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

func _cell_pos(c: int, r: int) -> Vector2:
	return Vector2(c * TILE + TILE / 2.0, r * TILE + TILE / 2.0)

func _spawn_entities() -> void:
	var species := ["fish_teal", "fish_rose"]
	var log_cells := {1: [], 2: [], 3: []}
	var arena_index := {}  # keeper id -> chunk start row
	for r in range(world_rows):
		var band := row_band[r]
		for c in range(WORLD_COLS):
			var ch := grid[r][c]
			var pos := _cell_pos(c, r)
			var depth_frac := float(r) / world_rows
			match ch:
				"s":
					if rng.randf() < 0.65:
						var value := rng.randi_range(3, 6) + int(depth_frac * 10.0) + (band - 1) * 3
						var p := Pickup.make_salvage(value, rng.randi_range(0, 2))
						p.position = pos
						add_child(p)
				"r":
					if rng.randf() < (0.55 + 0.1 * band):
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
				"j":
					if rng.randf() < 0.8:
						add_child(Lanternjaw.make(pos))
				"e":
					var face := 1 if c > 0 and grid[r][c - 1] == "#" else -1
					add_child(Eel.make(pos + Vector2(-10 * face, 0), face))
				"o":
					if rng.randf() < 0.85:
						add_child(Choir.make(pos))
				"D":
					_spawn_darkness(pos)
				"g":
					_spawn_glint(pos)
				"L":
					log_cells[band].append(pos)
				"A":
					add_child(Stunner.make("anemone", pos))
				"P":
					add_child(Stunner.make("pipe", pos))
				"V":
					_spawn_valve(pos, r)
				"N":
					var keeper_id := _keeper_for_row(r)
					_spawn_beacon(pos, keeper_id)
				"B":
					var keeper_id := _keeper_for_row(r)
					arena_index[keeper_id] = pos
				"G":
					pass  # handled as a block below
				"c", "C", "<", ">":
					pass  # merged into areas below

	_build_currents()
	_build_gates()
	_spawn_keepers(arena_index)
	_spawn_logs(log_cells)

func _keeper_for_row(r: int) -> int:
	return row_band[r]  # arena 1 sits in band 1, etc.

func _spawn_darkness(pos: Vector2) -> void:
	var area := Area2D.new()
	area.position = pos
	area.collision_layer = 0
	area.collision_mask = 2
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 96.0
	shape.shape = circle
	area.add_child(shape)
	var spr := Sprite2D.new()
	spr.texture = load("res://assets/darkness.png")
	spr.scale = Vector2(1.6, 1.6)
	spr.z_index = 12
	area.add_child(spr)
	area.body_entered.connect(func(b: Node2D) -> void:
		if b is Player:
			(b as Player).dark_pockets += 1)
	area.body_exited.connect(func(b: Node2D) -> void:
		if b is Player:
			(b as Player).dark_pockets = maxi(0, (b as Player).dark_pockets - 1))
	add_child(area)

func _spawn_glint(pos: Vector2) -> void:
	var light := PointLight2D.new()
	light.texture = load("res://assets/halo.png")
	light.position = pos
	light.scale = Vector2(0.16, 0.16)
	light.energy = 0.4
	light.color = Color(0.4, 0.9, 0.8) if rng.randf() < 0.7 else Color(0.9, 0.5, 0.6)
	add_child(light)

var valves: Array = []  # [{node, sprite, cooldown}]

func _spawn_valve(pos: Vector2, _r: int) -> void:
	var valve := Node2D.new()
	valve.position = pos
	var spr := Sprites.animated("res://assets/valve.png", 2, 0.0, false)
	valve.add_child(spr)
	var light := PointLight2D.new()
	light.texture = load("res://assets/halo.png")
	light.scale = Vector2(0.15, 0.15)
	light.energy = 0.35
	light.color = Color(1.0, 0.7, 0.4)
	valve.add_child(light)
	add_child(valve)
	valves.append({"node": valve, "sprite": spr, "cooldown": 0.0})

func _update_valves(delta: float) -> void:
	for valve in valves:
		valve.cooldown = maxf(0.0, valve.cooldown - delta)
		if valve.cooldown > 0.0 or player.dead:
			continue
		if Input.is_action_just_pressed("interact") \
				and valve.node.position.distance_to(player.global_position) < 40.0:
			valve.cooldown = 5.0
			var spr: AnimatedSprite2D = valve.sprite
			spr.frame = 1 - spr.frame
			if Game.test_keeper > 0:
				print("[dive] valve turned, arming %d vents" % get_tree().get_nodes_in_group("vents").size())
			Sfx.play("gate", -10.0)
			for vent in get_tree().get_nodes_in_group("vents"):
				vent.arm_vent(6.0)
			hud.flash_message("The vents breathe — put the keeper in the water's path!")

func _build_currents() -> void:
	# vertical currents: per-column runs of c (down) / C (up)
	for c in range(WORLD_COLS):
		var r := 0
		while r < world_rows:
			var ch := grid[r][c]
			if ch == "c" or ch == "C":
				var start := r
				while r < world_rows and grid[r][c] == ch:
					r += 1
				_make_current(Rect2(c * TILE, start * TILE, TILE, (r - start) * TILE),
						Vector2(0, 1 if ch == "c" else -1), row_band[start])
			else:
				r += 1
	# horizontal currents: per-row runs of < / >
	for r in range(world_rows):
		var c := 0
		while c < WORLD_COLS:
			var ch := grid[r][c]
			if ch == "<" or ch == ">":
				var start := c
				while c < WORLD_COLS and grid[r][c] == ch:
					c += 1
				_make_current(Rect2(start * TILE, r * TILE, (c - start) * TILE, TILE),
						Vector2(-1 if ch == "<" else 1, 0), row_band[r])
			else:
				c += 1

func _make_current(rect: Rect2, dir: Vector2, band: int) -> void:
	var area := Area2D.new()
	area.position = rect.get_center()
	area.collision_layer = 0
	area.collision_mask = 2
	area.add_to_group("currents")
	area.set_meta("dir", dir)
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = rect.size
	shape.shape = box
	area.add_child(shape)
	var particles := CPUParticles2D.new()
	particles.texture = load("res://assets/bubble.png")
	particles.amount = int(maxf(6.0, rect.size.length() / 22.0))
	particles.lifetime = 1.3
	particles.direction = dir
	particles.spread = 7.0
	particles.initial_velocity_min = 90.0
	particles.initial_velocity_max = 150.0
	particles.emission_rect_extents = rect.size / 2.0
	particles.modulate = Color(1, 1, 1, 0.35)
	area.add_child(particles)
	# in arena 2 the vertical columns double as the bell-vents
	if band == 2 and dir.y != 0 and rect.size.y > TILE * 8:
		for i in range(4):
			var vent := Stunner.make("vent", Vector2(rect.get_center().x,
					rect.position.y + rect.size.y * (0.12 + 0.25 * i)))
			vent.add_to_group("vents")
			add_child(vent)
	add_child(area)

func _build_gates() -> void:
	# each arena's G-block becomes one slab; open if that keeper is dead
	var seen := {}
	for r in range(world_rows):
		for c in range(WORLD_COLS):
			if grid[r][c] != "G":
				continue
			var keeper_id := _keeper_for_row(r)
			if seen.has(keeper_id):
				continue
			seen[keeper_id] = true
			# bounding box of this gate block
			var min_c := c
			var max_c := c
			var min_r := r
			var max_r := r
			for rr in range(r, mini(r + 4, world_rows)):
				for cc in range(WORLD_COLS):
					if grid[rr][cc] == "G" and _keeper_for_row(rr) == keeper_id:
						min_c = mini(min_c, cc)
						max_c = maxi(max_c, cc)
						max_r = maxi(max_r, rr)
			if Game.keeper_defeated(keeper_id):
				continue
			var gate := StaticBody2D.new()
			gate.collision_layer = 1
			var shape := CollisionShape2D.new()
			var rect := RectangleShape2D.new()
			rect.size = Vector2((max_c - min_c + 1) * TILE, (max_r - min_r + 1) * TILE)
			shape.shape = rect
			gate.position = Vector2((min_c + max_c + 1) * TILE / 2.0, (min_r + max_r + 1) * TILE / 2.0)
			gate.add_child(shape)
			var spr := Sprite2D.new()
			spr.texture = load("res://assets/gate.png")
			spr.scale = Vector2(rect.size.x / 96.0, rect.size.y / 20.0)
			gate.add_child(spr)
			var glow := PointLight2D.new()
			glow.texture = load("res://assets/halo.png")
			glow.scale = Vector2(0.5, 0.2)
			glow.energy = 0.3
			glow.color = Color(0.5, 0.95, 0.85)
			gate.add_child(glow)
			add_child(gate)
			gates[keeper_id] = gate

func _spawn_keepers(spawns: Dictionary) -> void:
	for keeper_id in spawns:
		if Game.keeper_defeated(keeper_id):
			continue
		var pos: Vector2 = spawns[keeper_id]
		var chunk_start := int(pos.y / TILE) / Chunks.ROWS * Chunks.ROWS
		var arena_rect := Rect2(2 * TILE, chunk_start * TILE + TILE,
				(WORLD_COLS - 4) * TILE, (Chunks.ROWS - 3) * TILE)
		var keeper := Keeper.make(keeper_id, pos, arena_rect)
		keeper.defeated.connect(_on_keeper_defeated)
		add_child(keeper)

func _spawn_beacon(pos: Vector2, keeper_id: int) -> void:
	var active := Game.keeper_defeated(keeper_id)
	var beacon := Area2D.new()
	beacon.position = pos
	beacon.collision_layer = 0
	beacon.collision_mask = 2
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 22.0
	shape.shape = circle
	beacon.add_child(shape)
	var spr := Sprites.animated("res://assets/beacon.png", 2, 3.0)
	beacon.add_child(spr)
	var light := PointLight2D.new()
	light.texture = load("res://assets/halo.png")
	light.scale = Vector2(0.8, 0.8)
	light.color = Color(1.0, 0.85, 0.6)
	light.energy = 0.9 if active else 0.0
	beacon.add_child(light)
	spr.modulate = Color.WHITE if active else Color(0.4, 0.42, 0.5)
	beacon.set_meta("active", active)
	beacon.set_meta("cooldown", 0.0)
	beacon.body_entered.connect(func(b: Node2D) -> void:
		if b is Player and beacon.get_meta("active") and beacon.get_meta("cooldown") <= 0.0:
			beacon.set_meta("cooldown", 8.0)
			get_tree().create_timer(8.0).timeout.connect(func() -> void:
				beacon.set_meta("cooldown", 0.0))
			(b as Player).restore_light(Game.max_light())
			(b as Player).panic = 0.0
			Sfx.play("relight")
			hud.flash_message("The beacon steadies your line — light restored."))
	add_child(beacon)
	beacons[keeper_id] = {"node": beacon, "light": light, "sprite": spr}

func _spawn_logs(log_cells: Dictionary) -> void:
	for band in log_cells:
		if Game.autoplay:
			print("[logs] band %d: %d cells, suit %d, next log %d" % [
				band, log_cells[band].size(), Game.suit_tier, Game.next_log_for_band(band)])
		if band > Game.suit_tier:
			continue
		var cells: Array = log_cells[band]
		if cells.is_empty():
			continue
		var log_id: int = Game.next_log_for_band(band)
		if log_id < 0:
			continue
		var pos: Vector2 = cells[rng.randi_range(0, cells.size() - 1)]
		var log_area := Area2D.new()
		log_area.add_to_group("pickups")  # sonar pings recordings too
		log_area.add_to_group("logs")
		log_area.position = pos
		log_area.collision_layer = 0
		log_area.collision_mask = 2
		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = 14.0
		shape.shape = circle
		log_area.add_child(shape)
		log_area.add_child(Sprites.animated("res://assets/log_device.png", 2, 2.0))
		var light := PointLight2D.new()
		light.texture = load("res://assets/halo.png")
		light.scale = Vector2(0.18, 0.18)
		light.energy = 0.5
		light.color = Color(0.5, 0.95, 0.85)
		log_area.add_child(light)
		log_area.body_entered.connect(func(b: Node2D) -> void:
			if b is Player and not (b as Player).dead:
				Game.record_log(log_id)
				Sfx.play("log")
				hud.show_log(log_id)
				log_area.queue_free())
		add_child(log_area)

func _spawn_net_if_pending() -> void:
	var net := Game.take_pending_net()
	if net.is_empty():
		return
	net_was_pending = true
	net_pickup = Pickup.make_net(int(net.salvage), int(net.relics))
	net_pickup.position = _nearest_open(Vector2(net.x, net.y))
	net_pickup.tree_exited.connect(func() -> void: net_recovered = true; net_pickup = null)
	add_child(net_pickup)

func _spawn_anchor_cache() -> void:
	if Game.anchor_stash.is_empty():
		return
	var stash: Dictionary = Game.anchor_stash
	var cache := Pickup.new()
	cache.kind = "net"
	cache.item = {"name": "anchored haul", "weight": 4.0,
			"salvage": int(stash.salvage), "relics": int(stash.relics)}
	var spr := Sprite2D.new()
	spr.texture = load("res://assets/anchor_item.png")
	cache.add_child(spr)
	var light := PointLight2D.new()
	light.texture = load("res://assets/halo.png")
	light.scale = Vector2(0.3, 0.3)
	light.energy = 0.5
	light.color = Color(0.7, 0.85, 1.0)
	cache.add_child(light)
	cache.position = _nearest_open(Vector2(stash.x, stash.y))
	cache.tree_exited.connect(func() -> void:
		Game.anchor_stash = {}
		Game.save_game())
	add_child(cache)

func _nearest_open(pos: Vector2) -> Vector2:
	var c := clampi(int(pos.x / TILE), 1, WORLD_COLS - 2)
	var r := clampi(int(pos.y / TILE), 1, world_rows - 2)
	if _is_open(grid[r][c]):
		return pos
	for radius in range(1, 10):
		for dr in range(-radius, radius + 1):
			for dc in range(-radius, radius + 1):
				var rr := clampi(r + dr, 1, world_rows - 2)
				var cc := clampi(c + dc, 1, WORLD_COLS - 2)
				if _is_open(grid[rr][cc]):
					return _cell_pos(cc, rr)
	return pos

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
	if item.get("name", "") in ["your cargo net", "anchored haul"]:
		var p := Pickup.make_net(int(item.salvage), int(item.relics))
		p.position = at
		add_child(p)
		return
	var p := Pickup.make_dropped(item)
	p.position = at
	add_child(p)

# ---------- abilities from the player ----------
func do_sonar(rank: int) -> void:
	var radius := 350.0 if rank == 1 else 550.0
	for node in get_tree().get_nodes_in_group("pickups"):
		var p := node as Node2D
		if p and is_instance_valid(p) and player.global_position.distance_to(p.global_position) < radius:
			sonar_pings.append({"pos": p.global_position, "kind": "pickup", "ttl": 3.5})
	for node in get_tree().get_nodes_in_group("scannable"):
		var s := node as Node2D
		if s and is_instance_valid(s) and player.global_position.distance_to(s.global_position) < radius:
			var kind := "threat"
			if (s as Object).get("species") in ["fish_teal", "fish_rose"]:
				kind = "fauna"
			sonar_pings.append({"pos": s.global_position, "kind": kind, "ttl": 3.5})
			if rank >= 3 and s.has_method("stagger"):
				s.stagger(2.0)

func use_anchor(rank: int) -> void:
	if anchor_node == null:
		anchor_node = Node2D.new()
		anchor_node.position = player.global_position + Vector2(0, 10)
		var spr := Sprite2D.new()
		spr.texture = load("res://assets/anchor_item.png")
		anchor_node.add_child(spr)
		var light := PointLight2D.new()
		light.texture = load("res://assets/halo.png")
		light.scale = Vector2(0.25, 0.25)
		light.energy = 0.4
		light.color = Color(0.7, 0.85, 1.0)
		anchor_node.add_child(light)
		add_child(anchor_node)
		Sfx.play("deposit", -6.0)
		player.event_message.emit("Anchor set. Return and press again to deposit cargo.")
		return
	if player.global_position.distance_to(anchor_node.global_position) > 48.0:
		player.event_message.emit("Your anchor is set elsewhere — the line points to it.")
		return
	if player.cargo.is_empty():
		player.event_message.emit("Nothing to deposit.")
		return
	var salv := player.carried_salvage()
	var rel := player.carried_relics()
	player.cargo.clear()
	player.cargo_changed.emit()
	Sfx.play("deposit")
	if rank >= 3:
		Game.salvage += salv
		Game.relics += rel
		Game.total_banked += salv
		Game.save_game()
		player.event_message.emit("Cargo banked up the line: %d salvage, %d relics." % [salv, rel])
	else:
		var stash := Game.anchor_stash
		Game.anchor_stash = {
			"x": anchor_node.global_position.x, "y": anchor_node.global_position.y,
			"salvage": salv + int(stash.get("salvage", 0)),
			"relics": rel + int(stash.get("relics", 0)),
		}
		Game.save_game()
		player.event_message.emit("Cargo lashed to the anchor — it will survive you.")
	if rank >= 2:
		player.restore_light(Game.max_light() * 0.15)

# ---------- keeper resolution ----------
func _on_keeper_defeated(id: int) -> void:
	Game.record_keeper(id)
	Sfx.play("core")
	hud.flash_message("PRESSURE CORE %d RECOVERED — banked to the lighthouse" % id)
	# core flies to the player (cosmetic; the core itself is already banked)
	var core := Sprites.animated("res://assets/core.png", 4, 6.0)
	core.position = player.global_position + Vector2(0, -60)
	add_child(core)
	var tween := create_tween()
	tween.tween_property(core, "position", player.global_position, 0.8)
	tween.tween_callback(core.queue_free)
	if gates.has(id) and is_instance_valid(gates[id]):
		Sfx.play("gate")
		gates[id].queue_free()
		gates.erase(id)
	if beacons.has(id):
		beacons[id].node.set_meta("active", true)
		beacons[id].light.energy = 0.9
		beacons[id].sprite.modulate = Color.WHITE

# ---------- per-frame ----------
func _process(delta: float) -> void:
	if ending:
		return
	dive_time += delta
	max_depth_m = maxf(max_depth_m, player.depth_m())
	_update_tether()
	_update_currents(delta)
	_update_pressure(delta)
	_update_band()
	_update_pings(delta)
	_update_valves(delta)
	_feed_noise()

	if _shot_timer > 0.0:
		_shot_timer -= delta
		if _shot_timer <= 0.0:
			_take_shot()

	if player.global_position.y < SURFACE_Y + 12.0 and dive_time > 2.0 and not player.dead:
		_bank()

func _update_currents(delta: float) -> void:
	if player.dead:
		return
	for area in get_tree().get_nodes_in_group("currents"):
		if (area as Area2D).overlaps_body(player):
			player.velocity += (area.get_meta("dir") as Vector2) * 300.0 * delta

## Diving below the suit's pressure rating strains the hull: the light bleeds
## out faster and faster. You CAN dip in — briefly, on purpose, as a bet.
func _update_pressure(delta: float) -> void:
	if player.dead:
		return
	player.strained = player.global_position.y > rated_max_y
	if player.strained:
		strain_time += delta
		player.light -= (2.0 + strain_time * 1.5) * delta
		_creak_t -= delta
		if _creak_t <= 0.0:
			Sfx.play("creak", -4.0)
			_creak_t = 1.1
		player.add_panic(0.12 * delta)
	else:
		strain_time = 0.0

func _update_band() -> void:
	var r := clampi(int(player.global_position.y / TILE), 0, world_rows - 1)
	var band := row_band[r]
	if band != current_band:
		current_band = band
		hud.show_band_splash(Game.BANDS[band].name)

func _update_pings(delta: float) -> void:
	var alive := []
	for ping in sonar_pings:
		ping.ttl -= delta
		if ping.ttl > 0.0:
			alive.append(ping)
	sonar_pings = alive

var _noise_t := 0.0
func _feed_noise() -> void:
	# throttled: the Cantor tracks loud movement
	_noise_t -= get_process_delta_time()
	if _noise_t > 0.0 or player.dead:
		return
	_noise_t = 0.25
	if player.velocity.length() > Game.swim_speed() * 0.6:
		for keeper in get_tree().get_nodes_in_group("keepers"):
			if keeper.global_position.distance_to(player.global_position) < 500.0:
				keeper.hear_noise(player.global_position)

func _update_tether() -> void:
	var anchor := Vector2(Chunks.COLS * TILE / 2.0, -220)
	var attach := player.global_position + Vector2(-4, -8)
	var points := PackedVector2Array()
	var n := 14
	for i in range(n + 1):
		var t := float(i) / n
		var p := anchor.lerp(attach, t)
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
