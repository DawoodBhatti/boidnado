extends Node
class_name GridAssignPass

var rd: RenderingDevice
var shader_rid: RID
var pipeline_rid: RID
var uniform_set: RID

var boid_count: int = 0


# ---------------------------------------------------------
# Setup (called once by GlobalSimulationCore)
# ---------------------------------------------------------
func setup(p_rd: RenderingDevice, buffers: Node, grid_params: PackedFloat32Array, grid_dims: PackedInt32Array) -> void:
	rd = p_rd
	boid_count = buffers.total_boid_count

	# ---------------------------------------------------------
	# Load RDShaderFile (must be imported as RenderingDevice Shader)
	# ---------------------------------------------------------
	var folder: String = get_script().resource_path.get_base_dir()
	var shader_path: String = folder + "/GridAssignPass.glsl"
	print("GridAssignPass: loading shader ", shader_path)

	var shader_file: Resource = load(shader_path)
	if shader_file == null:
		push_error("GridAssignPass: failed to load shader file")
		return

	var spirv: RDShaderSPIRV = shader_file.get_spirv()

	# Create shader + pipeline
	shader_rid = rd.shader_create_from_spirv(spirv)
	if shader_rid == RID():
		push_error("GridAssignPass: shader_create_from_spirv() failed — shader not imported as RenderingDevice Shader?")
		return

	pipeline_rid = rd.compute_pipeline_create(shader_rid)

	# ---------------------------------------------------------
	# Buffers from GlobalSimulationCore
	# ---------------------------------------------------------
	var positions_buffer: RID = buffers.get_positions()
	var cell_ids_buffer: RID = buffers.get_cell_ids()

	# ---------------------------------------------------------
	# Create GridParams uniform buffer (16 bytes)
	# ---------------------------------------------------------
	var bytes := PackedByteArray()
	bytes.resize(16)
	bytes.encode_float(0, grid_params[0])   # cell_size
	bytes.encode_s32(4, grid_dims[0])       # grid_dim_x
	bytes.encode_s32(8, grid_dims[1])       # grid_dim_y
	bytes.encode_s32(12, grid_dims[2])      # grid_dim_z

	var grid_params_buffer := rd.uniform_buffer_create(bytes.size(), bytes)

	# ---------------------------------------------------------
	# Build RDUniforms
	# ---------------------------------------------------------
	var u_positions := RDUniform.new()
	u_positions.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	u_positions.binding = 0
	u_positions.add_id(positions_buffer)

	var u_cell_ids := RDUniform.new()
	u_cell_ids.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	u_cell_ids.binding = 1
	u_cell_ids.add_id(cell_ids_buffer)

	var u_params := RDUniform.new()
	u_params.uniform_type = RenderingDevice.UNIFORM_TYPE_UNIFORM_BUFFER
	u_params.binding = 2
	u_params.add_id(grid_params_buffer)

	# ---------------------------------------------------------
	# Create uniform set
	# ---------------------------------------------------------
	uniform_set = rd.uniform_set_create([u_positions, u_cell_ids, u_params], shader_rid, 0)

	print("GridAssignPass setup:",
		" shader_rid=", shader_rid,
		" pipeline_rid=", pipeline_rid,
		" uniform_set=", uniform_set)

	if uniform_set == RID():
		push_error("GridAssignPass: uniform_set is null (binding mismatch?)")

	print("shader_file class: ", shader_file.get_class())
	
	
# ---------------------------------------------------------
# Run (called every frame by GlobalSimulationCore)
# ---------------------------------------------------------
func run() -> void:
	
	if shader_rid == RID() or pipeline_rid == RID() or uniform_set == RID():
		
		print("shader_rid: ", shader_rid)
		print("pipeline_rid: ", pipeline_rid)
		print("uniform_set: ", uniform_set)
		push_error("GridAssignPass: not initialized before run()")
		return

	var cl := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(cl, pipeline_rid)
	rd.compute_list_bind_uniform_set(cl, uniform_set, 0)

	var group_size := 256
	var groups := int(ceil(float(boid_count) / float(group_size)))

	rd.compute_list_dispatch(cl, groups, 1, 1)
	rd.compute_list_end()
