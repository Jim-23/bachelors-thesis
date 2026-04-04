# res://scripts/main.gd
#
# main scene controller
#
#   - fills the dungeon type dropdown and reads the size inputs
#   - on generate press:
#       1. runs the chosen algorithm and measures only the generation time
#       2. shows the stats (time, floor count, coverage) right away
#       3. draws the dungeon row by row so you can see it appear
#       4. places the player on a safe floor spot after the reveal

extends Node2D

@onready var dungeon_layer: TileMapLayer = $DungeonLayer
@onready var player: CharacterBody2D = $Player

# generator scripts imported

const CoinScene         = preload("res://scenes/coin.tscn")
const RoomsGenerator    = preload("res://dungeons/algorithms/rooms_generator.gd")
const BSPGenerator      = preload("res://dungeons/algorithms/bsp_generator.gd")
const CellularGenerator = preload("res://dungeons/algorithms/cellular_generator.gd")
const DrunkardsGenerator  = preload("res://dungeons/algorithms/drunkards_generator.gd")
const MazeGenerator     = preload("res://dungeons/algorithms/maze_generator.gd")

# tile types - must match the constants in each generator
enum TileType { EMPTY = 0, 
				FLOOR = 1, 
				WALL = 2 }

# which tile in the atlas to use for each type
const TILE_FLOOR_POS:Vector2i = Vector2i(8, 1)
const TILE_WALL_POS: Vector2i = Vector2i(2, 0)
const TILE_SOURCE_ID: int = 0

# default map size
const DUNGEON_WIDTH: int = 60
const DUNGEON_HEIGHT: int= 60

# the CollisionShape2D inside player.tscn is offset Vector2(49, 6) from the
# CharacterBody2D origin. if we just set global_position = tile_center, the
# collision circle ends up ~3 tiles to the right (inside a wall).
# subtracting this offset puts the collision exactly on the chosen tile.
const PLAYER_COLLISION_OFFSET: Vector2 = Vector2(49.0, 6.0)

const MIN_COINS: int = 5
const MAX_COINS: int = 50

const BENCHMARK_SIZES = [
	Vector2i(60, 60),
	Vector2i(100, 100),
	Vector2i(150, 150),
	Vector2i(20, 50),
	Vector2i(70, 30)
]

const BENCHMARK_RUNS = 10

var _coins_collected: int = 0
var _coins_total: int = 0
var _spawned_coins: Array[Node] = []

# ui references
@onready var dungeon_type_option: OptionButton = $UI/Panel/VBoxContainer/Buttons/DungeonType
@onready var width_input: SpinBox = $UI/Panel/VBoxContainer/Buttons/Width
@onready var height_input: SpinBox = $UI/Panel/VBoxContainer/Buttons/Height
@onready var generate_button: Button = $UI/Panel/VBoxContainer/Buttons/GenerateButton
@onready var benchmark_button: Button = $UI/Panel/VBoxContainer/Buttons/BenchmarkButton

@onready var gen_time_label:  Label = $UI/Panel/VBoxContainer/Stats/GenTimeLabel
@onready var floor_label:     Label = $UI/Panel/VBoxContainer/Stats/FloorLabel
@onready var coverage_label:  Label = $UI/Panel/VBoxContainer/Stats/CoverageLabel
@onready var size_label:      Label = $UI/Panel/VBoxContainer/Stats/SizeLabel
@onready var status_label:    Label = $UI/Panel/VBoxContainer/Stats/StatusLabel
@onready var coins_label: Label = $UI/CoinsLabel

func _ready() -> void:
	# hide the player at startup - it will appear after the first generation
	if player:
		player.hide()
		_update_camera_limits(DUNGEON_WIDTH, DUNGEON_HEIGHT)

	# fill the dropdown (the index here must match the match statement below)
	dungeon_type_option.clear()
	dungeon_type_option.add_item("Rooms")     # 0
	dungeon_type_option.add_item("BSP")       # 1
	dungeon_type_option.add_item("Drunkards")   # 2
	dungeon_type_option.add_item("Cellular")  # 3
	dungeon_type_option.add_item("Maze")      # 4

	width_input.value  = DUNGEON_WIDTH
	height_input.value = DUNGEON_HEIGHT


