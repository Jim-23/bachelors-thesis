# res://dungeons/algorithms/drunkards_generator.gd

# drunkard's walk generator

# 1. start at the center of the map
# 2. carve a 3x3 area at the start so the player always has a safe spawn
# 3. move one step in a random direction (up/down/left/right)
# 4. every 15-25 steps carve a small 3x3 room, otherwise carve a 2x2 corridor
# 5. stop when 50% of the map is floor
# 6. add walls around all floor tiles

extends RefCounted

const TILE_EMPTY: int = 0
const TILE_FLOOR: int = 1
const TILE_WALL: int = 2

const TARGET_COVERAGE: int = 50

static func generate(width: int, height: int, seed_value: int) -> Array:
	# start with an empty map
	var map: Array = []
	for y: int in range(height):
		var row: Array = []
		for x: int in range(width):
			row.append(TILE_EMPTY)
		map.append(row)

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	if seed_value == 0:
		rng.randomize()
	else:
		rng.seed = seed_value

	# start the walk at the center
	@warning_ignore("integer_division")
	var x: int = width / 2
	@warning_ignore("integer_division")
	var y: int = height / 2

	(map[y] as Array)[x] = TILE_FLOOR

	# keep going until  TARGET_COVERAGE  tiles are floor
	@warning_ignore("integer_division")
	var target_floor_count: int = (width * height * TARGET_COVERAGE) / 100
	var current_floor_count: int = 1

	# carve the guaranteed 3x3 spawn area
	current_floor_count += _carve_area(map, x - 1, y - 1, width, height, 3)

	var steps_since_room: int = 0

	while current_floor_count < target_floor_count:
		# move one step in a random direction
		var dir: int = rng.randi_range(0, 3)
		match dir:
			0: x += 1
			1: x -= 1
			2: y += 1
			3: y -= 1

		# stay 2 tiles away from the edge so 3x3 carves never go out of bounds
		x = clamp(x, 2, width - 4)
		y = clamp(y, 2, height - 4)

		steps_since_room += 1

		# carve a room every 15-25 steps, otherwise just carve a small corridor
		if steps_since_room > rng.randi_range(15, 25):
			current_floor_count += _carve_area(map, x - 1, y - 1, width, height, 3)
			steps_since_room = 0
		else:
			current_floor_count += _carve_area(map, x, y, width, height, 2)

	_add_walls(map, width, height)
	return map

# carves a 2x2 or 3x3  area, return how many new floor tiles were created
static func _carve_area(map: Array, x: int, y: int, width: int, height: int, area_size: int) -> int:
	var carved_count: int = 0
	for dy in range(area_size):
		for dx in range(area_size):
			var nx: int = x + dx
			var ny: int = y + dy

			# only carve inside the map border and if not already floor
			if nx > 0 and nx < width - 1 and ny > 0 and ny < height - 1:
				if (map[ny] as Array)[nx] != TILE_FLOOR:
					(map[ny] as Array)[nx] = TILE_FLOOR
					carved_count += 1
	return carved_count


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
