extends Node3D
class_name DebugGridOverlay3

# ---------------------------------------------------------
# Debug Overlay Configuration
# ---------------------------------------------------------

@export var controller_path: NodePath = "../BoidController"
@export var cell_color: Color = Color(18.892, 18.892, 18.892, 1.0)
@export var visual_sphere_radius: float = 1.0

# Toggle debug layers
@export var show_grid: bool = true
@export var show_neighbours: bool = true

#FOV still needs some work...
@export var show_fov: bool = false
@export var show_velocity: bool = true

# ---------------------------------------------------------
# Internal State
# ---------------------------------------------------------

var controller: Node
var grid: BoidGrid3
var cell_length: float

# Two ImmediateMeshes:
# - im_grid:      all normal grid cells
# - im_highlight: the central cell (drawn on top)
var im_grid: ImmediateMesh
var im_highlight: ImmediateMesh

var mesh_grid: MeshInstance3D
var mesh_highlight: MeshInstance3D

# Surface tracking for the active mesh. When true any vertices passed to add_vertex are given to the active shape
var surface_active : bool = false
var vertex_count : int = 0
var active_im: ImmediateMesh = null

# ---------------------------------------------------------
# Lifecycle: _ready()
# ---------------------------------------------------------
func _ready() -> void:
	controller = get_node(controller_path)
	grid = controller.grid
	cell_length = grid.cell_size

	# --- Create normal grid mesh ---
	im_grid = ImmediateMesh.new()
	mesh_grid = MeshInstance3D.new()
	mesh_grid.mesh = im_grid
	mesh_grid.set_as_top_level(true)

	var mat_grid := StandardMaterial3D.new()
	mat_grid.vertex_color_use_as_albedo = true
	mat_grid.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_grid.render_priority = 0  # normal priority
	mesh_grid.material_override = mat_grid

	add_child(mesh_grid)

	# --- Create highlight mesh ---
	# This mesh draws the central cell. It has a higher render priority
	# so it always appears on top of the other grid lines.
	im_highlight = ImmediateMesh.new()
	mesh_highlight = MeshInstance3D.new()
	mesh_highlight.mesh = im_highlight
	mesh_highlight.set_as_top_level(true)

	var mat_highlight := StandardMaterial3D.new()
	mat_highlight.vertex_color_use_as_albedo = true
	mat_highlight.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_highlight.render_priority = 10  # draws on top
	mesh_highlight.material_override = mat_highlight

	add_child(mesh_highlight)


# ---------------------------------------------------------
# Lifecycle: _process()
# ---------------------------------------------------------
func _process(delta: float) -> void:
	if controller == null or grid == null:
		return

	im_grid.clear_surfaces()
	im_highlight.clear_surfaces()

	var positions: PackedVector3Array = controller.positions
	var velocities: PackedVector3Array = controller.velocities
	var radius: float = controller.neighbour_radius

	if positions.size() == 0:
		return

	var i := 0
	var pos: Vector3 = positions[i]
	var cell: Vector3i = grid._cell_from_pos(pos)

	# Draw grid cells
	if show_grid:
		for x in range(cell.x - 1, cell.x + 2):
			for y in range(cell.y - 1, cell.y + 2):
				for z in range(cell.z - 1, cell.z + 2):
					var this_cell := Vector3i(x, y, z)

					if this_cell == cell:
						# Draw the highlighted central cell into the highlight mesh
						_draw_cell_colored(im_highlight, this_cell, Color(0,0,0,1))
					else:
						# Draw all other cells into the normal grid mesh
						_draw_cell(im_grid, this_cell)

	# Draw target boid
	_draw_wire_sphere(im_grid, pos, visual_sphere_radius, Color(0,1,0))

	# Draw neighbours
	if show_neighbours:
		_draw_neighbours(im_grid, i, positions, velocities, radius)

	# Draw velocity vector
	if show_velocity:
		_draw_velocity(im_grid, i, positions, velocities)

	# Draw FOV cone
	if show_fov:
		_draw_partial_fov_cone(im_grid, i, positions, velocities)


# ---------------------------------------------------------
# Safe Surface API (now takes an ImmediateMesh)
# ---------------------------------------------------------

func begin_surface(im: ImmediateMesh, primitive: int, color: Color) -> void:
	if surface_active:
		active_im.surface_end()
		surface_active = false

	active_im = im
	active_im.surface_begin(primitive)
	active_im.surface_set_color(color)
	surface_active = true
	vertex_count = 0


func add_vertex(v: Vector3) -> void:
	if not surface_active:
		return
	active_im.surface_add_vertex(v)
	vertex_count += 1


func end_surface() -> void:
	if not surface_active:
		return

	if vertex_count > 0:
		active_im.surface_end()

	surface_active = false
	vertex_count = 0


# ---------------------------------------------------------
# Draw Grid Cells (World space is partitioned into 3 by 3 by 3 cuboid cells)
# ---------------------------------------------------------

