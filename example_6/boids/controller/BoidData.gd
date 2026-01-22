extends Node

# -------------------------------------------------------------------
# BoidData
# -------------------------------------------------------------------
# This node is the *state container* for the entire boid simulation.
#
# It owns:
#   - positions, velocities, accelerations
#   - simulation parameters (limits, weights)
#   - references to shared systems (grid, behaviours)
#
# It does NOT perform any simulation logic itself.
# Instead, it delegates simulation to a backend "core" node:
#
#       CPUSimulationCore   (pure GDScript implementation)
#       GPUSimulationCore   (future compute-shader implementation)
#
# This separation allows:
#   - clean CPU/GPU swapping
#   - running both backends in parallel for debugging
#   - keeping the controller free of simulation logic
#   - keeping all state in one place for rendering/debugging
#
# In short: BoidData = the body, SimulationCore = the brain.
# -------------------------------------------------------------------

var core: Node  # Active simulation backend (CPU or GPU child)


# -------------------------------------------------------------------
# Simulation State Arrays
# These are the single source of truth for all boid data.
# No other node should allocate or own these arrays.
# -------------------------------------------------------------------
var positions: PackedVector3Array
var velocities: PackedVector3Array
var accelerations: PackedVector3Array


# -------------------------------------------------------------------
# Simulation Parameters
# These are injected by the controller during setup.
# -------------------------------------------------------------------
var boid_count: int
var limits: Dictionary
var weights: Dictionary

var grid: Node          # Spatial hash grid for neighbour lookup
var behaviours: Node    # Behaviour functions (alignment, cohesion, etc.)
var cage_radius: float  # Boundary constraint


# -------------------------------------------------------------------
# setup()
# Called once by the controller after config is loaded.
#
# Responsibilities:
#   - store references + parameters
#   - allocate simulation arrays
#   - randomize initial boid positions/velocities
#
# After setup(), the simulation is ready to run.
# -------------------------------------------------------------------
func setup(boid_count, limits, weights, grid, behaviours, cage_radius, max_speed):
	self.boid_count = boid_count
	self.limits = limits
	self.weights = weights
	self.grid = grid
	self.behaviours = behaviours
	self.cage_radius = cage_radius

	# Allocate arrays
	positions = PackedVector3Array()
	velocities = PackedVector3Array()
	accelerations = PackedVector3Array()

	positions.resize(boid_count)
	velocities.resize(boid_count)
	accelerations.resize(boid_count)

	# Initialize boids with random positions + velocities
	randomize_initial_state(max_speed)


# -------------------------------------------------------------------
# randomize_initial_state()
# Creates an initial distribution of boids.
#
# This is intentionally simple for now, but the architecture allows:
#   - deterministic seeds
#   - spherical distributions
#   - grid distributions
#   - loading from file
#   - multi-species initialization
# -------------------------------------------------------------------
func randomize_initial_state(max_speed):
	var rng = RandomNumberGenerator.new()
	rng.randomize()

	for i in boid_count:
		positions[i] = Vector3(
			rng.randf_range(-20, 20),
			rng.randf_range(0, 10),
			rng.randf_range(-20, 20)
		)

		velocities[i] = Vector3(
			rng.randf_range(-10, 10),
			rng.randf_range(-10, 10),
			rng.randf_range(-10, 10)
		).normalized() * max_speed * 0.5

		accelerations[i] = Vector3.ZERO


# -------------------------------------------------------------------
# update()
# Called every physics frame by the controller.
#
# Delegates simulation to the active backend:
#   core.update(delta, self)
#
# This keeps BoidData free of simulation logic and allows
# CPU/GPU backends to be swapped or run in parallel.
# -------------------------------------------------------------------
func update(delta):
	core.update(delta, self)
