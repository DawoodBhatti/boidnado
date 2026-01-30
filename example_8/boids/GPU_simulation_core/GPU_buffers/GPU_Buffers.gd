extends Node

# ---------------------------------------------------------
# References
# ---------------------------------------------------------
var gpu_device : Node
var rd : RenderingDevice

# ---------------------------------------------------------
# CPU-side cached data (SoA layout)
# ---------------------------------------------------------
var initial_positions_x : Array = []
var initial_positions_y : Array = []
var initial_positions_z : Array = []

var initial_velocities_x : Array = []
var initial_velocities_y : Array = []
var initial_velocities_z : Array = []

var boid_indices : PackedInt32Array = []
var cell_ids : PackedInt32Array = []
var sorted_boid_indices : PackedInt32Array = []
var sorted_cell_ids : PackedInt32Array = []

var grid_cell_size : float = 0.0
var swarm_parameters : Array = []
var swarm_count : int = 0
var total_boids : int = 0

# ---------------------------------------------------------
# GPU buffers (SoA layout)
# ---------------------------------------------------------
var positions_x_buffer : RID
var positions_y_buffer : RID
var positions_z_buffer : RID

var velocities_x_buffer : RID
var velocities_y_buffer : RID
var velocities_z_buffer : RID

var swarm_params_buffer : RID
var boid_to_swarm_buffer : RID
var global_params_buffer : RID

var boid_indices_buffer : RID
var sorted_boid_indices_buffer : RID

var cell_id_buffer : RID
var sorted_cell_id_buffer : RID

# ---------------------------------------------------------
# RDUniform descriptors (one per buffer)
# ---------------------------------------------------------
var u_pos_x : RDUniform
var u_pos_y : RDUniform
var u_pos_z : RDUniform

var u_vel_x : RDUniform
var u_vel_y : RDUniform
var u_vel_z : RDUniform

var u_swarm : RDUniform
var u_map : RDUniform
var u_global : RDUniform

var u_boid_index : RDUniform
var u_sorted_boid_index : RDUniform

var u_cell_id : RDUniform
var u_sorted_cell_id : RDUniform


func _ready() -> void:
	gpu_device = get_node("../GPU_Device")
	rd = gpu_device.rd
	print("GPU_Buffers: ready")
	
# ---------------------------------------------------------
# Set index buffers and cell_id buffers used for grid calculations and neighbour lookups
# ---------------------------------------------------------
func set_index_and_cell_ids() -> void:
	if total_boids == 0:
		push_error("set the position, velocity and swarm params first")
		return
	
	for i in range (total_boids):
		boid_indices.append(i)
		cell_ids.append(0)
		sorted_boid_indices.append(0)
		sorted_cell_ids.append(0)

# ---------------------------------------------------------
# Set per-boid data (positions, velocities) in SoA layout
# ---------------------------------------------------------

func set_positions_soa(pos_x : Array, pos_y : Array, pos_z : Array) -> void:
	# Store CPU-side SoA arrays
	initial_positions_x = pos_x
	initial_positions_y = pos_y
	initial_positions_z = pos_z


func set_velocities_soa(vel_x : Array, vel_y : Array, vel_z : Array) -> void:
	# Store CPU-side SoA arrays
	initial_velocities_x = vel_x
	initial_velocities_y = vel_y
	initial_velocities_z = vel_z

# ---------------------------------------------------------
# Set cell_size and per-swarm parameters 
# ---------------------------------------------------------
func set_params(cell_size : float, swarm_parameters_in : Array) -> void:
	grid_cell_size = cell_size
	swarm_count = swarm_parameters_in.size()
	swarm_parameters = swarm_parameters_in

	# Count total boids
	total_boids = 0
	for p in swarm_parameters:
		var count_value : int = int(p["count"])
		total_boids = total_boids + count_value

	print("GPU_Buffers: total boids =", total_boids)
	print("GPU_Buffers: swarms =", swarm_count)


