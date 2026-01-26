extends Node

var rd: RenderingDevice
var shader_rid: RID
var pipeline_rid: RID
var uniform_set: RID
var shader_file: RDShaderFile

var total_boid_count: int = 0


# ---------------------------------------------------------
# Setup (called once by GlobalSimulationCore)
# ---------------------------------------------------------
func setup(p_rd: RenderingDevice, buffers: Node) -> void:
	rd = p_rd
	total_boid_count = buffers.total_boid_count

	# Load SPIR-V shader
	var folder: String = get_script().resource_path.get_base_dir()
	var shader_path: String = folder + "/IntegrationPass.glsl"
	print("IntegrationPass: loading shader ", shader_path)

	var loaded_shader: Resource = load(shader_path)
	shader_file = loaded_shader as RDShaderFile

	if shader_file == null:
		push_error("IntegrationPass: failed to load RDShaderFile at: " + shader_path)
		return

	var spirv: RDShaderSPIRV = shader_file.get_spirv()
	shader_rid = rd.shader_create_from_spirv(spirv)
	pipeline_rid = rd.compute_pipeline_create(shader_rid)

	# -----------------------------------------------------
	# Bind global buffers (adjust bindings to match GLSL)
	# -----------------------------------------------------
	var positions_buffer: RID = buffers.get_positions()
	var velocities_buffer: RID = buffers.get_velocities()

	var u_positions: RDUniform = RDUniform.new()
	u_positions.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	u_positions.binding = 0
	u_positions.add_id(positions_buffer)

	var u_velocities: RDUniform = RDUniform.new()
	u_velocities.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	u_velocities.binding = 1
	u_velocities.add_id(velocities_buffer)

	var uniforms: Array = [u_positions, u_velocities]

	uniform_set = rd.uniform_set_create(uniforms, shader_rid, 0)

	if uniform_set == RID():
		push_error("IntegrationPass: uniform_set is null in setup()")


# ---------------------------------------------------------
# Run (called every frame by GlobalSimulationCore)
# ---------------------------------------------------------
func run(delta: float) -> void:
	if shader_rid == RID():
		push_error("IntegrationPass: shader_rid is null")
		return

	if pipeline_rid == RID():
		push_error("IntegrationPass: pipeline_rid is null")
		return

	if uniform_set == RID():
		push_error("IntegrationPass: uniform_set is null")
		return

	var cl: int = rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(cl, pipeline_rid)
	rd.compute_list_bind_uniform_set(cl, uniform_set, 0)

	# -----------------------------------------------------
	# Push constants layout (16 bytes):
	# float delta;
	# float pad0;
	# float pad1;
	# float pad2;
	# -----------------------------------------------------
	var pc: PackedByteArray = PackedByteArray()
	pc.resize(16)
	pc.encode_float(0, delta)
	pc.encode_float(4, 0.0)
	pc.encode_float(8, 0.0)
	pc.encode_float(12, 0.0)

	rd.compute_list_set_push_constant(cl, pc, pc.size())

	var group_size: int = 256
	var groups: int = int(ceil(float(total_boid_count) / float(group_size)))

	rd.compute_list_dispatch(cl, groups, 1, 1)
	rd.compute_list_end()
