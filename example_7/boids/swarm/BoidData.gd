extends Node

# ---------------------------------------------------------
# BoidData (GPU‑Only)
# ---------------------------------------------------------
# Responsibilities:
#   - Hold all configuration/state for a single swarm
#   - Hold parameters (limits, weights, behaviours, FOV, cage)
#   - Hold boid_count and global_start/global_end (index slice)
#   - Own and configure the GPUSimulationCore
#
# It does NOT:
#   - Store positions/velocities on the CPU
#   - Perform simulation logic
#   - Know about GPU buffers or pipelines
# ---------------------------------------------------------

@onready var gpu_core: Node = $SwarmSimulationCore

var boid_count: int = 0

var limits: Dictionary = {}
var weights: Dictionary = {}
var behaviours_root: Node = null
var behaviours_gpu: Node = null
var behaviours_mask: Dictionary = {}

var cage_radius: float = 0.0

var FOV_angle_rad: float = 0.0
var FOV_DOT_THRESHOLD: float = 0.0

var global_start: int = 0
var global_end: int = 0   # global_start + boid_count


# ---------------------------------------------------------
# Setup (called by Swarm.initialize)
# ---------------------------------------------------------
func setup(
	boid_count_in: int,
	limits_in: Dictionary,
	weights_in: Dictionary,
	behaviours_root_in: Node,
	cage_radius_in: float,
	FOV_angle_deg_in: float,
	behaviours_mask_in: Dictionary
) -> void:
	boid_count = boid_count_in
	limits = limits_in
	weights = weights_in
	behaviours_root = behaviours_root_in
	cage_radius = cage_radius_in
	FOV_angle_rad = deg_to_rad(FOV_angle_deg_in)
	FOV_DOT_THRESHOLD = cos(FOV_angle_rad)
	behaviours_mask = behaviours_mask_in

	_select_behaviours_gpu()

	# Configure the GPU simulation core with all required parameters.
	gpu_core.setup(
		boid_count,
		limits,
		weights,
		cage_radius,
		FOV_angle_rad,
		FOV_DOT_THRESHOLD,
		behaviours_mask
	)


func _select_behaviours_gpu() -> void:
	if behaviours_root == null:
		return

	if behaviours_root.has_node("GPUBehaviours"):
		behaviours_gpu = behaviours_root.get_node("GPUBehaviours")
	else:
		behaviours_gpu = null


# ---------------------------------------------------------
# Local → Global index mapping called by SwarmManager
# ---------------------------------------------------------
func assign_global_slice(start_index: int) -> void:
	global_start = start_index
	global_end = start_index + boid_count


# ---------------------------------------------------------
# Per‑frame simulation entry point (called by Swarm)
# ---------------------------------------------------------
func simulate(delta: float) -> void:
	gpu_core.step_simulation(delta)