func _validate_inputs() -> void:
	# ---------------------------------------------------------
	# Ensure all SoA arrays exist and contain data
	# If any of these are empty, the simulation cannot proceed.
	# ---------------------------------------------------------
	assert(not initial_positions_x.is_empty(), "positions_x not supplied")
	assert(not initial_positions_y.is_empty(), "positions_y not supplied")
	assert(not initial_positions_z.is_empty(), "positions_z not supplied")

	assert(not initial_velocities_x.is_empty(), "velocities_x not supplied")
	assert(not initial_velocities_y.is_empty(), "velocities_y not supplied")
	assert(not initial_velocities_z.is_empty(), "velocities_z not supplied")

	# ---------------------------------------------------------
	# Ensure each SoA component array matches total_boids.
	# This guarantees that every boid has a valid x/y/z entry.
	# ---------------------------------------------------------
	assert(initial_positions_x.size() == total_boids, "positions_x length mismatch")
	assert(initial_positions_y.size() == total_boids, "positions_y length mismatch")
	assert(initial_positions_z.size() == total_boids, "positions_z length mismatch")

	assert(initial_velocities_x.size() == total_boids, "velocities_x length mismatch")
	assert(initial_velocities_y.size() == total_boids, "velocities_y length mismatch")
	assert(initial_velocities_z.size() == total_boids, "velocities_z length mismatch")

	# ---------------------------------------------------------
	# Internal consistency check:
	# All position arrays must match each other,
	# and all velocity arrays must match each other.
	# This protects against partial uploads or corrupted state.
	# ---------------------------------------------------------
	assert(initial_positions_x.size() == initial_positions_y.size(), "position x/y mismatch")
	assert(initial_positions_y.size() == initial_positions_z.size(), "position y/z mismatch")

	assert(initial_velocities_x.size() == initial_velocities_y.size(), "velocity x/y mismatch")
	assert(initial_velocities_y.size() == initial_velocities_z.size(), "velocity y/z mismatch")

	# ---------------------------------------------------------
	# Validate swarm parameters exist.
	# These define per-swarm constants and are required for GPU setup.
	# ---------------------------------------------------------
	assert(not swarm_parameters.is_empty(), "swarm parameters not supplied")

	# ---------------------------------------------------------
	# Validate grid cell size.
	# A zero or negative cell size would break grid assignment.
	# ---------------------------------------------------------
	assert(grid_cell_size > 0.0, "grid cell size invalid")


# ---------------------------------------------------------
# Build all buffers and uniform 
# ---------------------------------------------------------
func build_all_buffers():
	_validate_inputs()

	_allocate_position_buffers()
	_allocate_velocity_buffers()
	_allocate_swarm_params_buffer()
	_allocate_boid_to_swarm_buffer()
	_allocate_global_params_buffer()
	_allocate_boid_index_and_cell_id_buffers()
	_build_uniform_descriptors()


# ---------------------------------------------------------
# Allocate position buffers (SoA: x, y, z)
# ---------------------------------------------------------
func _allocate_position_buffers() -> void:
	# Each component is a float (4 bytes)
	var byte_count : int = total_boids * 4

	# Create three separate SSBOs for x, y, z
	positions_x_buffer = rd.storage_buffer_create(byte_count)
	positions_y_buffer = rd.storage_buffer_create(byte_count)
	positions_z_buffer = rd.storage_buffer_create(byte_count)

	# Upload CPU-side SoA arrays into GPU buffers
	var x_bytes : PackedByteArray = PackedFloat32Array(initial_positions_x).to_byte_array()
	var y_bytes : PackedByteArray = PackedFloat32Array(initial_positions_y).to_byte_array()
	var z_bytes : PackedByteArray = PackedFloat32Array(initial_positions_z).to_byte_array()

	rd.buffer_update(positions_x_buffer, 0, x_bytes.size(), x_bytes)
	rd.buffer_update(positions_y_buffer, 0, y_bytes.size(), y_bytes)
	rd.buffer_update(positions_z_buffer, 0, z_bytes.size(), z_bytes)


# ---------------------------------------------------------
# Allocate velocity buffers (SoA: x, y, z)
# ---------------------------------------------------------
func _allocate_velocity_buffers() -> void:
	# Each component is a float (4 bytes)
	var byte_count : int = total_boids * 4

	# Create three separate SSBOs for x, y, z
	velocities_x_buffer = rd.storage_buffer_create(byte_count)
	velocities_y_buffer = rd.storage_buffer_create(byte_count)
	velocities_z_buffer = rd.storage_buffer_create(byte_count)

	# Upload CPU-side SoA arrays into GPU buffers
	var x_bytes : PackedByteArray = PackedFloat32Array(initial_velocities_x).to_byte_array()
	var y_bytes : PackedByteArray = PackedFloat32Array(initial_velocities_y).to_byte_array()
	var z_bytes : PackedByteArray = PackedFloat32Array(initial_velocities_z).to_byte_array()

	rd.buffer_update(velocities_x_buffer, 0, x_bytes.size(), x_bytes)
	rd.buffer_update(velocities_y_buffer, 0, y_bytes.size(), y_bytes)
	rd.buffer_update(velocities_z_buffer, 0, z_bytes.size(), z_bytes)
	
