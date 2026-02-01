extends Node

"""
Pass_GridSort.gd
----------------

This compute pass performs a full GPU counting-sort of boids by cell_id.

Pipeline:
    1. Histogram  (cell_ids → cell_counts)
    2. Prefix     (cell_counts → cell_offsets)
    3. Scatter    (cell_ids + boid_indices + cell_offsets → sorted buffers)

Each stage:
    - pulls RDUniforms from GPU_Buffers
    - pulls pipelines from GPU_Device
    - builds its own uniform set
    - dispatches its own compute work
"""

# ---------------------------------------------------------
# Child references
# ---------------------------------------------------------
var gpu_device : Node
var gpu_buffers : Node

# ---------------------------------------------------------
# Pipeline RIDs
# ---------------------------------------------------------
var pipeline_histogram_rid : RID
var pipeline_prefix_rid : RID
var pipeline_scatter_rid : RID

# ---------------------------------------------------------
# Uniform set RIDs
# ---------------------------------------------------------
var uniform_set_histogram_rid : RID
var uniform_set_prefix_rid : RID
var uniform_set_scatter_rid : RID

# ---------------------------------------------------------
# Internal state
# ---------------------------------------------------------
var _initialised : bool = false
var debug : bool = true


func _ready() -> void:
	# Cache references
	gpu_device = get_node("../../GPU_Device")
	gpu_buffers = get_node("../../GPU_Buffers")

	# Pipelines created in GPU_Device
	pipeline_histogram_rid = gpu_device.grid_sort_histogram_pipeline
	pipeline_prefix_rid = gpu_device.grid_sort_prefix_pipeline
	pipeline_scatter_rid = gpu_device.grid_sort_scatter_pipeline


# ---------------------------------------------------------
# Initialise all uniform sets (once)
# ---------------------------------------------------------
func _init_passes(rd : RenderingDevice) -> void:
	if debug:
		print("\n[GridSort] --- INIT PASSES ---")

	# Strong asserts: GPU_Device must be fully initialised
	assert(gpu_device.grid_sort_histogram_rid.is_valid())
	assert(gpu_device.grid_sort_prefix_rid.is_valid())
	assert(gpu_device.grid_sort_scatter_rid.is_valid())
	assert(gpu_device.grid_sort_histogram_pipeline.is_valid())
	assert(gpu_device.grid_sort_prefix_pipeline.is_valid())
	assert(gpu_device.grid_sort_scatter_pipeline.is_valid())


	# Pull RDUniforms from GPU_Buffers
	var u_cell_id : RDUniform = gpu_buffers.u_cell_id
	var u_boid_index : RDUniform = gpu_buffers.u_boid_index
	var u_sorted_boid : RDUniform = gpu_buffers.u_sorted_boid_index
	var u_sorted_cell_id : RDUniform = gpu_buffers.u_sorted_cell_id
	var u_cell_counts : RDUniform = gpu_buffers.u_cell_counts
	var u_cell_offsets : RDUniform = gpu_buffers.u_cell_offsets
	var u_global : RDUniform = gpu_buffers.u_global

	# ---------------------------------------------------------
	# Histogram uniform set
	# ---------------------------------------------------------
	uniform_set_histogram_rid = rd.uniform_set_create(
		[
			u_cell_id,      # binding 11
			u_cell_counts,  # binding 13
			u_global        # binding 8
		],
		gpu_device.grid_sort_histogram_rid,
		0
	)

	# ---------------------------------------------------------
	# Prefix uniform set
	# ---------------------------------------------------------
	uniform_set_prefix_rid = rd.uniform_set_create(
		[
			u_cell_counts,  # binding 13
			u_cell_offsets, # binding 14
			u_global        # binding 8
		],
		gpu_device.grid_sort_prefix_rid,
		0
	)

	# ---------------------------------------------------------
	# Scatter uniform set
	# ---------------------------------------------------------
	uniform_set_scatter_rid = rd.uniform_set_create(
		[
			u_cell_id,        # binding 11
			u_boid_index,     # binding 9
			u_sorted_boid,    # binding 10
			u_sorted_cell_id, # binding 12
			u_cell_offsets,   # binding 14
			u_global          # binding 8
		],
		gpu_device.grid_sort_scatter_rid,
		0
	)

	_initialised = true

	if debug:
		print("[GridSort] INIT COMPLETE\n")


func _print_dispatch_message() -> void:
	print(name, ": dispatching grid_sort compute shaders")


# ---------------------------------------------------------
# Public entry point
# ---------------------------------------------------------
func run(rd : RenderingDevice, compute_list : int, workgroups_boids : int, workgroups_cells : int) -> void:
	if not _initialised:
		_init_passes(rd)

	if debug:
		print("\n[GridSort] --- RUN ---")
		print("[GridSort] workgroups (boids): ", workgroups_boids)
		print("[GridSort] workgroups (cells): ", workgroups_cells)

	_print_dispatch_message()
	_run_histogram(rd, compute_list, workgroups_boids)
	_run_prefix(rd, compute_list, workgroups_cells)
	_run_scatter(rd, compute_list, workgroups_boids)


# ---------------------------------------------------------
# Stage 1 — Histogram
# ---------------------------------------------------------
func _run_histogram(rd : RenderingDevice, list : int, N_boids : int) -> void:
	if debug:
		print("[GridSort] HISTOGRAM")

	rd.compute_list_bind_compute_pipeline(list, pipeline_histogram_rid)
	rd.compute_list_bind_uniform_set(list, uniform_set_histogram_rid, 0)
	rd.compute_list_dispatch(list, N_boids, 1, 1)


# ---------------------------------------------------------
# Stage 2 — Prefix
# ---------------------------------------------------------
func _run_prefix(rd : RenderingDevice, list : int, N_cells : int) -> void:
	if debug:
		print("[GridSort] PREFIX")

	rd.compute_list_bind_compute_pipeline(list, pipeline_prefix_rid)
	rd.compute_list_bind_uniform_set(list, uniform_set_prefix_rid, 0)
	rd.compute_list_dispatch(list, N_cells, 1, 1)


# ---------------------------------------------------------
# Stage 3 — Scatter
# ---------------------------------------------------------
func _run_scatter(rd : RenderingDevice, list : int, N_boids : int) -> void:
	if debug:
		print("[GridSort] SCATTER")

	rd.compute_list_bind_compute_pipeline(list, pipeline_scatter_rid)
	rd.compute_list_bind_uniform_set(list, uniform_set_scatter_rid, 0)
	rd.compute_list_dispatch(list, N_boids, 1, 1)
