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
# Simulation parameters
# ---------------------------------------------------------
var total_boids : int = 0
var workgroup_count : int = 0
var local_group_size : int = 64


# ---------------------------------------------------------
# Child nodes (GPU subsystems)
# ---------------------------------------------------------
var device : Node              # GPU_Device (RenderingDevice + pipelines)
var buffers : Node             # GPU_Buffers (storage buffers + RDUniform descriptors)
var pass_grid_assign : Node
var pass_grid_sort : Node
var pass_grid_mapping : Node
var pass_behaviour : Node
var pass_integration : Node
var pass_test : Node
var pass_debug : Node

var rd : RenderingDevice       # Cached RenderingDevice reference


func _ready() -> void:
	# ---------------------------------------------------------
	# Cache subsystem references
	# ---------------------------------------------------------
	device  = get_node("GPU_Device")
	buffers = get_node("GPU_Buffers")
	pass_debug = get_node("GPU_Debug")

	rd = device.rd

	# All compute passes live under GPU_Passes
	var passes = get_node("GPU_Passes")

	pass_test         = passes.get_node("Pass_TestPass")
	pass_grid_assign  = passes.get_node("Pass_GridAssign")
	pass_grid_sort    = passes.get_node("Pass_GridSort")
	pass_grid_mapping = passes.get_node("Pass_GridMapping")
	pass_behaviour    = passes.get_node("Pass_Behaviour")
	pass_integration  = passes.get_node("Pass_Integration")

	# NOTE:
	# Other systems (Renderer, Debug tools) should access GPU buffers
	# ONLY through:
	#     get_node("RootMaster/Boids/GPU_SimulationCore").buffers
	#
	# This ensures a single source of truth for GPU data.


# ---------------------------------------------------------
# INITIALISATION ENTRY POINT
# ---------------------------------------------------------
func initialise_simulation(grid_cell_size : float, swarm_params : Array) -> void:
	"""
	Called once by SwarmManager after all configs are loaded.

	This function:
	  - Computes total boid count
	  - Generates initial positions + velocities (CPU-side)
	  - Uploads them to GPU_Buffers
	  - Uploads per-swarm constants
	  - Allocates grid + index buffers
	  - Builds all GPU-side storage buffers
	"""

	# Compute total boid count
	total_boids = 0
	for p in swarm_params:
		total_boids += p["count"]

	# Compute number of workgroups for compute dispatch
	workgroup_count = ceil(total_boids / float(local_group_size))

	# ---------------------------------------------------------
	# Allocate CPU-side SoA arrays
	# ---------------------------------------------------------
	var pos_x := []
	var pos_y := []
	var pos_z := []

	var vel_x := []
	var vel_y := []
	var vel_z := []

	pos_x.resize(total_boids)
	pos_y.resize(total_boids)
	pos_z.resize(total_boids)

	vel_x.resize(total_boids)
	vel_y.resize(total_boids)
	vel_z.resize(total_boids)

	# Fill with placeholder initial values
	for i in range(total_boids):
		pos_x[i] = randf() * 10.0
		pos_y[i] = randf() * 10.0
		pos_z[i] = randf() * 10.0

		vel_x[i] = randf() * 2.0 - 1.0
		vel_y[i] = randf() * 2.0 - 1.0
		vel_z[i] = randf() * 2.0 - 1.0

	# ---------------------------------------------------------
	# Upload CPU-side data to GPU_Buffers
	# ---------------------------------------------------------
	buffers.set_positions_soa(pos_x, pos_y, pos_z)
	buffers.set_velocities_soa(vel_x, vel_y, vel_z)

	buffers.set_params(grid_cell_size, swarm_params)
	buffers.set_index_and_cell_ids()

	# Allocate and upload all GPU buffers
	buffers.build_all_buffers()

	print("GPU_SimulationCore: initialised ", total_boids,
		  " boids with grid_cell_size ", grid_cell_size)


# ---------------------------------------------------------
# MAIN SIMULATION STEP
# ---------------------------------------------------------
func simulate(delta : float) -> void:
	"""
	Runs the full GPU simulation pipeline for one frame.

	No CPU reads occur here.
	The GPU writes directly into the storage buffers owned by GPU_Buffers.
	Other systems (Renderer, Debug tools) can read these buffers on demand.
	"""

	print("GPU_SimulationCore: simulate() with workgroups = ", workgroup_count)

	var compute_list = rd.compute_list_begin()

	# ---------------------------------------------------------
	# Execute compute passes in order
	# Each pass builds its own uniform set and dispatches its own pipeline
	# ---------------------------------------------------------
	#pass_test.run(rd, compute_list, workgroup_count)
	pass_grid_assign.run(rd, compute_list, workgroup_count)
	#pass_grid_sort.run(rd, compute_list, workgroup_count)
	#pass_grid_mapping.run(rd, compute_list, workgroup_count)
	#pass_behaviour.run(rd, compute_list, workgroup_count)
	#pass_integration.run(rd, compute_list, workgroup_count)

	# ---------------------------------------------------------
	# Submit GPU work
	# ---------------------------------------------------------
	rd.compute_list_end()
	rd.submit()

	# Sync if CPU needs readback (debug, renderer) 
	# Keep this in temporarily while we are building the pipeline but eventually:
	# 	Future Improvement 1 — Fence-based scheduling (Vulkan-style)
	#	Future Improvement 2 — Double-buffered GPU job
	#	Future Improvement 4 — GPU job queue
	
	
	rd.sync()

	# Optional debug readback
	#pass_debug.run()
