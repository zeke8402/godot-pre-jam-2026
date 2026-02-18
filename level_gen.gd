extends Node

@export var mob_scene: PackedScene

@export var grid_width := 16
@export var grid_height := 16
@export var tile_size := 1.0
@export var random_seed := 0
@export var maze_loop_chance := 0.12
@export var park_chance := 0.18
@export var building_chance := 0.82
@export var asset_scale := 2.0
@export var roof_height_offset := 0.95
@export var debug_logs := true

var _rng := RandomNumberGenerator.new()
var _road_cells: Dictionary = {}
var _entry: Vector2i
var _exit: Vector2i
var _roads_placed := 0
var _lots_placed := 0
var _props_placed := 0
var _buildings_placed := 0

const ROAD_CENTER: PackedScene = preload("res://kenney_retro-urban-kit/GLB format/road-asphalt-center.glb")
const ROAD_STRAIGHT: PackedScene = preload("res://kenney_retro-urban-kit/GLB format/road-asphalt-straight.glb")
const ROAD_CORNER: PackedScene = preload("res://kenney_retro-urban-kit/GLB format/road-asphalt-corner.glb")
const ROAD_SIDE: PackedScene = preload("res://kenney_retro-urban-kit/GLB format/road-asphalt-side.glb")
const ROAD_DAMAGED: PackedScene = preload("res://kenney_retro-urban-kit/GLB format/road-asphalt-damaged.glb")

const HOUSE_WALLS_A: Array[PackedScene] = [
	preload("res://kenney_retro-urban-kit/GLB format/wall-a-door.glb"),
	preload("res://kenney_retro-urban-kit/GLB format/wall-a-window.glb"),
	preload("res://kenney_retro-urban-kit/GLB format/wall-a-flat-window.glb"),
	preload("res://kenney_retro-urban-kit/GLB format/wall-a-detail.glb"),
	preload("res://kenney_retro-urban-kit/GLB format/wall-a-painted.glb")
]

const HOUSE_WALLS_B: Array[PackedScene] = [
	preload("res://kenney_retro-urban-kit/GLB format/wall-b-door.glb"),
	preload("res://kenney_retro-urban-kit/GLB format/wall-b-window.glb"),
	preload("res://kenney_retro-urban-kit/GLB format/wall-b-flat-window.glb"),
	preload("res://kenney_retro-urban-kit/GLB format/wall-b-detail-painted.glb"),
	preload("res://kenney_retro-urban-kit/GLB format/wall-b-flat.glb")
]

const HOUSE_CORNERS_A: Array[PackedScene] = [
	preload("res://kenney_retro-urban-kit/GLB format/wall-a-corner.glb"),
	preload("res://kenney_retro-urban-kit/GLB format/wall-a-column.glb")
]

const HOUSE_CORNERS_B: Array[PackedScene] = [
	preload("res://kenney_retro-urban-kit/GLB format/wall-b-corner.glb"),
	preload("res://kenney_retro-urban-kit/GLB format/wall-b-column.glb")
]

const HOUSE_ROOFS_A: Array[PackedScene] = [
	preload("res://kenney_retro-urban-kit/GLB format/wall-a-roof.glb"),
	preload("res://kenney_retro-urban-kit/GLB format/wall-a-roof-detailed.glb"),
	preload("res://kenney_retro-urban-kit/GLB format/wall-a-roof-slant.glb")
]

const HOUSE_ROOFS_B: Array[PackedScene] = [
	preload("res://kenney_retro-urban-kit/GLB format/wall-b-roof.glb"),
	preload("res://kenney_retro-urban-kit/GLB format/wall-b-roof-detailed.glb"),
	preload("res://kenney_retro-urban-kit/GLB format/wall-b-roof-slant.glb")
]

const PROP_SCENES: Array[PackedScene] = [
	preload("res://kenney_retro-urban-kit/GLB format/tree-small.glb"),
	preload("res://kenney_retro-urban-kit/GLB format/tree-shrub.glb"),
	preload("res://kenney_retro-urban-kit/GLB format/detail-bench.glb"),
	preload("res://kenney_retro-urban-kit/GLB format/pallet.glb"),
	preload("res://kenney_retro-urban-kit/GLB format/detail-dumpster-closed.glb")
]

