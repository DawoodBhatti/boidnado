extends Node3D

"""
VisualDebug.gd
--------------
Standalone per-swarm debug visualiser.

Responsibilities:
 - Draw grid cells around a selected boid
 - Draw FOV cone
 - Draw velocity vectors (single or all)
 - Draw wireframe spheres
 - Read-only access to GPU_Debug CPU arrays
 - No neighbour visualisation
"""

# ---------------------------------------------------------
# Debug Toggles
# ---------------------------------------------------------
@export var target_local_index: int = 0

@export var show_grid: bool = false
@export var show_debug_boid: bool = false
@export var show_FOV_cone: bool = false
@export var show_velocity_single: bool = false
@export var show_velocity_all: bool = false

# ---------------------------------------------------------
# References
# ---------------------------------------------------------
var swarm: Node = null
var gpu_debug: Node = null

var start_index: int = 0
var count: int = 0

# ---------------------------------------------------------
# Meshes
# ---------------------------------------------------------
var im_grid: ImmediateMesh
var im_highlight: ImmediateMesh
var mesh_grid: MeshInstance3D
var mesh_highlight: MeshInstance3D

# ---------------------------------------------------------
# Surface state
# ---------------------------------------------------------
var surface_state: Dictionary = {}

func _ensure_state(im: ImmediateMesh) -> void:
	if not surface_state.has(im):
		surface_state[im] = {
			"active": false,
			"vertex_count": 0
		}

func begin_surface(im: ImmediateMesh, primitive: int, color: Color) -> void:
	_ensure_state(im)
	var st: Dictionary = surface_state[im]

	if st["active"] == true:
		im.surface_end()

	im.surface_begin(primitive)
	im.surface_set_color(color)

	st["active"] = true
	st["vertex_count"] = 0

func add_vertex(im: ImmediateMesh, v: Vector3) -> void:
	_ensure_state(im)
	var st: Dictionary = surface_state[im]

	if st["active"] == true:
		im.surface_add_vertex(v)
		st["vertex_count"] += 1

func end_surface(im: ImmediateMesh) -> void:
	_ensure_state(im)
	var st: Dictionary = surface_state[im]

	if st["active"] == true and st["vertex_count"] > 0:
		im.surface_end()

	st["active"] = false
	st["vertex_count"] = 0

# ---------------------------------------------------------
# Visual parameters
# ---------------------------------------------------------
var cell_length: float = 4.0
var color_grid: Color = Color(0.2, 0.2, 0.2)
var color_highlight: Color = Color(1.0, 0.0, 0.0)
var color_velocity: Color = Color(1.0, 1.0, 0.0)
var default_color: Color = Color(1,1,1)

# ---------------------------------------------------------
# Init
# ---------------------------------------------------------
func _ready() -> void:
	swarm = get_parent()
	start_index = swarm.start_index
	count = swarm.count
	default_color = swarm.colour

	gpu_debug = get_node("../../GPU_SimulationCore/GPU_Debug")

	_init_meshes()

func _init_meshes() -> void:
	im_grid = ImmediateMesh.new()
	mesh_grid = MeshInstance3D.new()
	mesh_grid.mesh = im_grid

	var mat_grid: StandardMaterial3D = StandardMaterial3D.new()
	mat_grid.vertex_color_use_as_albedo = true
	mat_grid.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh_grid.material_override = mat_grid

	add_child(mesh_grid)
	mesh_grid.set_as_top_level(true)

	im_highlight = ImmediateMesh.new()
	mesh_highlight = MeshInstance3D.new()
	mesh_highlight.mesh = im_highlight

	var mat_high: StandardMaterial3D = StandardMaterial3D.new()
	mat_high.vertex_color_use_as_albedo = true
	mat_high.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_high.render_priority = 10
	mesh_highlight.material_override = mat_high

	add_child(mesh_highlight)
	mesh_highlight.set_as_top_level(true)

