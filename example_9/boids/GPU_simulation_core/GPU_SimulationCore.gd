extends Node

"""
GPU_SimulationCore.gd
---------------------

This node is the *orchestrator* of the GPU simulation pipeline.

ARCHITECTURE:

 - GPU_Device owns the RenderingDevice, shaders, and compute pipelines.
 - GPU_Buffers owns all GPU storage buffers and RDUniform descriptors.
 - Each compute pass (GridAssign, GridSort, Behaviour, etc.)
     * pulls buffers from GPU_Buffers
     * pulls pipelines from GPU_Device
     * builds its own uniform set
     * dispatches its own compute work

GPU_SimulationCore does NOT:
 - build uniform sets
 - create pipelines
 - manage shader layouts
 - touch GPU buffers directly

It simply:
 - initialises buffers once
 - computes workgroup counts
 - calls each compute pass in sequence
 - exposes GPU_Buffers to other systems (Renderer, Debug)
"""

# ---------------------------------------------------------
# Internal state
# ---------------------------------------------------------
var debug_print : = false

# ---------------------------------------------------------
# Simulation parameters
# ---------------------------------------------------------
var total_boids : int = 0
var workgroup_count : int = 0
var local_group_size : int = 64

# ---------------------------------------------------------
# Grid / world dimensions (derived from cage radius + cell size)
# ---------------------------------------------------------
var grid_dim_x : int = 0
var grid_dim_y : int = 0
var grid_dim_z : int = 0
var grid_cell_count : int = 0

# ---------------------------------------------------------
# Sibling nodes
# ---------------------------------------------------------
var renderer : Node

# ---------------------------------------------------------
# Child nodes (GPU subsystems)
# ---------------------------------------------------------
var gpu_device : Node              # GPU_Device (RenderingDevice + pipelines)
var gpu_buffers : Node             # GPU_Buffers (storage buffers + RDUniform descriptors)
var pass_grid_assign : Node
var pass_grid_clear : Node
var pass_grid_sort : Node
var pass_grid_mapping : Node
var pass_behaviour : Node
var pass_density3D : Node
var pass_integration : Node
var pass_test : Node
var pass_debug : Node

var rd : RenderingDevice       # Cached RenderingDevice reference


func _ready() -> void:
	# ---------------------------------------------------------
	# Cache subsystem references
	# ---------------------------------------------------------
	gpu_device = get_node("GPU_Device")
	gpu_buffers = get_node("GPU_Buffers")
	pass_debug = get_node("GPU_Debug")
	renderer = get_node("../Renderer3D")
	
	# Wait until GPU_Device and GPU_Buffers report ready
	await _wait_for_gpu_backend()

	rd = gpu_device.rd
	
	await _wait_for_renderer()

	# All compute passes live under GPU_Passes
	var passes : Node = get_node("GPU_Passes")

	pass_test = passes.get_node("Pass_TestPass")
	pass_grid_assign = passes.get_node("Pass_GridAssign")
	pass_grid_clear = passes.get_node("Pass_GridClear")
	pass_grid_sort = passes.get_node("Pass_GridSort")
	pass_grid_mapping = passes.get_node("Pass_GridMapping")
	pass_behaviour = passes.get_node("Pass_Behaviour")
	pass_density3D = passes.get_node("Pass_Density3D")
	pass_integration = passes.get_node("Pass_Integration")

	# NOTE:
	# Other systems (Renderer, Debug tools) should access GPU buffers
	# ONLY through:
	#     get_node("RootMaster/Boids/GPU_SimulationCore").buffers
	#
	# This ensures a single source of truth for GPU data.


# ---------------------------------------------------------
# Helper: wait until GPU Buffers and Device fully initialised
# ---------------------------------------------------------
func _wait_for_gpu_backend() -> void:
	# Simple polling loop; usually resolves in 1 frame
	while not gpu_device.is_initialised or not gpu_buffers.is_initialised:
		await get_tree().process_frame

	# Optional: strong asserts once the loop exits
	assert(gpu_device.rd != null)


# ---------------------------------------------------------
# Helper: wait until renderer fully initialised
# ---------------------------------------------------------
func _wait_for_renderer() -> void:
	# Simple polling loop; usually resolves in 1 frame
	while not renderer.is_initialised:
		await get_tree().process_frame

	# Optional: strong asserts once the loop exits
	assert(gpu_device.rd != null)

# ---------------------------------------------------------
# Helper: compute grid dimensions from cage radius
# ---------------------------------------------------------
func get_grid_dimensions(grid_cell_size : float, swarm_params : Array) -> Dictionary:
	var max_cage_radius : float = 0.0

	for p in swarm_params:
		var r : float = float(p["constants"]["cage_radius"])
		if r > max_cage_radius:
			max_cage_radius = r

	var grid_extent : float = max_cage_radius * 2.0

	var dim_x : int = int(floor(grid_extent / grid_cell_size))
	var dim_y : int = int(floor(grid_extent / grid_cell_size))
	var dim_z : int = int(floor(grid_extent / grid_cell_size))

	var cell_count : int = dim_x * dim_y * dim_z

	var result : Dictionary = {
		"dim_x": dim_x,
		"dim_y": dim_y,
		"dim_z": dim_z,
		"cell_count": cell_count
	}
	return result