const BUILDING_DETAIL_SCENES: Array[PackedScene] = [
	preload("res://kenney_retro-urban-kit/GLB format/detail-awning-small.glb"),
	preload("res://kenney_retro-urban-kit/GLB format/detail-awning-wide.glb"),
	preload("res://kenney_retro-urban-kit/GLB format/balcony-type-a.glb"),
	preload("res://kenney_retro-urban-kit/GLB format/balcony-ladder-top.glb"),
	preload("res://kenney_retro-urban-kit/GLB format/detail-cables-type-a.glb"),
	preload("res://kenney_retro-urban-kit/GLB format/detail-cables-type-b.glb")
]

func _ready() -> void:
	_log("level_gen.gd _ready() on node: %s" % name)
	if random_seed == 0:
		_rng.randomize()
		_log("RNG randomized (random_seed=0)")
	else:
		_rng.seed = random_seed
		_log("RNG seeded with %d" % random_seed)

	_generate_level()

func _on_mob_timer_timeout() -> void:
	if mob_scene == null:
		return

	var mob: Variant = mob_scene.instantiate()
	var spawn_location: PathFollow3D = get_node("SpawnPath/SpawnLocation") as PathFollow3D
	var player: CharacterBody3D = $Player as CharacterBody3D

	spawn_location.progress_ratio = randf()
	mob.initialize(spawn_location.position, player)
	add_child(mob)

func _generate_level() -> void:
	_roads_placed = 0
	_lots_placed = 0
	_props_placed = 0
	_buildings_placed = 0

	var city_root := get_node_or_null("City") as Node3D
	if city_root == null:
		city_root = Node3D.new()
		city_root.name = "City"
		add_child(city_root)
		_log("Created missing City node at runtime")
	else:
		_log("Found existing City node")

	var previous_children := city_root.get_child_count()
	for child in city_root.get_children():
		child.queue_free()
	_log("Cleared City children: %d" % previous_children)

	var ok := _generate_connected_road_graph()
	if not ok:
		push_warning("Level generation fallback: could not satisfy road connectivity constraints.")
		_log("Connectivity fallback was used")

	var path := _dijkstra_path(_entry, _exit)
	_log("Road graph cells=%d entry=%s exit=%s path_len=%d" % [_road_cells.size(), str(_entry), str(_exit), path.size()])
	_log("asset_scale=%.2f effective_tile_step=%.2f" % [asset_scale, tile_size * asset_scale])

	_place_city(city_root)
	_position_player_at_entry()
	_log("Placed roads=%d lots=%d buildings=%d props=%d City.children=%d" % [_roads_placed, _lots_placed, _buildings_placed, _props_placed, city_root.get_child_count()])

