extends Node

var rd: RenderingDevice
var total_boid_count: int = 0

var positions_buffer: RID
var velocities_buffer: RID
var swarm_id_buffer: RID

var cell_ids_buffer: RID
var sorted_indices_buffer: RID
var cell_start_buffer: RID
var cell_end_buffer: RID

func setup(p_rd: RenderingDevice) -> void:
	rd = p_rd

func allocate(count: int, grid_dims: PackedInt32Array) -> void:
	total_boid_count = count

	var vec4_size: int = 16
	var int_size: int = 4

	# Per-boid buffers
	positions_buffer = rd.storage_buffer_create(count * vec4_size)
	velocities_buffer = rd.storage_buffer_create(count * vec4_size)
	swarm_id_buffer = rd.storage_buffer_create(count * int_size)
	cell_ids_buffer = rd.storage_buffer_create(count * int_size)
	sorted_indices_buffer = rd.storage_buffer_create(count * int_size)

	# Per-cell buffers
	var grid_x: int = grid_dims[0]
	var grid_y: int = grid_dims[1]
	var grid_z: int = grid_dims[2]

	var max_cells: int = grid_x * grid_y * grid_z

	cell_start_buffer = rd.storage_buffer_create(max_cells * int_size)
	cell_end_buffer = rd.storage_buffer_create(max_cells * int_size)

func get_positions() -> RID:
	return positions_buffer

func get_velocities() -> RID:
	return velocities_buffer

func get_swarm_ids() -> RID:
	return swarm_id_buffer

func get_cell_ids() -> RID:
	return cell_ids_buffer

func get_sorted_indices() -> RID:
	return sorted_indices_buffer

func get_cell_start() -> RID:
	return cell_start_buffer

func get_cell_end() -> RID:
	return cell_end_buffer
