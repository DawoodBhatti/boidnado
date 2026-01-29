extends Node

var rd : RenderingDevice
var test_compute : Resource = load("res://example_8/boids/GPU_simulation_core/GPU_passes/test_compute.glsl")

var test_shader_rid
var test_compute_pipeline


func _ready():
	# Create the RenderingDevice (Vulkan-like GPU context)
	rd = RenderingServer.create_local_rendering_device()
	print("GPU_Device: creating RenderingDevice")

	_load_shaders()
	print("GPU_Device: loading shaders")

	_create_compute_pipelines()
	print("GPU_Device: creating compute pipelines")


# ---------------------------------------------------------
# Load SPIR-V and create shader RID
# ---------------------------------------------------------
func _load_shaders():
	var spirv = test_compute.get_spirv()
	test_shader_rid = rd.shader_create_from_spirv(spirv)


# ---------------------------------------------------------
# Create compute pipeline for the test shader
# ---------------------------------------------------------
func _create_compute_pipelines():
	test_compute_pipeline = rd.compute_pipeline_create(test_shader_rid)
