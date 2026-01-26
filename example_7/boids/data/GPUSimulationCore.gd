extends Node

# ---------------------------------------------------------
# GPUSimulationCore
# ---------------------------------------------------------
# Responsibilities:
#   - Own all GPU simulation state for a single swarm
#   - Allocate and manage GPU buffers (positions, velocities, grid, etc.)
#   - Run the full GPU simulation pipeline each frame
#
# It does NOT:
#   - Store positions/velocities on the CPU
#   - Know about SwarmManager or GlobalGrid
#   - Handle rendering (renderer consumes GPU data separately)
# ---------------------------------------------------------

var boid_count: int = 0

var limits: Dictionary = {}
var weights: Dictionary = {}
var cage_radius: float = 0.0

var FOV_angle_rad: float = 0.0
var FOV_DOT_THRESHOLD: float = 0.0

var behaviours_mask: Dictionary = {}

# GPU handles (to be implemented)
var rd: RenderingDevice = null
var positions_buffer: RID
var velocities_buffer: RID
# Additional buffers (grid, neighbours, etc.) will be added later.


func _ready() -> void:
	rd = RenderingServer.get_rendering_device()


# ---------------------------------------------------------
# One‑time setup from BoidData
# ---------------------------------------------------------
func setup(
	boid_count_in: int,
	limits_in: Dictionary,
	weights_in: Dictionary,
	cage_radius_in: float,
	FOV_angle_rad_in: float,
	FOV_DOT_THRESHOLD_in: float,
	behaviours_mask_in: Dictionary
) -> void:
	boid_count = boid_count_in
	limits = limits_in
	weights = weights_in
	cage_radius = cage_radius_in
	FOV_angle_rad = FOV_angle_rad_in
	FOV_DOT_THRESHOLD = FOV_DOT_THRESHOLD_in
	behaviours_mask = behaviours_mask_in

	_allocate_buffers()
	_initialize_state_on_gpu()


func _allocate_buffers() -> void:
	if boid_count <= 0:
		return

	# Positions: vec4 per boid (x, y, z, w)
	var positions_bytes: int = boid_count * 16
	positions_buffer = rd.storage_buffer_create(positions_bytes)

	# Velocities: vec4 per boid (x, y, z, w)
	var velocities_bytes: int = boid_count * 16
	velocities_buffer = rd.storage_buffer_create(velocities_bytes)

	# Additional buffers (grid, neighbours, etc.) will be added here later.


func _initialize_state_on_gpu() -> void:
	# For now, just a placeholder.
	# Later: dispatch a compute shader to randomize positions/velocities on the GPU.
	print("GPUSimulationCore: initialize GPU state (positions/velocities) coming soon.")


# ---------------------------------------------------------
# Per‑frame simulation step
# ---------------------------------------------------------
func step_simulation(delta: float) -> void:
	# This will become:
	#   1. grid_assign_pass
	#   2. grid_sort_pass (later)
	#   3. grid_ranges_pass
	#   4. behaviour_pass
	#   5. integration_pass (update positions/velocities)
	#
	# For now, just a placeholder.
	print("GPUSimulationCore: step_simulation(", delta, ") - GPU pipeline coming soon.")


func run_behaviour_pass(
	delta: float,
	global_core: Node,
	start_index: int,
	count: int
) -> void:
	# Later: dispatch behaviour compute shader using:
	#   - global_core.get_positions_buffer()
	#   - global_core.get_velocities_buffer()
	#   - global_core.get_cell_* buffers
	#   - start_index, count
	print("Swarm behaviour pass stub: ", start_index, " + ", count)