# ---------------------------------------------------------
# Build SwarmParams buffer (one struct per swarm)
# ---------------------------------------------------------
func _allocate_swarm_params_buffer() -> void:
	var floats : PackedFloat32Array = PackedFloat32Array()

	for p in swarm_parameters:
		var start_index : int = int(p["start"])
		var count_value : int = int(p["count"])

		var c : Dictionary = p["constants"]
		var w : Dictionary = p["weights"]
		var m : Dictionary = p["masks"]

		# Constants
		floats.append(float(start_index))
		floats.append(float(count_value))
		floats.append(float(c["sight_radius"]))
		floats.append(float(c["FOV_angle_deg"]))
		floats.append(float(c["cage_radius"]))
		floats.append(float(c["desired_separation"]))

		# Weights
		floats.append(float(w["alignment_weight"]))
		floats.append(float(w["cohesion_weight"]))
		floats.append(float(w["separation_weight"]))
		floats.append(float(w["wander_strength"]))
		floats.append(float(w["boundary_strength"]))

		# Masks (explicit if/else, no ternary)
		var alignment_mask : float = 0.0
		if m["alignment"] == true:
			alignment_mask = 1.0
		floats.append(alignment_mask)

		var cohesion_mask : float = 0.0
		if m["cohesion"] == true:
			cohesion_mask = 1.0
		floats.append(cohesion_mask)

		var separation_mask : float = 0.0
		if m["separation"] == true:
			separation_mask = 1.0
		floats.append(separation_mask)

		var wander_mask : float = 0.0
		if m["wander"] == true:
			wander_mask = 1.0
		floats.append(wander_mask)

		var boundary_mask : float = 0.0
		if m["boundary"] == true:
			boundary_mask = 1.0
		floats.append(boundary_mask)

	var byte_size : int = floats.size() * 4
	swarm_params_buffer = rd.storage_buffer_create(byte_size)
	rd.buffer_update(swarm_params_buffer, 0, byte_size, floats.to_byte_array())


# ---------------------------------------------------------
# Build boid_to_swarm buffer (length = total_boids)
# ---------------------------------------------------------
func _allocate_boid_to_swarm_buffer() -> void:
	var ints : PackedInt32Array = PackedInt32Array()
	ints.resize(total_boids)

	for swarm_index in range(swarm_parameters.size()):
		var p : Dictionary = swarm_parameters[swarm_index]
		var start_index : int = int(p["start"])
		var count_value : int = int(p["count"])

		for i in range(start_index, start_index + count_value):
			ints[i] = swarm_index + 1 # Want swarm to start at 1 not 0

	var byte_size : int = ints.size() * 4
	boid_to_swarm_buffer = rd.storage_buffer_create(byte_size)
	rd.buffer_update(boid_to_swarm_buffer, 0, byte_size, ints.to_byte_array())


# ---------------------------------------------------------
# Global params buffer (currently only cell_size)
# ---------------------------------------------------------
func _allocate_global_params_buffer() -> void:
	var ints := PackedInt32Array()
	ints.resize(4)  # std140: one 16-byte slot
	ints[0] = int(grid_cell_size)

	var byte_size := ints.size() * 4  # 16 bytes
	global_params_buffer = rd.uniform_buffer_create(byte_size)
	rd.buffer_update(global_params_buffer, 0, byte_size, ints.to_byte_array())
	
	
