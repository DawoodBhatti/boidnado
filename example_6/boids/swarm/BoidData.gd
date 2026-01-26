extends Node

# ---------------------------------------------------------
# BoidData
# ---------------------------------------------------------
# Responsibilities:
#   - Hold all simulation state for a single swarm
#   - Hold parameters (limits, weights, behaviours)
#   - Hold global_start/global_end assigned by SwarmManager
#   - Store neighbour lists (populated by CPU/GPU core)
#   - Store local/global index mapping
#   - Select CPU/GPU simulation core
#
# It does NOT:
#   - Know about the global grid
#   - Know about global buffers
#   - Perform simulation logic
#   - Call its own core
# ---------------------------------------------------------

var start_simulation: bool = false
var simulation_core: String = ""
var core: Node = null
var behaviours_CPU: Node = null
var behaviours_GPU: Node = null
var behaviours_root: Node = null
var behaviours_mask: Dictionary 

@onready var cpu_core: Node = $CPUSimulationCore
@onready var gpu_core: Node = $GPUSimulationCore

# Simulation state arrays
var positions: PackedVector3Array = PackedVector3Array()
var velocities: PackedVector3Array = PackedVector3Array()
var accelerations: PackedVector3Array = PackedVector3Array()

# Per‑boid neighbour lists (local indices)
var neighbours: Array = []   # Array[PackedInt32Array]

# Local → Global index mapping
var local_to_global: PackedInt32Array = PackedInt32Array()


# Parameters
var boid_count: int = 0
var limits: Dictionary = {}
var weights: Dictionary = {}
var cage_radius: float = 0.0

# Assigned by SwarmManager each frame
var global_start: int = 0
var global_end: int = 0   # global_start + boid_count

# FOV
var FOV_angle: float 
var FOV_DOT_THRESHOLD: float


# ---------------------------------------------------------
# Setup (called by Swarm.initialize)
# ---------------------------------------------------------
func setup(
	simulation_core_in: String,
	boid_count_in: int,
	limits_in: Dictionary,
	weights_in: Dictionary,
	behaviours_root_in: Node,
	cage_radius_in: float,
	FOV_angle_deg_in: float, 
	max_speed: float,
	behaviours_mask_in: Dictionary
) -> void:

	simulation_core = simulation_core_in
	boid_count = boid_count_in
	limits = limits_in
	weights = weights_in
	behaviours_root = behaviours_root_in
	cage_radius = cage_radius_in
	FOV_angle = deg_to_rad(FOV_angle_deg_in)
	FOV_DOT_THRESHOLD = cos(FOV_angle)
	behaviours_mask = behaviours_mask_in

	_select_core()
	_select_behaviours()

	# Allocate arrays
	positions.resize(boid_count)
	velocities.resize(boid_count)
	accelerations.resize(boid_count)

	# Neighbour storage
	neighbours.clear()
	neighbours.resize(boid_count)
	for i in boid_count:
		neighbours[i] = PackedInt32Array()

	# Local → Global mapping (filled by SwarmManager)
	local_to_global.resize(boid_count)

	_randomize_initial_state(max_speed)

	# GPU setup if needed
	if simulation_core == "GPU":
		await gpu_core.setup(self)

	start_simulation = true


# ---------------------------------------------------------
# Select CPU or GPU core
# ---------------------------------------------------------
func _select_core() -> void:
	if simulation_core == "CPU":
		core = cpu_core
	else:
		core = gpu_core

func _select_behaviours() -> void:
	if simulation_core == "CPU":
		behaviours_CPU = behaviours_root.get_node("CPUBehaviours")
	elif simulation_core == "GPU":
		behaviours_GPU = behaviours_root.get_node("GPUBehaviours")


# ---------------------------------------------------------
# Randomize initial boid positions + velocities
# ---------------------------------------------------------
func _randomize_initial_state(max_speed: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()

	for i in boid_count:
		positions[i] = Vector3(
			rng.randf_range(-20.0, 20.0),
			rng.randf_range(0.0, 10.0),
			rng.randf_range(-20.0, 20.0)
		)

		var v := Vector3(
			rng.randf_range(-10.0, 10.0),
			rng.randf_range(-10.0, 10.0),
			rng.randf_range(-10.0, 10.0)
		).normalized()

		velocities[i] = v * max_speed * 0.5
		accelerations[i] = Vector3.ZERO


# ---------------------------------------------------------
# # Local → Global index mapping called by SwarmManager each frame
# Assigns the global index slice for this swarm
# ---------------------------------------------------------
func assign_global_slice(start_index: int) -> void:
	global_start = start_index
	global_end = start_index + boid_count
