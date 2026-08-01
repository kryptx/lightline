class_name Worldgen
## Shared world construction: tile painting + collision from a chunk grid,
## and the underwater backdrop. Used by the procedural dive and the fixed
## finale descent.

const TILE := 32
const SHEETS := ["rock_tiles.png", "town_tiles.png", "cathedral_tiles.png",
		"gardens_tiles.png", "throat_tiles.png"]

static func is_open(ch: String) -> bool:
	return ch != "#"

## Paints tiles (atlas source = row_source[r], 0..4) and builds merged-run
## collision rectangles. Adds both nodes to root.
static func build_tiles_and_collision(root: Node2D, grid: Array[String],
		row_source: Array[int]) -> void:
	var cols := grid[0].length()
	var tiles := TileMapLayer.new()
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE, TILE)
	for si in range(SHEETS.size()):
		var src := TileSetAtlasSource.new()
		src.texture = load("res://assets/" + SHEETS[si])
		src.texture_region_size = Vector2i(TILE, TILE)
		for i in range(4):
			src.create_tile(Vector2i(i, 0))
		ts.add_source(src, si)
	tiles.tile_set = ts
	tiles.z_index = 0
	root.add_child(tiles)

	var body := StaticBody2D.new()
	body.collision_layer = 1
	root.add_child(body)

	for r in range(grid.size()):
		var source := row_source[r]
		var run_start := -1
		for c in range(cols + 1):
			var solid: bool = c < cols and grid[r][c] == "#"
			if solid:
				var open_above: bool = r > 0 and is_open(grid[r - 1][c])
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

## Gradient water, optional sky/waterline, darkness, and the surface glow.
static func build_backdrop(root: Node2D, rows: int, cols: int,
		with_surface := true, darkness := Color(0.055, 0.075, 0.13)) -> void:
	var world_h := rows * TILE
	var bg := Sprite2D.new()
	bg.texture = load("res://assets/water_gradient.png")
	bg.centered = false
	bg.scale = Vector2(cols * TILE / 16.0, (world_h + 400) / 1024.0)
	bg.z_index = -20
	root.add_child(bg)
	var cm := CanvasModulate.new()
	cm.color = darkness
	root.add_child(cm)
	if not with_surface:
		return
	var sky := ColorRect.new()
	sky.color = Color(0.09, 0.06, 0.16)
	sky.position = Vector2(-200, -420)
	sky.size = Vector2(cols * TILE + 400, 420 + 24 - 8)
	sky.z_index = -19
	root.add_child(sky)
	var surf_tex: Texture2D = load("res://assets/surface.png")
	for i in range(cols * TILE / 64 + 1):
		var s := Sprite2D.new()
		s.texture = surf_tex
		s.centered = false
		s.position = Vector2(i * 64, 24 - 8)
		s.z_index = -18
		root.add_child(s)
	var sun := PointLight2D.new()
	sun.texture = load("res://assets/halo.png")
	sun.position = Vector2(cols * TILE / 2.0, -160)
	sun.scale = Vector2(9, 4.5)
	sun.energy = 0.75
	sun.color = Color(0.8, 0.76, 0.88)
	root.add_child(sun)
