extends Node3D

# ---------------------------------------------------------
# GlobalGrid (Façade)
# ---------------------------------------------------------
# Responsibilities:
#   - Public API for spatial hashing (CPU or GPU backend)
#   - Store reference to global positions
#   - Delegate rebuild + neighbour queries to CPUGrid or GPUGrid
#   - Provide helper functions used by external systems
#
# It does NOT:
#   - Implement grid logic directly (delegated to children)
#   - Know how CPU/GPU grids store their data internally
# ---------------------------------------------------------

@onready var cpu_grid: Node = $CPUGrid
@onready var gpu_grid: Node = $GPUGrid

# Internal mode switch ("CPU" or "GPU")
var mode: String = "CPU"

# Reference to global positions (shared by all swarms)
var global_positions_ref: PackedVector3Array = PackedVector3Array()


# ---------------------------------------------------------
# Set reference to global positions
# Called by SwarmManager before rebuild
# ---------------------------------------------------------
func set_global_positions_ref(ref: PackedVector3Array) -> void:
	global_positions_ref = ref
	cpu_grid.set_global_positions_ref(ref)
	gpu_grid.set_global_positions_ref(ref)


# ---------------------------------------------------------
# Convert world position → grid cell
# (Shared helper used by debug + external systems)
# ---------------------------------------------------------
func cell_from_pos(pos: Vector3) -> Vector3i:
	return cpu_grid.cell_from_pos(pos)  # identical logic for both backends


# ---------------------------------------------------------
# Get position for a specific global index
# ---------------------------------------------------------
func get_position_for_global_index(global_i: int) -> Vector3:
	return global_positions_ref[global_i]


# ---------------------------------------------------------
# Rebuild the grid using the active backend
# ---------------------------------------------------------
func rebuild(global_positions: PackedVector3Array) -> void:
	if mode == "CPU":
		cpu_grid.rebuild(global_positions)
	else:
		gpu_grid.rebuild(global_positions)


# ---------------------------------------------------------
# Get raw neighbour candidates for a global index
# Delegated to backend
# ---------------------------------------------------------
func get_neighbours(global_i: int) -> PackedInt32Array:
	if mode == "CPU":
		return cpu_grid.get_neighbours(global_i)
	else:
		return gpu_grid.get_neighbours(global_i)
