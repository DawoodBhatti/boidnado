extends Node

# ---------------------------------------------------------
# Init flag
# ---------------------------------------------------------
var is_initialised = false

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

var grid_cell_size : float 
var swarm_parameters : Array = []
var swarm_count : int 
var total_boids : int 

# NEW: grid dimensions (set externally from GPU_SimulationCore)
var grid_dim_x : int
var grid_dim_y : int
var grid_dim_z : int


# ---------------------------------------------------------
# GPU buffers (SoA layout) + density texture
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

var cell_counts_buffer : RID
var cell_offsets_buffer : RID
var cell_mapping_buffer : RID

var density_texture_3D : RID

# ---------------------------------------------------------
# RDUniform descriptors (one per buffer/texture)
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

var u_cell_counts : RDUniform
var u_cell_offsets : RDUniform
var u_cell_mapping : RDUniform

var u_density_image_3D : RDUniform  

func _ready() -> void:
	gpu_device = get_node("../GPU_Device")
	rd = gpu_device.rd
	is_initialised = true
	print("GPU_Buffers: initialised")


# ---------------------------------------------------------
# Build index + cell_id arrays on CPU
# ---------------------------------------------------------
func set_index_and_cell_ids() -> void:
	if total_boids == 0:
		push_error("set the global params first")
		return

	for i in range(total_boids):
		boid_indices.append(i)
		cell_ids.append(0)
		sorted_boid_indices.append(0)
		sorted_cell_ids.append(0)

# ---------------------------------------------------------
# Set positions (SoA)
# ---------------------------------------------------------
func set_positions_soa(pos_x : Array, pos_y : Array, pos_z : Array) -> void:
	initial_positions_x = pos_x
	initial_positions_y = pos_y
	initial_positions_z = pos_z

# ---------------------------------------------------------
# Set velocities (SoA)
# ---------------------------------------------------------
func set_velocities_soa(vel_x : Array, vel_y : Array, vel_z : Array) -> void:
	initial_velocities_x = vel_x
	initial_velocities_y = vel_y
	initial_velocities_z = vel_z

# ---------------------------------------------------------
# Set grid + swarm params
# ---------------------------------------------------------
func set_swarm_params(swarm_parameters_in : Array) -> void:
	swarm_parameters = swarm_parameters_in
	swarm_count = swarm_parameters_in.size()

	var total : int = 0
	for p in swarm_parameters:
		var count_value : int = int(p["count"])
		total = total + count_value
	
	if total != get_parent().total_boids:
		push_error("total count mismatch")
		
# ---------------------------------------------------------
# Set global parameters which include total boid count, grid cell size, dim_x, dim_y, dim_z (from GPU_SimulationCore)
# ---------------------------------------------------------
func set_global_params(total_boid_count, grid_size, dim_x : int, dim_y : int, dim_z : int) -> void:
	total_boids = total_boid_count
	grid_cell_size = grid_size
	grid_dim_x = dim_x
	grid_dim_y = dim_y
	grid_dim_z = dim_z
	
# ---------------------------------------------------------
# Provide a reference to the density texture already set in Renderer
# ---------------------------------------------------------
func set_density_texture(texture_ref :RID ) -> void:
	density_texture_3D = texture_ref

# ---------------------------------------------------------
# Validate inputs
# ---------------------------------------------------------
func _validate_inputs() -> void:
	assert(not initial_positions_x.is_empty(), "positions_x not supplied")
	assert(not initial_positions_y.is_empty(), "positions_y not supplied")
	assert(not initial_positions_z.is_empty(), "positions_z not supplied")

	assert(not initial_velocities_x.is_empty(), "velocities_x not supplied")
	assert(not initial_velocities_y.is_empty(), "velocities_y not supplied")
	assert(not initial_velocities_z.is_empty(), "velocities_z not supplied")

	assert(initial_positions_x.size() == total_boids, "positions_x length mismatch")
	assert(initial_positions_y.size() == total_boids, "positions_y length mismatch")
	assert(initial_positions_z.size() == total_boids, "positions_z length mismatch")

	assert(initial_velocities_x.size() == total_boids, "velocities_x length mismatch")
	assert(initial_velocities_y.size() == total_boids, "velocities_y length mismatch")
	assert(initial_velocities_z.size() == total_boids, "velocities_z length mismatch")

	assert(initial_positions_x.size() == initial_positions_y.size(), "position x/y mismatch")
	assert(initial_positions_y.size() == initial_positions_z.size(), "position y/z mismatch")

	assert(initial_velocities_x.size() == initial_velocities_y.size(), "velocity x/y mismatch")
	assert(initial_velocities_y.size() == initial_velocities_z.size(), "velocity y/z mismatch")

	assert(not swarm_parameters.is_empty(), "swarm parameters not supplied")
	assert(grid_cell_size > 0.0, "grid cell size invalid")