# ---------------------------------------------------------
# Main Loop
# ---------------------------------------------------------
func _process(delta: float) -> void:
	if gpu_debug.positions_x.is_empty():
		return

	im_grid.clear_surfaces()
	im_highlight.clear_surfaces()
	surface_state.clear()

	if count <= 0:
		return

	if show_debug_boid or show_grid or show_FOV_cone or show_velocity_single:
		_draw_single_debug()

	if show_velocity_all:
		_draw_velocity_all(im_grid, color_velocity)

# ---------------------------------------------------------
# Single-boid debug
# ---------------------------------------------------------
func _draw_single_debug() -> void:
	var local_i: int = clamp(target_local_index, 0, count - 1)
	var id: int = start_index + local_i

	var pos: Vector3 = Vector3(
		gpu_debug.positions_x[id],
		gpu_debug.positions_y[id],
		gpu_debug.positions_z[id]
	)

	if show_grid:
		var cell_x: int = int(pos.x / cell_length)
		var cell_y: int = int(pos.y / cell_length)
		var cell_z: int = int(pos.z / cell_length)
		var central_cell: Vector3i = Vector3i(cell_x, cell_y, cell_z)
		_draw_world_cells(central_cell)

	if show_debug_boid:
		var r: float = _get_sight_radius()
		_draw_wire_sphere(im_grid, pos, r, Color(0.3, 0.3, 1.0))

	if show_velocity_single and not show_velocity_all:
		_draw_velocity_single(im_grid, id, color_velocity)

	if show_FOV_cone:
		_draw_fov_cone(im_grid, id, Color(0.0, 0.0, 1.0))

# ---------------------------------------------------------
# Swarm params helpers
# ---------------------------------------------------------
func _get_sight_radius() -> float:
	var floats: PackedFloat32Array = gpu_debug.swarm_params
	var swarm_idx: int = start_index / count
	var base: int = swarm_idx * 16
	return floats[base + 2]

func _get_fov_angle() -> float:
	var floats: PackedFloat32Array = gpu_debug.swarm_params
	var swarm_idx: int = start_index / count
	var base: int = swarm_idx * 16
	var deg: float = floats[base + 3]
	return deg_to_rad(deg)

# ---------------------------------------------------------
# Grid drawing
# ---------------------------------------------------------
func _draw_world_cells(central_cell: Vector3i) -> void:
	for x in range(central_cell.x - 1, central_cell.x + 2):
		for y in range(central_cell.y - 1, central_cell.y + 2):
			for z in range(central_cell.z - 1, central_cell.z + 2):
				var cell: Vector3i = Vector3i(x, y, z)

				var color: Color = color_grid
				var im: ImmediateMesh = im_grid

				if cell == central_cell:
					color = color_highlight
					im = im_highlight

				_draw_cell(im, cell, color)

func _draw_cell(im: ImmediateMesh, cell: Vector3i, color: Color) -> void:
	var L: float = cell_length
	var nx: int = cell.x
	var ny: int = cell.y
	var nz: int = cell.z

	begin_surface(im, Mesh.PRIMITIVE_LINES, color)

	var corners: Array = [
		Vector3(nx * L, ny * L, nz * L),
		Vector3(nx * L, (ny + 1) * L, nz * L),
		Vector3(nx * L, (ny + 1) * L, (nz + 1) * L),
		Vector3(nx * L, ny * L, (nz + 1) * L),
		Vector3((nx + 1) * L, ny * L, nz * L),
		Vector3((nx + 1) * L, (ny + 1) * L, nz * L),
		Vector3((nx + 1) * L, (ny + 1) * L, (nz + 1) * L),
		Vector3((nx + 1) * L, ny * L, (nz + 1) * L)
	]

	var edges: Array = [
		[0, 1], [1, 2], [2, 3], [3, 0],
		[4, 5], [5, 6], [6, 7], [7, 4],
		[0, 4], [1, 5], [2, 6], [3, 7]
	]

	for edge in edges:
		var i0: int = edge[0]
		var i1: int = edge[1]
		add_vertex(im, corners[i0])
		add_vertex(im, corners[i1])

	end_surface(im)

