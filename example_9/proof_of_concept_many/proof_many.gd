extends Node

var rd: RenderingDevice
var debug_buf: RID

var shader_pass1_rid: RID
var shader_pass2_rid: RID
var shader_pass3_rid: RID

var pipeline_pass1: RID
var pipeline_pass2: RID
var pipeline_pass3: RID


func _ready():
	RenderingServer.call_on_render_thread(_init_and_run)


func _init_and_run():
	rd = RenderingServer.get_rendering_device()

	_create_debug_buffer()
	_create_pipelines()

	_run_poc()
	call_deferred("_readback")


# ---------------------------------------------------------
# DEBUG SSBO
# ---------------------------------------------------------
func _create_debug_buffer():
	debug_buf = rd.storage_buffer_create(4)

	var init := PackedByteArray()
	init.resize(4)
	init.encode_u32(0, 1)

	# Correct call: RID, offset, size, data
	rd.buffer_update(debug_buf, 0, 4, init)

# ---------------------------------------------------------
# PIPELINES + SHADERS
# ---------------------------------------------------------
func _create_pipelines():
	var shader_pass1: Resource = load("res://example_9/proof_of_concept_many/pass1.glsl")
	var shader_pass2: Resource = load("res://example_9/proof_of_concept_many/pass2.glsl")
	var shader_pass3: Resource = load("res://example_9/proof_of_concept_many/pass3.glsl")

	shader_pass1_rid = rd.shader_create_from_spirv(shader_pass1.get_spirv())
	shader_pass2_rid = rd.shader_create_from_spirv(shader_pass2.get_spirv())
	shader_pass3_rid = rd.shader_create_from_spirv(shader_pass3.get_spirv())

	pipeline_pass1 = rd.compute_pipeline_create(shader_pass1_rid)
	pipeline_pass2 = rd.compute_pipeline_create(shader_pass2_rid)
	pipeline_pass3 = rd.compute_pipeline_create(shader_pass3_rid)


# ---------------------------------------------------------
# RUN MANY-PASS POC
# ---------------------------------------------------------
func _run_poc():
	# Shared uniform for all passes
	var u_buf := RDUniform.new()
	u_buf.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	u_buf.binding = 0
	u_buf.add_id(debug_buf)

	# Run 10 iterations of (pass1 → pass2 → pass3)
	for iteration in 10:
		print("running iteration: ", iteration)
		# PASS 1
		var list1 = rd.compute_list_begin()
		var set1 = rd.uniform_set_create([u_buf], shader_pass1_rid, 0)
		rd.compute_list_bind_compute_pipeline(list1, pipeline_pass1)
		rd.compute_list_bind_uniform_set(list1, set1, 0)
		rd.compute_list_dispatch(list1, 1, 1, 1)
		rd.compute_list_end()

		# PASS 2
		var list2 = rd.compute_list_begin()
		var set2 = rd.uniform_set_create([u_buf], shader_pass2_rid, 0)
		rd.compute_list_bind_compute_pipeline(list2, pipeline_pass2)
		rd.compute_list_bind_uniform_set(list2, set2, 0)
		rd.compute_list_dispatch(list2, 1, 1, 1)
		rd.compute_list_end()

		# PASS 3
		var list3 = rd.compute_list_begin()
		var set3 = rd.uniform_set_create([u_buf], shader_pass3_rid, 0)
		rd.compute_list_bind_compute_pipeline(list3, pipeline_pass3)
		rd.compute_list_bind_uniform_set(list3, set3, 0)
		rd.compute_list_dispatch(list3, 1, 1, 1)
		rd.compute_list_end()
		

# ---------------------------------------------------------
# CPU READBACK (NEXT FRAME)
# ---------------------------------------------------------
func _readback():
	var bytes := rd.buffer_get_data(debug_buf)
	var value := bytes.decode_u32(0)
	print("Final GPU value: ", value, " (expected 2047)")
