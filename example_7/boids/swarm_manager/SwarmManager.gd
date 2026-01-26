extends Node3D

@export var debug: bool = false

var swarms: Array[Node3D] = []

var paused: bool = false
var advance_step: bool = false

@export var swarm1_config: String = "orbital_boids.json"
var swarm1_params: Dictionary = {}

@export var swarm2_config: String = "loose_migration.json"
var swarm2_params: Dictionary = {}

@onready var config_handler: Node = $"../ConfigHandler"
@onready var behaviours_root: Node = $"../Behaviours"
@onready var behaviours_presets: Node = behaviours_root.get_node("BehaviourPresets")
@onready var global_core: Node = $"../GlobalSimulationCore"


var boid_count: int:
	get:
		return _compute_total_boids()


func _compute_total_boids() -> int:
	var total: int = 0
	for swarm in swarms:
		if swarm.has_node("BoidData"):
			var data: Node = swarm.get_node("BoidData")
			total += data.boid_count
	return total


func _ready() -> void:
	swarm1_params = _extract_config_params(swarm1_config)
	swarm2_params = _extract_config_params(swarm2_config)

	if debug:
		print("Swarm1 parameters: ", swarm1_params)
		print("Swarm2 parameters: ", swarm2_params)

	_initialize_all_swarms()

	# Defer so GlobalSimulationCore @onready vars are valid
	call_deferred("_setup_global_core")


func _initialize_all_swarms() -> void:
	var swarm1: Node3D = get_node("Swarm1")
	var mask1: Dictionary = behaviours_presets.MASKS["default"]
	swarm1.initialize(swarm1_params, behaviours_root, mask1, null)
	swarms.append(swarm1)

	if debug:
		print("Initialized Swarm1 with ", swarm1_params["boid_count"], " boids")

	var swarm2: Node3D = get_node("Swarm2")
	var mask2: Dictionary = behaviours_presets.MASKS["default"]
	swarm2.initialize(swarm2_params, behaviours_root, mask2, null)
	swarms.append(swarm2)

	if debug:
		print("Initialized Swarm2 with ", swarm2_params["boid_count"], " boids")


func _setup_global_core() -> void:
	if debug:
		print("Setting up GlobalSimulationCore with ", swarms.size(), " swarms")
	global_core.setup_for_swarms(swarms)


func _physics_process(delta: float) -> void:
	if paused:
		if advance_step:
			_run_simulation_step(delta)
			advance_step = false
		return

	_run_simulation_step(delta)


func _run_simulation_step(delta: float) -> void:
	global_core.simulate(delta)

	for swarm in swarms:
		var swarm_node: Node3D = swarm
		swarm_node.update_renderer()


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
		advance_step = true
		if debug:
			print("Input: advance_simulation (single step)")


func _extract_config_params(file_name: String) -> Dictionary:
	return config_handler.extract_params(file_name)
