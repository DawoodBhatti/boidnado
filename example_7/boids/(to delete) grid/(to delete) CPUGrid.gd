extends Node

# ---------------------------------------------------------
# CPUGrid
# ---------------------------------------------------------
# Responsibilities:
#   - Maintain a CPU-side spatial hash
#   - Bucket global indices into 3D grid cells
#   - Return raw neighbour candidates
#
# It does NOT:
#   - Apply FOV, sight radius, or swarm filtering
#   - Perform behaviour logic
# ---------------------------------------------------------

var cell_size: float = 4.0

# Dictionary: cell → PackedInt32Array of global indices
var grid: Dictionary = {}

# Reference to global positions (set by GlobalGrid)
var global_positions_ref: PackedVector3Array = PackedVector3Array()

# Temporary list reused to avoid allocations
var temp_list: PackedInt32Array = PackedInt32Array()


func set_global_positions_ref(ref: PackedVector3Array) -> void:
	global_positions_ref = ref


func cell_from_pos(pos: Vector3) -> Vector3i:
	var x: int = int(floor(pos.x / cell_size))
	var y: int = int(floor(pos.y / cell_size))
	var z: int = int(floor(pos.z / cell_size))
	return Vector3i(x, y, z)


func rebuild(global_positions: PackedVector3Array) -> void:
	grid.clear()

	var count: int = global_positions.size()

	for i in count:
		var pos: Vector3 = global_positions[i]
		var cell: Vector3i = cell_from_pos(pos)

		if grid.has(cell) == false:
			grid[cell] = PackedInt32Array()

		grid[cell].append(i)


func get_neighbours(global_i: int) -> PackedInt32Array:
	temp_list = PackedInt32Array()

	var pos: Vector3 = global_positions_ref[global_i]
	var cell: Vector3i = cell_from_pos(pos)

	for dx in range(-1, 2):
		for dy in range(-1, 2):
			for dz in range(-1, 2):

				var neighbour_cell: Vector3i = Vector3i(
					cell.x + dx,
					cell.y + dy,
					cell.z + dz
				)

				if grid.has(neighbour_cell):
					var arr: PackedInt32Array = grid[neighbour_cell]

					for g in arr:
						if g != global_i:
							temp_list.append(g)

	return temp_list