# ---------------------------------------------------------
# Boid index and cell_id buffers used in calculating grids/neighbours
# ---------------------------------------------------------
func _allocate_boid_index_and_cell_id_buffers() -> void:
	
	if len(boid_indices) == 0 or len(cell_ids) == 0:
		push_error("boid_index_array or cell_id_array have zero length")
	
	if boid_indices.size() != total_boids:
		push_error("boid_index_array length mismatch")
		return

	if cell_ids.size() != total_boids:
		push_error("cell_id_array length mismatch")
		return
		
	if len(boid_indices) != len(sorted_boid_indices) and len(cell_ids) != len(sorted_cell_ids):
		push_error("array mismatch")
		return
	
	var boid_indices_bytes : PackedByteArray = boid_indices.to_byte_array()
	var bytes_size : int = boid_indices_bytes.size()  	#re use this variable since all these arrays are same size
	boid_indices_buffer = rd.storage_buffer_create(bytes_size)
	rd.buffer_update(boid_indices_buffer, 0, bytes_size, boid_indices_bytes)

	var sorted_indices_bytes : PackedByteArray = sorted_boid_indices.to_byte_array()
	sorted_boid_indices_buffer = rd.storage_buffer_create(bytes_size)
	rd.buffer_update(sorted_boid_indices_buffer, 0, bytes_size, sorted_indices_bytes)

	var cell_id_bytes : PackedByteArray = cell_ids.to_byte_array()
	cell_id_buffer = rd.storage_buffer_create(bytes_size)
	rd.buffer_update(cell_id_buffer, 0, bytes_size, cell_id_bytes)

	var sorted_cell_id_bytes : PackedByteArray = cell_ids.to_byte_array()
	sorted_cell_id_buffer = rd.storage_buffer_create(bytes_size)
	rd.buffer_update(sorted_cell_id_buffer, 0, bytes_size, sorted_cell_id_bytes)

# ---------------------------------------------------------
# Build RDUniform descriptors for all GPU buffers
# ---------------------------------------------------------
# Each descriptor:
#   - is stored as a class variable
#   - contains the correct binding index (global ABI)
#   - references the GPU buffer RID
#
# Compute passes will pull these descriptors and assemble
# their own uniform sets using the bindings defined here.
# ---------------------------------------------------------
func _build_uniform_descriptors() -> void:

	# ---------------------------------------------------------
	# Position buffers (SoA: x, y, z)
	# ---------------------------------------------------------
	u_pos_x = RDUniform.new()
	u_pos_x.binding = 0
	u_pos_x.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	u_pos_x.add_id(positions_x_buffer)

	u_pos_y = RDUniform.new()
	u_pos_y.binding = 1
	u_pos_y.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	u_pos_y.add_id(positions_y_buffer)

	u_pos_z = RDUniform.new()
	u_pos_z.binding = 2
	u_pos_z.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	u_pos_z.add_id(positions_z_buffer)


	# ---------------------------------------------------------
	# Velocity buffers (SoA: x, y, z)
	# ---------------------------------------------------------
	u_vel_x = RDUniform.new()
	u_vel_x.binding = 3
	u_vel_x.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	u_vel_x.add_id(velocities_x_buffer)

	u_vel_y = RDUniform.new()
	u_vel_y.binding = 4
	u_vel_y.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	u_vel_y.add_id(velocities_y_buffer)

	u_vel_z = RDUniform.new()
	u_vel_z.binding = 5
	u_vel_z.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	u_vel_z.add_id(velocities_z_buffer)


	# ---------------------------------------------------------
	# Swarm + global parameters
	# ---------------------------------------------------------
	u_swarm = RDUniform.new()
	u_swarm.binding = 6
	u_swarm.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	u_swarm.add_id(swarm_params_buffer)

	u_map = RDUniform.new()
	u_map.binding = 7
	u_map.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	u_map.add_id(boid_to_swarm_buffer)

	u_global = RDUniform.new()
	u_global.binding = 8
	u_global.uniform_type = RenderingDevice.UNIFORM_TYPE_UNIFORM_BUFFER
	u_global.add_id(global_params_buffer)


	# ---------------------------------------------------------
	# Grid + sorted grid buffers
	# ---------------------------------------------------------
	u_boid_index = RDUniform.new()
	u_boid_index.binding = 9
	u_boid_index.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	u_boid_index.add_id(boid_indices_buffer)

	u_sorted_boid_index = RDUniform.new()
	u_sorted_boid_index.binding = 10
	u_sorted_boid_index.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	u_sorted_boid_index.add_id(sorted_boid_indices_buffer)

	u_cell_id = RDUniform.new()
	u_cell_id.binding = 11
	u_cell_id.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	u_cell_id.add_id(cell_id_buffer)

	u_sorted_cell_id = RDUniform.new()
	u_sorted_cell_id.binding = 12
	u_sorted_cell_id.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	u_sorted_cell_id.add_id(sorted_cell_id_buffer)
