extends Node

"""
Pass_Density3D.gd
-----------------

This compute pass writes per-cell density into a 3D texture.

Pipeline:
    Density3D (cell_counts → density_texture_3d)

For each cell c:
    density = cell_counts[c] (optionally normalised)
    write density into voxel corresponding to cell index.

Each stage:
    - pulls RDUniforms from GPU_Buffers
    - pulls pipeline from GPU_Device
    - builds its own uniform set
    - dispatches its own compute work
"""

var gpu_device : Node
var gpu_buffers : Node

var pipeline_density_rid : RID
var uniform_set_density_rid : RID

var _initialised : bool = false
var debug : bool = true


func _ready() -> void:
	gpu_device = get_node("../../GPU_Device")
	gpu_buffers = get_node("../../GPU_Buffers")

	# Pipeline created in GPU_Device (e.g. density_pipeline)
	pipeline_density_rid = gpu_device.density_3D_pipeline


func _init_pass(rd : RenderingDevice) -> void:
	if debug:
		print("\n[Density3D] --- INIT PASS ---")

	assert(gpu_device.density_3D_rid.is_valid())
	assert(gpu_device.density_3D_pipeline.is_valid())

	var u_cell_counts : RDUniform = gpu_buffers.u_cell_counts      # binding 13
	var u_global      : RDUniform = gpu_buffers.u_global           # binding 8
	var u_density     : RDUniform = gpu_buffers.u_density_image_3D # binding 16

	uniform_set_density_rid = rd.uniform_set_create(
		[
			u_cell_counts,  # 13
			u_global,       # 8
			u_density       # 16
		],
		gpu_device.density_3D_rid,
		0
	)

	_initialised = true

	if debug:
		print("[Density3D] INIT COMPLETE\n")


func _print_dispatch_message(N_cells: int) -> void:
	print(name, ": dispatching density3D compute shader with ", N_cells, " workgroups (cells)")


func run(rd : RenderingDevice, compute_list : int, N_cells : int) -> void:
	if not _initialised:
		_init_pass(rd)

	if debug:
		print("\n[Density3D] --- RUN ---")
		print("[Density3D] workgroups (cells): ", N_cells)

	_print_dispatch_message(N_cells)
	_run_density(rd, compute_list, N_cells)


func _run_density(rd : RenderingDevice, list : int, N_cells : int) -> void:
	if debug:
		print("[Density3D] WRITING DENSITY")

	rd.compute_list_bind_compute_pipeline(list, pipeline_density_rid)
	rd.compute_list_bind_uniform_set(list, uniform_set_density_rid, 0)
	rd.compute_list_dispatch(list, N_cells, 1, 1)