# ---------------------------------------------------------
# INITIALISATION ENTRY POINT
# ---------------------------------------------------------
func initialise_simulation(grid_cell_size : float, swarm_params : Array) -> void:
	# Compute total boid count
	total_boids = 0
	for p in swarm_params:
		total_boids += p["count"]

	# Compute number of workgroups
	workgroup_count = ceil(total_boids / float(local_group_size))

	# ---------------------------------------------------------
	# Allocate CPU-side SoA arrays
	# ---------------------------------------------------------
	var pos_x : Array = []
	var pos_y : Array = []
	var pos_z : Array = []

	var vel_x : Array = []
	var vel_y : Array = []
	var vel_z : Array = []

	pos_x.resize(total_boids)
	pos_y.resize(total_boids)
	pos_z.resize(total_boids)

	vel_x.resize(total_boids)
	vel_y.resize(total_boids)
	vel_z.resize(total_boids)

	# Fill with placeholder initial values
	for i in range(total_boids):
		pos_x[i] = -5.0 + randf() * 10.0
		pos_y[i] = -5.0 + randf() * 10.0
		pos_z[i] = -5.0 + randf() * 10.0

		vel_x[i] = -0.5 + randf()
		vel_y[i] = -0.5 + randf()
		vel_z[i] = -0.5 + randf()

	# ---------------------------------------------------------
	# Compute grid dimensions from cage radius
	# ---------------------------------------------------------
	var grid_info : Dictionary = get_grid_dimensions(grid_cell_size, swarm_params)

	grid_dim_x = grid_info["dim_x"]
	grid_dim_y = grid_info["dim_y"]
	grid_dim_z = grid_info["dim_z"]
	grid_cell_count = grid_info["cell_count"]

	print("Grid dims: ", grid_dim_x, " x ", grid_dim_y, " x ", grid_dim_z)
	print("Grid cell count: ", grid_cell_count)
	
	# ---------------------------------------------------------
	# Set Renderer 3D density texture size and provide the rendering device
	# ---------------------------------------------------------
	renderer.set_density_texture_size(rd, Vector3i(grid_dim_x, grid_dim_y, grid_dim_z))

	# ---------------------------------------------------------
	# Upload CPU-side data to GPU_Buffers
	# ---------------------------------------------------------
	gpu_buffers.set_positions_soa(pos_x, pos_y, pos_z)
	gpu_buffers.set_velocities_soa(vel_x, vel_y, vel_z)
	gpu_buffers.set_swarm_params(swarm_params)
	gpu_buffers.set_global_params(total_boids, grid_cell_size, grid_dim_x, grid_dim_y, grid_dim_z)
	gpu_buffers.set_index_and_cell_ids()
	gpu_buffers.set_density_texture(renderer.density_texture_3d)

	# Allocate and upload all GPU buffers
	gpu_buffers.build_all_buffers(grid_cell_count)

	print("GPU_SimulationCore: initialised ", total_boids,
		  " boids with grid_cell_size ", grid_cell_size)


# ---------------------------------------------------------
# MAIN SIMULATION STEP
# Execute compute passes in order
# Each pass builds its own uniform set and dispatches its own pipeline
# ---------------------------------------------------------
func simulate(delta : float) -> void:
	"""
	Runs the full GPU simulation pipeline for one frame.

	No CPU read (should) occur here.
	
	The GPU writes directly into the storage buffers owned by GPU_Buffers.
	Other systems (Renderer, Debug tools) can read these buffers on demand.
	"""

	var workgroups_cells : int = ceil(grid_cell_count / float(local_group_size))

	# ---------------------------------------------------------
	# PHASE 1: Grid assign + grid clear
	# Separate compute list to guarantee visibility for later passes.
	# ---------------------------------------------------------
	var list_phase1 : int = rd.compute_list_begin()

	#pass_test.run(rd, list_phase1, workgroup_count)
	pass_grid_assign.run(rd, list_phase1, workgroup_count)
	pass_grid_clear.run(rd, list_phase1, workgroups_cells)

	rd.compute_list_end()

	# ---------------------------------------------------------
	# PHASE 2: Grid sort (histogram + prefix + scatter)
	# GridSort internally uses its own compute lists for the 3 sub-passes.
	# ---------------------------------------------------------
	pass_grid_sort.run(rd, workgroup_count, workgroups_cells)

	# ---------------------------------------------------------
	# PHASE 3: Grid mapping + behaviour
	# Mapping depends on cell_counts and cell_offsets produced by GridSort.
	# Behaviour depends on sorted indices and cell_mapping.
	# ---------------------------------------------------------
	var list_phase3 : int = rd.compute_list_begin()

	pass_grid_mapping.run(rd, list_phase3, workgroups_cells)  # per cell
	pass_behaviour.run(rd, list_phase3, workgroup_count)      # per boid
	#pass_density3D.run(rd, list_phase3, workgroups_cells)    # per cell
	#pass_integration.run(rd, list_phase3, workgroup_count)

	rd.compute_list_end()

	# ---------------------------------------------------------
	# DEBUG: Workgroup diagnostics
	# ---------------------------------------------------------
	if debug_print:
		print("\n--- GPU Dispatch Debug ---")

		print("Boid count:          ", total_boids)
		print("Grid cell count:     ", grid_cell_count)
		print("Local group size:    ", local_group_size)

		print("Workgroups (boids):  ", workgroup_count,
			  "   (", workgroup_count * local_group_size, " threads launched )")

		print("Workgroups (cells):  ", workgroups_cells,
			  "   (", workgroups_cells * local_group_size, " threads launched )")

		print("---------------------------\n")

	# Optional debug readback
	#pass_debug.run()
