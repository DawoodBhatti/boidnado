extends Node3D

# ---------------------------------------------------------
# VisualDebug (Per‑Swarm)
# ---------------------------------------------------------
# Responsibilities:
#   - Visualize a single boid (grid, neighbours, FOV, velocity)
#   - Visualize the whole swarm (velocities only)
#   - Read-only access to BoidData (no recomputation)
# ---------------------------------------------------------

# ---------------------------------------------------------
# Debug Toggles
# ---------------------------------------------------------
@export var target_local_index: int = 0

@export var show_grid: bool = true
@export var show_debug_boid: bool = true
@export var show_neighbours: bool = true
@export var show_FOV_cone: bool = true
@export var show_velocity_single: bool = true
@export var show_velocity_all: bool = true

# ---------------------------------------------------------
# References
# ---------------------------------------------------------
var swarm_data: Node = null
var global_grid: Node3D = null

# ---------------------------------------------------------
# Meshes
# ---------------------------------------------------------
var im_grid: ImmediateMesh
var im_highlight: ImmediateMesh
var mesh_grid: MeshInstance3D
var mesh_highlight: MeshInstance3D

# ---------------------------------------------------------
# Surface state (per-mesh)
# ---------------------------------------------------------
var surface_state := {}   # ImmediateMesh -> { active: bool, vertex_count: int }

func _ensure_state(im: ImmediateMesh) -> void:
	if not surface_state.has(im):
		surface_state[im] = {
			"active": false,
			"vertex_count": 0
		}

func begin_surface(im: ImmediateMesh, primitive: int, color: Color) -> void:
	_ensure_state(im)
	var st = surface_state[im]

	# If a surface is already active on this mesh, end it first
	if st["active"]:
		im.surface_end()

	im.surface_begin(primitive)
	im.surface_set_color(color)
	st["active"] = true
	st["vertex_count"] = 0

func add_vertex(im: ImmediateMesh, v: Vector3) -> void:
	_ensure_state(im)
	var st = surface_state[im]

	if st["active"]:
		im.surface_add_vertex(v)
		st["vertex_count"] += 1

func end_surface(im: ImmediateMesh) -> void:
	_ensure_state(im)
	var st = surface_state[im]

	if st["active"] and st["vertex_count"] > 0:
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
var color_neighbour: Color = Color(0.0, 1.0, 0.0)
var color_single: Color = Color(1.0, 1.0, 1.0)
var default_color: Color

# ---------------------------------------------------------
# Initialization (injected from Swarm)
# ---------------------------------------------------------
func initialize(data_in: Node, global_grid_node: Node3D, swarm_color: Color) -> void:
	swarm_data = data_in
	global_grid = global_grid_node
	default_color = swarm_color

	# Hack override colours
	color_grid = default_color

	# Grid mesh
	im_grid = ImmediateMesh.new()
	mesh_grid = MeshInstance3D.new()
	mesh_grid.mesh = im_grid

	var mat_grid: StandardMaterial3D = StandardMaterial3D.new()
	mat_grid.vertex_color_use_as_albedo = true
	mat_grid.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh_grid.material_override = mat_grid

	add_child(mesh_grid)
	mesh_grid.set_as_top_level(true)

	# Highlight mesh
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
	if swarm_data == null:
		return

	im_grid.clear_surfaces()
	im_highlight.clear_surfaces()

	# Reset surface state each frame
	surface_state.clear()

	# Mode 1: single debug boid (representative)
	if show_debug_boid or show_grid or show_neighbours or show_FOV_cone or show_velocity_single:
		_draw_single_debug()

	# Mode 2: whole swarm velocities only
	if show_velocity_all:
		_draw_velocity_all(im_grid, color_velocity)

# ---------------------------------------------------------
# Single‑boid debug path
# ---------------------------------------------------------
func _draw_single_debug() -> void:
	if swarm_data.boid_count <= 0:
		return

	var local_i: int = clamp(target_local_index, 0, swarm_data.boid_count - 1)
	var pos: Vector3 = swarm_data.positions[local_i]
	var neighbours: PackedInt32Array = swarm_data.neighbours[local_i]
	var central_cell: Vector3i = global_grid.cell_from_pos(pos)

	# Grid around this boid
	if show_grid:
		_draw_world_cells(central_cell)

	# Highlight this boid using its sight radius
	if show_debug_boid:
		var r: float = swarm_data.limits["sight_radius"]
		_draw_wire_sphere(im_grid, pos, r, Color(0.3, 0.3, 1.0))

	# Neighbours of this boid
	if show_neighbours:
		for local_j: int in neighbours:
			var p_n: Vector3 = swarm_data.positions[local_j]
			_draw_wire_sphere(im_grid, p_n, 0.5, color_neighbour)

	# Single velocity vector
	if show_velocity_single and not show_velocity_all:
		_draw_velocity_single(im_grid, local_i, color_velocity)

	# FOV cone
	if show_FOV_cone:
		_draw_fov_cone(im_grid, local_i, Color(0.0, 0.0, 1.0))

