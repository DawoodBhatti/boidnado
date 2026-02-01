extends Node3D

"""
Standalone Visual Debugger
--------------------------
This node draws either:
 - wireframe spheres at each boid position, OR
 - velocity vectors for each boid.

It is completely independent from the renderer and GPU simulation logic.
Used only for debugging and visual verification of GPU_Debug buffers.
"""

# Debug toggles
@export var debug_print_enabled: bool = false

# Debug mode: "positions" or "velocities"
@export_enum("positions", "velocities") var debug_mode: String = "velocities"

# Sphere radius for position visualisation
@export var sphere_radius: float = 0.5

# Velocity vector scale
@export var velocity_scale: float = 3.0

# Run debug every N frames (1 = every frame)
@export var frequency: int = 120
var frame_counter: int = 0

# References
var swarm: Node = null
var gpu_debug: Node = null

# ImmediateMesh drawing
var im: ImmediateMesh
var mesh_instance: MeshInstance3D

# ---------------------------------------------------------
# Initialisation
# ---------------------------------------------------------
func _ready() -> void:
	# Swarm reference (parent node)
	swarm = get_parent()

	# GPU_Debug lives under GPU_SimulationCore
	gpu_debug = get_node("../../../GPU_SimulationCore/GPU_Debug")

	# Create ImmediateMesh + MeshInstance3D
	im = ImmediateMesh.new()
	mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = im

	# Simple unshaded material so colours show clearly
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh_instance.material_override = mat

	add_child(mesh_instance)
	mesh_instance.set_as_top_level(true)

# ---------------------------------------------------------
# Main loop with frequency control
# ---------------------------------------------------------
func _process(delta: float) -> void:
	frame_counter += 1

	# Only run when counter reaches frequency
	if frame_counter == frequency:
		frame_counter = 0
		_run_debug()

# ---------------------------------------------------------
# Debug logic (drawing + printing)
# ---------------------------------------------------------
func _run_debug() -> void:
	print("[VisualDebug]: running for swarm: ", swarm.name)

	if gpu_debug.positions_x.is_empty():
		if debug_print_enabled:
			print("DEBUG: GPU positions array is empty")
		return

	im.clear_surfaces()

	var start_index: int = swarm.start_index
	var count: int = swarm.count

	if debug_print_enabled:
		_debug_print(start_index, count)

	if debug_mode == "positions":
		_draw_positions(start_index, count)
	else:
		_draw_velocities(start_index, count)

# ---------------------------------------------------------
# POSITION VISUALISATION (wire spheres)
# ---------------------------------------------------------
func _draw_positions(start_index: int, count: int) -> void:
	# Draw wireframe spheres using 3 surfaces (x, y, z)
	_draw_axis_circles(start_index, count, "x")
	_draw_axis_circles(start_index, count, "y")
	_draw_axis_circles(start_index, count, "z")

func _draw_axis_circles(start_index: int, count: int, axis: String) -> void:
	var color: Color = swarm.colour
	var segments: int = 24

	im.surface_begin(Mesh.PRIMITIVE_LINES)
	im.surface_set_color(color)

	for i in range(count):
		var id: int = start_index + i

		var center: Vector3 = Vector3(
			gpu_debug.positions_x[id],
			gpu_debug.positions_y[id],
			gpu_debug.positions_z[id]
		)

		for s in range(segments):
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

# ---------------------------------------------------------
# VELOCITY VISUALISATION (lines)
# ---------------------------------------------------------
func _draw_velocities(start_index: int, count: int) -> void:
	var color: Color = swarm.colour

	im.surface_begin(Mesh.PRIMITIVE_LINES)
	im.surface_set_color(color)

	for i in range(count):
		var id: int = start_index + i

		var p: Vector3 = Vector3(
			gpu_debug.positions_x[id],
			gpu_debug.positions_y[id],
			gpu_debug.positions_z[id]
		)

		var v: Vector3 = Vector3(
			gpu_debug.velocities_x[id],
			gpu_debug.velocities_y[id],
			gpu_debug.velocities_z[id]
		)

		var p2: Vector3 = p + v.normalized() * velocity_scale

		im.surface_add_vertex(p)
		im.surface_add_vertex(p2)

	im.surface_end()

# ---------------------------------------------------------
# Debug print helper
# ---------------------------------------------------------
func _debug_print(start_index: int, count: int) -> void:
	print("\n[VisualDebug] Swarm slice: ", start_index, " → ", start_index + count - 1)

	var limit: int = min(count, 5)
	print("  First ", limit, " positions:")

	for i in range(limit):
		var id: int = start_index + i
		var p: Vector3 = Vector3(
			gpu_debug.positions_x[id],
			gpu_debug.positions_y[id],
			gpu_debug.positions_z[id]
		)
		print("    Boid ", id, ": ", p)
