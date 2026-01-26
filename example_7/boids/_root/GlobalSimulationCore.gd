extends Node

@onready var compute_device: Node = $GlobalComputeDevice
@onready var assign_pass: Node = $GridAssignPass
@onready var sort_pass: Node = $GridSortPass
@onready var ranges_pass: Node = $GridRangesPass
@onready var behaviour_dispatcher: Node = $BehaviourDispatcher
@onready var integration_pass: Node = $IntegrationPass
@onready var buffers: Node = $GlobalBuffers

var rd: RenderingDevice

var total_boid_count: int = 0
var total_cells: int = 0
var grid_params: PackedFloat32Array = PackedFloat32Array()
var grid_dims: PackedInt32Array = PackedInt32Array()
var swarm_slices: Array = []

func setup_for_swarms(swarms: Array) -> void:
	print("GlobalSimulationCore: setup_for_swarms")

	rd = compute_device.rd

	buffers.setup(rd)

	_compute_swarm_slices(swarms)
	_compute_grid_params()

	total_boid_count = buffers.total_boid_count
	buffers.allocate(total_boid_count, grid_dims)

	assign_pass.setup(rd, buffers, grid_params, grid_dims)
	sort_pass.setup(rd, buffers)
	ranges_pass.setup(rd, buffers, total_cells)
	behaviour_dispatcher.setup(rd, buffers, swarm_slices)
	integration_pass.setup(rd, buffers)

	print("total_boid_count BEFORE allocate = ", total_boid_count)
	print("grid_dims = ", grid_dims)

func simulate(delta: float) -> void:
	if total_boid_count <= 0:
		return

	assign_pass.run()
	sort_pass.run()
	ranges_pass.run()
	behaviour_dispatcher.run(delta)
	integration_pass.run(delta)


func _compute_swarm_slices(swarms: Array) -> void:
	var slices: Array = []
	var start_index: int = 0
	var total: int = 0

	for i in range(swarms.size()):
		var swarm_node: Node3D = swarms[i]

		# Each swarm must have a BoidData child with boid_count
		if swarm_node.has_node("BoidData"):
			var data_node: Node = swarm_node.get_node("BoidData")
			var count: int = data_node.boid_count

			var slice: Dictionary = {}
			slice["start"] = start_index
			slice["count"] = count
			slice["swarm_id"] = i

			# Optional: attach behaviour params here later
			var params: Dictionary = {}
			slice["params"] = params

			slices.append(slice)

			start_index += count
			total += count

	swarm_slices = slices
	buffers.total_boid_count = total


func _compute_grid_params() -> void:
	# ---------------------------------------------------------
	# GRID CONFIGURATION (TEMPORARY STATIC GRID)
	#
	# For now we use a fixed 128×128×128 spatial grid.
	# This is large enough for most test scenarios and keeps
	# the GPU pipeline simple and predictable.
	#
	# In the future, we may want to:
	#   - implement world wrapping (toroidal space)
	#   - dynamically resize the grid based on swarm extents
	#   - allow per-simulation configuration of grid size
	#   - compute grid bounds from boid positions
	#
	# For now, static grid = stability.
	# ---------------------------------------------------------

	var grid_x: int = 128
	var grid_y: int = 128
	var grid_z: int = 128

	grid_dims = PackedInt32Array()
	grid_dims.append(grid_x)
	grid_dims.append(grid_y)
	grid_dims.append(grid_z)

	# ---------------------------------------------------------
	# CELL SIZE
	#
	# This defines the physical size of each grid cell.
	# Behaviour shaders assume neighbour search radius is
	# related to this value.
	#
	# In the future, we may want to:
	#   - expose this as a config parameter
	#   - tie it to behaviour radii
	#   - adjust it dynamically
	# ---------------------------------------------------------

	var cell_size: float = 2.0

	grid_params = PackedFloat32Array()
	grid_params.append(cell_size)

	# ---------------------------------------------------------
	# TOTAL CELLS
	# ---------------------------------------------------------
	total_cells = grid_x * grid_y * grid_z
