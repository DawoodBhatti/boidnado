extends Node

"""
Pass_Behaviour.gd
-----------------

This compute pass applies all boid behaviours in a single shader:

    - alignment
    - cohesion
    - separation
    - wander
    - boundary potential

Pipeline:
    Behaviour (per-boid)

Each stage:
    - pulls RDUniforms from GPU_Buffers
    - pulls pipeline from GPU_Device
    - builds its own uniform set
    - dispatches compute work over boids
"""

# ---------------------------------------------------------
# Child references
# ---------------------------------------------------------
var gpu_device : Node
var gpu_buffers : Node

# ---------------------------------------------------------
# Pipeline RID
# ---------------------------------------------------------
var pipeline_behaviour_rid : RID

# ---------------------------------------------------------
# Uniform set RID
# ---------------------------------------------------------
var uniform_set_behaviour_rid : RID

# ---------------------------------------------------------
# Internal state
# ---------------------------------------------------------
var _initialised : bool = false
var debug : bool = false


func _ready() -> void:
	# Cache references
	gpu_device = get_node("../../GPU_Device")
	gpu_buffers = get_node("../../GPU_Buffers")

	# Pipeline created in GPU_Device
	pipeline_behaviour_rid = gpu_device.behaviour_pipeline


# ---------------------------------------------------------
# Initialise uniform set (once)
# ---------------------------------------------------------
func _init_pass(rd : RenderingDevice) -> void:
	if debug:
		print("\n[Behaviour] --- INIT PASS ---")

	# Strong asserts: GPU_Device must be fully initialised
	assert(gpu_device.behaviour_rid.is_valid())
	assert(gpu_device.behaviour_pipeline.is_valid())

	# Pull RDUniforms from GPU_Buffers
	var u_pos_x        : RDUniform = gpu_buffers.u_pos_x
	var u_pos_y        : RDUniform = gpu_buffers.u_pos_y
	var u_pos_z        : RDUniform = gpu_buffers.u_pos_z

	var u_vel_x        : RDUniform = gpu_buffers.u_vel_x
	var u_vel_y        : RDUniform = gpu_buffers.u_vel_y
	var u_vel_z        : RDUniform = gpu_buffers.u_vel_z

	var u_swarm        : RDUniform = gpu_buffers.u_swarm
	var u_boid_to_swarm: RDUniform = gpu_buffers.u_map
	var u_global       : RDUniform = gpu_buffers.u_global

	var u_sorted_boid  : RDUniform = gpu_buffers.u_sorted_boid_index
	var u_sorted_cell  : RDUniform = gpu_buffers.u_sorted_cell_id
	var u_cell_mapping : RDUniform = gpu_buffers.u_cell_mapping

	# ---------------------------------------------------------
	# Behaviour uniform set
	# ---------------------------------------------------------
	uniform_set_behaviour_rid = rd.uniform_set_create(
		[
			u_pos_x,            # binding 0
			u_pos_y,            # binding 1
			u_pos_z,            # binding 2

			u_vel_x,            # binding 3
			u_vel_y,            # binding 4
			u_vel_z,            # binding 5

			u_swarm,            # binding 6
			u_boid_to_swarm,    # binding 7
			u_global,           # binding 8

			u_sorted_boid,      # binding 10
			u_sorted_cell,      # binding 12
			u_cell_mapping      # binding 15
		],
		gpu_device.behaviour_rid,
		0
	)

	_initialised = true

	if debug:
		print("[Behaviour] INIT COMPLETE\n")


func _print_dispatch_message() -> void:
	print(name, ": dispatching behaviour compute shader")


# ---------------------------------------------------------
# Public entry point
# N_boid_groups = ceil(boid_count / local_size_x)
# ---------------------------------------------------------
func run(rd : RenderingDevice, compute_list : int, N_boid_groups : int) -> void:
	if not _initialised:
		_init_pass(rd)

	if debug:
		print("\n[Behaviour] --- RUN ---")
		print("[Behaviour] workgroups (boids): ", N_boid_groups)

		_print_dispatch_message()
		
	_run_behaviour(rd, compute_list, N_boid_groups)


# ---------------------------------------------------------
# Single stage — Behaviour
# ---------------------------------------------------------
func _run_behaviour(rd : RenderingDevice, list : int, N_boids : int) -> void:
	if debug:
		print("[Behaviour] APPLY")

	rd.compute_list_bind_compute_pipeline(list, pipeline_behaviour_rid)
	rd.compute_list_bind_uniform_set(list, uniform_set_behaviour_rid, 0)
	rd.compute_list_dispatch(list, N_boids, 1, 1)
