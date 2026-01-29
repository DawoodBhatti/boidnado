extends Node

var gpu_buffers : Node


func _ready() -> void:
	gpu_buffers = get_node("../GPU_Buffers")


# ---------------------------------------------------------
# Read + print all GPU buffers
# ---------------------------------------------------------
func run() -> void:
	print("GPU_Debug: GPU → CPU readback")
	
	# Ensure GPU has finished all compute work
	
	print_positions()
	print_velocities()
	print_swarm_params()
	print_boid_to_swarm()
	print_global_params()
	print_boid_index()
	print_cell_id()

# ---------------------------------------------------------
# Positions buffer
# ---------------------------------------------------------
func print_positions() -> void:
	var byte_data : PackedByteArray = gpu_buffers.rd.buffer_get_data(gpu_buffers.positions_buffer)
	var floats : PackedFloat32Array = byte_data.to_float32_array()

	print("\n[Positions Buffer] (", floats.size() / 3, " boids)")
	
	for i in range(0, 10, 3):
	#for i in range(0, floats.size(), 3):
		var x : float = floats[i]
		var y : float = floats[i + 1]
		var z : float = floats[i + 2]
		print("  Boid ", i / 3, ": (", x, ", ", y, ", ", z, ")")



# ---------------------------------------------------------
# Velocities buffer
# ---------------------------------------------------------
func print_velocities() -> void:
	var byte_data : PackedByteArray = gpu_buffers.rd.buffer_get_data(gpu_buffers.velocities_buffer)
	var floats : PackedFloat32Array = byte_data.to_float32_array()

	print("\n[Velocities Buffer] (", floats.size() / 3, " boids)")

	for i in range(0, 10, 3):
	#for i in range(0, floats.size(), 3):
		var x : float = floats[i]
		var y : float = floats[i + 1]
		var z : float = floats[i + 2]
		print("  Boid ", i / 3, ": (", x, ", ", y, ", ", z, ")")



# ---------------------------------------------------------
# Swarm parameters buffer
# ---------------------------------------------------------
func print_swarm_params() -> void:
	var byte_data : PackedByteArray = gpu_buffers.rd.buffer_get_data(gpu_buffers.swarm_params_buffer)
	var floats : PackedFloat32Array = byte_data.to_float32_array()

	print("\n[Swarm Params Buffer] (", gpu_buffers.swarm_count, " swarms)")

	# Each swarm has 16 floats (based on your struct)
	var floats_per_swarm : int = 16

	for s in range(gpu_buffers.swarm_count):
		var base : int = s * floats_per_swarm

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
func print_boid_to_swarm() -> void:
	var byte_data : PackedByteArray = gpu_buffers.rd.buffer_get_data(gpu_buffers.boid_to_swarm_buffer)
	var ints : PackedInt32Array = byte_data.to_int32_array()

	print("\n[Boid → Swarm Buffer] (", ints.size(), " entries)")
	
	for i in range(0, ints.size(), 50):
	#for i in range(ints.size()):
		print("  Boid ", i, " → Swarm ", ints[i])



# ---------------------------------------------------------
# Global params buffer
# ---------------------------------------------------------
func print_global_params() -> void:
	var byte_data : PackedByteArray = gpu_buffers.rd.buffer_get_data(gpu_buffers.global_params_buffer)
	var floats : PackedFloat32Array = byte_data.to_float32_array()

	print("\n[Global Params Buffer]")
	print("  grid_cell_size = ", floats[0])



# ---------------------------------------------------------
# Boid indices buffers (regular and sorted)
# ---------------------------------------------------------
func print_boid_index() -> void:
	var byte_data : PackedByteArray = gpu_buffers.rd.buffer_get_data(gpu_buffers.boid_indices_buffer)
	var ints : PackedInt32Array = byte_data.to_int32_array()

	print("\n[Boid Index Buffer (unsorted)]")
	print(ints)
	
	var sorted_byte_data : PackedByteArray = gpu_buffers.rd.buffer_get_data(gpu_buffers.sorted_boid_indices_buffer)
	var ints_sorted : PackedInt32Array = sorted_byte_data.to_int32_array()

	print("\n[Boid Index Buffer (sorted)]")
	print(ints_sorted)
	
	
	
# ---------------------------------------------------------
# Cell id buffers (regular and sorted)
# ---------------------------------------------------------
func print_cell_id() -> void:
	var byte_data : PackedByteArray = gpu_buffers.rd.buffer_get_data(gpu_buffers.cell_id_buffer)
	var ints : PackedInt32Array = byte_data.to_int32_array()

	print("\n[Cell Id Buffer (unsorted)]")
	print(ints)
	
	var byte_data_sorted : PackedByteArray = gpu_buffers.rd.buffer_get_data(gpu_buffers.sorted_cell_id_buffer)
	var ints_sorted : PackedInt32Array = byte_data_sorted.to_int32_array()

	print("\n[Cell Id Buffer (sorted)]")
	print(ints_sorted)
	
