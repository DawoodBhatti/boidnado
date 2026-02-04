extends Node3D

@export var debug_print: bool = false
@export var frequency: int = 1
@export var point_size: float = 2.0
@export var max_density: int = 100

var frame_counter: int = 0

var swarm: Node = null
var gpu_buffers: Node = null

var im: ImmediateMesh
var mesh_instance: MeshInstance3D


func _ready() -> void:
	swarm = get_parent()
	gpu_buffers = get_node("../../../GPU_SimulationCore/GPU_Buffers")

	im = ImmediateMesh.new()
	mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = im

	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.use_point_size = true
	mat.point_size = point_size

	mesh_instance.material_override = mat
	add_child(mesh_instance)
	mesh_instance.set_as_top_level(true)


func _process(delta: float) -> void:
	frame_counter += 1
	if frame_counter >= frequency:
		frame_counter = 0
		_run_debug()


func _run_debug() -> void:
	if debug_print:
		print("[VisualDebug]: running for swarm: ", swarm.name)

	# GPU buffer reads
	var pos_x: PackedFloat32Array = gpu_buffers.rd.buffer_get_data(gpu_buffers.positions_x_buffer).to_float32_array()
	var pos_y: PackedFloat32Array = gpu_buffers.rd.buffer_get_data(gpu_buffers.positions_y_buffer).to_float32_array()
	var pos_z: PackedFloat32Array = gpu_buffers.rd.buffer_get_data(gpu_buffers.positions_z_buffer).to_float32_array()

	var cell_ids: PackedInt32Array = gpu_buffers.rd.buffer_get_data(gpu_buffers.cell_id_buffer).to_int32_array()
	var cell_counts: PackedInt32Array = gpu_buffers.rd.buffer_get_data(gpu_buffers.cell_counts_buffer).to_int32_array()

	if pos_x.is_empty():
		if debug_print:
			print("DEBUG: GPU positions array is empty")
		return

	im.clear_surfaces()

	var start_index: int = swarm.start_index
	var count: int = swarm.count

	if debug_print:
		_debug_print(start_index, count, pos_x, pos_y, pos_z)

	_draw_points(start_index, count, pos_x, pos_y, pos_z, cell_ids, cell_counts)

func _draw_points(
		start_index: int,
		count: int,
		pos_x: PackedFloat32Array,
		pos_y: PackedFloat32Array,
		pos_z: PackedFloat32Array,
		cell_ids: PackedInt32Array,
		cell_counts: PackedInt32Array
	) -> void:

	im.surface_begin(Mesh.PRIMITIVE_POINTS)

	var base_color: Color = swarm.colour

	for i: int in range(count):
		var id: int = start_index + i

		var p: Vector3 = Vector3(pos_x[id], pos_y[id], pos_z[id])
		var cell: int = cell_ids[id]

		if cell < 0 or cell >= cell_counts.size():
			continue

		var density: float = float(cell_counts[cell])
		var t: float = clamp(density / float(max_density), 0.0, 1.0)

		# Keep the swarm's RGB, scale only alpha
		var color: Color = Color(base_color.r, base_color.g, base_color.b, t)

		im.surface_set_color(color)
		im.surface_add_vertex(p)

	im.surface_end()


func _debug_print(
		start_index: int,
		count: int,
		pos_x: PackedFloat32Array,
		pos_y: PackedFloat32Array,
		pos_z: PackedFloat32Array
	) -> void:

	print("\n[VisualDebug] Swarm slice: ", start_index, " → ", start_index + count - 1)

	var limit: int = min(count, 5)
	print("  First ", limit, " positions:")

	for i: int in range(limit):
		var id: int = start_index + i
		var p: Vector3 = Vector3(pos_x[id], pos_y[id], pos_z[id])
		print("    Boid ", id, ": ", p)
