extends Node

var rd : RenderingDevice 
var test_compute: Resource = load("res://example_8/boids/GPU_simulation_core/GPU_passes/test_compute.glsl")
var test_shader_rid 
var test_compute_pipeline 


	## Prepare compute shader SPIR-V
	#var shader_spirv = shader_file.get_spirv()

	#shader_rid = rd.shader_create_from_spirv(shader_spirv)
	#pipeline_rid = rd.compute_pipeline_create(shader_rid)

	## RDUniform objects that wrap each GPU buffer.
	## Act as binding handles, linking storage buffers (x, z, constants, wavenumbers, output)
	## to specific binding slots in the compute shader.
	#var uniform_in_x := RDUniform.new()
	#var uniform_in_z := RDUniform.new()
	#var uniform_constants := RDUniform.new()
	#var uniform_kx := RDUniform.new()
	#var uniform_kz := RDUniform.new()
	#var uniform_kmag := RDUniform.new()
	#var uniform_dispersion_rel := RDUniform.new()
	#var uniform_dispersion_quant := RDUniform.new()
	#var uniform_phil_spectrum := RDUniform.new()
	#var uniform_out := RDUniform.new()
#
	## Select uniform type 
	#uniform_in_x.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	#uniform_in_z.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	#uniform_constants.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	#uniform_kx.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	#uniform_kz.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	#uniform_kmag.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	#uniform_dispersion_rel.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	#uniform_dispersion_quant.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	#uniform_phil_spectrum.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	#uniform_out.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
#
	## buffer binding index must match bindings in compute shader
	#uniform_in_x.binding = 0
	#uniform_in_z.binding = 1
	#uniform_constants.binding = 2
	#uniform_kx.binding = 3
	#uniform_kz.binding = 4
	#uniform_kmag.binding = 5
	#uniform_dispersion_rel.binding = 6
	#uniform_dispersion_quant.binding = 7
	#uniform_phil_spectrum.binding = 8
	#uniform_out.binding = 9


func _ready():
	rd = RenderingServer.create_local_rendering_device()
	print("GPU_Device: creating RenderingDevice")
	
	_load_shaders()
	print("GPU_Device: loading shaders")
	
	_create_compute_pipelines()
	print("GPU_Device: creating compute pipelines")
	
	_create_uniform_set_layout()
	print("GPU_Device: creating uniform set layouts")


func _load_shaders():
	var test_shader_spirv = test_compute.get_spirv()
	test_shader_rid = rd.shader_create_from_spirv(test_shader_spirv)


func _create_compute_pipelines():
	test_compute_pipeline = rd.compute_pipeline_create(test_shader_rid)


## RDUniform objects that wrap each GPU buffer.
## Act as binding handles, which will be connected to buffer indices in GPU_Buffers
func _create_uniform_set_layout():
	var uniform_test_in := RDUniform.new()
	uniform_test_in.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	
	var uniform_test_constants := RDUniform.new()
	uniform_test_constants.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	

	var uniform_test_out := RDUniform.new()
	uniform_test_out.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	
	
