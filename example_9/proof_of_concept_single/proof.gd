extends Node

var rd: RenderingDevice

var tex: RID
var debug_buf: RID

var shader_write_rid: RID
var shader_read_rid: RID

var pipeline_write: RID
var pipeline_read: RID


func _ready():
	RenderingServer.call_on_render_thread(_init_and_run)


func _init_and_run():
	rd = RenderingServer.get_rendering_device()

	_create_pipelines()
	_create_texture()
	_create_debug_buffer()

	_run_poc()


# ---------------------------------------------------------
# TEXTURE
# ---------------------------------------------------------
func _create_texture():
	var fmt := RDTextureFormat.new()
	fmt.width = 1
	fmt.height = 1
	fmt.depth = 1
	fmt.array_layers = 1
	fmt.mipmaps = 1
	fmt.texture_type = RenderingDevice.TEXTURE_TYPE_2D
	fmt.format = RenderingDevice.DATA_FORMAT_R32_UINT
	fmt.usage_bits = RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT

	var view := RDTextureView.new()
	tex = rd.texture_create(fmt, view, [])


# ---------------------------------------------------------
# DEBUG SSBO
# ---------------------------------------------------------
func _create_debug_buffer():
	debug_buf = rd.storage_buffer_create(4)


# ---------------------------------------------------------
# PIPELINES + SHADERS
# ---------------------------------------------------------
func _create_pipelines():
	var shader_write: Resource = load("res://example_9/proof_of_concept_single/write_texture.glsl")
	var shader_read:  Resource = load("res://example_9/proof_of_concept_single/read_texture.glsl")

	shader_write_rid = rd.shader_create_from_spirv(shader_write.get_spirv())
	shader_read_rid  = rd.shader_create_from_spirv(shader_read.get_spirv())

	pipeline_write = rd.compute_pipeline_create(shader_write_rid)
	pipeline_read  = rd.compute_pipeline_create(shader_read_rid)


# ---------------------------------------------------------
# RUN POC (OceanFFT-style)
# ---------------------------------------------------------
func _run_poc():
	# -------------------------
	# LIST 1: write to texture
	# -------------------------
	var list1 = rd.compute_list_begin()

	var u_tex_write := RDUniform.new()
	u_tex_write.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	u_tex_write.binding = 0
	u_tex_write.add_id(tex)

	var set_write = rd.uniform_set_create([u_tex_write], shader_write_rid, 0)

	rd.compute_list_bind_compute_pipeline(list1, pipeline_write)
	rd.compute_list_bind_uniform_set(list1, set_write, 0)

	var push := PackedByteArray()
	push.resize(16)
	push.encode_u32(0, 12345)
	rd.compute_list_set_push_constant(list1, push, 16)

	rd.compute_list_dispatch(list1, 1, 1, 1)
	rd.compute_list_end()


	# -------------------------
	# LIST 2: read from texture
	# -------------------------
	var list2 = rd.compute_list_begin()

	var u_tex_read := RDUniform.new()
	u_tex_read.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	u_tex_read.binding = 0
	u_tex_read.add_id(tex)

	var u_buf := RDUniform.new()
	u_buf.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	u_buf.binding = 1
	u_buf.add_id(debug_buf)

	var set_read = rd.uniform_set_create([u_tex_read, u_buf], shader_read_rid, 0)

	rd.compute_list_bind_compute_pipeline(list2, pipeline_read)
	rd.compute_list_bind_uniform_set(list2, set_read, 0)
	rd.compute_list_dispatch(list2, 1, 1, 1)

	rd.compute_list_end()


	# -----------------------------------------------------
	# CPU READBACK MUST HAPPEN NEXT FRAME
	# -----------------------------------------------------
	call_deferred("_readback")


func _readback():
	var bytes := rd.buffer_get_data(debug_buf)
	var value := bytes.decode_u32(0)
	print("GPU readback value: ", value)
