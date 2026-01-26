extends Node3D

# ---------------------------------------------------------
# Swarm (GPU‑Only)
# ---------------------------------------------------------
# Responsibilities:
#   - Own per‑swarm components:
#       • BoidData (parameters only)
#       • GPUSimulationCore (inside BoidData)
#       • Renderer (GPU‑driven)
#       • Cage
#       • VisualDebug (optional, GPU‑aware)
#   - Initialize parameters and forward them to BoidData
#   - Forward per‑frame simulation to BoidData
#   - Forward per‑frame rendering to Renderer
#
# It does NOT:
#   - Store positions/velocities on CPU
#   - Read GPU buffers
#   - Perform simulation logic
#   - Manage global buffers
# ---------------------------------------------------------

@onready var data: Node = $BoidData
@onready var renderer: Node3D = $BoidRenderer
@onready var visual_debug: Node = $BoidVisualDebug
@onready var cage: Node3D = $BoidCage

var global_grid: Node3D = null


# ---------------------------------------------------------
# Initialize swarm with parameters
# ---------------------------------------------------------
func initialize(
	params: Dictionary,
	behaviours_root: Node,
	behaviours_mask: Dictionary,
	global_grid_in: Node3D
) -> void:

	global_grid = global_grid_in

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

	# -----------------------------------------------------
	# Setup BoidData (GPU‑only)
	# -----------------------------------------------------
	data.setup(
		boid_count,
		limits,
		weights,
		behaviours_root,
		cage_radius,
		FOV_angle_deg,
		behaviours_mask
	)

	# -----------------------------------------------------
	# Setup cage
	# -----------------------------------------------------
	cage.cage_radius = cage_radius
	cage.cage_center = global_transform.origin
	cage.cage_visible = true

	# -----------------------------------------------------
	# Setup renderer (GPU‑driven)
	# -----------------------------------------------------
	renderer.setup(
		params["boid_mesh"],
		params["boid_colour"],
		boid_count
	)

	# -----------------------------------------------------
	# Setup VisualDebug (GPU‑aware)
	# -----------------------------------------------------
	visual_debug.initialize(data, global_grid, params["boid_colour"])


# ---------------------------------------------------------
# Called by SwarmManager each frame
# ---------------------------------------------------------
func simulate(delta: float) -> void:
	data.simulate(delta)


# ---------------------------------------------------------
# Called by SwarmManager after simulation step
# ---------------------------------------------------------
func update_renderer() -> void:
	# GPU‑driven renderer does NOT take CPU arrays anymore.
	# It pulls transforms from GPU buffers internally.
	renderer.update_from_gpu()
