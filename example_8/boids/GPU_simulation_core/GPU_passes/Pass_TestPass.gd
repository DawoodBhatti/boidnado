extends Node

var gpu_device
var gpu_buffers
var gpu_debug
var rd : RenderingDevice

func _ready():
	gpu_device = get_node("../../GPU_Device")
	gpu_buffers = get_node("../../GPU_Buffers")
	gpu_debug = get_node("../../GPU_Debug")
	rd = gpu_device.rd



func _dispatch_test_compute():
	print("Pass_TestPass: dispatching test compute shader")
	var list = rd.compute_list_begin()

	rd.compute_list_bind_compute_pipeline(list, gpu_device.test_compute_pipeline)
	rd.compute_list_bind_uniform_set(list, gpu_buffers.test_uniform_set_rid, 0)

	# local_size_x = 64, N = 100 → 2 workgroups
	rd.compute_list_dispatch(list, 2, 1, 1)

	rd.compute_list_end()
	rd.submit()
	rd.sync()