func _generate_connected_road_graph() -> bool:
	_road_cells.clear()

	var usable_w: int = max(7, grid_width)
	var usable_h: int = max(7, grid_height)
	if usable_w % 2 == 0:
		usable_w -= 1
	if usable_h % 2 == 0:
		usable_h -= 1

	var coarse_w: int = (usable_w - 1) / 2
	var coarse_h: int = (usable_h - 1) / 2
	if coarse_w < 2 or coarse_h < 2:
		return _fallback_street()

	var visited: Dictionary = {}
	var stack: Array[Vector2i] = []
	var start := Vector2i(_rng.randi_range(0, coarse_w - 1), _rng.randi_range(0, coarse_h - 1))
	stack.push_back(start)
	visited[start] = true
	_road_cells[_coarse_to_fine(start)] = true

	while not stack.is_empty():
		var current: Vector2i = stack[stack.size() - 1]
		var candidates: Array[Vector2i] = []
		var dirs: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
		for dir in dirs:
			var next: Vector2i = current + dir
			if next.x < 0 or next.y < 0 or next.x >= coarse_w or next.y >= coarse_h:
				continue
			if visited.has(next):
				continue
			candidates.push_back(next)

		if candidates.is_empty():
			stack.pop_back()
			continue

		var chosen: Vector2i = candidates[_rng.randi_range(0, candidates.size() - 1)]
		var a: Vector2i = _coarse_to_fine(current)
		var b: Vector2i = _coarse_to_fine(chosen)
		var mid: Vector2i = Vector2i((a.x + b.x) / 2, (a.y + b.y) / 2)

		_road_cells[a] = true
		_road_cells[mid] = true
		_road_cells[b] = true

		visited[chosen] = true
		stack.push_back(chosen)

	# Add sparse loopbacks so the maze is not a strict tree.
	for cy in range(coarse_h):
		for cx in range(coarse_w):
			var c: Vector2i = Vector2i(cx, cy)
			var c_fine: Vector2i = _coarse_to_fine(c)
			var loop_dirs: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.DOWN]
			for dir in loop_dirs:
				if _rng.randf() > maze_loop_chance:
					continue
				var n: Vector2i = c + dir
				if n.x < 0 or n.y < 0 or n.x >= coarse_w or n.y >= coarse_h:
					continue
				var n_fine: Vector2i = _coarse_to_fine(n)
				var mid: Vector2i = Vector2i((c_fine.x + n_fine.x) / 2, (c_fine.y + n_fine.y) / 2)
				_road_cells[mid] = true

	var entry_y: int = _pick_edge_road_row(1, usable_h)
	var exit_y: int = _pick_edge_road_row(usable_w - 2, usable_h)

	_entry = Vector2i(0, entry_y)
	_exit = Vector2i(usable_w - 1, exit_y)
	_road_cells[_entry] = true
	_road_cells[Vector2i(1, entry_y)] = true
	_road_cells[Vector2i(usable_w - 2, exit_y)] = true
	_road_cells[_exit] = true

	var path: Array[Vector2i] = _dijkstra_path(_entry, _exit)
	if path.is_empty():
		return _fallback_street()

	_log("Maze street graph built coarse=%dx%d path_len=%d" % [coarse_w, coarse_h, path.size()])
	return true

func _coarse_to_fine(cell: Vector2i) -> Vector2i:
	return Vector2i(cell.x * 2 + 1, cell.y * 2 + 1)

func _pick_edge_road_row(x: int, usable_h: int) -> int:
	var rows: Array[int] = []
	for y in range(1, usable_h - 1):
		if _road_cells.has(Vector2i(x, y)):
			rows.push_back(y)
	if rows.is_empty():
		return int(usable_h / 2)
	return rows[_rng.randi_range(0, rows.size() - 1)]

func _fallback_street() -> bool:
	_road_cells.clear()
	var y_mid := int(grid_height / 2)
	for x in range(grid_width):
		_road_cells[Vector2i(x, y_mid)] = true
	_entry = Vector2i(0, y_mid)
	_exit = Vector2i(grid_width - 1, y_mid)
	return false

func _dijkstra_path(start: Vector2i, goal: Vector2i) -> Array[Vector2i]:
	if not _road_cells.has(start) or not _road_cells.has(goal):
		return []

	var dist: Dictionary = {}
	var prev: Dictionary = {}
	var open: Array[Vector2i] = []

	dist[start] = 0
	open.push_back(start)

	while not open.is_empty():
		var current := _extract_lowest(open, dist)
		if current == goal:
			break

		for next in _neighbors(current):
			if not _road_cells.has(next):
				continue

			var alt := int(dist[current]) + 1
			if not dist.has(next) or alt < int(dist[next]):
				dist[next] = alt
				prev[next] = current
				if not open.has(next):
					open.push_back(next)

	if not dist.has(goal):
		return []

	var path: Array[Vector2i] = []
	var node := goal
	while node != start:
		path.push_front(node)
		node = prev[node]
	path.push_front(start)
	return path

func _extract_lowest(open: Array[Vector2i], dist: Dictionary) -> Vector2i:
	var best_idx := 0
	var best: Vector2i = open[0]
	for i in range(1, open.size()):
		var candidate: Vector2i = open[i]
		if int(dist[candidate]) < int(dist[best]):
			best = candidate
			best_idx = i
	open.remove_at(best_idx)
	return best

