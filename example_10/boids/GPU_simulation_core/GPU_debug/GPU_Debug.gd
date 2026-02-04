extends Node

@export var debug_print_enabled: bool = true

var gpu_buffers: Node
var renderer: Node


func _ready() -> void:
	gpu_buffers = get_node("../GPU_Buffers")


func run() -> void:
	if not debug_print_enabled:
		return
		
	print(" -------------- Debug Start --------------  ")

	#_print_positions()
	#_print_velocities()
	#_print_swarm_params()
	#_print_boid_to_swarm()
	_print_global_params()
	_print_boid_indices()
	_print_cell_ids()

	_print_cell_counts_slice(0, 13824)
	_print_cell_offsets_slice(0, 13824)
	_print_cell_mappings_slice(0, 13824)

	print(" -------------- Debug End --------------  ")
	print()

# ---------------------------------------------------------
# POSITIONS / VELOCITIES
# ---------------------------------------------------------

func _print_positions() -> void:
	var x_bytes: PackedByteArray = gpu_buffers.rd.buffer_get_data(gpu_buffers.positions_x_buffer)
	var y_bytes: PackedByteArray = gpu_buffers.rd.buffer_get_data(gpu_buffers.positions_y_buffer)
	var z_bytes: PackedByteArray = gpu_buffers.rd.buffer_get_data(gpu_buffers.positions_z_buffer)

	var x: PackedFloat32Array = x_bytes.to_float32_array()
	var y: PackedFloat32Array = y_bytes.to_float32_array()
	var z: PackedFloat32Array = z_bytes.to_float32_array()

	print("\n[Positions Buffer] (", x.size(), " boids)")
	var limit: int = min(10, x.size())
	for i: int in range(limit):
		print("  Boid ", i, ": (", x[i], ", ", y[i], ", ", z[i], ")")


func _print_velocities() -> void:
	var x_bytes: PackedByteArray = gpu_buffers.rd.buffer_get_data(gpu_buffers.velocities_x_buffer)
	var y_bytes: PackedByteArray = gpu_buffers.rd.buffer_get_data(gpu_buffers.velocities_y_buffer)
	var z_bytes: PackedByteArray = gpu_buffers.rd.buffer_get_data(gpu_buffers.velocities_z_buffer)

	var x: PackedFloat32Array = x_bytes.to_float32_array()
	var y: PackedFloat32Array = y_bytes.to_float32_array()
	var z: PackedFloat32Array = z_bytes.to_float32_array()

	print("\n[Velocities Buffer] (", x.size(), " boids)")
	var limit: int = min(10, x.size())
	for i: int in range(limit):
		print("  Vel ", i, ": (", x[i], ", ", y[i], ", ", z[i], ")")


# ---------------------------------------------------------
# SWARM PARAMS / BOID→SWARM / GLOBAL PARAMS
# ---------------------------------------------------------

func _print_swarm_params() -> void:
	var bytes: PackedByteArray = gpu_buffers.rd.buffer_get_data(gpu_buffers.swarm_params_buffer)
	var data: PackedFloat32Array = bytes.to_float32_array()

	var swarm_count: int = gpu_buffers.swarm_count
	var floats_per_swarm: int = 16

	print("\n[Swarm Params Buffer] (", swarm_count, " swarms)")

	for s: int in range(swarm_count):
		var base: int = s * floats_per_swarm

		print("\n  Swarm ", s)
		print("    start_index         = ", data[base + 0])
		print("    count               = ", data[base + 1])
		print("    sight_radius        = ", data[base + 2])
		print("    FOV_angle_deg       = ", data[base + 3])
		print("    cage_radius         = ", data[base + 4])
		print("    desired_separation  = ", data[base + 5])
		print("    alignment_weight    = ", data[base + 6])
		print("    cohesion_weight     = ", data[base + 7])
		print("    separation_weight   = ", data[base + 8])
		print("    wander_strength     = ", data[base + 9])
		print("    boundary_strength   = ", data[base + 10])
		print("    alignment_mask      = ", data[base + 11])
		print("    cohesion_mask       = ", data[base + 12])
		print("    separation_mask     = ", data[base + 13])
		print("    wander_mask         = ", data[base + 14])
		print("    boundary_mask       = ", data[base + 15])


func _print_boid_to_swarm() -> void:
	var bytes: PackedByteArray = gpu_buffers.rd.buffer_get_data(gpu_buffers.boid_to_swarm_buffer)
	var arr: PackedInt32Array = bytes.to_int32_array()

	print("\n[Boid → Swarm Buffer] (", arr.size(), " entries)")
	var step: int = min(50, arr.size())
	for i: int in range(0, arr.size(), step):
		print("  Boid ", i, " → Swarm ", arr[i])


