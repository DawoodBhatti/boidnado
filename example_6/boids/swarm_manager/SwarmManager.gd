extends Node3D

# ---------------------------------------------------------
# SwarmManager
# ---------------------------------------------------------
# Responsibilities:
#   - Create and initialize all swarm instances
#   - Build global position/velocity buffers every frame
#   - Assign each swarm its global index slice
#   - Rebuild the global spatial grid
#   - Call each swarm's CPU/GPU simulation core
#   - Update each swarm's renderer
# ---------------------------------------------------------

# Debug toggle
@export var debug: bool = false

# Swarm list
var swarms: Array[Node3D] = []

# Simulation control
var paused: bool = false
var advance_held: bool = false   # ← NEW: hold-to-step

# Total boid count across all swarms
var boid_count: int = 0

# Config
@export var swarm1_config: String = "orbital_boids.json"
var swarm1_params: Dictionary = {}
var swarm1_use_config: bool = true

@export var swarm2_config: String = "loose_migration.json"
var swarm2_params: Dictionary = {}
var swarm2_use_config: bool = true

# References
@onready var config_handler: Node = $"../ConfigHandler"
@onready var global_grid: Node = $"../GlobalGrid"
@onready var behaviours_root: Node = $"../Behaviours"
@onready var behaviours_presets: Node = behaviours_root.get_node("BehaviourPresets")

# Global buffers (rebuilt every frame)
var global_positions: PackedVector3Array = PackedVector3Array()
var global_velocities: PackedVector3Array = PackedVector3Array()


# ---------------------------------------------------------
# Ready: load configs + initialize swarms
# ---------------------------------------------------------
func _ready() -> void:
	swarm1_params = _extract_config_params(swarm1_config)
	swarm2_params = _extract_config_params(swarm2_config)
	#swarm2_params = _manually_set_params()

	boid_count = swarm1_params["boid_count"] + swarm2_params["boid_count"]

	if debug:
		print("Swarm1 parameters: ", swarm1_params)
		print("Swarm2 parameters: ", swarm2_params)
		print("Total boid count: ", boid_count)

	_initialize_all_swarms()


# ---------------------------------------------------------
# Initialize all swarm nodes
# ---------------------------------------------------------
func _initialize_all_swarms() -> void:
	var swarm1: Node3D = get_node("Swarm1")
	var behaviours_mask_swarm1 : Dictionary = behaviours_presets.MASKS["default"]
	swarm1.initialize(swarm1_params, behaviours_root, behaviours_mask_swarm1, global_grid)
	swarms.append(swarm1)

	if debug:
		print("Initialized Swarm1 with ", swarm1_params["boid_count"], " boids")
		print("Using behaviour mask: ", behaviours_mask_swarm1)

	var swarm2: Node3D = get_node("Swarm2")
	var behaviours_mask_swarm2 : Dictionary = behaviours_presets.MASKS["default"]
	swarm2.initialize(swarm2_params, behaviours_root, behaviours_mask_swarm2, global_grid)
	swarms.append(swarm2)

	if debug:
		print("Initialized Swarm2 with ", swarm2_params["boid_count"], " boids")
		print("Using behaviour mask: ", behaviours_mask_swarm2)


# ---------------------------------------------------------
# Extract config params
# ---------------------------------------------------------
func _extract_config_params(file_name: String) -> Dictionary:
	return config_handler.extract_params(file_name)


# ---------------------------------------------------------
# Manual params for swarm2
# ---------------------------------------------------------
func _manually_set_params() -> Dictionary:
	var mesh: Resource = load("res://example_6/boids/models/biggerboid.obj")

	return {
		"swarm_name": "Swarm 2",
		"simulation_core": "CPU",
		"boid_count": 50,
		"cell_size": 3.0,
		"sight_radius": 4.0,
		"FOV_angle_deg": 360,
		"cage_radius": 30.0,
		"max_speed": 48.0,
		"desired_separation": 0.4,

		"alignment_weight": 0.8,
		"cohesion_weight": 3.0,
		"separation_weight": 5.0,
		"wander_strength": 1.0,
		"boundary_strength": 1.0,

		"boid_mesh": mesh,
		"boid_colour": Color(0.0, 0.0, 1.0, 0.5)
	}


# ---------------------------------------------------------
# Simulation Loop
# ---------------------------------------------------------
func _physics_process(delta: float) -> void:
	if paused:
		if advance_held:
			_run_simulation_step(delta)
		return

	_run_simulation_step(delta)


# ---------------------------------------------------------
# Run one simulation step
# ---------------------------------------------------------
func _run_simulation_step(delta: float) -> void:
	# 1. Build global buffers
	_rebuild_global_buffers()

	# 2. Give grid the global positions
	global_grid.set_global_positions_ref(global_positions)

	# 3. Rebuild spatial grid
	global_grid.rebuild(global_positions)

	# 4. Update each swarm using its simulation core
	for swarm: Node3D in swarms:
		var data: Node = swarm.data
		data.core.update(
			delta,
			data,
			global_grid,
			global_positions,
			global_velocities
		)

	# 5. Update renderers
	for swarm: Node3D in swarms:
		swarm.update_renderer()


# ---------------------------------------------------------
# Build global buffers + assign global slices
# ---------------------------------------------------------
func _rebuild_global_buffers() -> void:
	global_positions = PackedVector3Array()
	global_velocities = PackedVector3Array()

	var cursor: int = 0

	for swarm: Node3D in swarms:
		var data: Node = swarm.data
		var count: int = data.boid_count

		data.assign_global_slice(cursor)

		for i: int in count:
			global_positions.append(data.positions[i])
			global_velocities.append(data.velocities[i])

		cursor += count


# ---------------------------------------------------------
# Input handling
# ---------------------------------------------------------
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		paused = true
		if debug:
			print("Input: pause")

	elif event.is_action_pressed("resume"):
		paused = false
		if debug:
			print("Input: resume")

	elif event.is_action_pressed("advance_simulation"):
		advance_held = true
		if debug:
			print("Input: advance_simulation (held)")

	elif event.is_action_released("advance_simulation"):
		advance_held = false
		if debug:
			print("Input: advance_simulation released")
