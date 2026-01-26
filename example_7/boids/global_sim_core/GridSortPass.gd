extends Node
class_name GridSortPass

var rd: RenderingDevice
var shader_rid: RID
var pipeline_rid: RID
var uniform_set: RID
var shader_file: RDShaderFile

var boid_count: int = 0


func setup(p_rd: RenderingDevice, buffers: Node) -> void:
	rd = p_rd
	boid_count = buffers.total_boid_count

	# Same pattern as ComputeOcean24: load RDShaderFile, get_spirv, create pipeline
	var folder: String = get_script().resource_path.get_base_dir()
	var shader_path: String = folder + "/GridSortPass.glsl"
	shader_file = load(shader_path)
	if shader_file == null:
		push_error("GridSortPass: failed to load RDShaderFile at: " + shader_path)
		return

	var spirv: RDShaderSPIRV = shader_file.get_spirv()
	shader_rid = rd.shader_create_from_spirv(spirv)
	pipeline_rid = rd.compute_pipeline_create(shader_rid)

	# Buffers from your global core
	var cell_ids_buffer: RID = buffers.get_cell_ids()
	var sorted_indices_buffer: RID = buffers.get_sorted_indices()

	var u_cell_ids := RDUniform.new()
	u_cell_ids.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	u_cell_ids.binding = 0
	u_cell_ids.add_id(cell_ids_buffer)

	var u_sorted := RDUniform.new()
	u_sorted.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	u_sorted.binding = 1
	u_sorted.add_id(sorted_indices_buffer)

	uniform_set = rd.uniform_set_create([u_cell_ids, u_sorted], shader_rid, 0)
	if uniform_set == RID():
		push_error("GridSortPass: uniform_set is null in setup()")


func run() -> void:
	if shader_rid == RID() or pipeline_rid == RID() or uniform_set == RID():
		push_error("GridSortPass: not initialized before run()")
		return

	if boid_count <= 1:
		return

	var n: int = boid_count
	var group_size: int = 256
	var groups_x: int = int(ceil(float(n) / float(group_size)))

	# Classic bitonic sort outer loops, like a CPU version but driving the GPU kernel
	var stage: int = 2
	while stage <= n:
		var pass_index: int = stage / 2
		while pass_index > 0:
			var compute_list := rd.compute_list_begin()
			rd.compute_list_bind_compute_pipeline(compute_list, pipeline_rid)
			rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)

			# Push constants: must match the 16‑byte block in GridSortPass.glsl
			var push_constants := PackedByteArray()
			push_constants.resize(16)
			push_constants.encode_s32(0, n)          # int total_boids
			push_constants.encode_s32(4, stage)      # int stage
			push_constants.encode_s32(8, pass_index) # int pass
			push_constants.encode_s32(12, 0)         # int pad

			rd.compute_list_set_push_constant(compute_list, push_constants, push_constants.size())

			rd.compute_list_dispatch(compute_list, groups_x, 1, 1)
			rd.compute_list_end()

			pass_index /= 2
		stage *= 2
