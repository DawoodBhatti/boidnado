extends Node
"""
GPU_SimulationCore.gd
---------------------

This node is the *central access point* for all GPU simulation data.

ARCHITECTURE:
 - GPU_SimulationCore owns GPU buffers.
 - All other systems (SwarmManager, Renderer, Debug tools) access buffers
   *through this node* instead of receiving references.
 - No CPU system updates transforms or slices arrays instead we use the GPU_Debug node,
 - also accessed through this node.
 - Renderer can read GPU buffers directly for GPU-driven rendering.

This keeps the simulation pipeline clean, scalable, and GPU-native.
"""

# ---------------------------------------------------------
# CHILD NODES (GPU subsystems)
# ---------------------------------------------------------

var device : Node            # GPU device wrapper (RenderingDevice)
var buffers : Node           # GPU_Buffers: owns all storage buffers
var pass_grid_assign : Node
var pass_grid_sort : Node
var pass_grid_mapping : Node
var pass_behaviour : Node
var pass_integration : Node
var pass_debug : Node
var rd : RenderingDevice 


func _ready():
	# GPU device, buffer owner and debug node
	device             = get_node("GPU_Device")
	buffers            = get_node("GPU_Buffers")
	pass_debug         = get_node("GPU_Debug")

	rd = device.rd

	# All compute passes live under GPU_Passes
	var passes = get_node("GPU_Passes")

	pass_grid_assign   = passes.get_node("Pass_GridAssign")
	pass_grid_sort     = passes.get_node("Pass_GridSort")
	pass_grid_mapping  = passes.get_node("Pass_GridMapping")
	pass_behaviour     = passes.get_node("Pass_Behaviour")
	pass_integration   = passes.get_node("Pass_Integration")

	# NOTE:
	# Other systems should *not* hold references to buffers directly.
	# They should always access them via:
	#    get_node("RootMaster/Boids/GPU_SimulationCore").buffers
	#
	# This ensures a single source of truth for GPU data.


# ---------------------------------------------------------
# INITIALISATION ENTRY POINT
# ---------------------------------------------------------

func initialise_simulation(gpu_params: Array):
	"""
    Called once by SwarmManager after all configs are loaded.
    gpu_params is an array of dictionaries, each containing:
      - start: global start index
      - count: number of boids in this swarm
      - constants: swarm_constants JSON
      - weights: behaviour_weights JSON
      - masks: behaviour_masks JSON
      - interactions: interaction_masks JSON

    This function:
      - Computes total boid count
      - Generates initial positions + velocities
      - Uploads them to GPU_Buffers
      - Uploads per-swarm constants (placeholder)
    """

	# Compute total boid count
	var total: int = 0
	for p in gpu_params:
		total += p["count"]

	# Allocate CPU-side arrays
	var positions := []
	var velocities := []
	positions.resize(total)
	velocities.resize(total)

	# Fill with simple initial values (placeholder)
	for i in range(total):
		positions[i] = Vector3(
			randf() * 10.0,
			randf() * 10.0,
			randf() * 10.0
		)
		velocities[i] = Vector3(
			randf() * 2.0 - 1.0,
			randf() * 2.0 - 1.0,
			randf() * 2.0 - 1.0
		)

	# Upload initial data to GPU buffers
	#buffers.upload_positions(positions)
	#buffers.upload_velocities(velocities)

	# Upload per-swarm constants (placeholder)
	#buffers.upload_swarm_params(gpu_params)

	print("GPU_SimulationCore: initialised", total, "boids")

# ---------------------------------------------------------
# MAIN SIMULATION STEP
# ---------------------------------------------------------

func simulate(delta):
	"""
    Runs the full GPU simulation pipeline for one frame.

    No CPU reads occur here.
    No transforms are updated here.
    No slicing or per-swarm logic occurs here.

    The GPU writes directly into the storage buffers owned by GPU_Buffers.
    Other systems (Renderer, Debug tools) can read these buffers on demand.
    """

	# TODO: finish building these systems before we can run final code
	pass_debug.run()
	#pass_grid_assign.run()
	#pass_grid_sort.run()
	#pass_grid_mapping.run()
	#pass_behaviour.run(delta)
	#pass_integration.run(delta)

	# After this point:
	# - positions buffer contains updated boid positions
	# - velocities buffer contains updated boid velocities
	# - grid buffers contain updated spatial partitioning
	#
	# Renderer can now read these buffers directly in a shader.
	# Debug tools can read them via buffers.read_positions(), etc.
