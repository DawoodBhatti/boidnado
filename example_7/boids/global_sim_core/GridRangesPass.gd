extends Node
class_name GridRangesPass

var rd: RenderingDevice
var shader_rid: RID
var pipeline_rid: RID
var uniform_set: RID
var shader_file: RDShaderFile

var total_cells: int = 0
var boid_count: int = 0


# ---------------------------------------------------------
# Setup (called once by GlobalSimulationCore)
# ---------------------------------------------------------
func setup(p_rd: RenderingDevice, buffers: Node, p_total_cells: int) -> void:
	rd = p_rd
	total_cells = p_total_cells
	boid_count = buffers.total_boid_count

	# Load SPIR-V shader
	var folder : String = get_script().resource_path.get_base_dir()
	var shader_path := folder + "/GridRangesPass.glsl"
	print("GridRangesPass: loading shader ", shader_path)

	shader_file = load(shader_path)
	if shader_file == null:
		push_error("GridRangesPass: failed to load RDShaderFile at: " + shader_path)
		return

	var spirv := shader_file.get_spirv()
	shader_rid = rd.shader_create_from_spirv(spirv)
	pipeline_rid = rd.compute_pipeline_create(shader_rid)

	# -----------------------------------------------------
	# Bind buffers from GlobalSimulationCore
	# -----------------------------------------------------
	var sorted_indices_buffer: RID = buffers.get_sorted_indices()
	var cell_ids_buffer: RID = buffers.get_cell_ids()
	var cell_start_buffer: RID = buffers.get_cell_start()
	var cell_end_buffer: RID = buffers.get_cell_end()

	# -----------------------------------------------------
	# Create uniform buffer for GridParams (16 bytes)
	# int total_cells;
	# int boid_count;
	# int pad0;
	# int pad1;
	# -----------------------------------------------------
	var bytes := PackedByteArray()
	bytes.resize(16)
	bytes.encode_s32(0, total_cells)
	bytes.encode_s32(4, boid_count)
	bytes.encode_s32(8, 0)
	bytes.encode_s32(12, 0)

	var grid_params_buffer := rd.uniform_buffer_create(bytes.size(), bytes)

	# -----------------------------------------------------
	# Build RDUniforms
	# -----------------------------------------------------
	var u_sorted := RDUniform.new()
	u_sorted.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	u_sorted.binding = 0
	u_sorted.add_id(sorted_indices_buffer)

	var u_ids := RDUniform.new()
	u_ids.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	u_ids.binding = 1
	u_ids.add_id(cell_ids_buffer)

	var u_start := RDUniform.new()
	u_start.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	u_start.binding = 2
	u_start.add_id(cell_start_buffer)

	var u_end := RDUniform.new()
	u_end.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	u_end.binding = 3
	u_end.add_id(cell_end_buffer)

	var u_params := RDUniform.new()
	u_params.uniform_type = RenderingDevice.UNIFORM_TYPE_UNIFORM_BUFFER
	u_params.binding = 4
	u_params.add_id(grid_params_buffer)

	# -----------------------------------------------------
	# Create uniform set ON THE SAME RD
	# -----------------------------------------------------
	uniform_set = rd.uniform_set_create(
		[u_sorted, u_ids, u_start, u_end, u_params],
		shader_rid,
		0
	)

	if uniform_set == RID():
		push_error("GridRangesPass: uniform_set is null in setup()")


# ---------------------------------------------------------
# Run (called every frame by GlobalSimulationCore)
# ---------------------------------------------------------
func run() -> void:
	if shader_rid == RID() or pipeline_rid == RID() or uniform_set == RID():
		push_error("GridRangesPass: not initialized before run()")
		return

	var cl := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(cl, pipeline_rid)
	rd.compute_list_bind_uniform_set(cl, uniform_set, 0)

	var group_size := 256
	var groups := int(ceil(float(total_cells) / float(group_size)))

	rd.compute_list_dispatch(cl, groups, 1, 1)
	rd.compute_list_end()
