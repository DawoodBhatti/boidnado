extends Node3D

@export var debug_print: bool = false
@export_enum("positions", "velocities") var debug_mode: String = "velocities"
@export var sphere_radius: float = 0.5
@export var velocity_scale: float = 3.0
@export var frequency: int = 1

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
	mat.vertex_color_use_as_albedo = true
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
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

	# Read GPU buffers directly
	var pos_x: PackedFloat32Array = gpu_buffers.rd.buffer_get_data(gpu_buffers.positions_x_buffer).to_float32_array()
	var pos_y: PackedFloat32Array = gpu_buffers.rd.buffer_get_data(gpu_buffers.positions_y_buffer).to_float32_array()
	var pos_z: PackedFloat32Array = gpu_buffers.rd.buffer_get_data(gpu_buffers.positions_z_buffer).to_float32_array()

	var vel_x: PackedFloat32Array = gpu_buffers.rd.buffer_get_data(gpu_buffers.velocities_x_buffer).to_float32_array()
	var vel_y: PackedFloat32Array = gpu_buffers.rd.buffer_get_data(gpu_buffers.velocities_y_buffer).to_float32_array()
	var vel_z: PackedFloat32Array = gpu_buffers.rd.buffer_get_data(gpu_buffers.velocities_z_buffer).to_float32_array()

	if pos_x.is_empty():
		if debug_print:
			print("DEBUG: GPU positions array is empty")
		return

	im.clear_surfaces()

	var start_index: int = swarm.start_index
	var count: int = swarm.count

	if debug_print:
		_debug_print(start_index, count, pos_x, pos_y, pos_z)

	if debug_mode == "positions":
		_draw_positions(start_index, count, pos_x, pos_y, pos_z)
	else:
		_draw_velocities(start_index, count, pos_x, pos_y, pos_z, vel_x, vel_y, vel_z)


func _draw_positions(start_index: int, count: int,
		pos_x: PackedFloat32Array,
		pos_y: PackedFloat32Array,
		pos_z: PackedFloat32Array) -> void:

	_draw_axis_circles(start_index, count, "x", pos_x, pos_y, pos_z)
	_draw_axis_circles(start_index, count, "y", pos_x, pos_y, pos_z)
	_draw_axis_circles(start_index, count, "z", pos_x, pos_y, pos_z)


func _draw_axis_circles(start_index: int, count: int, axis: String,
		pos_x: PackedFloat32Array,
		pos_y: PackedFloat32Array,
		pos_z: PackedFloat32Array) -> void:

	var color: Color = swarm.colour
	var segments: int = 24

	im.surface_begin(Mesh.PRIMITIVE_LINES)
	im.surface_set_color(color)

	for i: int in range(count):
		var id: int = start_index + i

		var center: Vector3 = Vector3(pos_x[id], pos_y[id], pos_z[id])

		for s: int in range(segments):
			var a1: float = float(s) / float(segments) * TAU
			var a2: float = float(s + 1) / float(segments) * TAU

			var p1: Vector3
			var p2: Vector3

			if axis == "x":
				p1 = center + Vector3(0.0, cos(a1), sin(a1)) * sphere_radius
				p2 = center + Vector3(0.0, cos(a2), sin(a2)) * sphere_radius
			elif axis == "y":
				p1 = center + Vector3(cos(a1), 0.0, sin(a1)) * sphere_radius
				p2 = center + Vector3(cos(a2), 0.0, sin(a2)) * sphere_radius
			else:
				p1 = center + Vector3(cos(a1), sin(a1), 0.0) * sphere_radius
				p2 = center + Vector3(cos(a2), sin(a2), 0.0) * sphere_radius

			im.surface_add_vertex(p1)
			im.surface_add_vertex(p2)

	im.surface_end()


func _draw_velocities(start_index: int, count: int,
		pos_x: PackedFloat32Array,
		pos_y: PackedFloat32Array,
		pos_z: PackedFloat32Array,
		vel_x: PackedFloat32Array,
		vel_y: PackedFloat32Array,
		vel_z: PackedFloat32Array) -> void:

	var color: Color = swarm.colour

	im.surface_begin(Mesh.PRIMITIVE_LINES)
	im.surface_set_color(color)

	for i: int in range(count):
		var id: int = start_index + i

		var p: Vector3 = Vector3(pos_x[id], pos_y[id], pos_z[id])
		var v: Vector3 = Vector3(vel_x[id], vel_y[id], vel_z[id])

		var p2: Vector3 = p + v.normalized() * velocity_scale

		im.surface_add_vertex(p)
		im.surface_add_vertex(p2)

	im.surface_end()


func _debug_print(start_index: int, count: int,
		pos_x: PackedFloat32Array,
		pos_y: PackedFloat32Array,
		pos_z: PackedFloat32Array) -> void:

	print("\n[VisualDebug] Swarm slice: ", start_index, " → ", start_index + count - 1)

	var limit: int = min(count, 5)
	print("  First ", limit, " positions:")

	for i: int in range(limit):
		var id: int = start_index + i
		var p: Vector3 = Vector3(pos_x[id], pos_y[id], pos_z[id])
		print("    Boid ", id, ": ", p)