func _print_global_params() -> void:
	var bytes: PackedByteArray = gpu_buffers.rd.buffer_get_data(gpu_buffers.global_params_buffer)

	print("\n[Global Params Buffer]")

	if bytes.size() < 32:
		print("  WARNING: global_params_buffer too small: ", bytes.size(), " bytes (expected 32).")
		return

	var cell_size: float = bytes.slice(0, 4).to_float32_array()[0]
	var ints: PackedInt32Array = bytes.slice(4, 32).to_int32_array()

	print("  cell_size   = ", cell_size)
	print("  boid_count  = ", ints[0])
	print("  grid_dim_x  = ", ints[1])
	print("  grid_dim_y  = ", ints[2])
	print("  grid_dim_z  = ", ints[3])
	print("  pad0        = ", ints[4])
	print("  pad1        = ", ints[5])
	print("  pad2        = ", ints[6])


# ---------------------------------------------------------
# INDICES / CELL IDS
# ---------------------------------------------------------

func _print_boid_indices() -> void:
	var unsorted_bytes: PackedByteArray = gpu_buffers.rd.buffer_get_data(gpu_buffers.boid_indices_buffer)
	var sorted_bytes: PackedByteArray = gpu_buffers.rd.buffer_get_data(gpu_buffers.sorted_boid_indices_buffer)

	var unsorted: PackedInt32Array = unsorted_bytes.to_int32_array()
	var sorted: PackedInt32Array = sorted_bytes.to_int32_array()

	print("\n[Boid Index Buffer (unsorted)]")
	print(unsorted)

	print("\n[Boid Index Buffer (sorted)]")
	print(sorted)


func _print_cell_ids() -> void:
	var unsorted_bytes: PackedByteArray = gpu_buffers.rd.buffer_get_data(gpu_buffers.cell_id_buffer)
	var sorted_bytes: PackedByteArray = gpu_buffers.rd.buffer_get_data(gpu_buffers.sorted_cell_id_buffer)

	var unsorted: PackedInt32Array = unsorted_bytes.to_int32_array()
	var sorted: PackedInt32Array = sorted_bytes.to_int32_array()

	print("\n[Cell Id Buffer (unsorted)]")
	print(unsorted)

	print("\n[Cell Id Buffer (sorted)]")
	print(sorted)


# ---------------------------------------------------------
# CELL COUNTS / OFFSETS / MAPPINGS (SLICE VERSIONS)
# ---------------------------------------------------------

func _print_cell_counts_slice(start_index: int, end_index: int) -> void:
	var bytes: PackedByteArray = gpu_buffers.rd.buffer_get_data(gpu_buffers.cell_counts_buffer)
	var counts: PackedInt32Array = bytes.to_int32_array()

	start_index = clamp(start_index, 0, counts.size())
	end_index = clamp(end_index, 0, counts.size())

	if end_index <= start_index:
		print("\n[Cell Counts] Invalid slice: ", start_index, " to ", end_index)
		return

	print("\n[Cell Counts Buffer] (", counts.size(), " cells)")
	print("Slice: ", start_index, " → ", end_index, "  (length: ", end_index - start_index, ")")

	var sum_counts: int = 0

	for i: int in range(start_index, end_index):
		var v: int = counts[i]
		sum_counts += v
		if v != 0:
			print("  cell_counts[", i, "] = ", v)

	print("  Slice sum = ", sum_counts)


func _print_cell_offsets_slice(start_index: int, end_index: int) -> void:
	var bytes: PackedByteArray = gpu_buffers.rd.buffer_get_data(gpu_buffers.cell_offsets_buffer)
	var offsets: PackedInt32Array = bytes.to_int32_array()

	start_index = clamp(start_index, 0, offsets.size())
	end_index = clamp(end_index, 0, offsets.size())

	if end_index <= start_index:
		print("\n[Cell Offsets] Invalid slice: ", start_index, " to ", end_index)
		return

	print("\n[Cell Offsets Buffer] (", offsets.size(), " cells)")
	print("Slice: ", start_index, " → ", end_index, "  (length: ", end_index - start_index, ")")

	var sum_offsets: int = 0

	for i: int in range(start_index, end_index):
		var v: int = offsets[i]
		sum_offsets += v
		if v != 0:
			print("  cell_offsets[", i, "] = ", v)

	print("  Slice sum = ", sum_offsets)


func _print_cell_mappings_slice(start_index: int, end_index: int) -> void:
	var bytes: PackedByteArray = gpu_buffers.rd.buffer_get_data(gpu_buffers.cell_mapping_buffer)
	var mapping: PackedInt32Array = bytes.to_int32_array()

	var cell_count: int = mapping.size() / 2

	start_index = clamp(start_index, 0, cell_count)
	end_index = clamp(end_index, 0, cell_count)

	if end_index <= start_index:
		print("\n[Cell Mappings] Invalid slice: ", start_index, " to ", end_index)
		return

	print("\n[Cell Mappings Buffer] (", cell_count, " cells)")
	print("Slice: ", start_index, " → ", end_index, "  (length: ", end_index - start_index, ")")

	var total_length: int = 0

	for i: int in range(start_index, end_index):
		var start_val: int = mapping[i * 2 + 0]
		var end_val: int = mapping[i * 2 + 1]
		var length: int = end_val - start_val

		total_length += length

		if length != 0:
			print("  cell_mappings[", i, "]  start=", start_val, ", end=", end_val, ", len=", length)

	print("  Slice total length = ", total_length)