# ---------------------------------------------------------
# Build all GPU buffers
# ---------------------------------------------------------
func build_all_buffers(grid_cell_count) -> void:
	_validate_inputs()

	_allocate_position_buffers()
	_allocate_velocity_buffers()
	_allocate_swarm_params_buffer()
	_allocate_boid_to_swarm_buffer()
	_allocate_global_params_buffer()
	_allocate_boid_index_and_cell_id_buffers()
	_allocate_sorting_buffers(grid_cell_count)

	_build_uniform_descriptors()


# ---------------------------------------------------------
# Allocate velocity buffers
# ---------------------------------------------------------
func _allocate_velocity_buffers() -> void:
	var byte_count : int = total_boids * 4

	velocities_x_buffer = rd.storage_buffer_create(byte_count)
	velocities_y_buffer = rd.storage_buffer_create(byte_count)
	velocities_z_buffer = rd.storage_buffer_create(byte_count)

	var x_bytes : PackedByteArray = PackedFloat32Array(initial_velocities_x).to_byte_array()
	var y_bytes : PackedByteArray = PackedFloat32Array(initial_velocities_y).to_byte_array()
	var z_bytes : PackedByteArray = PackedFloat32Array(initial_velocities_z).to_byte_array()

	rd.buffer_update(velocities_x_buffer, 0, x_bytes.size(), x_bytes)
	rd.buffer_update(velocities_y_buffer, 0, y_bytes.size(), y_bytes)
	rd.buffer_update(velocities_z_buffer, 0, z_bytes.size(), z_bytes)

# ---------------------------------------------------------
# Allocate position buffers
# ---------------------------------------------------------
func _allocate_position_buffers() -> void:
	var byte_count : int = total_boids * 4

	positions_x_buffer = rd.storage_buffer_create(byte_count)
	positions_y_buffer = rd.storage_buffer_create(byte_count)
	positions_z_buffer = rd.storage_buffer_create(byte_count)

	var x_bytes : PackedByteArray = PackedFloat32Array(initial_positions_x).to_byte_array()
	var y_bytes : PackedByteArray = PackedFloat32Array(initial_positions_y).to_byte_array()
	var z_bytes : PackedByteArray = PackedFloat32Array(initial_positions_z).to_byte_array()

	rd.buffer_update(positions_x_buffer, 0, x_bytes.size(), x_bytes)
	rd.buffer_update(positions_y_buffer, 0, y_bytes.size(), y_bytes)
	rd.buffer_update(positions_z_buffer, 0, z_bytes.size(), z_bytes)

# ---------------------------------------------------------
# Allocate swarm params buffer (one struct per swarm)
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

		# Masks (explicit if/else)
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
			ints[i] = swarm_index + 1  # swarms start at 1

	var byte_size : int = ints.size() * 4
	boid_to_swarm_buffer = rd.storage_buffer_create(byte_size)
	rd.buffer_update(boid_to_swarm_buffer, 0, byte_size, ints.to_byte_array())

# ---------------------------------------------------------
# Global params buffer (cell_size + boid_count + grid dims)
# ---------------------------------------------------------
func _allocate_global_params_buffer() -> void:
	var bytes := PackedByteArray()

	# float cell_size
	bytes.append_array(PackedFloat32Array([grid_cell_size]).to_byte_array())

	# int boid_count
	bytes.append_array(PackedInt32Array([total_boids]).to_byte_array())

	# int grid_dim_x, grid_dim_y, grid_dim_z
	bytes.append_array(PackedInt32Array([grid_dim_x]).to_byte_array())
	bytes.append_array(PackedInt32Array([grid_dim_y]).to_byte_array())
	bytes.append_array(PackedInt32Array([grid_dim_z]).to_byte_array())

	# padding ints (pad0, pad1, pad2)
	bytes.append_array(PackedInt32Array([0, 0, 0]).to_byte_array())

	var byte_size := bytes.size()  # must be exactly 32
	global_params_buffer = rd.uniform_buffer_create(byte_size)
	rd.buffer_update(global_params_buffer, 0, byte_size, bytes)
	
	
