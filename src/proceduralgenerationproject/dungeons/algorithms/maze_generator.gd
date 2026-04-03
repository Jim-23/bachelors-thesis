# res://dungeons/algorithms/maze_generator.gd
#
# recursive backtracker maze generator (depth-first search)
#
# how it works:
#   1. split the map into a grid of abstract cells
#      (each cell is 2x2 floor tiles with a 1-tile gap between cells)
#   2. start dfs from cell (0,0) and randomly carve through walls to unvisited neighbours
#   3. backtrack when no unvisited neighbours are left
#   4. translate the cell grid into actual floor tiles on the map
#   5. add walls around all floor tiles
#
# this always produces a perfect maze - every cell is reachable and
# there is exactly one path between any two points

extends RefCounted

const TILE_EMPTY: int = 0
const TILE_FLOOR: int = 1
const TILE_WALL: int = 2

# bit flags for the four walls of a cell
const N: int = 1
const E: int = 2
const S: int = 4
const W: int = 8

# maps a direction vector to the corresponding wall bit
static var cell_walls := {
	Vector2i(0, -1): N,
	Vector2i(1, 0): E,
	Vector2i(0, 1): S,
	Vector2i(-1, 0): W
}

# the opposite wall for each direction (used when removing walls between cells)
static var opposite_walls := {
	N: S,
	S: N,
	E: W,
	W: E
}


static func generate(width: int, height: int) -> Array:
	# start with an empty map
	var map: Array = []
	for y: int in range(height):
		var row: Array = []
		for x: int in range(width):
			row.append(TILE_EMPTY)
		map.append(row)

	# figure out how many cells fit inside the map
	# layout: 1-tile border on each side, each cell takes 3 tiles (2 floor + 1 wall gap)
	@warning_ignore("integer_division")
	var cells_w: int = max(1, (width - 2) / 3)
	@warning_ignore("integer_division")
	var cells_h: int = max(1, (height - 2) / 3)

	# every cell starts with all four walls present
	var grid: Dictionary = {}
	for cy in range(cells_h):
		for cx in range(cells_w):
			grid[Vector2i(cx, cy)] = N | E | S | W

	# --- depth-first search ---
	var stack: Array[Vector2i] = []
	var current_cell := Vector2i(0, 0)

	# unvisited holds all cells we haven't reached yet
	var unvisited: Dictionary = grid.duplicate()
	unvisited.erase(current_cell)  # starting cell is visited immediately

	var rng := RandomNumberGenerator.new()
	rng.randomize()

	while unvisited.size() > 0:
		# get unvisited neighbours of the current cell
		var neighbours := _check_neighbours(current_cell, unvisited, cells_w, cells_h)

		if neighbours.size() > 0:
			# pick a random neighbour and carve through the wall to it
			var next: Vector2i = neighbours[rng.randi() % neighbours.size()]
			stack.append(current_cell)

			# remove the wall on both sides
			var dir: Vector2i = next - current_cell
			grid[current_cell] = grid[current_cell] - cell_walls[dir]
			grid[next]         = grid[next]         - cell_walls[-dir]

			current_cell = next
			unvisited.erase(current_cell)
		elif stack.size() > 0:
			# dead end - go back one step
			current_cell = stack.pop_back()
		else:
			# stack is empty but there are still unvisited cells - jump to one
			if unvisited.size() > 0:
				current_cell = unvisited.keys()[0]
				unvisited.erase(current_cell)

	# --- translate cells to tiles ---
	# each cell's floor area starts at tile (1 + cell_x*3, 1 + cell_y*3)
	# corridors fill the 1-tile gap between adjacent cells
	for cell_pos in grid.keys():
		var cell_x: int = cell_pos.x
		var cell_y: int = cell_pos.y
		var walls: int  = grid[cell_pos]

		# top-left tile of this cell's 2x2 floor area
		var tile_x: int = 1 + cell_x * 3
		var tile_y: int = 1 + cell_y * 3

		# draw the 2x2 floor area
		for dy in range(2):
			for dx in range(2):
				var tx: int = tile_x + dx
				var ty: int = tile_y + dy
				if tx >= 1 and tx < width - 1 and ty >= 1 and ty < height - 1:
					(map[ty] as Array)[tx] = TILE_FLOOR

		# north corridor - connects to the cell above
		if not (walls & N):
			for dx in range(2):
				var tx: int = tile_x + dx
				var ty: int = tile_y - 1
				if tx >= 1 and tx < width - 1 and ty >= 1 and ty < height - 1:
					(map[ty] as Array)[tx] = TILE_FLOOR

		# east corridor - connects to the cell on the right
		if not (walls & E):
			for dy in range(2):
				var tx: int = tile_x + 2
				var ty: int = tile_y + dy
				if tx >= 1 and tx < width - 1 and ty >= 1 and ty < height - 1:
					(map[ty] as Array)[tx] = TILE_FLOOR

		# south corridor - connects to the cell below
		if not (walls & S):
			for dx in range(2):
				var tx: int = tile_x + dx
				var ty: int = tile_y + 2
				if tx >= 1 and tx < width - 1 and ty >= 1 and ty < height - 1:
					(map[ty] as Array)[tx] = TILE_FLOOR

		# west corridor - connects to the cell on the left
		if not (walls & W):
			for dy in range(2):
				var tx: int = tile_x - 1
				var ty: int = tile_y + dy
				if tx >= 1 and tx < width - 1 and ty >= 1 and ty < height - 1:
					(map[ty] as Array)[tx] = TILE_FLOOR

	_add_walls(map, width, height)
	return map


# returns all unvisited neighbours of a cell that are inside the grid
static func _check_neighbours(cell: Vector2i, unvisited: Dictionary,
		cells_w: int, cells_h: int) -> Array[Vector2i]:
	var list: Array[Vector2i] = []
	for dir in cell_walls.keys():
		var neighbour: Vector2i = cell + dir
		# make sure the neighbour is within bounds and not yet visited
		if neighbour.x >= 0 and neighbour.x < cells_w and neighbour.y >= 0 and neighbour.y < cells_h:
			if unvisited.has(neighbour):
				list.append(neighbour)
	return list


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
