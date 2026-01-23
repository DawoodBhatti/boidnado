extends Node3D

# ---------------------------------------------------------
# Internal State
# ---------------------------------------------------------

@onready var grid: Node3D = $BoidsGrid
@onready var cage: Node3D = $BoidCage
@onready var debug: Node3D = $BoidsDebugOverlay
@onready var behaviours: Node3D = $BoidBehaviours
@onready var renderer: MultiMeshInstance3D = $BoidRenderer
@onready var data: Node = $BoidData

var simulation_core: String = "CPU"

var boid_count: int = 0
var cell_size: float = 0.0
var sight_radius: float = 0.0
var cage_radius: float = 0.0
var max_speed: float = 0.0
var desired_separation: float = 0.0
var boid_mesh: ArrayMesh = null
var boid_colour : Color = Color(1,1,1,1)

var weights: Dictionary = {}
var limits: Dictionary = {}


# ---------------------------------------------------------
# Initialization (called by SwarmManager)
# ---------------------------------------------------------

func initialize(params: Dictionary) -> void:
	simulation_core = params.simulation_core

	boid_count = params.boid_count
	cell_size = params.cell_size
	sight_radius = params.sight_radius
	cage_radius = params.cage_radius
	max_speed = params.max_speed
	desired_separation = params.desired_separation
	boid_mesh = params.boid_mesh
	boid_colour = params.boid_colour

	weights = {
		"alignment": params.alignment_weight,
		"cohesion": params.cohesion_weight,
		"separation": params.separation_weight,
		"wander": params.wander_strength,
		"boundary": params.boundary_strength
	}

	limits = {
		"max_speed": max_speed,
		"desired_separation": desired_separation,
		"sight_radius": sight_radius
	}

	_init_geometry()
	_init_data()
	_init_debug_overlay()
	_init_renderer()

	print("BoidSwarm: initialized swarm with ", boid_count, " boids")


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
		simulation_core,
		boid_count,
		limits,
		weights,
		grid,
		behaviours,
		cage_radius,
		max_speed
	)


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
	debug.default_colour = boid_colour


# ---------------------------------------------------------
# Renderer
# ---------------------------------------------------------

func _init_renderer() -> void:
	if renderer and boid_mesh:
		renderer.setup(boid_mesh, boid_colour, boid_count)


# ---------------------------------------------------------
# Simulation Step (called by SwarmManager)
# ---------------------------------------------------------

func simulate_step(delta: float) -> void:
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
