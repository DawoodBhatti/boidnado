extends Node

var rd: RenderingDevice
var shader_rid: RID
var pipeline_rid: RID
var uniform_set: RID
var shader_file: RDShaderFile

var swarm_slices: Array = []
var total_boid_count: int = 0


# ---------------------------------------------------------
# Setup (called once by GlobalSimulationCore)
# swarm_slices: Array of Dictionaries:
#   {
#       "start": int,
#       "count": int,
#       "swarm_id": int,
#       "params": Dictionary
#   }
# ---------------------------------------------------------
func setup(p_rd: RenderingDevice, buffers: Node, p_swarm_slices: Array) -> void:
	rd = p_rd
	swarm_slices = p_swarm_slices
	total_boid_count = buffers.total_boid_count

	# Load SPIR-V shader
	var folder: String = get_script().resource_path.get_base_dir()
	var shader_path: String = "res://example_7/boids/behaviours/Behaviour.glsl"
	print("BehaviourDispatcher: loading shader ", shader_path)

	var loaded_shader: Resource = load(shader_path)
	shader_file = loaded_shader as RDShaderFile

	if shader_file == null:
		push_error("BehaviourDispatcher: failed to load RDShaderFile at: " + shader_path)
		return

	var spirv: RDShaderSPIRV = shader_file.get_spirv()
	shader_rid = rd.shader_create_from_spirv(spirv)
	pipeline_rid = rd.compute_pipeline_create(shader_rid)

	# -----------------------------------------------------
	# Bind global buffers (adjust bindings to match GLSL)
	# -----------------------------------------------------
	var positions_buffer: RID = buffers.get_positions()
	var velocities_buffer: RID = buffers.get_velocities()
	var cell_start_buffer: RID = buffers.get_cell_start()
	var cell_end_buffer: RID = buffers.get_cell_end()
	var sorted_indices_buffer: RID = buffers.get_sorted_indices()

	var u_positions: RDUniform = RDUniform.new()
	u_positions.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	u_positions.binding = 0
	u_positions.add_id(positions_buffer)

	var u_velocities: RDUniform = RDUniform.new()
	u_velocities.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	u_velocities.binding = 1
	u_velocities.add_id(velocities_buffer)

	var u_cell_start: RDUniform = RDUniform.new()
	u_cell_start.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	u_cell_start.binding = 2
	u_cell_start.add_id(cell_start_buffer)

	var u_cell_end: RDUniform = RDUniform.new()
	u_cell_end.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	u_cell_end.binding = 3
	u_cell_end.add_id(cell_end_buffer)

	var u_sorted: RDUniform = RDUniform.new()
	u_sorted.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	u_sorted.binding = 4
	u_sorted.add_id(sorted_indices_buffer)

	var uniforms: Array = [u_positions, u_velocities, u_cell_start, u_cell_end, u_sorted]

	uniform_set = rd.uniform_set_create(uniforms, shader_rid, 0)

	if uniform_set == RID():
		push_error("BehaviourDispatcher: uniform_set is null in setup()")


	print("BehaviourDispatcher buffers:",
	" pos=", positions_buffer,
	" vel=", velocities_buffer,
	" start=", cell_start_buffer,
	" end=", cell_end_buffer,
	" sorted=", sorted_indices_buffer)

# ---------------------------------------------------------
# Run (called every frame by GlobalSimulationCore)
# One dispatch per swarm, using push constants for slice info
# ---------------------------------------------------------
func run(delta: float) -> void:
	if shader_rid == RID():
		push_error("BehaviourDispatcher: shader_rid is null")
		return

	if pipeline_rid == RID():
		push_error("BehaviourDispatcher: pipeline_rid is null")
		return

	if uniform_set == RID():
		push_error("BehaviourDispatcher: uniform_set is null")
		return

	for slice_data in swarm_slices:
		var slice_dict: Dictionary = slice_data

		var start_index: int = 0
		var count: int = 0
		var swarm_id: int = 0

		if slice_dict.has("start"):
			start_index = int(slice_dict["start"])

		if slice_dict.has("count"):
			count = int(slice_dict["count"])

		if slice_dict.has("swarm_id"):
			swarm_id = int(slice_dict["swarm_id"])

		if count <= 0:
			continue

		var cl: int = rd.compute_list_begin()
		rd.compute_list_bind_compute_pipeline(cl, pipeline_rid)
		rd.compute_list_bind_uniform_set(cl, uniform_set, 0)

		# -------------------------------------------------
		# Push constants layout (16 bytes):
		# int   start_index;
		# int   count;
		# int   swarm_id;
		# float delta;
		# -------------------------------------------------
		var pc: PackedByteArray = PackedByteArray()
		pc.resize(16)
		pc.encode_s32(0, start_index)
		pc.encode_s32(4, count)
		pc.encode_s32(8, swarm_id)
		pc.encode_float(12, delta)

		rd.compute_list_set_push_constant(cl, pc, pc.size())

		var group_size: int = 256
		var groups: int = int(ceil(float(count) / float(group_size)))

		rd.compute_list_dispatch(cl, groups, 1, 1)
		rd.compute_list_end()
