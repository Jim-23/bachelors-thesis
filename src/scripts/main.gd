# res://scripts/main.gd

# main scene controller


extends Node2D

# init of player and tilemap
@onready var dungeon_layer: TileMapLayer = $DungeonLayer
@onready var player: CharacterBody2D = $Player

# ui interactive buttons and spinboxes 
@onready var dungeon_type_option: OptionButton = $UI/Panel/MarginContainerUI/VBoxContainer/FirstRow/DungeonType
@onready var width_input: SpinBox = $UI/Panel/MarginContainerUI/VBoxContainer/FirstRow/Width
@onready var height_input: SpinBox = $UI/Panel/MarginContainerUI/VBoxContainer/FirstRow/Height
@onready var generate_button: Button = $UI/Panel/MarginContainerUI/VBoxContainer/FirstRow/GenerateButton
@onready var benchmark_button: Button = $UI/Panel/MarginContainerUI/VBoxContainer/FirstRow/BenchmarkButton

#TODO add to gui in the engine
@onready var benchmark_input: SpinBox = $UI/Panel/MarginContainerUI/VBoxContainer/FirstRow/BenchmarkInput
@onready var seed_input: SpinBox = $UI/Panel/MarginContainerUI/VBoxContainer/Seed/SeedInput
@onready var seed_checkbox: CheckBox = $UI/Panel/MarginContainerUI/VBoxContainer/Seed/SeedCheckBox
@onready var progress_bar: ProgressBar = $UI/Panel/MarginContainerUI/VBoxContainer/FirstRow/ProgressBar

# UI labels
@onready var gen_time_label:  Label = $UI/Panel/MarginContainerUI/VBoxContainer/Stats/GenTimeLabel
@onready var floor_label:     Label = $UI/Panel/MarginContainerUI/VBoxContainer/Stats/FloorLabel
@onready var coverage_label:  Label = $UI/Panel/MarginContainerUI/VBoxContainer/Stats/CoverageLabel
@onready var size_label:      Label = $UI/Panel/MarginContainerUI/VBoxContainer/Stats/SizeLabel
@onready var status_label:    Label = $UI/Panel/MarginContainerUI/VBoxContainer/Stats/StatusLabel
@onready var coins_label: Label = $UI/MarginContainerCoins/CoinsLabel

# import generators scripts + coin scene
const CoinScene = preload("res://scenes/coin.tscn")
const RoomsGenerator = preload("res://dungeons/algorithms/rooms_generator.gd")
const BSPGenerator = preload("res://dungeons/algorithms/bsp_generator.gd")
const CellularGenerator = preload("res://dungeons/algorithms/cellular_generator.gd")
const DrunkardsGenerator = preload("res://dungeons/algorithms/drunkards_generator.gd")
const MazeGenerator = preload("res://dungeons/algorithms/maze_generator.gd")

# tile types - must match the constants in each generator
enum TileType { EMPTY = 0, 
				FLOOR = 1, 
				WALL = 2 
}

# seed for replicable results
const SEED:int = 1

# positions of tiles in atlas
const TILE_FLOOR_POS:Vector2i = Vector2i(8, 1)
const TILE_WALL_POS: Vector2i = Vector2i(2, 0)
const TILE_SOURCE_ID: int = 0

# default map size
const DUNGEON_WIDTH: int = 60
const DUNGEON_HEIGHT: int= 60

# position of the collision area of the player
const PLAYER_COLLISION_OFFSET: Vector2 = Vector2(49.0, 6.0)

# min and max coins variables, the exact number will be randomly choosen based on this range
const MIN_COINS: int = 5
const MAX_COINS: int = 50

# We need more runs! (At least 1000 results per alg - 200 runs)
const BENCHMARK_RUNS: int = 200

# map sizes for the benchmark
const BENCHMARK_SIZES = [
	Vector2i(60, 60),
	Vector2i(100, 100),
	Vector2i(150, 150),
	Vector2i(20, 50),
	Vector2i(70, 30)
]

# init of empty variables for coins so we can work with them later
var _coins_collected: int = 0
var _coins_total: int = 0
var _spawned_coins: Array[Node] = []



func _ready() -> void:
	# hide the player at start - it will appear after the first generation
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

	# set default width and height to input values in the UI
	width_input.value  = DUNGEON_WIDTH
	height_input.value = DUNGEON_HEIGHT
	benchmark_input.value = BENCHMARK_RUNS
	seed_input.value = SEED


