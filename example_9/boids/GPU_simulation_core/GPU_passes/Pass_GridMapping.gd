extends Node

"""
Pass_GridMapping.gd
-------------------

This compute pass builds per-cell ranges into the sorted boid arrays.

Pipeline:
    GridMapping (cell_counts + cell_offsets → cell_mapping)

For each cell c:
    start = cell_offsets[c]
    end   = start + cell_counts[c]
    cell_mapping[c] = ivec2(start, end)

Each stage:
    - pulls RDUniforms from GPU_Buffers
    - pulls pipeline from GPU_Device
    - builds its own uniform set
    - dispatches its own compute work
"""

# ---------------------------------------------------------
# Child references
# ---------------------------------------------------------
var gpu_device : Node
var gpu_buffers : Node

# ---------------------------------------------------------
# Pipeline RID
# ---------------------------------------------------------
var pipeline_mapping_rid : RID

# ---------------------------------------------------------
# Uniform set RID
# ---------------------------------------------------------
var uniform_set_mapping_rid : RID

# ---------------------------------------------------------
# Internal state
# ---------------------------------------------------------
var _initialised : bool = false
var debug_print : bool = false


func _ready() -> void:
	# Cache references
	gpu_device = get_node("../../GPU_Device")
	gpu_buffers = get_node("../../GPU_Buffers")

	# Pipeline created in GPU_Device
	pipeline_mapping_rid = gpu_device.grid_mapping_pipeline


# ---------------------------------------------------------
# Initialise uniform set (once)
# ---------------------------------------------------------
func _init_pass(rd : RenderingDevice) -> void:
	if debug_print:
		print("\n[GridMapping] --- INIT PASS ---")

	# Strong asserts: GPU_Device must be fully initialised
	assert(gpu_device.grid_mapping_rid.is_valid())
	assert(gpu_device.grid_mapping_pipeline.is_valid())

	# Pull RDUniforms from GPU_Buffers
	var u_cell_counts : RDUniform = gpu_buffers.u_cell_counts   # binding 13
	var u_cell_offsets : RDUniform = gpu_buffers.u_cell_offsets # binding 14
	var u_cell_mapping : RDUniform = gpu_buffers.u_cell_mapping # binding 15
	var u_global : RDUniform = gpu_buffers.u_global             # binding 8

	# Single uniform set for this pass
	uniform_set_mapping_rid = rd.uniform_set_create(
		[
			u_global,        # 8
			u_cell_counts,   # 13
			u_cell_offsets,  # 14
			u_cell_mapping   # 15

		],
		gpu_device.grid_mapping_rid,
		0
	)

	_initialised = true

	if debug_print:
		print("[GridMapping] INIT COMPLETE\n")


func _print_dispatch_message() -> void:
	print(name, ": dispatching grid_mapping compute shader")


# ---------------------------------------------------------
# Public entry point
# N_cells = workgroups over cells (ceil(total_cells / local_size_x))
# ---------------------------------------------------------
func run(rd : RenderingDevice, compute_list : int, N_cells : int) -> void:
	if not _initialised:
		_init_pass(rd)

	if debug_print:
		print("\n[GridMapping] --- RUN ---")
		print("[GridMapping] workgroups (cells): ", N_cells)

		_print_dispatch_message()
		
	_run_mapping(rd, compute_list, N_cells)


# ---------------------------------------------------------
# Single stage — GridMapping
# ---------------------------------------------------------
func _run_mapping(rd : RenderingDevice, list : int, N_cells : int) -> void:
	if debug_print:
		print("[GridMapping] MAPPING")

	rd.compute_list_bind_compute_pipeline(list, pipeline_mapping_rid)
	rd.compute_list_bind_uniform_set(list, uniform_set_mapping_rid, 0)
	rd.compute_list_dispatch(list, N_cells, 1, 1)
