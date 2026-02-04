extends Node

"""
SwarmManager.gd
----------------
Responsibilities:
 - Discover Swarm nodes
 - Load config files (via ConfigHandler)
 - Extract ONLY CPU‑side metadata:
      • boid_count
      • mesh
      • colour
 - Build GPU parameter blocks for each swarm
 - Pass GPU parameters to GPU_SimulationCore
 - Do NOT store simulation data
 - Do NOT update transforms
 - Do NOT read GPU buffers
"""

var gpu_core: Node
var config_handler: Node
var swarms: Array = []

# Simulation control state
var is_paused: bool = false
var is_stepping: bool = false   # true while "advance_simulation" button is held
var run_count: int = 0

# Raw config filenames
var swarm_constants_files: Array = ["orbital_boids.json", "loose_migration.json"]
var behaviour_weights_files: Array = ["orbital_boids.json", "loose_migration.json"]
var behaviour_masks_files: Array = ["default.json", "default.json"]
var interaction_masks_files: Array = ["default.json", "default.json"]
var swarm_mesh_files: Array = ["cylinderboid.obj", "cylinderboid.obj"]

# Grid size
var grid_cell_size: float = 6.0


func _ready() -> void:
	gpu_core = get_node("../GPU_SimulationCore")
	config_handler = get_node("../ConfigHandler")

	_discover_swarms()
	_initialise_swarms()


# ---------------------------------------------------------
# PUBLIC CONTROL API
# ---------------------------------------------------------

func pause_simulation() -> void:
	is_paused = true
	is_stepping = false
	print("Simulation paused")


func resume_simulation() -> void:
	is_paused = false
	is_stepping = false
	print("Simulation resumed")


func advance_simulation_start() -> void:
	# Called when button is pressed
	is_paused = false
	is_stepping = true
	print("Advance simulation: stepping enabled")


func advance_simulation_stop() -> void:
	# Called when button is released
	is_stepping = false
	is_paused = true
	print("Advance simulation: stepping stopped")


# ---------------------------------------------------------
# DISCOVER SWARM CHILDREN
# ---------------------------------------------------------

func _discover_swarms() -> void:
	for child: Node in get_children():
		if child.name.begins_with("Swarm"):
			swarms.append(child)
			print("SwarmManager: detected swarm:", child.name)


# ---------------------------------------------------------
# INITIALISE SWARMS
# ---------------------------------------------------------

func _initialise_swarms() -> void:
	var swarm_params_gpu: Array = []
	var offset: int = 0

	for i: int in range(swarms.size()):
		var swarm: Node = swarms[i]

		var constants: Dictionary = config_handler.extract_swarm_constants(swarm_constants_files[i])
		var weights: Dictionary = config_handler.extract_behaviour_weights(behaviour_weights_files[i])
		var masks: Dictionary = config_handler.extract_behaviour_masks(behaviour_masks_files[i])
		var interact: Dictionary = config_handler.extract_interaction_masks(interaction_masks_files[i])

		var count: int = constants.get("boid_count", 100)
		var colour_arr: Array = constants.get("boid_colour", [1,1,1,1])

		var mesh: Mesh = config_handler.extract_mesh(swarm_mesh_files[i])
		swarm.mesh = mesh
		swarm.colour = Color(colour_arr[0], colour_arr[1], colour_arr[2], colour_arr[3])

		swarm.start_index = offset
		swarm.count = count

		swarm_params_gpu.append({
			"start": offset,
			"count": count,
			"constants": constants,
			"weights": weights,
			"masks": masks,
			"interactions": interact
		})

		offset += count

	await get_tree().process_frame
	gpu_core.initialise_simulation(grid_cell_size, swarm_params_gpu)


# ---------------------------------------------------------
# MAIN UPDATE LOOP
# ---------------------------------------------------------

func _process(delta: float) -> void:
	# If paused and not stepping, do nothing
	if is_paused and not is_stepping:
		return

	# If stepping, run exactly one frame per _process tick
	if is_stepping:
		gpu_core.simulate(delta)
		return

	# Normal continuous simulation
	gpu_core.simulate(delta)


func _input(event: InputEvent) -> void:
	# --- Pause ---
	if event.is_action_pressed("pause"):
		pause_simulation()
		return

	# --- Resume ---
	if event.is_action_pressed("resume"):
		resume_simulation()
		return

	# --- Advance Simulation (hold to step) ---
	if event.is_action_pressed("advance_simulation"):
		advance_simulation_start()
		return

	if event.is_action_released("advance_simulation"):
		advance_simulation_stop()
		return
