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
var is_initialised = false

func _ready() -> void:
	
	print("Renderer: initialised")
	
func set_density_texture_size(rd: RenderingDevice, dims: Vector3i) -> void:

	var fmt := RDTextureFormat.new()
	fmt.width = dims.x
	fmt.height = dims.y
	fmt.depth = dims.z
	fmt.texture_type = RenderingDevice.TEXTURE_TYPE_3D
	fmt.format = RenderingDevice.DATA_FORMAT_R32_SFLOAT
	fmt.usage_bits = (
		RenderingDevice.TEXTURE_USAGE_STORAGE_BIT |
		RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT
	)

	density_texture_3d = rd.texture_create(fmt, RDTextureView.new(), [])
	
	#TODO:
	#if code errors we might need to force GPU Simulation to wait for this
	#before we hand off to buffers to allocate uniform based on this
	is_initialised = true
