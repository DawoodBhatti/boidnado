extends Node

"""
GPU_Device is the low‑level GPU backend for the simulation engine.

It owns:
  - the RenderingDevice (Vulkan‑style GPU context)
  - all shader programs (SPIR‑V → shader RIDs)
  - all compute pipelines (one per shader)

It does NOT:
  - manage buffers or textures
  - build uniform sets
  - run compute passes
  - know anything about simulation logic

Higher‑level compute passes pull the pipelines they need and build
their own uniform sets using GPU_Buffers. This keeps GPU_Device
focused purely on GPU program creation and lifetime management.
"""

# ---------------------------------------------------------
# Init flag
# ---------------------------------------------------------
var is_initialised = false

# ---------------------------------------------------------
# RenderingDevice (Vulkan-like GPU context)
# ---------------------------------------------------------
var rd : RenderingDevice

# ---------------------------------------------------------
# Shader resources (GLSL → SPIR-V)
# ---------------------------------------------------------
var test_compute            : Resource      = load("res://example_9/boids/GPU_simulation_core/GPU_passes/test_compute.glsl")
var grid_assign             : Resource      = load("res://example_9/boids/GPU_simulation_core/GPU_passes/grid_assign.glsl")
var grid_clear              : Resource      = load("res://example_9/boids/GPU_simulation_core/GPU_passes/grid_clear.glsl")
var grid_sort_histogram     : Resource      = load("res://example_9/boids/GPU_simulation_core/GPU_passes/grid_sort_histogram.glsl")
var grid_sort_prefix        : Resource      = load("res://example_9/boids/GPU_simulation_core/GPU_passes/grid_sort_prefix.glsl")
var grid_sort_scatter       : Resource      = load("res://example_9/boids/GPU_simulation_core/GPU_passes/grid_sort_scatter.glsl")
var grid_mapping            : Resource      = load("res://example_9/boids/GPU_simulation_core/GPU_passes/grid_mapping.glsl")
var behaviour               : Resource      = load("res://example_9/boids/GPU_simulation_core/GPU_passes/behaviour.glsl")
var density_3D              : Resource      = load("res://example_9/boids/GPU_simulation_core/GPU_passes/density_3D.glsl")
#var integration  : Resource      = load("res://example_8/boids/GPU_simulation_core/GPU_passes/integration.glsl")

# ---------------------------------------------------------
# Shader RIDs (GPU-side shader handles)
# ---------------------------------------------------------
var test_compute_shader_rid
var grid_assign_rid
var grid_clear_rid
var grid_sort_histogram_rid
var grid_sort_prefix_rid
var grid_sort_scatter_rid
var grid_mapping_rid
var behaviour_rid
var density_3D_rid
#var integration_rid


# ---------------------------------------------------------
# Compute pipelines (one per shader)
# ---------------------------------------------------------
var test_compute_pipeline
var grid_assign_pipeline
var grid_clear_pipeline
var grid_sort_histogram_pipeline
var grid_sort_prefix_pipeline
var grid_sort_scatter_pipeline
var grid_mapping_pipeline
var behaviour_pipeline
var density_3D_pipeline
#var integration_pipeline


func _ready() -> void:
	# ---------------------------------------------------------
	# Create the RenderingDevice (Vulkan-like GPU context)
	# ---------------------------------------------------------
	rd = RenderingServer.get_rendering_device()
	print("GPU_Device: RenderingDevice created")

	# ---------------------------------------------------------
	# Load SPIR-V shaders and create shader RIDs
	# ---------------------------------------------------------
	_load_shaders()
	print("GPU_Device: shaders loaded")

	# ---------------------------------------------------------
	# Create compute pipelines for each shader
	# ---------------------------------------------------------
	_create_compute_pipelines()
	print("GPU_Device: compute pipelines created")

	is_initialised = true
	print("GPU_Device: initialised =", is_initialised)


# ---------------------------------------------------------
# Load SPIR-V and create shader RIDs
# ---------------------------------------------------------
func _load_shaders() -> void:

	# Test pass
	var test_spirv = test_compute.get_spirv()
	test_compute_shader_rid = rd.shader_create_from_spirv(test_spirv)

	# Grid Assign
	var assign_spirv = grid_assign.get_spirv()
	grid_assign_rid = rd.shader_create_from_spirv(assign_spirv)

	# Grid Clear
	var clear_spirv = grid_clear.get_spirv()
	grid_clear_rid = rd.shader_create_from_spirv(clear_spirv)

	# Grid Sort
	var sort_histogram_spirv = grid_sort_histogram.get_spirv()
	var sort_prefix_spirv = grid_sort_prefix.get_spirv()
	var sort_scatter_spirv = grid_sort_scatter.get_spirv()

	grid_sort_histogram_rid = rd.shader_create_from_spirv(sort_histogram_spirv)
	grid_sort_prefix_rid = rd.shader_create_from_spirv(sort_prefix_spirv)
	grid_sort_scatter_rid = rd.shader_create_from_spirv(sort_scatter_spirv)

	# Grid Mapping
	var mapping_spirv = grid_mapping.get_spirv()
	grid_mapping_rid = rd.shader_create_from_spirv(mapping_spirv)

	# Behaviour
	var behaviour_spirv = behaviour.get_spirv()
	behaviour_rid = rd.shader_create_from_spirv(behaviour_spirv)

	# Density
	var density_3d_spriv = density_3D.get_spirv()
	density_3D_rid = rd.shader_create_from_spirv(density_3d_spriv)

	# Integration
	#var integration_spirv = integration.get_spirv()
	#integration_rid = rd.shader_create_from_spirv(integration_spirv)


# ---------------------------------------------------------
# Create compute pipelines (one per shader)
# ---------------------------------------------------------
func _create_compute_pipelines() -> void:

	# Test pass
	test_compute_pipeline = rd.compute_pipeline_create(test_compute_shader_rid)

	# Grid Assign
	grid_assign_pipeline = rd.compute_pipeline_create(grid_assign_rid)
	
	# Grid Clear
	grid_clear_pipeline = rd.compute_pipeline_create(grid_clear_rid)
	
	# Grid Sort
	grid_sort_histogram_pipeline = rd.compute_pipeline_create(grid_sort_histogram_rid)
	grid_sort_prefix_pipeline = rd.compute_pipeline_create(grid_sort_prefix_rid)
	grid_sort_scatter_pipeline = rd.compute_pipeline_create(grid_sort_scatter_rid)
	
	# Grid Mapping
	grid_mapping_pipeline = rd.compute_pipeline_create(grid_mapping_rid)

	# Behaviour
	behaviour_pipeline = rd.compute_pipeline_create(behaviour_rid)
	
	# Density 3d
	density_3D_pipeline = rd.compute_pipeline_create(density_3D_rid)


	# test before proceeding
	assert(test_compute_pipeline.is_valid())
	assert(grid_assign_pipeline.is_valid())
	assert(grid_clear_pipeline.is_valid())
	assert(grid_sort_histogram_pipeline.is_valid())
	assert(grid_sort_prefix_pipeline.is_valid())
	assert(grid_sort_scatter_pipeline.is_valid())
	assert(grid_mapping_pipeline.is_valid())
	assert(behaviour_pipeline.is_valid())
	assert(density_3D_pipeline.is_valid())


	# Integration
	#integration_pipeline = rd.compute_pipeline_create(integration_rid)
