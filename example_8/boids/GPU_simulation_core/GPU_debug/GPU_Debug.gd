extends Node

var gpu_buffers

func _ready():
	gpu_buffers = get_node("../GPU_Buffers")


# ---------------------------------------------------------
# Read + print all GPU buffers
# ---------------------------------------------------------
func run():
	print("GPU_Debug: GPU → CPU readback")

	print_positions()
	print_velocities()
	print_swarm_params()
	print_boid_to_swarm()
	print_global_params()
	print_boid_index()
	print_cell_id()


# ---------------------------------------------------------
# Positions buffer (SoA: x, y, z)
# ---------------------------------------------------------
func print_positions():
	var x_bytes = gpu_buffers.rd.buffer_get_data(gpu_buffers.positions_x_buffer)
	var y_bytes = gpu_buffers.rd.buffer_get_data(gpu_buffers.positions_y_buffer)
	var z_bytes = gpu_buffers.rd.buffer_get_data(gpu_buffers.positions_z_buffer)

	var xs = x_bytes.to_float32_array()
	var ys = y_bytes.to_float32_array()
	var zs = z_bytes.to_float32_array()

	print("\n[Positions Buffer] (", xs.size(), " boids)")

	var limit = 10
	if xs.size() < 10:
		limit = xs.size()

	for i in range(limit):
		print("  Boid ", i, ": (", xs[i], ", ", ys[i], ", ", zs[i], ")")


# ---------------------------------------------------------
# Velocities buffer (SoA: x, y, z)
# ---------------------------------------------------------
func print_velocities():
	var x_bytes = gpu_buffers.rd.buffer_get_data(gpu_buffers.velocities_x_buffer)
	var y_bytes = gpu_buffers.rd.buffer_get_data(gpu_buffers.velocities_y_buffer)
	var z_bytes = gpu_buffers.rd.buffer_get_data(gpu_buffers.velocities_z_buffer)

	var xs = x_bytes.to_float32_array()
	var ys = y_bytes.to_float32_array()
	var zs = z_bytes.to_float32_array()

	print("\n[Velocities Buffer] (", xs.size(), " boids)")

	var limit = 10
	if xs.size() < 10:
		limit = xs.size()

	for i in range(limit):
		print("  Boid ", i, ": (", xs[i], ", ", ys[i], ", ", zs[i], ")")


# ---------------------------------------------------------
# Swarm parameters buffer
# ---------------------------------------------------------
func print_swarm_params():
	var byte_data = gpu_buffers.rd.buffer_get_data(gpu_buffers.swarm_params_buffer)
	var floats = byte_data.to_float32_array()

	print("\n[Swarm Params Buffer] (", gpu_buffers.swarm_count, " swarms)")

	var floats_per_swarm = 16

	for s in range(gpu_buffers.swarm_count):
		var base = s * floats_per_swarm

		print("\n  Swarm ", s)
		print("    start_index         = ", floats[base + 0])
		print("    count               = ", floats[base + 1])
		print("    sight_radius        = ", floats[base + 2])
		print("    FOV_angle_deg       = ", floats[base + 3])
		print("    cage_radius         = ", floats[base + 4])
		print("    desired_separation  = ", floats[base + 5])

		print("    alignment_weight    = ", floats[base + 6])
		print("    cohesion_weight     = ", floats[base + 7])
		print("    separation_weight   = ", floats[base + 8])
		print("    wander_strength     = ", floats[base + 9])
		print("    boundary_strength   = ", floats[base + 10])

		print("    alignment_mask      = ", floats[base + 11])
		print("    cohesion_mask       = ", floats[base + 12])
		print("    separation_mask     = ", floats[base + 13])
		print("    wander_mask         = ", floats[base + 14])
		print("    boundary_mask       = ", floats[base + 15])


# ---------------------------------------------------------
# Boid → Swarm mapping buffer
# ---------------------------------------------------------
func print_boid_to_swarm():
	var byte_data = gpu_buffers.rd.buffer_get_data(gpu_buffers.boid_to_swarm_buffer)
	var ints = byte_data.to_int32_array()

	print("\n[Boid → Swarm Buffer] (", ints.size(), " entries)")

	var step = 50
	if ints.size() < 50:
		step = ints.size()

	for i in range(0, ints.size(), step):
		print("  Boid ", i, " → Swarm ", ints[i])


# ---------------------------------------------------------
# Global params buffer
# ---------------------------------------------------------
func print_global_params():
	var byte_data = gpu_buffers.rd.buffer_get_data(gpu_buffers.global_params_buffer)
	var floats = byte_data.to_float32_array()

	print("\n[Global Params Buffer]")
	print("  grid_cell_size = ", floats[0])


# ---------------------------------------------------------
# Boid indices buffers (regular and sorted)
# ---------------------------------------------------------
func print_boid_index():
	var byte_data = gpu_buffers.rd.buffer_get_data(gpu_buffers.boid_indices_buffer)
	var ints = byte_data.to_int32_array()

	print("\n[Boid Index Buffer (unsorted)]")
	print(ints)

	var sorted_byte_data = gpu_buffers.rd.buffer_get_data(gpu_buffers.sorted_boid_indices_buffer)
	var ints_sorted = sorted_byte_data.to_int32_array()

	print("\n[Boid Index Buffer (sorted)]")
	print(ints_sorted)


# ---------------------------------------------------------
# Cell id buffers (regular and sorted)
# ---------------------------------------------------------
func print_cell_id():
	var byte_data = gpu_buffers.rd.buffer_get_data(gpu_buffers.cell_id_buffer)
	var ints = byte_data.to_int32_array()

	print("\n[Cell Id Buffer (unsorted)]")
	print(ints)

	var byte_data_sorted = gpu_buffers.rd.buffer_get_data(gpu_buffers.sorted_cell_id_buffer)
	var ints_sorted = byte_data_sorted.to_int32_array()

	print("\n[Cell Id Buffer (sorted)]")
	print(ints_sorted)