# ---------------------------------------------------------
# Velocity vectors
# ---------------------------------------------------------
func _draw_velocity_single(im: ImmediateMesh, id: int, color: Color) -> void:
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

	begin_surface(im, Mesh.PRIMITIVE_LINES, color)
	add_vertex(im, p)
	add_vertex(im, p + v.normalized() * 3.0)
	end_surface(im)

func _draw_velocity_all(im: ImmediateMesh, color: Color) -> void:
	begin_surface(im, Mesh.PRIMITIVE_LINES, color)

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

		add_vertex(im, p)
		add_vertex(im, p + v.normalized() * 3.0)

	end_surface(im)

# ---------------------------------------------------------
# Wireframe sphere
# ---------------------------------------------------------
func _draw_wire_sphere(im: ImmediateMesh, center: Vector3, radius: float, color: Color) -> void:
	_draw_wire_circle(im, center, radius, color, "x")
	_draw_wire_circle(im, center, radius, color, "y")
	_draw_wire_circle(im, center, radius, color, "z")

func _draw_wire_circle(im: ImmediateMesh, center: Vector3, radius: float, color: Color, axis: String) -> void:
	var segments: int = 24
	begin_surface(im, Mesh.PRIMITIVE_LINES, color)

	for s in range(segments):
		var a1: float = float(s) / float(segments) * TAU
		var a2: float = float(s + 1) / float(segments) * TAU

		var p1: Vector3
		var p2: Vector3

		if axis == "x":
			p1 = center + Vector3(0.0, cos(a1), sin(a1)) * radius
			p2 = center + Vector3(0.0, cos(a2), sin(a2)) * radius
		elif axis == "y":
			p1 = center + Vector3(cos(a1), 0.0, sin(a1)) * radius
			p2 = center + Vector3(cos(a2), 0.0, sin(a2)) * radius
		else:
			p1 = center + Vector3(cos(a1), sin(a1), 0.0) * radius
			p2 = center + Vector3(cos(a2), sin(a2), 0.0) * radius

		add_vertex(im, p1)
		add_vertex(im, p2)

	end_surface(im)

# ---------------------------------------------------------
# FOV cone
# ---------------------------------------------------------
func _draw_fov_cone(im: ImmediateMesh, id: int, cone_color: Color) -> void:
	var phi: float = _get_fov_angle()
	var sight_radius: float = _get_sight_radius()

	var p: Vector3 = Vector3(
		gpu_debug.positions_x[id],
		gpu_debug.positions_y[id],
		gpu_debug.positions_z[id]
	)

	var v: Vector3 = Vector3(
		gpu_debug.velocities_x[id],
		gpu_debug.velocities_y[id],
		gpu_debug.velocities_z[id]
	).normalized()

	var segments: int = 32
	var rim_points: PackedVector3Array = PackedVector3Array()

	var circle_normal: Vector3 = Vector3(0.0, 0.0, 1.0)
	var perp_axis: Vector3 = circle_normal.cross(v).normalized()
	var angle_between: float = acos(circle_normal.dot(v))
	var rotation_basis: Basis = Basis(perp_axis, angle_between)
	var transform: Transform3D = Transform3D(rotation_basis, p)

	var phi_vis: float = phi
	var dir_sign: float = 1.0

	if phi > PI * 0.5:
		phi_vis = PI - phi
		dir_sign = -1.0
		cone_color = Color(1.0, 0.0, 0.0)

	var r: float = dir_sign * sight_radius * cos(phi_vis)
	var radius_scaled: float = sight_radius * sin(phi_vis)

	for s in range(segments):
		var a: float = float(s) / float(segments) * TAU
		var coord: Vector3 = Vector3(
			radius_scaled * sin(a),
			radius_scaled * cos(a),
			r
		)
		var coord_transformed: Vector3 = transform * coord
		rim_points.append(coord_transformed)

	begin_surface(im, Mesh.PRIMITIVE_LINES, cone_color)

	for rp in rim_points:
		add_vertex(im, p)
		add_vertex(im, rp)

	end_surface(im)
