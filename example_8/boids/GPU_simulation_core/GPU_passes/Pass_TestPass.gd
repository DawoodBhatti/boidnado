extends Node

var gpu_device
var gpu_buffers
var gpu_debug

func _ready():
	gpu_device = get_node("../../GPU_Device")
	gpu_buffers = get_node("../../GPU_Buffers")
	gpu_debug = get_node("../../GPU_Debug")



func run(rendering_device, compute_list):
	var rd = rendering_device
	var list = compute_list
	print("Pass_TestPass: dispatching test compute shader")

	rd.compute_list_bind_compute_pipeline(list, gpu_device.test_compute_pipeline)
	rd.compute_list_bind_uniform_set(list, gpu_buffers.uniform_set_rid, 0)

	# local_size_x = 64, N = 100 → 2 workgroups
	rd.compute_list_dispatch(list, 2, 1, 1)
