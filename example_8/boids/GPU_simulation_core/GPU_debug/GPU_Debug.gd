extends Node

"""
GPU_Debug.gd
------------
Responsibilities:
 - Read back all GPU buffers into CPU arrays
 - Store them in class variables for other systems (SwarmDebug)
 - Optionally print debug info using a debug switch
"""

var gpu_buffers

# Toggle printing
@export var debug_print_enabled: bool = true


# ---------------------------------------------------------
# Stored CPU-side mirrors of GPU buffers
# ---------------------------------------------------------

var positions_x : PackedFloat32Array
var positions_y : PackedFloat32Array
var positions_z : PackedFloat32Array

var velocities_x : PackedFloat32Array
var velocities_y : PackedFloat32Array
var velocities_z : PackedFloat32Array

var swarm_params : PackedFloat32Array
var boid_to_swarm : PackedInt32Array

var global_params : Array

var boid_indices : PackedInt32Array
var sorted_boid_indices : PackedInt32Array

var cell_ids : PackedInt32Array
var sorted_cell_ids : PackedInt32Array

var cell_counts : PackedInt32Array
var cell_offsets : PackedInt32Array


func _ready() -> void:
	gpu_buffers = get_node("../GPU_Buffers")


# ---------------------------------------------------------
# PUBLIC ENTRY POINT — called once per frame
# ---------------------------------------------------------
func run() -> void:
	_read_positions()
	_read_velocities()
	_read_swarm_params()
	_read_boid_to_swarm()
	_read_global_params()
	_read_boid_indices()
	_read_cell_ids()
	_read_cell_counts_and_offsets()

	if debug_print_enabled:
		_print_all()


		


# ---------------------------------------------------------
# READBACK FUNCTIONS
# ---------------------------------------------------------

func _read_positions() -> void:
	var x_bytes : PackedByteArray = gpu_buffers.rd.buffer_get_data(gpu_buffers.positions_x_buffer)
	var y_bytes : PackedByteArray = gpu_buffers.rd.buffer_get_data(gpu_buffers.positions_y_buffer)
	var z_bytes : PackedByteArray = gpu_buffers.rd.buffer_get_data(gpu_buffers.positions_z_buffer)

	positions_x = x_bytes.to_float32_array()
	positions_y = y_bytes.to_float32_array()
	positions_z = z_bytes.to_float32_array()


func _read_velocities() -> void:
	var x_bytes : PackedByteArray = gpu_buffers.rd.buffer_get_data(gpu_buffers.velocities_x_buffer)
	var y_bytes : PackedByteArray = gpu_buffers.rd.buffer_get_data(gpu_buffers.velocities_y_buffer)
	var z_bytes : PackedByteArray = gpu_buffers.rd.buffer_get_data(gpu_buffers.velocities_z_buffer)

	velocities_x = x_bytes.to_float32_array()
	velocities_y = y_bytes.to_float32_array()
	velocities_z = z_bytes.to_float32_array()


func _read_swarm_params() -> void:
	var byte_data : PackedByteArray = gpu_buffers.rd.buffer_get_data(gpu_buffers.swarm_params_buffer)
	swarm_params = byte_data.to_float32_array()


func _read_boid_to_swarm() -> void:
	var byte_data : PackedByteArray = gpu_buffers.rd.buffer_get_data(gpu_buffers.boid_to_swarm_buffer)
	boid_to_swarm = byte_data.to_int32_array()


func _read_global_params() -> void:
	var bytes : PackedByteArray = gpu_buffers.rd.buffer_get_data(gpu_buffers.global_params_buffer)

	if bytes.size() < 32:
		print("WARNING: global_params_buffer too small: ", bytes.size(), " bytes (expected 32).")
		global_params = []
		return

	var cell_size = bytes.slice(0, 4).to_float32_array()[0]
	var ints = bytes.slice(4, 32).to_int32_array()

	global_params = [
		cell_size,      # 0
		ints[0],        # boid_count
		ints[1],        # grid_dim_x
		ints[2],        # grid_dim_y
		ints[3],        # grid_dim_z
		ints[4],        # pad0
		ints[5],        # pad1
		ints[6],        # pad2
	]


func _read_boid_indices() -> void:
	var byte_data : PackedByteArray = gpu_buffers.rd.buffer_get_data(gpu_buffers.boid_indices_buffer)
	boid_indices = byte_data.to_int32_array()

	var sorted_byte_data : PackedByteArray = gpu_buffers.rd.buffer_get_data(gpu_buffers.sorted_boid_indices_buffer)
	sorted_boid_indices = sorted_byte_data.to_int32_array()


func _read_cell_ids() -> void:
	var byte_data : PackedByteArray = gpu_buffers.rd.buffer_get_data(gpu_buffers.cell_id_buffer)
	cell_ids = byte_data.to_int32_array()

	var sorted_byte_data : PackedByteArray = gpu_buffers.rd.buffer_get_data(gpu_buffers.sorted_cell_id_buffer)
	sorted_cell_ids = sorted_byte_data.to_int32_array()


