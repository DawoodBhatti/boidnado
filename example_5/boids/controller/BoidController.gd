extends Node3D


# ---------------------------------------------------------
# Preload Config
# ---------------------------------------------------------
var config_file: String = "orbital_boids.json"
var use_preloaded_config : bool = true


# ---------------------------------------------------------
# Backend Selector
# ---------------------------------------------------------
@export_enum("CPU", "GPU") var simulation_backend: String = "CPU"


# ---------------------------------------------------------
# Editable Configuration
# ---------------------------------------------------------

@export var boid_count: int = 200
@export var cell_size: float = 4.0
@export var sight_radius: float = 5.0
@export var cage_radius: float = cell_size * 10
@export var max_speed: float = 25.0
@export var desired_separation: float = 0.5
@export var boid_mesh: Mesh

@export var alignment_weight: float = 1.1
@export var cohesion_weight: float = 4.5
@export var separation_weight: float = 4.00
@export var wander_strength: float = 2.00
@export var boundary_strength: float = 0.9

# ---------------------------------------------------------
# Internal State
# ---------------------------------------------------------

@onready var grid: Node3D = $BoidsGrid
@onready var cage: Node3D = $BoidCage
@onready var debug: Node3D = $BoidsDebugOverlay
@onready var behaviours: Node3D = $BoidBehaviours
@onready var renderer: MultiMeshInstance3D = $BoidRenderer
@onready var config: Node3D  = $BoidConfigHandler

@onready var data : Node = $BoidData
@onready var cpu_core : Node3D = $BoidData/CPUSimulationCore
@onready var gpu_core : Node3D = $BoidData/GPUSimulationCore

var pause_simulation: bool = false
var step_counter: int = 0
var stepping_held: bool = false

var weights : Dictionary = {}
var limits : Dictionary = {}

# ---------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------

func _ready() -> void:

	_init_config()
	_apply_config()
	_init_weights_and_limits()
	_init_data()
	_init_geometry()
	_init_debug_overlay()
	_init_renderer()

# ---------------------------------------------------------
# Config
# ---------------------------------------------------------

func _init_config() -> void:
	config.set_config_file(config_file)
	config.load_config()
	config.load_boid_mesh()
	

func _apply_config() -> void:
	if not use_preloaded_config:
		return

	boid_count = int(config.get_value("boid_count", boid_count))
	cell_size = float(config.get_value("cell_size", cell_size))
	sight_radius = float(config.get_value("sight_radius", sight_radius))
	cage_radius = float(config.get_value("cage_radius", cage_radius))
	max_speed = float(config.get_value("max_speed", max_speed))
	desired_separation = float(config.get_value("desired_separation", desired_separation))

	alignment_weight = float(config.get_value("alignment_weight", alignment_weight))
	cohesion_weight = float(config.get_value("cohesion_weight", cohesion_weight))
	separation_weight = float(config.get_value("separation_weight", separation_weight))
	wander_strength = float(config.get_value("wander_strength", wander_strength))
	boundary_strength = float(config.get_value("boundary_strength", boundary_strength))

	config.print_all_values()

	var loaded_mesh: Mesh = config.get_mesh()
	if loaded_mesh != null:
		boid_mesh = loaded_mesh
		print("Loaded boid mesh from config.")
	else:
		print("No mesh found in config — using inspector mesh.")

func _init_weights_and_limits() -> void:
	weights = {
		"alignment": alignment_weight,
		"cohesion": cohesion_weight,
		"separation": separation_weight,
		"wander": wander_strength,
		"boundary": boundary_strength
	}

	limits = {
		"max_speed": max_speed,
		"desired_separation": desired_separation,
		"sight_radius": sight_radius
	}

# ---------------------------------------------------------
# Geometry
# ---------------------------------------------------------

func _init_geometry() -> void:
	grid.cell_size = cell_size
	cage.cage_radius = cage_radius


# ---------------------------------------------------------
# Data
# ---------------------------------------------------------

func _init_data() -> void:
	data.setup(
		boid_count,
		limits,
		weights,
		grid,
		behaviours,
		cage_radius,
		max_speed
	)

	# Select backend
	if simulation_backend == "CPU":
		data.core = cpu_core
		print("Simulation backend: CPU")
	else:
		data.core = gpu_core
		print("Simulation backend: GPU")

# ---------------------------------------------------------
# Debug Overlay
# ---------------------------------------------------------

func _init_debug_overlay() -> void:
	debug.cell_length = cell_size
	debug.FOV_radius = sight_radius
	debug.FOV_angle = grid.FOV_angle
	debug.positions = data.positions
	debug.velocities = data.velocities
	debug.sight_radius = sight_radius
	debug.grid = grid
	debug.renderer = renderer

# ---------------------------------------------------------
# Renderer
# ---------------------------------------------------------

func _init_renderer() -> void:
	if renderer and boid_mesh:
		renderer.setup(boid_mesh, boid_count)

# ---------------------------------------------------------
# Simulation Step
# ---------------------------------------------------------

func _physics_process(delta: float) -> void:
	if pause_simulation:
		if stepping_held:
			step_counter += 1

		if step_counter > 0:
			data.update(delta)
			_update_renderer()
			_update_debug_overlay()
			step_counter -= 1
		return

	data.update(delta)
	_update_renderer()
	_update_debug_overlay()

# ---------------------------------------------------------
# Renderer + Debug Updates
# ---------------------------------------------------------

func _update_renderer() -> void:
	if renderer:
		renderer.update_transforms(data.positions, data.velocities)

func _update_debug_overlay() -> void:
	if debug:
		debug.positions = data.positions
		debug.velocities = data.velocities
		debug.sight_radius = limits["sight_radius"]

# ---------------------------------------------------------
# Input Handling
# ---------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		print("pausing")
		pause_simulation = true
	elif event.is_action_pressed("resume"):
		print("resuming")
		pause_simulation = false
	elif event.is_action_pressed("advance_simulation") and pause_simulation:
		stepping_held = true
	elif event.is_action_released("advance_simulation"):
		stepping_held = false