func _place_city(root: Node3D) -> void:
	for x in range(grid_width):
		for y in range(grid_height):
			var cell := Vector2i(x, y)
			var world := _cell_to_world(cell)
			if _road_cells.has(cell):
				_place_road(root, cell, world)
			else:
				_place_lot(root, world)

func _place_road(root: Node3D, cell: Vector2i, world: Vector3) -> void:
	var n: bool = _road_cells.has(cell + Vector2i(0, -1))
	var e: bool = _road_cells.has(cell + Vector2i(1, 0))
	var s: bool = _road_cells.has(cell + Vector2i(0, 1))
	var w: bool = _road_cells.has(cell + Vector2i(-1, 0))
	var degree := int(n) + int(e) + int(s) + int(w)

	var scene: PackedScene = ROAD_CENTER
	var rot_deg := 0.0

	if degree >= 3:
		scene = ROAD_CENTER
	elif degree == 2:
		if (n and s) or (e and w):
			scene = ROAD_STRAIGHT
			rot_deg = 90.0 if e and w else 0.0
		else:
			scene = ROAD_CORNER
			if n and e:
				rot_deg = 0.0
			elif e and s:
				rot_deg = 90.0
			elif s and w:
				rot_deg = 180.0
			else:
				rot_deg = 270.0
	elif degree == 1:
		scene = ROAD_SIDE
		if n:
			rot_deg = 0.0
		elif e:
			rot_deg = 90.0
		elif s:
			rot_deg = 180.0
		else:
			rot_deg = 270.0
	else:
		scene = ROAD_DAMAGED

	var piece := scene.instantiate() as Node3D
	if piece == null:
		_log("WARN: road scene instantiate returned null at cell=%s" % str(cell))
		return
	piece.position = world
	piece.scale = Vector3.ONE * asset_scale
	piece.rotation_degrees.y = rot_deg
	root.add_child(piece)
	_roads_placed += 1

func _place_lot(root: Node3D, world: Vector3) -> void:
	_lots_placed += 1
	if _rng.randf() > building_chance:
		if _rng.randf() < park_chance:
			var prop := PROP_SCENES[_rng.randi_range(0, PROP_SCENES.size() - 1)].instantiate() as Node3D
			if prop == null:
				_log("WARN: prop instantiate returned null at world=%s" % str(world))
				return
			prop.position = world
			prop.scale = Vector3.ONE * asset_scale
			prop.rotation_degrees.y = _rng.randi_range(0, 3) * 90.0
			root.add_child(prop)
			_props_placed += 1
		return

	var lot := Node3D.new()
	lot.position = world
	lot.rotation_degrees.y = _rng.randi_range(0, 3) * 90.0
	root.add_child(lot)
	lot.scale = Vector3.ONE * asset_scale

	var style_is_a: bool = _rng.randf() < 0.5
	var wall_pool: Array[PackedScene]
	var corner_pool: Array[PackedScene]
	var roof_pool: Array[PackedScene]
	if style_is_a:
		wall_pool = HOUSE_WALLS_A
		corner_pool = HOUSE_CORNERS_A
		roof_pool = HOUSE_ROOFS_A
	else:
		wall_pool = HOUSE_WALLS_B
		corner_pool = HOUSE_CORNERS_B
		roof_pool = HOUSE_ROOFS_B

	var half_extent := 0.52
	var corner_extent := 0.48
	var built_any_wall := false

	# Single-storey house footprint: maze is 2D, rendered with 3D assets.
	var y := 0.0
	built_any_wall = _add_wall_face_from_pool(lot, wall_pool, y, Vector3(0, 0, -half_extent), 0.0, world, true) or built_any_wall
	built_any_wall = _add_wall_face_from_pool(lot, wall_pool, y, Vector3(half_extent, 0, 0), 90.0, world, false) or built_any_wall
	built_any_wall = _add_wall_face_from_pool(lot, wall_pool, y, Vector3(0, 0, half_extent), 180.0, world, false) or built_any_wall
	built_any_wall = _add_wall_face_from_pool(lot, wall_pool, y, Vector3(-half_extent, 0, 0), 270.0, world, false) or built_any_wall

	_add_corner_piece_from_pool(lot, corner_pool, y, Vector3(corner_extent, 0, corner_extent), 180.0, world)
	_add_corner_piece_from_pool(lot, corner_pool, y, Vector3(-corner_extent, 0, corner_extent), 90.0, world)
	_add_corner_piece_from_pool(lot, corner_pool, y, Vector3(-corner_extent, 0, -corner_extent), 0.0, world)
	_add_corner_piece_from_pool(lot, corner_pool, y, Vector3(corner_extent, 0, -corner_extent), 270.0, world)

	var roof_scene: PackedScene = roof_pool[_rng.randi_range(0, roof_pool.size() - 1)]
	var roof := roof_scene.instantiate() as Node3D
	if roof == null:
		_log("WARN: roof instantiate returned null at world=%s" % str(world))
		lot.queue_free()
		return
	roof.position = Vector3(0, roof_height_offset, 0)
	lot.add_child(roof)

	if not built_any_wall:
		# Guarantee each building has walls + roof, never roof-only lots.
		lot.queue_free()
		return

	var detail_scene: PackedScene = BUILDING_DETAIL_SCENES[_rng.randi_range(0, BUILDING_DETAIL_SCENES.size() - 1)]
	var detail: Node3D = detail_scene.instantiate() as Node3D
	if detail:
		var detail_y: float = 0.6
		detail.position = Vector3(0, detail_y, 0.6)
		lot.add_child(detail)
	else:
		_log("WARN: detail instantiate returned null at world=%s" % str(world))

	_buildings_placed += 1