func _reset_coins_state() -> void:
	# clean up the rest of the coins and spawned coins array + reset other vars
	for coin in _spawned_coins:
		if is_instance_valid(coin):
			coin.queue_free()

	_spawned_coins.clear()
	
	_coins_collected = 0
	_coins_total = 0
	coins_label.text = "Coins: 0/0"

func _on_generate_button_pressed() -> void:

	status_label.text = ""
	# hide the player while generating - it will be shown again after placement
	if player:
		player.hide()
	
	# disable generate button so the user can't press it while processing
	generate_button.disabled = true

	_reset_coins_state()

	# get choosen width and height + seed if checked
	var width: int = int(width_input.value)
	var height: int = int(height_input.value)
	var seed_value: int = int(seed_input.value) if seed_checkbox.button_pressed else 0


	# generate selected dungeon
	# only the generate() call is timed
	var t_start: int = Time.get_ticks_usec() # start of the timer

	var map: Array = []
	match dungeon_type_option.selected:
		0: map = RoomsGenerator.generate(width, height, seed_value)
		1: map = BSPGenerator.generate(width, height, seed_value)
		2: map = DrunkardsGenerator.generate(width, height, seed_value)
		3: map = CellularGenerator.generate(width, height, seed_value)
		4: map = MazeGenerator.generate(width, height, seed_value)
		_:
			push_warning("Unknown dungeon type selected.")
			return

	# end timer and get time in ms
	var t_end: int = Time.get_ticks_usec()
	var gen_ms: float = (t_end - t_start) / 1000.0

	# 2. count floor tiles and show the stats
	# this happens before any drawing so the numbers are instant
	var total_tiles: int = width * height
	var floor_count: int = _count_floor_tiles(map)

	# divide floor tiles with all tiles to get coverage
	var coverage_pct: float = (float(floor_count) / float(total_tiles)) * 100.0

	# update labels
	gen_time_label.text = "Gen time: %.2f ms" % gen_ms
	floor_label.text = "Floor tiles: %d" % floor_count
	coverage_label.text = "Coverage: %.1f%%" % coverage_pct
	size_label.text = "Size: %dx%d" % [width, height]
	status_label.text = "Rendering..."



	# 3. draw map row by row
	var floor_tiles: Array[Vector2i] = await _draw_map_animated(map)

	# update camera so it is within the dungeon bounds
	_update_camera_limits(width, height)
	
	# 5. randomly place coins
	_place_coins_on_floor(floor_tiles)

	# 6. place the player
	_place_player_on_floor(floor_tiles)


	status_label.text = "Done"

	# reenable the button
	generate_button.disabled = false


func run_benchmark() -> void: 
	# TODO add more benchmarks with specific seed!
	# TODO add status label and progress bar or something so you can see something is happening during benchmark
	# TODO maybe spinning character to make it more interesting?
	print("Benchmark starts")
	var algorithms = [
		{"name":"Rooms", "func": RoomsGenerator.generate},
		{"name":"BSP", "func": BSPGenerator.generate},
		{"name":"Drunkards", "func": DrunkardsGenerator.generate},
		{"name":"Cellular", "func": CellularGenerator.generate},
		{"name":"Maze", "func": MazeGenerator.generate}
	]

	# get number of benchmark runs
	var benchmark_runs: int = int(benchmark_input.value)
	# get seed value if checked
	var seed_value: int = int(seed_input.value) if seed_checkbox.button_pressed else 0

	# setup progress bar - keep max at 100 and increment by percentage per run
	var total_runs: int = algorithms.size() * BENCHMARK_SIZES.size() * benchmark_runs
	var progress_per_run: float = 100.0 / total_runs
	print("Total runs: ", total_runs)
	print("Progress per run: ", progress_per_run)
	progress_bar.max_value = 100.0
	progress_bar.step = progress_per_run
	progress_bar.value = 0.0

	for algo in algorithms:

		for size in BENCHMARK_SIZES:

			for run in range(benchmark_runs):

				var width = size.x
				var height = size.y

				var t_start = Time.get_ticks_usec()
				var map = algo.func.call(width, height, seed_value)
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

				#print(algo.name, " ", width, "x", height, " run ", run, " done")
				# update progress bar
				progress_bar.value += progress_per_run
				await get_tree().process_frame  # this will ensure the UI updates

	print("Benchmark done")