func _on_generate_button_pressed() -> void:
	# hide the player while generating - it will be shown again after placement
	if player:
		player.hide()
		
	# clean up the rest of the coins
	for coin in _spawned_coins:
		if is_instance_valid(coin):
			coin.queue_free()
	_spawned_coins.clear()
	
	_coins_collected = 0
	_coins_total = 0
	coins_label.text = "Coins: 0/0"


	var width:  int = int(width_input.value)
	var height: int = int(height_input.value)

	# --- 1. run the generator and time it ---
	# only the generate() call is timed - drawing and placement are not included
	var t_start: int = Time.get_ticks_usec()

	var map: Array = []
	match dungeon_type_option.selected:
		0: map = RoomsGenerator.generate(width, height)
		1: map = BSPGenerator.generate(width, height)
		2: map = DrunkardsGenerator.generate(width, height)
		3: map = CellularGenerator.generate(width, height)
		4: map = MazeGenerator.generate(width, height)
		_:
			push_warning("Unknown dungeon type selected.")
			return

	var t_end: int = Time.get_ticks_usec()
	var gen_ms: float = (t_end - t_start) / 1000.0

	# --- 2. count floor tiles and show the stats ---
	# this happens before any drawing so the numbers are instant
	print("Map: ", map)
	var total_tiles: int = width * height
	var floor_count: int = _count_floor_tiles(map)
	var coverage_pct: float = (float(floor_count) / float(total_tiles)) * 100.0

	gen_time_label.text = "Gen time: %.2f ms" % gen_ms
	floor_label.text = "Floor tiles: %d" % floor_count
	coverage_label.text = "Coverage: %.1f%%" % coverage_pct
	size_label.text = "Size: %dx%d" % [width, height]
	status_label.text = "Rendering..."

	# lock the button so the user can't press generate again while rendering
	generate_button.disabled = true

	# --- 3. draw the map row by row ---
	var floor_tiles: Array[Vector2i] = await _draw_map_animated(map)

	# --- 4. update camera bounds
	_update_camera_limits(width, height)
	
	# --- 5. randomly place coins
	_place_coins_on_floor(floor_tiles)

	# --- 6. place the player
	_place_player_on_floor(floor_tiles)

	
	"""
	var algorithm_name := dungeon_type_option.get_item_text(dungeon_type_option.selected)
	var run_id := Time.get_ticks_usec()

	_log_results(
		algorithm_name,
		width,
		height,
		run_id,
		gen_ms,
		coverage_pct,
		floor_count
	)
	"""
	status_label.text = "Done"
	generate_button.disabled = false

func run_benchmark() -> void:

	var algorithms = [
		{"name":"Rooms", "func": RoomsGenerator.generate},
		{"name":"BSP", "func": BSPGenerator.generate},
		{"name":"Drunkards", "func": DrunkardsGenerator.generate},
		{"name":"Cellular", "func": CellularGenerator.generate},
		{"name":"Maze", "func": MazeGenerator.generate}
	]

	for algo in algorithms:

		for size in BENCHMARK_SIZES:

			for run in range(BENCHMARK_RUNS):

				var width = size.x
				var height = size.y

				var t_start = Time.get_ticks_usec()
				var map = algo.func.call(width, height)
				var t_end = Time.get_ticks_usec()

				var gen_ms = (t_end - t_start) / 1000.0

				var total_tiles = width * height
				var floor_count = _count_floor_tiles(map)
				var coverage_pct = float(floor_count) / float(total_tiles) * 100.0

				_log_results(
					algo.name,
					width,
					height,
					run,
					gen_ms,
					coverage_pct,
					floor_count
				)

				print(algo.name, " ", width, "x", height, " run ", run, " done")