func _add_wall_face_from_pool(lot: Node3D, wall_pool: Array[PackedScene], y: float, local_offset: Vector3, yaw_deg: float, world: Vector3, prefer_door: bool) -> bool:
	var wall_scene: PackedScene
	if prefer_door and _rng.randf() < 0.8:
		# Bias the front face toward entries so houses read naturally from the road.
		wall_scene = wall_pool[0]
	else:
		wall_scene = wall_pool[_rng.randi_range(0, wall_pool.size() - 1)]
	var wall := wall_scene.instantiate() as Node3D
	if wall == null:
		_log("WARN: wall instantiate returned null at world=%s" % str(world))
		return false
	wall.position = local_offset + Vector3(0, y, 0)
	wall.rotation_degrees.y = yaw_deg
	lot.add_child(wall)
	return true

func _add_corner_piece_from_pool(lot: Node3D, corner_pool: Array[PackedScene], y: float, local_offset: Vector3, yaw_deg: float, world: Vector3) -> void:
	var corner_scene: PackedScene = corner_pool[_rng.randi_range(0, corner_pool.size() - 1)]
	var corner := corner_scene.instantiate() as Node3D
	if corner == null:
		_log("WARN: corner instantiate returned null at world=%s" % str(world))
		return
	corner.position = local_offset + Vector3(0, y, 0)
	corner.rotation_degrees.y = yaw_deg
	lot.add_child(corner)

func _position_player_at_entry() -> void:
	var player := get_node_or_null("Player") as CharacterBody3D
	if player == null:
		return

	var entry_world := _cell_to_world(_entry)
	player.global_position = entry_world + Vector3(0, 0.5, 0)

func _cell_to_world(cell: Vector2i) -> Vector3:
	var step := tile_size * asset_scale
	var x_offset := (float(grid_width - 1) * step) * 0.5
	var z_offset := (float(grid_height - 1) * step) * 0.5
	return Vector3(cell.x * step - x_offset, 0.0, cell.y * step - z_offset)

func _neighbors(cell: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var dirs: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
	for dir in dirs:
		var n: Vector2i = cell + dir
		if _in_bounds(n):
			result.push_back(n)
	return result

func _in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < grid_width and cell.y < grid_height

func _log(message: String) -> void:
	if debug_logs:
		print("[LevelGen] %s" % message)
