extends Node

var gpu_core : Node
var config_handler : Node
var swarms = []

var positions_cpu = []
var velocities_cpu = []

# Arrays initially contain filenames.
# After extraction, they will contain dictionaries.
var swarm_constants:  Array = ["orbital_boids.json", "loose_migration.json"]
var behaviour_weights: Array = ["orbital_boids.json", "loose_migration.json"]
var behaviour_masks:   Array = ["default.json", "default.json"]
var interaction_masks: Array = ["default.json", "default.json"]
var swarm_mesh: Array = ["cylinderboid.obj", "cylinderboid.obj"]


func _ready():
	gpu_core = get_node("../GPU_SimulationCore")
	config_handler = get_node("../ConfigHandler")

	_create_swarms()
	_extract_all_configs()


# ---------------------------------------------------------
# LOAD ALL CONFIGS FOR EACH SWARM
# ---------------------------------------------------------

func _extract_all_configs():
	for i in range(len(swarms)):
		var swarm = swarms[i]
		print("Extracting configs for:", swarm.name)

		# Load JSON dictionaries
		swarm_constants[i]  = config_handler.extract_swarm_constants(swarm_constants[i])
		behaviour_weights[i] = config_handler.extract_behaviour_weights(behaviour_weights[i])
		behaviour_masks[i]   = config_handler.extract_behaviour_masks(behaviour_masks[i])
		interaction_masks[i] = config_handler.extract_interaction_masks(interaction_masks[i])

		# Load mesh separately
		swarm_mesh[i] = config_handler.extract_mesh(swarm_mesh[i])

		# Assign mesh to swarm (optional)
		if swarm_mesh[i] != null:
			swarm.mesh = swarm_mesh[i]


# ---------------------------------------------------------
# DISCOVER SWARM CHILDREN
# ---------------------------------------------------------

func _create_swarms():
	for child in get_children():
		if child.name.begins_with("Swarm"):
			print("SwarmManager: detected:", child.name)
			swarms.append(child)


# ---------------------------------------------------------
# MAIN UPDATE LOOP
# ---------------------------------------------------------

func _process(delta):
	_run_gpu_simulation(delta)
	_read_gpu_data()
	_distribute_slices()
	_update_swarms()


func _run_gpu_simulation(delta):
	gpu_core.simulate(delta)


func _read_gpu_data():
	positions_cpu = gpu_core.buffers.read_positions()
	velocities_cpu = gpu_core.buffers.read_velocities()


func _distribute_slices():
	for swarm in swarms:
		swarm.positions  = positions_cpu.slice(swarm.start_index, swarm.count)
		swarm.velocities = velocities_cpu.slice(swarm.start_index, swarm.count)


func _update_swarms():
	for swarm in swarms:
		swarm.update()
