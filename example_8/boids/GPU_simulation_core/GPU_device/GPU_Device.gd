extends Node

"""
GPU_Device is the low‑level GPU backend for this simulation engine.
It acts as the Vulkan‑style device manager, responsible for creating 
and owning all GPU‑side shader programs and compute pipelines.

This class does not run simulation logic, dispatch compute passes, or manage buffers.
Instead, it provides the GPU execution primitives that the higher‑level systems rely on.
"""

# ---------------------------------------------------------
# RenderingDevice (Vulkan-like GPU context)
# ---------------------------------------------------------
var rd : RenderingDevice

# ---------------------------------------------------------
# Shader resources (GLSL → SPIR-V)
# ---------------------------------------------------------
var test_compute      : Resource = load("res://example_8/boids/GPU_simulation_core/GPU_passes/test_compute.glsl")
var grid_assign       : Resource = load("res://example_8/boids/GPU_simulation_core/GPU_passes/grid_assign.glsl")
#var grid_sort         : Resource = load("res://example_8/boids/GPU_simulation_core/GPU_passes/grid_sort.glsl")
#var grid_mapping      : Resource = load("res://example_8/boids/GPU_simulation_core/GPU_passes/grid_mapping.glsl")
#var behaviour         : Resource = load("res://example_8/boids/GPU_simulation_core/GPU_passes/behaviour.glsl")
#var integration       : Resource = load("res://example_8/boids/GPU_simulation_core/GPU_passes/integration.glsl")

# ---------------------------------------------------------
# Shader RIDs (GPU-side shader handles)
# ---------------------------------------------------------
var test_shader_rid
var grid_assign_rid
var grid_sort_rid
var grid_mapping_rid
var behaviour_rid
var integration_rid

# ---------------------------------------------------------
# Compute pipelines (one per shader)
# ---------------------------------------------------------
var test_compute_pipeline
var grid_assign_pipeline
var grid_sort_pipeline
var grid_mapping_pipeline
var behaviour_pipeline
var integration_pipeline


func _ready():
	# Create the RenderingDevice (Vulkan-like GPU context)
	rd = RenderingServer.create_local_rendering_device()
	print("GPU_Device: creating RenderingDevice")

	_load_shaders()
	print("GPU_Device: loading shaders")

	_create_compute_pipelines()
	print("GPU_Device: creating compute pipelines")


# ---------------------------------------------------------
# Load SPIR-V and create shader RIDs
# ---------------------------------------------------------
func _load_shaders():

	# Test pass
	var test_spirv = test_compute.get_spirv()
	test_shader_rid = rd.shader_create_from_spirv(test_spirv)

	# Grid Assign
	var assign_spirv = grid_assign.get_spirv()
	grid_assign_rid = rd.shader_create_from_spirv(assign_spirv)

	# Grid Sort
	#var sort_spirv = grid_sort.get_spirv()
	#grid_sort_rid = rd.shader_create_from_spirv(sort_spirv)

	# Grid Mapping
	#var mapping_spirv = grid_mapping.get_spirv()
	#grid_mapping_rid = rd.shader_create_from_spirv(mapping_spirv)

	# Behaviour
	#var behaviour_spirv = behaviour.get_spirv()
	#behaviour_rid = rd.shader_create_from_spirv(behaviour_spirv)

	# Integration
	#var integration_spirv = integration.get_spirv()
	#integration_rid = rd.shader_create_from_spirv(integration_spirv)


# ---------------------------------------------------------
# Create compute pipelines (one per shader)
# ---------------------------------------------------------
func _create_compute_pipelines():

	# Test pass
	test_compute_pipeline = rd.compute_pipeline_create(test_shader_rid)

	# Grid Assign
	grid_assign_pipeline = rd.compute_pipeline_create(grid_assign_rid)

	# Grid Sort
	#grid_sort_pipeline = rd.compute_pipeline_create(grid_sort_rid)

	# Grid Mapping
	#grid_mapping_pipeline = rd.compute_pipeline_create(grid_mapping_rid)

	# Behaviour
	#behaviour_pipeline = rd.compute_pipeline_create(behaviour_rid)

	# Integration
	#integration_pipeline = rd.compute_pipeline_create(integration_rid)
