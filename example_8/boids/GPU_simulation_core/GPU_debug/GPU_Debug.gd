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
@export var debug_print_enabled: bool = false


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

var global_params : PackedFloat32Array

var boid_indices : PackedInt32Array
var sorted_boid_indices : PackedInt32Array

var cell_ids : PackedInt32Array
var sorted_cell_ids : PackedInt32Array


func _ready():
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

	if debug_print_enabled:
		_print_all()


# ---------------------------------------------------------
# READBACK FUNCTIONS
# ---------------------------------------------------------

func _read_positions():
	var x_bytes = gpu_buffers.rd.buffer_get_data(gpu_buffers.positions_x_buffer)
	var y_bytes = gpu_buffers.rd.buffer_get_data(gpu_buffers.positions_y_buffer)
	var z_bytes = gpu_buffers.rd.buffer_get_data(gpu_buffers.positions_z_buffer)

	positions_x = x_bytes.to_float32_array()
	positions_y = y_bytes.to_float32_array()
	positions_z = z_bytes.to_float32_array()


func _read_velocities():
	var x_bytes = gpu_buffers.rd.buffer_get_data(gpu_buffers.velocities_x_buffer)
	var y_bytes = gpu_buffers.rd.buffer_get_data(gpu_buffers.velocities_y_buffer)
	var z_bytes = gpu_buffers.rd.buffer_get_data(gpu_buffers.velocities_z_buffer)

	velocities_x = x_bytes.to_float32_array()
	velocities_y = y_bytes.to_float32_array()
	velocities_z = z_bytes.to_float32_array()


func _read_swarm_params():
	var byte_data = gpu_buffers.rd.buffer_get_data(gpu_buffers.swarm_params_buffer)
	swarm_params = byte_data.to_float32_array()


func _read_boid_to_swarm():
	var byte_data = gpu_buffers.rd.buffer_get_data(gpu_buffers.boid_to_swarm_buffer)
	boid_to_swarm = byte_data.to_int32_array()


func _read_global_params():
	var byte_data = gpu_buffers.rd.buffer_get_data(gpu_buffers.global_params_buffer)
	global_params = byte_data.to_float32_array()


func _read_boid_indices():
	var byte_data = gpu_buffers.rd.buffer_get_data(gpu_buffers.boid_indices_buffer)
	boid_indices = byte_data.to_int32_array()

	var sorted_byte_data = gpu_buffers.rd.buffer_get_data(gpu_buffers.sorted_boid_indices_buffer)
	sorted_boid_indices = sorted_byte_data.to_int32_array()


func _read_cell_ids():
	var byte_data = gpu_buffers.rd.buffer_get_data(gpu_buffers.cell_id_buffer)
	cell_ids = byte_data.to_int32_array()

	var sorted_byte_data = gpu_buffers.rd.buffer_get_data(gpu_buffers.sorted_cell_id_buffer)
	sorted_cell_ids = sorted_byte_data.to_int32_array()


# ---------------------------------------------------------
# PRINT HELPERS (only run if debug_print_enabled)
# ---------------------------------------------------------

func _print_all():
	print("\nGPU_Debug: GPU → CPU readback")

	_print_positions()
	_print_velocities()
	_print_swarm_params()
	_print_boid_to_swarm()
	_print_global_params()
	_print_boid_indices()
	_print_cell_ids()


func _print_positions():
	print("\n[Positions Buffer] (", positions_x.size(), " boids)")
	var limit = min(10, positions_x.size())
	for i in range(limit):
		print("  Boid ", i, ": (", positions_x[i], ", ", positions_y[i], ", ", positions_z[i], ")")


func _print_velocities():
	print("\n[Velocities Buffer] (", velocities_x.size(), " boids)")
	var limit = min(10, velocities_x.size())
	for i in range(limit):
		print("  Vel ", i, ": (", velocities_x[i], ", ", velocities_y[i], ", ", velocities_z[i], ")")


func _print_swarm_params():
	print("\n[Swarm Params Buffer] (", gpu_buffers.swarm_count, " swarms)")
	var floats_per_swarm = 16

	for s in range(gpu_buffers.swarm_count):
		var base = s * floats_per_swarm

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


func _print_boid_to_swarm():
	print("\n[Boid → Swarm Buffer] (", boid_to_swarm.size(), " entries)")
	var step = min(50, boid_to_swarm.size())
	for i in range(0, boid_to_swarm.size(), step):
		print("  Boid ", i, " → Swarm ", boid_to_swarm[i])


func _print_global_params():
	print("\n[Global Params Buffer]")
	print("  grid_cell_size = ", global_params[0])


func _print_boid_indices():
	print("\n[Boid Index Buffer (unsorted)]")
	print(boid_indices)

	print("\n[Boid Index Buffer (sorted)]")
	print(sorted_boid_indices)


func _print_cell_ids():
	print("\n[Cell Id Buffer (unsorted)]")
	print(cell_ids)

	print("\n[Cell Id Buffer (sorted)]")
	print(sorted_cell_ids)
