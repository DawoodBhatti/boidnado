extends Node

@export var boid_count: int = 30
@export var alignment_weight: float = 1.0
@export var neighbour_radius: float = 10.0

@export var max_speed: float = 30.0
@export var cohesion_weight: float = 1.0
@export var separation_weight: float = 15.5
@export var desired_separation: float = 10.0
@export var wander_strength: float = 0.5

@export var boid_mesh: Mesh
@export var renderer_path: NodePath

var positions: PackedVector3Array
var velocities: PackedVector3Array
var accelerations: PackedVector3Array

var grid: Object = BoidGrid2.new()
var behaviours : Object = BoidBehaviours2
var renderer : Object = BoidRenderer2

func _ready() -> void:
	
	renderer_path = NodePath("BoidRenderer")
	
	_init_data()
	_init_grid()
	_init_renderer()

func _init_data() -> void:
	positions = PackedVector3Array()
	velocities = PackedVector3Array()
	accelerations = PackedVector3Array()

	positions.resize(boid_count)
	velocities.resize(boid_count)
	accelerations.resize(boid_count)

	var rng := RandomNumberGenerator.new()
	for i in boid_count:
		positions[i] = Vector3(
			rng.randf_range(-20.0, 20.0),
			rng.randf_range(0.0, 10.0),
			rng.randf_range(-20.0, 20.0)
		)
		velocities[i] = Vector3(
			rng.randf_range(-1.0, 1.0),
			rng.randf_range(-1.0, 1.0),
			rng.randf_range(-1.0, 1.0)
		).normalized() * max_speed * 0.5
		accelerations[i] = Vector3.ZERO

func _init_grid() -> void:
	grid.cell_size = neighbour_radius

func _init_renderer() -> void:
	renderer = get_node_or_null(renderer_path)
	if renderer and boid_mesh:
		renderer.setup(boid_mesh, boid_count)

func _physics_process(delta: float) -> void:
	# 1. clear accelerations
	for i in accelerations.size():
		accelerations[i] = Vector3.ZERO

	# 2. rebuild grid
	grid.rebuild(positions)

	# 3. apply behaviours
	for i in positions.size():
		var neighbours : PackedInt32Array = grid.get_neighbours(i, positions, velocities, neighbour_radius)
		behaviours.apply_alignment(
			i,
			positions,
			velocities,
			accelerations,
			neighbours,
			alignment_weight
		)
		
		behaviours.apply_cohesion(
		i,
		positions,
		velocities,
		accelerations,
		neighbours,
		cohesion_weight
		)

		behaviours.apply_separation(
		i,
		positions,
		velocities,
		accelerations,
		neighbours,
		desired_separation,
		separation_weight
		)
		
		behaviours.apply_wander(
		i,
		velocities,
		accelerations,
		wander_strength
	)

	# 4. integrate forces
	for i in positions.size():
		velocities[i] += accelerations[i] * delta
		if velocities[i].length() > max_speed:
			velocities[i] = velocities[i].normalized() * max_speed
		positions[i] += velocities[i] * delta

	# 5. update renderer
	if renderer:
		renderer.update_transforms(positions, velocities)
