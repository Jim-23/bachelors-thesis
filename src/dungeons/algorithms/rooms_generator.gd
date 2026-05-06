# res://dungeons/algorithms/rooms_generator.gd

# random rooms generator

# 1. try to place random rectangles on the map without overlapping
# 2. connect each new room to the previous one with an l-shaped corridor
# 3. add walls around all floor tiles

extends RefCounted

const TILE_EMPTY: int = 0
const TILE_FLOOR: int = 1
const TILE_WALL:  int = 2

# average room is 11x11 = 121 tiles; multiplied by 3 to consider corridors, walls, and spacing between rooms -> approx. one room per 360 tiles of map area
const AREA_PER_ROOM: int = 360

static func generate(width: int, height: int, seed_value: int) -> Array:
	var rng := RandomNumberGenerator.new()
	if seed_value == 0:
		rng.randomize()
	else:
		rng.seed = seed_value

	# start with an empty map
	var map: Array = []
	for y: int in range(height):
		var row: Array = []
		for x: int in range(width):
			row.append(TILE_EMPTY)
		map.append(row)

	var rooms: Array[Rect2] = []

	@warning_ignore("integer_division") # it was annoying so I ignore it but could make a mess in the future
	# calculate the number of rooms that we can approximately place in the map area
	var room_count: int = maxi(5, (width * height) / AREA_PER_ROOM)
	var max_attempts: int = room_count * 10 # based on the room_count, we get at least 10 attempts
	var tries: int = 0

	# keep trying to place rooms until we reach the target or run out of attempts
	while rooms.size() < room_count and tries < max_attempts:
		var w: int = rng.randi_range(6, 16)
		var h: int = rng.randi_range(6, 16)

		# skip if the room won't fit on the map
		if width < w + 2 or height < h + 2:
			tries += 1
			continue

		var x: int = rng.randi_range(1, width  - w - 1)
		var y: int = rng.randi_range(1, height - h - 1)

		var room: Rect2 = Rect2(x, y, w, h)

		# skip this room if it overlaps with an existing one (1-tile gap between rooms)
		var overlaps: bool = false
		for other in rooms:
			if room.grow(1).intersects(other):
				overlaps = true
				break

		if not overlaps:
			rooms.append(room)

			# carve the floor tiles for this room
			for iy: int in range(y, y + h):
				for ix: int in range(x, x + w):
					(map[iy] as Array)[ix] = TILE_FLOOR

			# connect to the previous room with a corridor
			if rooms.size() > 1:
				var prev_center: Vector2 = rooms[rooms.size() - 2].get_center()
				var curr_center: Vector2 = room.get_center()
				_carve_corridor(map, prev_center, curr_center, width, height, rng)

		tries += 1

	# place walls around all the floor tiles
	_add_walls(map, width, height)
	return map


# carves a 2-tile-wide l-shaped corridor between two points
# randomly picks horizontal-first or vertical-first
static func _carve_corridor(map: Array, from: Vector2, to: Vector2,
		width: int, height: int, rng: RandomNumberGenerator,
		corridor_width: int = 2) -> void:

	var fx: int = int(from.x)
	var fy: int = int(from.y)
	var tx: int = int(to.x)
	var ty: int = int(to.y)

	if rng.randf() < 0.5:
		# horizontal first, then vertical
		for cx: int in range(min(fx, tx), max(fx, tx) + 1):
			for off: int in range(corridor_width):
				var cy: int = fy + off
				if _in_bounds(cx, cy, width, height):
					(map[cy] as Array)[cx] = TILE_FLOOR
		for cy: int in range(min(fy, ty), max(fy, ty) + 1):
			for off: int in range(corridor_width):
				var cx: int = tx + off
				if _in_bounds(cx, cy, width, height):
					(map[cy] as Array)[cx] = TILE_FLOOR
	else:
		# vertical first, then horizontal
		for cy: int in range(min(fy, ty), max(fy, ty) + 1):
			for off: int in range(corridor_width):
				var cx: int = fx + off
				if _in_bounds(cx, cy, width, height):
					(map[cy] as Array)[cx] = TILE_FLOOR
		for cx: int in range(min(fx, tx), max(fx, tx) + 1):
			for off: int in range(corridor_width):
				var cy: int = ty + off
				if _in_bounds(cx, cy, width, height):
					(map[cy] as Array)[cx] = TILE_FLOOR


# checks if tile is inside the map boundaries
static func _in_bounds(x: int, y: int, width: int, height: int) -> bool:
	return x >= 0 and y >= 0 and x < width and y < height


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