func _read_cell_counts_and_offsets() -> void:
	var counts_bytes : PackedByteArray = gpu_buffers.rd.buffer_get_data(gpu_buffers.cell_counts_buffer)
	cell_counts = counts_bytes.to_int32_array()

	var offsets_bytes : PackedByteArray = gpu_buffers.rd.buffer_get_data(gpu_buffers.cell_offsets_buffer)
	cell_offsets = offsets_bytes.to_int32_array()


# ---------------------------------------------------------
# PRINT HELPERS (only run if debug_print_enabled)
# ---------------------------------------------------------

func _print_all() -> void:
	print("\nGPU_Debug: GPU → CPU readback")

	#_print_positions()
	#_print_velocities()
	#_print_swarm_params()
	#_print_boid_to_swarm()
	_print_global_params()
	_print_boid_indices()
	_print_cell_ids()
	_print_cell_counts_and_offsets()


func _print_positions() -> void:
	print("\n[Positions Buffer] (", positions_x.size(), " boids)")
	var limit : int = min(10, positions_x.size())
	for i in range(limit):
		print("  Boid ", i, ": (", positions_x[i], ", ", positions_y[i], ", ", positions_z[i], ")")
	


func _print_velocities() -> void:
	print("\n[Velocities Buffer] (", velocities_x.size(), " boids)")
	var limit : int = min(10, velocities_x.size())
	for i in range(limit):
		print("  Vel ", i, ": (", velocities_x[i], ", ", velocities_y[i], ", ", velocities_z[i], ")")


func _print_swarm_params() -> void:
	print("\n[Swarm Params Buffer] (", gpu_buffers.swarm_count, " swarms)")
	var floats_per_swarm : int = 16

	for s in range(gpu_buffers.swarm_count):
		var base : int = s * floats_per_swarm

		print("\n  Swarm ", s)
		print("    start_index         = ", swarm_params[base + 0])
		print("    count               = ", swarm_params[base + 1])
		print("    sight_radius        = ", swarm_params[base + 2])
		print("    FOV_angle_deg       = ", swarm_params[base + 3])
		print("    cage_radius         = ", swarm_params[base + 4])
		print("    desired_separation  = ", swarm_params[base + 5])
		print("    alignment_weight    = ", swarm_params[base + 6])
		print("    cohesion_weight     = ", swarm_params[base + 7])
		print("    separation_weight   = ", swarm_params[base + 8])
		print("    wander_strength     = ", swarm_params[base + 9])
		print("    boundary_strength   = ", swarm_params[base + 10])
		print("    alignment_mask      = ", swarm_params[base + 11])
		print("    cohesion_mask       = ", swarm_params[base + 12])
		print("    separation_mask     = ", swarm_params[base + 13])
		print("    wander_mask         = ", swarm_params[base + 14])
		print("    boundary_mask       = ", swarm_params[base + 15])


func _print_boid_to_swarm() -> void:
	print("\n[Boid → Swarm Buffer] (", boid_to_swarm.size(), " entries)")
	var step : int = min(50, boid_to_swarm.size())
	for i in range(0, boid_to_swarm.size(), step):
		print("  Boid ", i, " → Swarm ", boid_to_swarm[i])


func _print_global_params() -> void:
	print("\n[Global Params Buffer]")

	if global_params.size() >= 8:
		print("  cell_size   = ", global_params[0])               # float
		print("  boid_count  = ", int(global_params[1]))         # int
		print("  grid_dim_x  = ", int(global_params[2]))         # int
		print("  grid_dim_y  = ", int(global_params[3]))         # int
		print("  grid_dim_z  = ", int(global_params[4]))         # int
		print("  pad0        = ", int(global_params[5]))         # int
		print("  pad1        = ", int(global_params[6]))         # int
		print("  pad2        = ", int(global_params[7]))         # int
		

func _print_boid_indices() -> void:
	print("\n[Boid Index Buffer (unsorted)]")
	print(boid_indices)

	print("\n[Boid Index Buffer (sorted)]")
	print(sorted_boid_indices)


func _print_cell_ids() -> void:
	print("\n[Cell Id Buffer (unsorted)]")
	print(cell_ids)

	print("\n[Cell Id Buffer (sorted)]")
	print(sorted_cell_ids)


func _print_cell_counts_and_offsets() -> void:
	print("\n[Cell Counts Buffer] (", cell_counts.size(), " cells)")
	var limit_counts : int = min(32, cell_counts.size())
	var sum_counts : int = 0
	for i in range(limit_counts):
		sum_counts += cell_counts[i]
		print("  cell_counts[", i, "] = ", cell_counts[i])
	print("  (partial sum of first ", limit_counts, " cells) = ", sum_counts)

	print("\n[Cell Offsets Buffer] (", cell_offsets.size(), " cells)")
	var limit_offsets : int = min(32, cell_offsets.size())
	for i in range(limit_offsets):
		print("  cell_offsets[", i, "] = ", cell_offsets[i])
