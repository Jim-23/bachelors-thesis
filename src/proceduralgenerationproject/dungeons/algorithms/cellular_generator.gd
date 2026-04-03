# res://dungeons/algorithms/cellular_generator.gd
#
# cellular automata cave generator
#
# how it works:
#   1. fill the map randomly - each tile becomes floor with 45% chance
#   2. run 5 simulation steps where each tile looks at its 8 neighbours:
#      if 4 or more neighbours are floor -> tile becomes/stays floor
#      otherwise -> tile becomes/stays empty
#   3. add walls around all floor tiles
#
# produces organic cave-like maps, completely different from room-based generators
# note: connectivity is not guaranteed - isolated pockets can appear on small maps

extends RefCounted

const TILE_EMPTY: int = 0
const TILE_FLOOR: int = 1
const TILE_WALL: int = 2

# 45% fill gives a good balance between open space and walls
const FILL_PROBABILITY: float = 0.45

# more steps = smoother and rounder caves
const SIMULATION_STEPS: int = 5

static func generate(width: int, height: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.randomize()

	# step 1: random fill
	# the 1-tile border always stays empty
	var map: Array = []
	for y: int in range(height):
		var row: Array = []
		for x: int in range(width):
			if x == 0 or x == width - 1 or y == 0 or y == height - 1:
				row.append(TILE_EMPTY)
			elif rng.randf() < FILL_PROBABILITY:
				row.append(TILE_FLOOR)
			else:
				row.append(TILE_EMPTY)
		map.append(row)

	# step 2: run the simulation
	for _step in range(SIMULATION_STEPS):
		map = _simulate_step(map, width, height)

	# step 3: add walls
	_add_walls(map, width, height)
	return map


# runs one simulation step and returns the updated map
# we write into a new map so the old state isn't changed mid-step
static func _simulate_step(map: Array, width: int, height: int) -> Array:
	var new_map: Array = []
	for y: int in range(height):
		var row: Array = []
		for x: int in range(width):
			row.append(TILE_EMPTY)
		new_map.append(row)

	for y: int in range(height):
		for x: int in range(width):
			# border always stays empty
			if x == 0 or x == width - 1 or y == 0 or y == height - 1:
				(new_map[y] as Array)[x] = TILE_EMPTY
				continue

			var floor_count: int = _count_floor_neighbours(map, x, y, width, height)

			# 4+ floor neighbours -> floor, otherwise empty
			# this smooths out noise and creates solid cave walls
			if floor_count >= 4:
				(new_map[y] as Array)[x] = TILE_FLOOR
			else:
				(new_map[y] as Array)[x] = TILE_EMPTY

	return new_map


# counts how many of the 8 surrounding tiles are floor
static func _count_floor_neighbours(map: Array, x: int, y: int, width: int, height: int) -> int:
	var count: int = 0
	for dy: int in range(-1, 2):
		for dx: int in range(-1, 2):
			if dx == 0 and dy == 0:
				continue  # skip the tile itself
			var nx: int = x + dx
			var ny: int = y + dy
			if nx >= 0 and nx < width and ny >= 0 and ny < height:
				if (map[ny] as Array)[nx] == TILE_FLOOR:
					count += 1
	return count


# surrounds all floor tiles with walls where there is empty space
static func _add_walls(map: Array, width: int, height: int) -> void:
	for y: int in range(height):
		for x: int in range(width):
			if (map[y] as Array)[x] == TILE_FLOOR:
				for dy: int in range(-1, 2):
					for dx: int in range(-1, 2):
						var nx: int = x + dx
						var ny: int = y + dy
						if nx >= 0 and nx < width and ny >= 0 and ny < height:
							if (map[ny] as Array)[nx] == TILE_EMPTY:
								(map[ny] as Array)[nx] = TILE_WALL
