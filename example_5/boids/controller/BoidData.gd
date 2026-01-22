extends Node

var core: Node  # either CPU or GPU child

var positions: PackedVector3Array
var velocities: PackedVector3Array
var accelerations: PackedVector3Array

var boid_count: int
var limits: Dictionary
var weights: Dictionary

var grid: Node
var behaviours: Node
var cage_radius: float

func setup(boid_count, limits, weights, grid, behaviours, cage_radius, max_speed):
	self.boid_count = boid_count
	self.limits = limits
	self.weights = weights
	self.grid = grid
	self.behaviours = behaviours
	self.cage_radius = cage_radius

	positions = PackedVector3Array()
	velocities = PackedVector3Array()
	accelerations = PackedVector3Array()

	positions.resize(boid_count)
	velocities.resize(boid_count)
	accelerations.resize(boid_count)
	
	randomize_initial_state(max_speed)

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

func update(delta):
	core.update(delta, self)
