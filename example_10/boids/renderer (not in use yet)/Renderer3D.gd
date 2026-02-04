extends Node

# Here we implement some of the potential rendering options:
# Raymarching (fog like technique)
# Orthographic slices (MRI like view) (cheapeast and easiest)
# Point cloud rendering (pixel per point representation)
# Max intensity projection
# Marching cubes (coming soon, hopefully)

# Each of these methods first requires us to sample density into a 3d texture

# Rough logic flow:
# Renderer holds 3d image texture
# compute pipeline runs simulation passes and also density pass
# writes into 3d storage texture
# Renderer holds storage texture
# Renderer calls rendering of orthographic slices. Then point cloud rendering. Then MArching cubes?

var density_texture_3d : RID
var is_initialised : bool = false
var rd : RenderingDevice


func _ready() -> void:
	print("Renderer: initialised")

	# Cache RenderingDevice from simulation core
	var sim_core : Node = get_node("../GPU_SimulationCore")
	rd = sim_core.gpu_device.rd

	# Set up the quad material (now using MIP shader)
	var quad : MeshInstance3D = $SliceQuad
	var mat : ShaderMaterial = ShaderMaterial.new()
	mat.shader = load("res://example_9/boids/renderer/MIP/mip_viewer.gdshader")
	quad.material_override = mat


func set_density_texture_size(rd_in : RenderingDevice, dims : Vector3i) -> void:
	# Create the 3D texture
	var fmt : RDTextureFormat = RDTextureFormat.new()
	fmt.width = dims.x
	fmt.height = dims.y
	fmt.depth = dims.z
	fmt.texture_type = RenderingDevice.TEXTURE_TYPE_3D
	fmt.format = RenderingDevice.DATA_FORMAT_R32_SFLOAT
	fmt.usage_bits = (
		RenderingDevice.TEXTURE_USAGE_STORAGE_BIT |
		RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT
	)

	density_texture_3d = rd_in.texture_create(fmt, RDTextureView.new(), [])

	# Bind the texture to the MIP shader
	var quad : MeshInstance3D = $SliceQuad
	var mat : ShaderMaterial = quad.material_override
	mat.set_shader_parameter("density_tex", density_texture_3d)

	is_initialised = true


func _process(delta : float) -> void:
	# Nothing to update per-frame for MIP
	if not is_initialised:
		return
