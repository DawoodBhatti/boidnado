extends Node

var gpu_device : Node
var gpu_buffers : Node

var pipeline_rid : RID
var uniform_set_rid : RID

var _initialised := false

var debug := true

func _ready() -> void:
	gpu_device = get_node("../../GPU_Device")
	gpu_buffers = get_node("../../GPU_Buffers")

	pipeline_rid = gpu_device.grid_assign_pipeline


func _init_pass(rd: RenderingDevice) -> void:

	if debug:
		#TODO seeing a strange bug where the grid assign fires before we have completed this init pass
		#can come back to it soon.
		print("\n[GridAssign] --- INIT PASS ---")

	# Strong asserts: GPU_Device must be fully initialised
	assert(gpu_device.grid_assign_rid.is_valid())
	assert(gpu_device.grid_assign_pipeline.is_valid())

	# Pull RDUniform descriptors
	var u_pos_x : RDUniform = gpu_buffers.u_pos_x
	var u_pos_y : RDUniform = gpu_buffers.u_pos_y
	var u_pos_z : RDUniform = gpu_buffers.u_pos_z
	var u_global : RDUniform = gpu_buffers.u_global
	var u_cell_id : RDUniform = gpu_buffers.u_cell_id

	if debug:
		# Print descriptor sanity
		print("[GridAssign] u_pos_x:", u_pos_x)
		print("[GridAssign] u_pos_y:", u_pos_y)
		print("[GridAssign] u_pos_z:", u_pos_z)
		print("[GridAssign] u_global:", u_global)
		print("[GridAssign] u_cell_id:", u_cell_id)
		
		# Print binding ids
		print("u_pos_x.binding =", u_pos_x.binding)
		print("u_pos_y.binding =", u_pos_y.binding)
		print("u_pos_z.binding =", u_pos_z.binding)
		print("u_global.binding =", u_global.binding)
		print("u_cell_id.binding =", u_cell_id.binding)

		# Print buffer RIDs inside descriptors
		print("[GridAssign] pos_x buffer RID:", gpu_buffers.positions_x_buffer)
		print("[GridAssign] pos_y buffer RID:", gpu_buffers.positions_y_buffer)
		print("[GridAssign] pos_z buffer RID:", gpu_buffers.positions_z_buffer)
		print("[GridAssign] global buffer RID:", gpu_buffers.global_params_buffer)
		print("[GridAssign] cell_id buffer RID:", gpu_buffers.cell_id_buffer)

	# Create uniform set
	uniform_set_rid = rd.uniform_set_create(
		[
			u_pos_x, u_pos_y, u_pos_z,
			u_global,
			u_cell_id
		],
		gpu_device.grid_assign_rid,
		0
	)
	if debug:
		print("[GridAssign] uniform_set_rid:", uniform_set_rid)

	_initialised = true
	
	if debug:
		print("[GridAssign] INIT COMPLETE\n")


func run(rd: RenderingDevice, compute_list: int, workgroup_count: int) -> void:
	if not _initialised:
		_init_pass(rd)

	_print_dispatch_message()
	_dispatch(rd, compute_list, workgroup_count)


func _print_dispatch_message() -> void:
	print(name, ": dispatching grid_assign compute shader")


func _dispatch(rd: RenderingDevice, list: int, N: int) -> void:
	if debug:
		
		print("\n[GridAssign] --- DISPATCH ---")
		print("[GridAssign] pipeline_rid:", pipeline_rid)
		print("[GridAssign] uniform_set_rid:", uniform_set_rid)
		print("[GridAssign] workgroups:", N)

	rd.compute_list_bind_compute_pipeline(list, pipeline_rid)
	rd.compute_list_bind_uniform_set(list, uniform_set_rid, 0)
	rd.compute_list_dispatch(list, N, 1, 1)

	if debug:
		print("[GridAssign] DISPATCH COMPLETE\n")
