extends Node

# ---------------------------------------------------------
# References
# ---------------------------------------------------------
var gpu_device : Node
var rd : RenderingDevice

# ---------------------------------------------------------
# CPU-side cached data
# ---------------------------------------------------------
var initial_positions : Array = []
var initial_velocities : Array = []
var boid_indices : PackedInt32Array = []
var cell_ids : PackedInt32Array = []
var sorted_boid_indices : PackedInt32Array = []
var sorted_cell_ids : PackedInt32Array = []
var grid_cell_size : float = 0.0
var swarm_parameters : Array  = []
var swarm_count : int = 0
var total_boids : int = 0

# ---------------------------------------------------------
# GPU buffers
# ---------------------------------------------------------
var positions_buffer : RID
var velocities_buffer : RID
var swarm_params_buffer : RID
var boid_to_swarm_buffer : RID
var global_params_buffer : RID
var boid_indices_buffer : RID
var sorted_boid_indices_buffer : RID
var cell_id_buffer : RID
var sorted_cell_id_buffer : RID


# Uniform set RID
var uniform_set_rid : RID


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
# Set per-boid data (positions, velocities)
# ---------------------------------------------------------
func set_positions(positions : Array) -> void:
	initial_positions = positions


func set_velocities(velocities : Array) -> void:
	initial_velocities = velocities


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


# ---------------------------------------------------------
# Build all buffers and uniform 
# ---------------------------------------------------------
func build_all_buffers():

	if len(initial_positions) == 0 or len(initial_velocities) == 0:
		push_error("positions or velocity array not supplied")
		return
	elif len(initial_positions) != total_boids or len(initial_velocities) != total_boids:
		push_error("length of positions or velocities do not match total boid count")
		return
	elif len(initial_positions) != len(initial_velocities):
		push_error("length of positions mismatch with length of array")
		return
	elif len(swarm_parameters) == 0:
		push_error("paramaters not supplied")
		return
	elif grid_cell_size <= 0:
		push_error("grid cell size not specified correctly")
		return

	_allocate_boid_buffers()
	_allocate_swarm_params_buffer()
	_allocate_boid_to_swarm_buffer()
	_allocate_global_params_buffer()
	_allocate_boid_index_and_cell_id_buffers()

	_create_uniform_set()


# ---------------------------------------------------------
# Allocate positions + velocities buffers
# ---------------------------------------------------------
func _allocate_boid_buffers() -> void:
	# Each boid has a Vector3 (3 floats = 12 bytes)
	var pos_byte_count : int = total_boids * 3 * 4
	var vel_byte_count : int = total_boids * 3 * 4

	positions_buffer = rd.storage_buffer_create(pos_byte_count)
	velocities_buffer = rd.storage_buffer_create(vel_byte_count)


	# Flatten positions into a PackedByteArray
	var pos_data : PackedByteArray = PackedVector3Array(initial_positions).to_byte_array()
	rd.buffer_update(positions_buffer, 0, pos_data.size(), pos_data)


	# Flatten velocities into a PackedByteArray
	var vel_data : PackedByteArray = PackedVector3Array(initial_velocities).to_byte_array()
	rd.buffer_update(velocities_buffer, 0, vel_data.size(), vel_data)
	
	
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
	var floats : PackedFloat32Array = PackedFloat32Array()
	floats.append(grid_cell_size)

	var byte_size : int = floats.size() * 4
	global_params_buffer = rd.storage_buffer_create(byte_size)
	rd.buffer_update(global_params_buffer, 0, byte_size, floats.to_byte_array())


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
# Create the uniform set (assign buffers to bindings)
# which contains inputs, outputs and constants
# ---------------------------------------------------------
func _create_uniform_set() -> void:
	# Binding 0 → positions buffer
	var u_pos : RDUniform = RDUniform.new()
	u_pos.binding = 0
	u_pos.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	u_pos.add_id(positions_buffer)

	# Binding 1 → velocities buffer
	var u_vel : RDUniform = RDUniform.new()
	u_vel.binding = 1
	u_vel.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	u_vel.add_id(velocities_buffer)

	# Binding 2 → swarm parameters for values common within swarms
	var u_swarm : RDUniform = RDUniform.new()
	u_swarm.binding = 2
	u_swarm.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	u_swarm.add_id(swarm_params_buffer)

	# Binding 3 → boid global index to swarm conversion buffer 
	var u_map : RDUniform = RDUniform.new()
	u_map.binding = 3
	u_map.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	u_map.add_id(boid_to_swarm_buffer)

	# Binding 4 → global parameters buffer for values common between swarms
	var u_global : RDUniform = RDUniform.new()
	u_global.binding = 4
	u_global.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	u_global.add_id(global_params_buffer)
	
	
	# Binding 5 → index ids used to create grid and allow efficient neighbour mapping
	var u_boid_index: RDUniform = RDUniform.new()
	u_boid_index.binding = 5
	u_boid_index.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	u_boid_index.add_id(boid_indices_buffer)
	
	# Binding 6 → sorted index ids used to create grid and allow efficient neighbour mapping
	var u_sorted_boid_index: RDUniform = RDUniform.new()
	u_sorted_boid_index.binding = 6
	u_sorted_boid_index.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	u_sorted_boid_index.add_id(sorted_boid_indices_buffer)

	# Binding 7 → cell_ids used to create grid and allow efficient neighbour mapping
	var u_cell_id : RDUniform = RDUniform.new()
	u_cell_id.binding = 7
	u_cell_id.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	u_cell_id.add_id(cell_id_buffer)
	
	# Binding 8 → sorted cell_ids used to create grid and allow efficient neighbour mapping
	var u_sorted_cell_id : RDUniform = RDUniform.new()
	u_sorted_cell_id.binding = 8
	u_sorted_cell_id.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	u_sorted_cell_id.add_id(sorted_cell_id_buffer)
	

	# Create the uniform set using which is a register created that maps which bindings connect to the buffers we have allocated
	# It is a requirement of Godot by Vulkan
	uniform_set_rid = rd.uniform_set_create(
		[u_pos, u_vel, u_swarm, u_map, u_global, u_boid_index, u_cell_id],
		gpu_device.test_shader_rid,
		0
	)