func _update_camera_limits(map_width: int, map_height: int) -> void:
	# Try to find camera as child of player (old structure) or as sibling (new structure)
	var camera: Camera2D = null
	
	if player != null:
		camera = player.get_node_or_null("Camera2D")
	
	if camera == null:
		# Try to find camera as sibling in main scene
		camera = get_node_or_null("Camera2D")
	
	if camera == null:
		push_warning("No Camera2D found!")
		return

	var tile_size: Vector2i = dungeon_layer.tile_set.tile_size

	camera.limit_left = 0
	camera.limit_top = -30
	camera.limit_right = map_width * tile_size.x
	camera.limit_bottom = map_height * tile_size.y

# draws the map one row at a time with a short delay so you can see it appear
# updates the status label with live elapsed time
# returns the list of floor tile positions (used for player placement)
func _draw_map_animated(map: Array) -> Array[Vector2i]:
	if dungeon_layer == null:
		return []

	dungeon_layer.clear()

	if map.is_empty():
		return []

	var floor_tiles: Array[Vector2i] = []
	var render_start: int = Time.get_ticks_usec()

	for y: int in range(map.size()):
		var row: Array = map[y]
		for x: int in range(row.size()):
			var tile_type: int = row[x]
			var pos := Vector2i(x, y)
			match tile_type:
				TileType.WALL:
					dungeon_layer.set_cell(pos, TILE_SOURCE_ID, TILE_WALL_POS)
				TileType.FLOOR:
					dungeon_layer.set_cell(pos, TILE_SOURCE_ID, TILE_FLOOR_POS)
					floor_tiles.append(pos)
				TileType.EMPTY:
					dungeon_layer.erase_cell(pos)

		# short pause between rows so the reveal effect is visible
		await get_tree().create_timer(0.01).timeout

		var elapsed: float = (Time.get_ticks_usec() - render_start) / 1_000_000.0
		status_label.text = "Rendering: %.2f s" % elapsed

	return floor_tiles


# counts how many floor tiles are in the map
func _count_floor_tiles(map: Array) -> int:
	var count: int = 0
	for row in map:
		for tile in row:
			if tile == TileType.FLOOR:
				count += 1
	return count


# places the player on a floor tile that has a clear 3x3 area around it
# also fixes the collision offset (see PLAYER_COLLISION_OFFSET at the top)
func _place_player_on_floor(floor_tiles: Array[Vector2i]) -> void:
	if player == null:
		push_warning("Player node not assigned.")
		return
	if floor_tiles.is_empty():
		push_warning("No floor tiles to spawn the player on.")
		return

	var floor_set: Dictionary = {}
	for tile in floor_tiles:
		floor_set[tile] = true

	# use only the largest connected floor region
	var main_region: Array[Vector2i] = _get_largest_floor_region(floor_tiles, floor_set)
	if main_region.is_empty():
		push_warning("No connected floor region found for player spawn.")
		return

	var main_region_set: Dictionary = {}
	for tile in main_region:
		main_region_set[tile] = true

	# prefer a tile with a full 3x3 floor neighborhood inside the main region
	for tile in main_region:
		if _is_clear_3x3_center(tile, main_region_set):
			player.global_position = dungeon_layer.map_to_local(tile) - PLAYER_COLLISION_OFFSET
			player.show()
			print("Player spawned at tile: ", tile)
			return

	# fallback: any tile from the largest connected region
	push_warning("No clean 3x3 floor area found in main region, using fallback spawn.")
	var fallback: Vector2i = main_region[randi() % main_region.size()]
	player.global_position = dungeon_layer.map_to_local(fallback) - PLAYER_COLLISION_OFFSET
	player.show()


