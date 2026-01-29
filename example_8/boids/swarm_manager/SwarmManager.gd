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

var gpu_core : Node
var config_handler : Node
var swarms : Array = []


# Raw config filenames (strings)
var swarm_constants_files  : Array = ["orbital_boids.json", "loose_migration.json"]
var behaviour_weights_files: Array = ["orbital_boids.json", "loose_migration.json"]
var behaviour_masks_files  : Array = ["default.json", "default.json"]
var interaction_masks_files: Array = ["default.json", "default.json"]
var swarm_mesh_files       : Array = ["cylinderboid.obj", "cylinderboid.obj"]

# Set grid size
var grid_cell_size : float = 5.0

func _ready():
	gpu_core = get_node("../GPU_SimulationCore")
	config_handler = get_node("../ConfigHandler")

	_discover_swarms()
	_initialise_swarms()


# ---------------------------------------------------------
# DISCOVER SWARM CHILDREN
# ---------------------------------------------------------

func _discover_swarms():
	for child in get_children():
		if child.name.begins_with("Swarm"):
			swarms.append(child)
			print("SwarmManager: detected swarm:", child.name)


# ---------------------------------------------------------
# INITIALISE SWARMS
# ---------------------------------------------------------

func _initialise_swarms():
	var swarm_params_gpu : Array = []
	var offset := 0

	for i in range(len(swarms)):
		var swarm = swarms[i]

		# --- Load raw JSON dictionaries ---
		var constants  = config_handler.extract_swarm_constants(swarm_constants_files[i])
		var weights    = config_handler.extract_behaviour_weights(behaviour_weights_files[i])
		var masks      = config_handler.extract_behaviour_masks(behaviour_masks_files[i])
		var interact   = config_handler.extract_interaction_masks(interaction_masks_files[i])

		# --- Extract CPU‑side metadata ---
		var count      = constants.get("boid_count", 100)
		var mesh_path  = constants.get("boid_mesh_path", "biggerboid.obj")
		var colour_arr = constants.get("boid_colour", [1,1,1,1])

		# Load mesh
		var mesh = config_handler.extract_mesh(swarm_mesh_files[i])
		swarm.mesh = mesh

		# Assign colour (renderer will use this)
		swarm.colour = Color(colour_arr[0], colour_arr[1], colour_arr[2], colour_arr[3])

		# Assign index range for GPU-driven rendering
		swarm.start_index = offset
		swarm.count = count

		# --- Build GPU parameter block ---
		swarm_params_gpu.append({
			"start": offset,
			"count": count,
			"constants": constants,
			"weights": weights,
			"masks": masks,
			"interactions": interact
		})

		offset += count

	# --- Hand off to GPU simulation core ---
	# --- but wait a frame until children have finished initialising
	await get_tree().process_frame 
	gpu_core.initialise_simulation(grid_cell_size, swarm_params_gpu)


# ---------------------------------------------------------
# MAIN UPDATE LOOP
# ---------------------------------------------------------

func _process(delta):
	# Only run the GPU simulation.
	# Renderer updates itself via GPU-driven shader.
	gpu_core.simulate(delta)