# ---------------------------------------------------------
# Draw world cells (around a single boid)
# ---------------------------------------------------------
func _draw_world_cells(central_cell: Vector3i) -> void:
	for x: int in range(central_cell.x - 1, central_cell.x + 2):
		for y: int in range(central_cell.y - 1, central_cell.y + 2):
			for z: int in range(central_cell.z - 1, central_cell.z + 2):
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

	var corners: Array[Vector3] = [
		Vector3(nx * L, ny * L, nz * L),
		Vector3(nx * L, (ny + 1) * L, nz * L),
		Vector3(nx * L, (ny + 1) * L, (nz + 1) * L),
		Vector3(nx * L, ny * L, (nz + 1) * L),
		Vector3((nx + 1) * L, ny * L, nz * L),
		Vector3((nx + 1) * L, (ny + 1) * L, nz * L),
		Vector3((nx + 1) * L, (ny + 1) * L, (nz + 1) * L),
		Vector3((nx + 1) * L, ny * L, (nz + 1) * L)
	]

	var edges: Array[Array] = [
		[0, 1], [1, 2], [2, 3], [3, 0],
		[4, 5], [5, 6], [6, 7], [7, 4],
		[0, 4], [1, 5], [2, 6], [3, 7]
	]

	for edge: Array in edges:
		var i0: int = edge[0]
		var i1: int = edge[1]
		add_vertex(im, corners[i0])
		add_vertex(im, corners[i1])

	end_surface(im)

# ---------------------------------------------------------
# Velocity vectors
# ---------------------------------------------------------
func _draw_velocity_single(
	im: ImmediateMesh,
	local_i: int,
	color: Color
) -> void:
	var p: Vector3 = swarm_data.positions[local_i]
	var v: Vector3 = swarm_data.velocities[local_i]

	begin_surface(im, Mesh.PRIMITIVE_LINES, color)
	add_vertex(im, p)
	add_vertex(im, p + v.normalized() * 3.0)
	end_surface(im)

func _draw_velocity_all(
	im: ImmediateMesh,
	color: Color
) -> void:
	if swarm_data.boid_count <= 0:
		return

	begin_surface(im, Mesh.PRIMITIVE_LINES, color)

	for i: int in swarm_data.boid_count:
		var p: Vector3 = swarm_data.positions[i]
		var v: Vector3 = swarm_data.velocities[i]
		add_vertex(im, p)
		add_vertex(im, p + v.normalized() * 3.0)

	end_surface(im)

# ---------------------------------------------------------
# Wireframe sphere
# ---------------------------------------------------------
func _draw_wire_sphere(
	im: ImmediateMesh,
	center: Vector3,
	radius: float,
	color: Color
) -> void:
	_draw_wire_circle(im, center, radius, color, "x")
	_draw_wire_circle(im, center, radius, color, "y")
	_draw_wire_circle(im, center, radius, color, "z")

func _draw_wire_circle(
	im: ImmediateMesh,
	center: Vector3,
	radius: float,
	color: Color,
	axis: String
) -> void:
	var segments: int = 24
	begin_surface(im, Mesh.PRIMITIVE_LINES, color)

	for s: int in range(segments):
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
# FOV cone (single boid only)
# ---------------------------------------------------------
func _draw_fov_cone(
	im: ImmediateMesh,
	local_i: int,
	cone_color: Color
) -> void:
	var phi: float = swarm_data.FOV_angle
	var p: Vector3 = swarm_data.positions[local_i]
	var cone_length: float = swarm_data.limits["sight_radius"]
	var segments: int = 32
	var rim_points: PackedVector3Array = PackedVector3Array()

	var forward_direction: Vector3 = swarm_data.velocities[local_i].normalized()
	var circle_normal: Vector3 = Vector3(0.0, 0.0, 1.0)
	var perpendicular_axis: Vector3 = circle_normal.cross(forward_direction).normalized()

	var angle_between: float = acos(circle_normal.dot(forward_direction))
	var rotation_basis: Basis = Basis(perpendicular_axis, angle_between)
	var transform: Transform3D = Transform3D(rotation_basis, p)

	var phi_vis: float = 0.0
	var dir_sign: float = 0.0

	if phi <= PI * 0.5:
		phi_vis = phi
		dir_sign = 1.0
		cone_color = Color(0.0, 0.0, 1.0)
	else:
		phi_vis = PI - phi
		dir_sign = -1.0
		cone_color = Color(1.0, 0.0, 0.0)

	var r: float = dir_sign * cone_length * cos(phi_vis)
	var radius_scaled: float = cone_length * sin(phi_vis)

	for s: int in range(segments):
		var a: float = float(s) / float(segments) * TAU
		var coord: Vector3 = Vector3(
			radius_scaled * sin(a),
			radius_scaled * cos(a),
			r
		)
		var coord_transformed: Vector3 = transform * coord
		rim_points.append(coord_transformed)

	begin_surface(im, Mesh.PRIMITIVE_LINES, cone_color)
	for rp: Vector3 in rim_points:
		add_vertex(im, p)
		add_vertex(im, rp)
	end_surface(im)
