extends Node

"""
Pass_GridClear.gd
-----------------

This pass clears the grid_sort buffers every frame:

    - cell_counts  (int[4096])
    - cell_offsets (int[4096])

It must run AFTER GridAssign and BEFORE GridSort.

Dispatch size:
    workgroups_cells = ceil(max_cells / 64)

"""

# ---------------------------------------------------------
# Child references
# ---------------------------------------------------------
var gpu_device : Node
var gpu_buffers : Node

# ---------------------------------------------------------
# Pipeline + Uniform Set
# ---------------------------------------------------------
var pipeline_rid : RID
var uniform_set_rid : RID

# ---------------------------------------------------------
# Internal state
# ---------------------------------------------------------
var _initialised := false
var debug_print := false


func _ready() -> void:
	gpu_device = get_node("../../GPU_Device")
	gpu_buffers = get_node("../../GPU_Buffers")

	pipeline_rid = gpu_device.grid_clear_pipeline


func _init_pass(rd : RenderingDevice) -> void:
	if debug_print:
		print("\n[GridClear] --- INIT PASS ---")

	# Strong asserts
	assert(gpu_device.grid_clear_rid.is_valid())
	assert(gpu_device.grid_clear_pipeline.is_valid())

	# Pull RDUniforms
	var u_cell_counts : RDUniform = gpu_buffers.u_cell_counts
	var u_cell_offsets : RDUniform = gpu_buffers.u_cell_offsets
	var u_global : RDUniform = gpu_buffers.u_global

	if debug_print:
		print("[GridClear] u_cell_counts:", u_cell_counts)
		print("[GridClear] u_cell_offsets:", u_cell_offsets)
		print("[GridClear] u_global:", u_global)

	# Create uniform set
	uniform_set_rid = rd.uniform_set_create(
		[
			u_cell_counts,   # binding 13
			u_cell_offsets,  # binding 14
			u_global         # binding 8
		],
		gpu_device.grid_clear_rid,
		0
	)

	if debug_print:
		print("[GridClear] uniform_set_rid:", uniform_set_rid)

	_initialised = true

	if debug_print:
		print("[GridClear] INIT COMPLETE\n")


func run(rd : RenderingDevice, compute_list : int, workgroups_cells : int) -> void:
	if not _initialised:
		_init_pass(rd)

	if debug_print:
		print("\n[GridClear] --- RUN ---")
		print("[GridClear] workgroups (cells):", workgroups_cells)

	_dispatch(rd, compute_list, workgroups_cells)


func _dispatch(rd : RenderingDevice, list : int, N_cells : int) -> void:
	if debug_print:
		print("[GridClear] DISPATCH")

	rd.compute_list_bind_compute_pipeline(list, pipeline_rid)
	rd.compute_list_bind_uniform_set(list, uniform_set_rid, 0)
	rd.compute_list_dispatch(list, N_cells, 1, 1)

	if debug_print:
		print("[GridClear] DISPATCH COMPLETE\n")
