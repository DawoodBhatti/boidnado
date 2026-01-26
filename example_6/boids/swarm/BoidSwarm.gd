extends Node3D

# ---------------------------------------------------------
# Swarm
# ---------------------------------------------------------
# Responsibilities:
#   - Owns the following per swarm instances:
#   -  boid data 
#   -  boid renderer
#   -  boid cage 
#   -  boid VisualDebug 
#   - Initialize simulation parameters within data cores
#   - Forward updates to renderer, cage and debugger (optional)
#
# It does NOT:
#   - Perform simulation logic (CPU/GPU cores do that)
#   - Manage global buffers (SwarmManager does that)
# ---------------------------------------------------------

@onready var data: Node = $BoidData
@onready var renderer: Node3D = $BoidRenderer
@onready var visual_debug: Node = $BoidVisualDebug   
@onready var cage: Node3D = $BoidCage
var global_grid: Node3D

# ---------------------------------------------------------
# Initialize swarm with parameters
# ---------------------------------------------------------
func initialize(params: Dictionary, behaviours_root: Node, behaviours_mask: Dictionary, global_grid: Node3D) -> void:
	var simulation_core: String = params["simulation_core"]
	var boid_count: int = params["boid_count"]
	var limits: Dictionary = {
		"max_speed": params["max_speed"],
		"sight_radius": params["sight_radius"],
		"desired_separation": params["desired_separation"]
	}
	var weights: Dictionary = {
		"alignment": params["alignment_weight"],
		"cohesion": params["cohesion_weight"],
		"separation": params["separation_weight"],
		"wander": params["wander_strength"],
		"boundary": params["boundary_strength"]
	}

	var cage_radius: float = params["cage_radius"]
	var FOV_angle_deg: float = params["FOV_angle_deg"]
	var max_speed: float = params["max_speed"]


	# Setup BoidData
	data.setup(
		simulation_core,
		boid_count,
		limits,
		weights,
		behaviours_root,
		cage_radius,
		FOV_angle_deg,
		max_speed,
		behaviours_mask
	)

	# Setup cage
	cage.cage_radius = cage_radius
	cage.cage_center = global_transform.origin
	cage.cage_visible = true

	# Setup renderer
	renderer.setup(
		params["boid_mesh"],
		params["boid_colour"],
		boid_count
	)

	# Setup VisualDebug (per-swarm)
	visual_debug.initialize(data, global_grid, params["boid_colour"])


# ---------------------------------------------------------
# Called by SwarmManager after simulation step
# ---------------------------------------------------------
func update_renderer() -> void:
	renderer.update_transforms(
		data.positions,
		data.velocities
	)
