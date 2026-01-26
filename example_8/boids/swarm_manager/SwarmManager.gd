extends Node

var gpu_core : Node
var config_handler : Node
var swarms = []

var positions_cpu = []
var velocities_cpu = []

func _ready():
	gpu_core = get_node("../GPU_SimulationCore")
	config_handler = get_node("../ConfigHandler")

	_create_swarms()

func _create_swarms():
	for child in get_children():
		if child.name.begins_with("Swarm"):
			swarms.append(child)

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
		swarm.positions = positions_cpu.slice(swarm.start_index, swarm.count)
		swarm.velocities = velocities_cpu.slice(swarm.start_index, swarm.count)

func _update_swarms():
	for swarm in swarms:
		swarm.update()
