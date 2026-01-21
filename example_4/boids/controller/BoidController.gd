extends Node3D

# ---------------------------------------------------------
# Exported Configuration
# ---------------------------------------------------------

@export var boid_count: int = 350
@export var cell_size: float = 4.0
@export var sight_radius: float = 8.0
@export var cage_radius: float = cell_size * 90
@export var max_speed: float = 10.0
@export var desired_separation: float = 144.0
@export var boid_mesh: Mesh
@export var renderer_path: NodePath = "BoidRenderer"

@export var alignment_weight: float = 1.5
@export var cohesion_weight: float = 0.01
@export var separation_weight: float = 1.5
@export var wander_strength: float = 0.5

# ---------------------------------------------------------
# Internal State
# ---------------------------------------------------------

var positions: PackedVector3Array
var velocities: PackedVector3Array
var accelerations: PackedVector3Array

@onready var grid: Node3D = $BoidsGrid
@onready var cage: Node3D = $BoidCage
@onready var debug: Node3D = $BoidsDebugOverlay
@onready var behaviours: Node3D = $BoidBehaviours
@onready var renderer: MultiMeshInstance3D = $BoidRenderer

var pause_simulation: bool = false
var step_counter: int = 0
var stepping_held: bool = false

# Grouped parameters for clarity
var weights := {}
var limits := {}

# ---------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------

func _ready() -> void:
	_init_data()
	_init_geometry()
	_init_debug_overlay()
	_init_renderer()

# ---------------------------------------------------------
# Data Initialization
# ---------------------------------------------------------

func _init_data() -> void:
	positions = PackedVector3Array()
	velocities = PackedVector3Array()
	accelerations = PackedVector3Array()

	positions.resize(boid_count)
	velocities.resize(boid_count)
	accelerations.resize(boid_count)

	var rng := RandomNumberGenerator.new()
	rng.randomize()

	for i in boid_count:
		positions[i] = _random_vector_in_box(rng, 20, 10, 20)
		velocities[i] = _random_vector_in_box(rng, 10, 10, 10).normalized() * max_speed * 0.5
		accelerations[i] = Vector3.ZERO

	weights = {
		"alignment": alignment_weight,
		"cohesion": cohesion_weight,
		"separation": separation_weight,
		"wander": wander_strength
	}

	limits = {
		"max_speed": max_speed,
		"desired_separation": desired_separation,
		"sight_radius": sight_radius
	}

func _random_vector_in_box(rng: RandomNumberGenerator, x: float, y: float, z: float) -> Vector3:
	return Vector3(
		rng.randf_range(-x, x),
		rng.randf_range(0, y),
		rng.randf_range(-z, z)
	)

# ---------------------------------------------------------
# Geometry Initialization
# ---------------------------------------------------------

func _init_geometry() -> void:
	grid.cell_size = cell_size
	cage.cage_radius = cage_radius

# ---------------------------------------------------------
# Debug Overlay Initialization
# ---------------------------------------------------------

func _init_debug_overlay() -> void:
	debug.cell_length = cell_size
	debug.FOV_radius = sight_radius
	debug.FOV_angle = grid.FOV_angle
	debug.positions = positions
	debug.velocities = velocities
	debug.sight_radius = sight_radius
	debug.grid = grid
	debug.renderer = renderer

# ---------------------------------------------------------
# Renderer Initialization
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
			_simulate_boids(delta)
			_update_renderer()
			_update_debug_overlay()
			step_counter -= 1
		return

	_simulate_boids(delta)
	_update_renderer()
	_update_debug_overlay()

func _simulate_boids(delta: float) -> void:
	for i in accelerations.size():
		accelerations[i] = Vector3.ZERO

	grid.rebuild(positions)

	for i in positions.size():
		var neighbours: PackedInt32Array = grid.get_neighbours(i, positions, velocities, limits["sight_radius"])
		behaviours.apply_alignment(i, positions, velocities, accelerations, neighbours, weights["alignment"])
		behaviours.apply_cohesion(i, positions, velocities, accelerations, neighbours, weights["cohesion"])
		behaviours.apply_separation(i, positions, velocities, accelerations, neighbours, limits["desired_separation"], weights["separation"])
		behaviours.apply_wander(i, velocities, accelerations, weights["wander"])

	for i in positions.size():
		velocities[i] += accelerations[i] * delta
		if velocities[i].length() > limits["max_speed"]:
			velocities[i] = velocities[i].normalized() * limits["max_speed"]
		positions[i] += velocities[i] * delta

func _update_renderer() -> void:
	if renderer:
		renderer.update_transforms(positions, velocities)

func _update_debug_overlay() -> void:
	if debug:
		debug.positions = positions
		debug.velocities = velocities
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
