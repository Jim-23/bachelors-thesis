# res://dungeons/algorithms/bsp_generator.gd
#
# binary space partitioning (bsp) dungeon generator
#
# how it works:
#   1. the whole map is one big rectangle (the root branch)
#   2. we recursively split it into two smaller pieces, building a binary tree
#   3. the leaves of the tree (smallest unsplit pieces) each get one room
#   4. every pair of sibling branches is connected with an l-shaped corridor
#   5. walls are added around all floor tiles

extends RefCounted

const TILE_EMPTY: int = 0
const TILE_FLOOR: int = 1
const TILE_WALL: int = 2


class Branch:
	var left_child: Branch
	var right_child: Branch
	var position: Vector2i  # top-left corner on the map
	var size: Vector2i      # width and height in tiles
	var padding: Vector4i   # how many tiles to inset the room (left, top, right, bottom)

	# rng is shared across the whole tree so every split gets a different value
	func _init(pos: Vector2i, sz: Vector2i, rng: RandomNumberGenerator) -> void:
		position = pos
		size = sz
		# random inset of 2-3 tiles on each side so rooms don't touch branch edges
		padding = Vector4i(
			rng.randi_range(2, 3),
			rng.randi_range(2, 3),
			rng.randi_range(2, 3),
			rng.randi_range(2, 3)
		)

	# returns all leaf nodes (the actual rooms)
	func get_leaves() -> Array:
		if not (left_child and right_child):
			return [self]
		return left_child.get_leaves() + right_child.get_leaves()

	# returns the center tile of this branch area
	func get_center() -> Vector2i:
		@warning_ignore("integer_division")
		return Vector2i(position.x + size.x / 2, position.y + size.y / 2)

	# splits this branch in two and records the connection for corridor drawing
	func split(remaining: int, paths: Array, rng: RandomNumberGenerator) -> void:
		# split horizontally if taller than wide, otherwise vertically
		var split_horizontal: bool = size.y >= size.x
		var split_percent: float = rng.randf_range(0.35, 0.65)

		if split_horizontal:
			var left_height: int = int(size.y * split_percent)
			left_child  = Branch.new(position, Vector2i(size.x, left_height), rng)
			right_child = Branch.new(
				Vector2i(position.x, position.y + left_height),
				Vector2i(size.x, size.y - left_height),
				rng
			)
		else:
			var left_width: int = int(size.x * split_percent)
			left_child  = Branch.new(position, Vector2i(left_width, size.y), rng)
			right_child = Branch.new(
				Vector2i(position.x + left_width, position.y),
				Vector2i(size.x - left_width, size.y),
				rng
			)

		# save the two centers so we can draw a corridor between them later
		paths.push_back({
			"left":  left_child.get_center(),
			"right": right_child.get_center()
		})

		# keep splitting if we have budget left
		if remaining > 0:
			left_child.split(remaining - 1, paths, rng)
			right_child.split(remaining - 1, paths, rng)


static func generate(width: int, height: int) -> Array:
	# start with an empty map
	var map: Array = []
	for y: int in range(height):
		var row: Array = []
		for x: int in range(width):
			row.append(TILE_EMPTY)
		map.append(row)

	# one rng shared across the whole tree
	var rng := RandomNumberGenerator.new()
	rng.randomize()

	# build the tree - 3 levels of splitting gives up to 8 rooms
	var paths: Array = []
	var root_branch := Branch.new(Vector2i(1, 1), Vector2i(width - 2, height - 2), rng)
	root_branch.split(3, paths, rng)

	# draw each leaf room inset by its padding
	for leaf in root_branch.get_leaves():
		var pad: Vector4i = leaf.padding
		for lx in range(leaf.size.x):
			for ly in range(leaf.size.y):
				if _is_inside_padding(lx, ly, leaf, pad):
					continue
				var mx: int = lx + leaf.position.x
				var my: int = ly + leaf.position.y
				if mx > 0 and mx < width - 1 and my > 0 and my < height - 1:
					(map[my] as Array)[mx] = TILE_FLOOR

	# draw corridors connecting sibling rooms
	for path in paths:
		var a: Vector2i = path["left"]
		var b: Vector2i = path["right"]
		_carve_l_corridor(map, a, b, width, height)

	_add_walls(map, width, height)
	return map


# checks if a tile falls within the padding border (not actual room space)
static func _is_inside_padding(x: int, y: int, leaf: Branch, pad: Vector4i) -> bool:
	return x < pad.x or y < pad.y or x >= leaf.size.x - pad.z or y >= leaf.size.y - pad.w


# carves a 2-tile-wide l-shaped corridor from a to b
# goes horizontal first then vertical
static func _carve_l_corridor(map: Array, a: Vector2i, b: Vector2i, width: int, height: int) -> void:
	# horizontal segment
	for cx in range(min(a.x, b.x), max(a.x, b.x) + 1):
		for dy in range(2):
			var ty: int = a.y + dy
			if cx > 0 and cx < width - 1 and ty > 0 and ty < height - 1:
				(map[ty] as Array)[cx] = TILE_FLOOR

	# vertical segment
	for cy in range(min(a.y, b.y), max(a.y, b.y) + 1):
		for dx in range(2):
			var tx: int = b.x + dx
			if tx > 0 and tx < width - 1 and cy > 0 and cy < height - 1:
				(map[cy] as Array)[tx] = TILE_FLOOR


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