func _draw_cell(im: ImmediateMesh, cell: Vector3i) -> void:
	var L := cell_length
	var nx := cell.x
	var ny := cell.y
	var nz := cell.z

	begin_surface(im, Mesh.PRIMITIVE_LINES, cell_color)

	var c = [
		Vector3(nx*L, ny*L, nz*L),
		Vector3(nx*L, (ny+1)*L, nz*L),
		Vector3(nx*L, (ny+1)*L, (nz+1)*L),
		Vector3(nx*L, ny*L, (nz+1)*L),
		Vector3((nx+1)*L, ny*L, nz*L),
		Vector3((nx+1)*L, (ny+1)*L, nz*L),
		Vector3((nx+1)*L, (ny+1)*L, (nz+1)*L),
		Vector3((nx+1)*L, ny*L, (nz+1)*L),
	]

	var edges = [
		[0,1],[1,2],[2,3],[3,0],
		[4,5],[5,6],[6,7],[7,4],
		[0,4],[1,5],[2,6],[3,7]
	]

	for e in edges:
		add_vertex(c[e[0]])
		add_vertex(c[e[1]])

	end_surface()


func _draw_cell_colored(im: ImmediateMesh, cell: Vector3i, color: Color) -> void:
	# This is the highlighted central cell.
	# It is drawn into a separate ImmediateMesh with a higher render priority
	# so it always appears on top of the normal grid lines.
	var L := cell_length
	var nx := cell.x
	var ny := cell.y
	var nz := cell.z

	begin_surface(im, Mesh.PRIMITIVE_LINES, color)

	var c = [
		Vector3(nx*L, ny*L, nz*L),
		Vector3(nx*L, (ny+1)*L, nz*L),
		Vector3(nx*L, (ny+1)*L, (nz+1)*L),
		Vector3(nx*L, ny*L, (nz+1)*L),
		Vector3((nx+1)*L, ny*L, nz*L),
		Vector3((nx+1)*L, (ny+1)*L, nz*L),
		Vector3((nx+1)*L, (ny+1)*L, (nz+1)*L),
		Vector3((nx+1)*L, ny*L, (nz+1)*L),
	]

	var edges = [
		[0,1],[1,2],[2,3],[3,0],
		[4,5],[5,6],[6,7],[7,4],
		[0,4],[1,5],[2,6],[3,7]
	]

	for e in edges:
		add_vertex(c[e[0]])
		add_vertex(c[e[1]])

	end_surface()


# ---------------------------------------------------------
# Draw Neighbours / Spheres / Velocity / FOV
# ---------------------------------------------------------

func _draw_neighbours(im: ImmediateMesh, i, positions, velocities, radius) -> void:
	var neighbours = controller.grid.get_neighbours(i, positions, velocities, radius)
	for j in neighbours:
		_draw_wire_sphere(im, positions[j], visual_sphere_radius, Color(1,0.2,0.2))


func _draw_wire_sphere(im: ImmediateMesh, center: Vector3, radius: float, color: Color) -> void:
	var segments := 24

	begin_surface(im, Mesh.PRIMITIVE_LINES, color)
	for s in range(segments):
		var a1 := float(s)/segments * TAU
		var a2 := float(s+1)/segments * TAU
		add_vertex(center + Vector3(cos(a1), sin(a1), 0) * radius)
		add_vertex(center + Vector3(cos(a2), sin(a2), 0) * radius)
	end_surface()

	begin_surface(im, Mesh.PRIMITIVE_LINES, color)
	for s in range(segments):
		var a1 := float(s)/segments * TAU
		var a2 := float(s+1)/segments * TAU
		add_vertex(center + Vector3(cos(a1), 0, sin(a1)) * radius)
		add_vertex(center + Vector3(cos(a2), 0, sin(a2)) * radius)
	end_surface()

	begin_surface(im, Mesh.PRIMITIVE_LINES, color)
	for s in range(segments):
		var a1 := float(s)/segments * TAU
		var a2 := float(s+1)/segments * TAU
		add_vertex(center + Vector3(0, cos(a1), sin(a1)) * radius)
		add_vertex(center + Vector3(0, cos(a2), sin(a2)) * radius)
	end_surface()


func _draw_velocity(im: ImmediateMesh, i, positions, velocities) -> void:
	var p = positions[i]
	var v = velocities[i]

	begin_surface(im, Mesh.PRIMITIVE_LINES, Color(1,1,0))
	add_vertex(p)
	add_vertex(p + v.normalized() * 3.0)
	end_surface()


func _draw_partial_fov_cone(im: ImmediateMesh, i, positions, velocities) -> void:
	var p = positions[i]
	var forward = velocities[i].normalized()
	var half_angle = deg_to_rad(130.0)
	var radius = controller.neighbour_radius
	var segments := 32

	var rim_points: Array[Vector3] = []
	for s in range(segments):
		var a : float= float(s)/segments * TAU
		var dir : Vector3 = (forward.rotated(Vector3.UP, a)).rotated(Vector3.RIGHT, half_angle)
		rim_points.append(p + dir * radius)

	begin_surface(im, Mesh.PRIMITIVE_LINES, Color(1,0.6,0))
	for s in range(segments):
		add_vertex(rim_points[s])
		add_vertex(rim_points[(s+1) % segments])
	end_surface()

	begin_surface(im, Mesh.PRIMITIVE_LINES, Color(1,0.6,0))
	for rp in rim_points:
		add_vertex(p)
		add_vertex(rp)
	end_surface()