func _update_camera_limits(map_width: int, map_height: int) -> void:

	var camera: Camera2D = null
	
	if player != null:
		# first try to get the camera of the player node
		camera = player.get_node_or_null("Camera2D")
	
	if camera == null:
		# try to find camera as sibling in main scene
		camera = get_node_or_null("Camera2D")
	
	if camera == null:
		push_warning("No Camera2D found!")
		return

	# get current tile sizes and set the limits
	var tile_size: Vector2i = dungeon_layer.tile_set.tile_size

	camera.limit_left = 0
	camera.limit_top = -30

	camera.limit_right = map_width * tile_size.x
	camera.limit_bottom = map_height * tile_size.y

# draws the map one row at a time with a short delay so you can see it appear
# updates the status label and returns the list of floor tile positions
func _draw_map_animated(map: Array) -> Array[Vector2i]:
	if dungeon_layer == null:
		return []

	if map.is_empty():
		return []

	# clear dungeon layer
	dungeon_layer.clear()


	var floor_tiles: Array[Vector2i] = []
	# measure rendering time
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
func _place_player_on_floor(floor_tiles: Array[Vector2i]) -> void:
	if player == null:
		push_warning("Player node not assigned.")
		return
	if floor_tiles.is_empty():
		push_warning("No floor tiles to spawn the player on.")
		return

	var floor_set: Dictionary = _build_tile_set(floor_tiles)

	# use only the largest connected floor region
	var main_region: Array[Vector2i] = _get_largest_floor_region(floor_tiles, floor_set)
	if main_region.is_empty():
		push_warning("No connected floor region found for player spawn.")
		return

	var main_region_set: Dictionary = _build_tile_set(main_region)

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


# finds the largest connected group of floor tiles using BFS (breadth-first search)
# returns only the tiles belonging to that region
func _get_largest_floor_region(floor_tiles: Array[Vector2i], floor_set: Dictionary) -> Array[Vector2i]:
	var visited: Dictionary = {}
	var largest_region: Array[Vector2i] = []

	for start_tile in floor_tiles:
		# skip tiles that were already part of a previous region
		if visited.has(start_tile):
			continue

		# BFS: explore all connected floor tiles starting from start_tile
		var region: Array[Vector2i] = []
		var queue: Array[Vector2i] = [start_tile]
		visited[start_tile] = true

		while not queue.is_empty():
			var current: Vector2i = queue.pop_front()
			region.append(current)

			# check all 4 neighbors (up, down, left, right)
			for neighbor in _get_floor_neighbors_4(current):
				if floor_set.has(neighbor) and not visited.has(neighbor):
					visited[neighbor] = true
					queue.append(neighbor)

		# keep track of the biggest region found so far
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

# creates a dictionary from tile positions for fast O(1) lookups using hashed keys
# Array.has() scans all elements, Dictionary.has() uses a hash table which is faster
func _build_tile_set(tiles: Array[Vector2i]) -> Dictionary:
	var tile_set: Dictionary = {}
	for tile in tiles:
		tile_set[tile] = true
	return tile_set

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

	var floor_set: Dictionary = _build_tile_set(floor_tiles)

	# use only the largest connected floor region
	var main_region: Array[Vector2i] = _get_largest_floor_region(floor_tiles, floor_set)
	if main_region.is_empty():
		push_warning("No connected floor region found for coin spawn.")
		return

	# pick a random coin_count between MIN and MAX, still consideres the floor count
	var coin_count: int = randi_range(MIN_COINS, MAX_COINS)
	# duplicate and shuffle the region so we pick random positions
	var shuffled: Array[Vector2i] = main_region.duplicate()
	shuffled.shuffle()

	# cap coin count to available floor tiles in case the region is small
	coin_count = mini(coin_count, shuffled.size())

	# reset coin tracking state
	_coins_collected = 0
	_coins_total = coin_count
	coins_label.text = "Coins: %d/%d" % [_coins_collected, _coins_total]

	# instantiate each coin at a random floor tile and connect its signal
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
	# if you collect all coins, new dungeon will be generated
	_coins_collected += 1
	coins_label.text = "Coins: %d/%d" % [_coins_collected, _coins_total]
	if _coins_collected == _coins_total:
		coins_label.text = "ALL COINS COLLECTED! NEW DUNGEON IS BEING GENERATED"
		_on_generate_button_pressed()
		
func _log_results(algorithm:String, width:int, height:int, run:int, gen_time:float, coverage:float, floor_tiles:int):
	# function for logging benchmark results
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
	benchmark_button.disabled = true
	status_label.text = "Benchmark is running ..."
	await run_benchmark()
	status_label.text = "Benchmark has finished. Data were saved to results.csv"
	generate_button.disabled = false
	benchmark_button.disabled = false
