extends Node3D

var swarms: Array = []
var paused := false
var step_mode := false
var step_counter := 0
var boid_count : int = 0

@export var swarm1_config : String = "default.json"
var swarm1_use_config := true
var swarm1_params : Dictionary

@export var swarm2_config : String = ""
var swarm2_use_config := false
var swarm2_params : Dictionary

@onready var config_handler: Node = $"../ConfigHandler"


func _ready() -> void:
	swarm1_params = _extract_config_params(swarm1_config)
	swarm2_params = _manually_set_params()
	boid_count = swarm1_params["boid_count"]+swarm2_params["boid_count"]
	_initialize_all_swarms()


# ---------------------------------------------------------
# INITIALIZE ALL SWARMS IN SCENE
# ---------------------------------------------------------

func _initialize_all_swarms() -> void:

	print(swarm1_params)

	var Swarm1 : Node3D = get_node("Swarm1")
	Swarm1.initialize(swarm1_params)
	swarms.append(Swarm1)
	
	var Swarm2 : Node3D = get_node("Swarm2")
	Swarm2.initialize(swarm2_params)
	swarms.append(Swarm2)


# ---------------------------------------------------------
# EXTRACT PARAMS FROM CONFIG FILE (STATELESS PATTERN)
# ---------------------------------------------------------

func _extract_config_params(file_name: String) -> Dictionary:
	return config_handler.extract_params(file_name)


# ---------------------------------------------------------
# MANUAL PARAMS
# ---------------------------------------------------------

func _manually_set_params() -> Dictionary:
	var mesh: Resource = load("res://example_6/boids/models/biggerboid.obj")
	return {
		"simulation_core": "CPU",
		"boid_count": 50,
		"cell_size": 3.0,
		"sight_radius": 4.0,
		"cage_radius": 30.0,
		"max_speed": 48.0,
		"desired_separation": 0.4,

		"alignment_weight": 0.8,
		"cohesion_weight": 3.0,
		"separation_weight": 5.0,
		"wander_strength": 1.0,
		"boundary_strength": 1.0,

		"boid_mesh": mesh,
		"boid_colour": Color(0.0,0.0,1.0,0.5)
	}


# ---------------------------------------------------------
# DEFAULT PARAMS (fallback)
# ---------------------------------------------------------

func _default_params() -> Dictionary:
	return {
		"simulation_core": "CPU",
		"boid_count": 200,
		"cell_size": 4.0,
		"sight_radius": 5.0,
		"cage_radius": 40.0,
		"max_speed": 5.0,
		"desired_separation": 0.5,

		"alignment_weight": 1.1,
		"cohesion_weight": 4.5,
		"separation_weight": 4.0,
		"wander_strength": 2.0,
		"boundary_strength": 0.9,

		"boid_mesh": null,
		"boid_colour": Color(1.0,0.0,0.0,0.5)
	}


# ---------------------------------------------------------
# SIMULATION CONTROL
# ---------------------------------------------------------

func _physics_process(delta: float) -> void:
	if paused:
		if step_mode and step_counter > 0:
			_step_once(delta)
			step_counter -= 1
		return

	for swarm in swarms:
		swarm.simulate_step(delta)


func _step_once(delta: float) -> void:
	for swarm in swarms:
		swarm.simulate_step(delta)


# ---------------------------------------------------------
# INPUT HANDLING
# ---------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		paused = true
		print("Paused all swarms")

	elif event.is_action_pressed("resume"):
		paused = false
		print("Resumed all swarms")

	elif event.is_action_pressed("advance_simulation") and paused:
		step_mode = true
		step_counter += 1

	elif event.is_action_released("advance_simulation"):
		step_mode = false