# ---------------------------------------------------------
# Allocate boid index + cell_id buffers
# ---------------------------------------------------------
func _allocate_boid_index_and_cell_id_buffers() -> void:
	if boid_indices.size() != total_boids:
		push_error("boid_index_array length mismatch")
		return

	if cell_ids.size() != total_boids:
		push_error("cell_id_array length mismatch")
		return

	if sorted_boid_indices.size() != total_boids:
		push_error("sorted_boid_indices length mismatch")
		return

	if sorted_cell_ids.size() != total_boids:
		push_error("sorted_cell_ids length mismatch")
		return

	var boid_indices_bytes : PackedByteArray = boid_indices.to_byte_array()
	var byte_size : int = boid_indices_bytes.size()

	boid_indices_buffer = rd.storage_buffer_create(byte_size)
	rd.buffer_update(boid_indices_buffer, 0, byte_size, boid_indices_bytes)

	var sorted_indices_bytes : PackedByteArray = sorted_boid_indices.to_byte_array()
	sorted_boid_indices_buffer = rd.storage_buffer_create(byte_size)
	rd.buffer_update(sorted_boid_indices_buffer, 0, byte_size, sorted_indices_bytes)

	var cell_id_bytes : PackedByteArray = cell_ids.to_byte_array()
	cell_id_buffer = rd.storage_buffer_create(byte_size)
	rd.buffer_update(cell_id_buffer, 0, byte_size, cell_id_bytes)

	var sorted_cell_id_bytes : PackedByteArray = sorted_cell_ids.to_byte_array()
	sorted_cell_id_buffer = rd.storage_buffer_create(byte_size)
	rd.buffer_update(sorted_cell_id_buffer, 0, byte_size, sorted_cell_id_bytes)

# ---------------------------------------------------------
# Allocate cell_counts, cell_offsets buffers and cell_mapping
# used in the grid sorting and grid mapping pass
# ---------------------------------------------------------
func _allocate_sorting_buffers(grid_cell_count : int) -> void:

	var cell_count = grid_cell_count
	if cell_count <= 0:
		push_error("grid_cell_count must be > 0 before building buffers")
		return

	var byte_size : int = cell_count * 4  # int32 per cell

	# Counts (histogram)
	cell_counts_buffer = rd.storage_buffer_create(byte_size)
	var zero_counts := PackedInt32Array()
	zero_counts.resize(cell_count)
	rd.buffer_update(cell_counts_buffer, 0, byte_size, zero_counts.to_byte_array())

	# Offsets (prefix sum)
	cell_offsets_buffer = rd.storage_buffer_create(byte_size)
	var zero_offsets := PackedInt32Array()
	zero_offsets.resize(cell_count)
	rd.buffer_update(cell_offsets_buffer, 0, byte_size, zero_offsets.to_byte_array())

	# Cell mapping (ivec2 per cell → 8 bytes per cell)
	var mapping_byte_size : int = cell_count * 2 * 4  # 2 ints per cell
	cell_mapping_buffer = rd.storage_buffer_create(mapping_byte_size)
	var zero_vec := PackedInt32Array()
	zero_vec.resize(cell_count * 2)  # two ints per cell
	rd.buffer_update(cell_mapping_buffer, 0, mapping_byte_size, zero_vec.to_byte_array())


# ---------------------------------------------------------
# Build RDUniform descriptors for all GPU buffers/textures/etc
# ---------------------------------------------------------
func _build_uniform_descriptors() -> void:

	# ---------------------------------------------------------
	# Position buffers
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
	# Velocity buffers
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
	# Swarm + global params
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

	# ---------------------------------------------------------
	# cell_counts, cell_offsets and cell_mapping
	# ---------------------------------------------------------
	u_cell_counts = RDUniform.new()
	u_cell_counts.binding = 13
	u_cell_counts.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	u_cell_counts.add_id(cell_counts_buffer)

	u_cell_offsets = RDUniform.new()
	u_cell_offsets.binding = 14
	u_cell_offsets.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	u_cell_offsets.add_id(cell_offsets_buffer)

	u_cell_mapping = RDUniform.new()
	u_cell_mapping.binding = 15
	u_cell_mapping.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	u_cell_mapping.add_id(cell_mapping_buffer)
	
	# ---------------------------------------------------------
	# density image
	# ---------------------------------------------------------
	
	u_density_image_3D = RDUniform.new()
	u_density_image_3D.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	u_density_image_3D.binding = 16
	u_density_image_3D.add_id(density_texture_3D)
