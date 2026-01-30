extends Node

# ---------------------------------------------------------
# Pass_TestPass.gd
# ---------------------------------------------------------
# A simple compute pass that:
#   - reads boid_indices (binding 9)
#   - writes sorted_boid_indices (binding 10)
# ---------------------------------------------------------

var gpu_device : Node
var gpu_buffers : Node

var pipeline_rid : RID
var uniform_set_rid : RID

var _initialised := false

var debug := false

func _ready() -> void:
	gpu_device = get_node("../../GPU_Device")
	gpu_buffers = get_node("../../GPU_Buffers")

	# Cache pipeline
	pipeline_rid = gpu_device.test_compute_pipeline


# ---------------------------------------------------------
# Lazy init: build uniform set on first run()
# ---------------------------------------------------------
func _init_pass(rd: RenderingDevice) -> void:
	if debug:
		print("\n[TestPass] --- INIT PASS ---")

	var u_boid_index : RDUniform = gpu_buffers.u_boid_index
	var u_sorted_boid_index : RDUniform = gpu_buffers.u_sorted_boid_index

	if debug:
		print("[TestPass] u_boid_index:", u_boid_index)
		print("[TestPass] u_sorted_boid_index:", u_sorted_boid_index)

	uniform_set_rid = rd.uniform_set_create(
		[
			u_boid_index,
			u_sorted_boid_index
		],
		gpu_device.test_compute_shader_rid,  # IMPORTANT: shader RID, not pipeline RID
		0
	)

	if debug:
		print("[TestPass] uniform_set_rid:", uniform_set_rid)
	_initialised = true
	if debug:
		print("[TestPass] INIT COMPLETE\n")


# ---------------------------------------------------------
# Public entry point
# ---------------------------------------------------------
func run(rd: RenderingDevice, compute_list: int, workgroup_count: int) -> void:
	if not _initialised:
		_init_pass(rd)

	print("Pass_TestPass: dispatching test compute shader")
	_dispatch(rd, compute_list, workgroup_count)


# ---------------------------------------------------------
# Dispatch logic
# ---------------------------------------------------------
func _dispatch(rd: RenderingDevice, list: int, N: int) -> void:
	if debug:
		print("\n[TestPass] --- DISPATCH ---")
		print("[TestPass] pipeline_rid:", pipeline_rid)
		print("[TestPass] uniform_set_rid:", uniform_set_rid)
		print("[TestPass] workgroups:", N)

	rd.compute_list_bind_compute_pipeline(list, pipeline_rid)
	rd.compute_list_bind_uniform_set(list, uniform_set_rid, 0)
	rd.compute_list_dispatch(list, N, 1, 1)

	if debug:
		print("[TestPass] DISPATCH COMPLETE\n")