func _get_largest_floor_region(floor_tiles: Array[Vector2i], floor_set: Dictionary) -> Array[Vector2i]:
	var visited: Dictionary = {}
	var largest_region: Array[Vector2i] = []

	for start_tile in floor_tiles:
		if visited.has(start_tile):
			continue

		var region: Array[Vector2i] = []
		var queue: Array[Vector2i] = [start_tile]
		visited[start_tile] = true

		while not queue.is_empty():
			var current: Vector2i = queue.pop_front()
			region.append(current)

			for neighbor in _get_floor_neighbors_4(current):
				if floor_set.has(neighbor) and not visited.has(neighbor):
					visited[neighbor] = true
					queue.append(neighbor)

		if region.size() > largest_region.size():
			largest_region = region

	return largest_region


func _get_floor_neighbors_4(tile: Vector2i) -> Array[Vector2i]:
	return [
		tile + Vector2i(1, 0),
		tile + Vector2i(-1, 0),
		tile + Vector2i(0, 1),
		tile + Vector2i(0, -1)
	]

# returns true if all 9 tiles in a 3x3 area centered on 'center' are floor
func _is_clear_3x3_center(center: Vector2i, floor_set: Dictionary) -> bool:
	for dy: int in range(-1, 2):
		for dx: int in range(-1, 2):
			if not floor_set.has(center + Vector2i(dx, dy)):
				return false
	return true

func _place_coins_on_floor(floor_tiles: Array[Vector2i]) -> void:
	if floor_tiles.is_empty():
		push_warning("No floor tiles to spawn coins on.")
		return

	var floor_set: Dictionary = {}
	for tile in floor_tiles:
		floor_set[tile] = true

	# use only the largest connected floor region
	var main_region: Array[Vector2i] = _get_largest_floor_region(floor_tiles, floor_set)
	if main_region.is_empty():
		push_warning("No connected floor region found for coin spawn.")
		return

	# pick a random coin_count between MIN and MAX, capped by available floor tiles
	var coin_count: int = randi_range(MIN_COINS, MAX_COINS)
	var shuffled: Array[Vector2i] = main_region.duplicate()
	shuffled.shuffle()

	coin_count = mini(coin_count, shuffled.size())

	_coins_collected = 0
	_coins_total = coin_count
	coins_label.text = "Coins: %d/%d" % [_coins_collected, _coins_total]


	for i in range(coin_count):
		var tile: Vector2i = shuffled[i]
		var world_pos: Vector2 = dungeon_layer.map_to_local(tile)
		var c: Area2D = CoinScene.instantiate()
		c.global_position = world_pos
		
		c.collected.connect(_on_coin_collected)
		
		add_child(c)
		_spawned_coins.append(c)

	print("Spawned %d coins" % coin_count)

func _on_coin_collected() -> void:
	_coins_collected += 1
	coins_label.text = "Coins: %d/%d" % [_coins_collected, _coins_total]
	if _coins_collected == _coins_total:
		coins_label.text = "ALL COINS COLLECTED! NEW DUNGEON IS BEING GENERATED"
		_on_generate_button_pressed()
		
func _log_results(algorithm:String, width:int, height:int, run:int, gen_time:float, coverage:float, floor_tiles:int):

	var path := "results.csv"
	var file: FileAccess

	if FileAccess.file_exists(path):
		file = FileAccess.open(path, FileAccess.READ_WRITE)
		file.seek_end()
	else:
		file = FileAccess.open(path, FileAccess.WRITE_READ)
		file.store_line("algorithm,width,height,run,gen_time_ms,coverage,floor_tiles")

	file.store_line("%s,%d,%d,%d,%.3f,%.2f,%d" % [
		algorithm,
		width,
		height,
		run,
		gen_time,
		coverage,
		floor_tiles,
	])

	file.close()


func _on_benchmark_button_pressed() -> void:
	generate_button.disabled = true
	run_benchmark()
	generate_button.disabled = false
