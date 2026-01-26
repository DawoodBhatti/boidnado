extends Node3D

# ---------------------------------------------------------
# Debug Overlay Configuration
# ---------------------------------------------------------

# These are assigned by the controller
var cell_length: float
var FOV_radius: float
var FOV_angle: float
var positions: PackedVector3Array
var velocities: PackedVector3Array 
var neighbours: PackedInt32Array
var sight_radius : float

# Optional references (assigned by controller if needed)
var grid: Node3D
var renderer: Node3D

# Visual config
var cell_color: Color = Color(0.0, 0.0, 12.536, 1.0)
var central_cell_color : Color = Color(0,0,0,1)
var velocity_color : Color = Color(1,1,0)

# Toggle debug layers
var show_grid: bool = true
var show_debug_boid: bool = true
var show_neighbours: bool = true
var show_FOV_cone: bool = true
var show_velocity_single: bool = false
var show_velocity_all: bool = true

# ---------------------------------------------------------
# Internal State
# ---------------------------------------------------------

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
	# --- Create normal grid mesh ---
	im_grid = ImmediateMesh.new()
	mesh_grid = MeshInstance3D.new()
	mesh_grid.mesh = im_grid

	# --- Create material override for mesh colouring of neighbour cells
	var mat_grid := StandardMaterial3D.new()
	mat_grid.vertex_color_use_as_albedo = true
	mat_grid.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_grid.render_priority = 0  # normal priority
	mesh_grid.material_override = mat_grid

	add_child(mesh_grid)
	mesh_grid.set_as_top_level(true)
	
	# --- Create highlight mesh ---
	# This mesh draws the central cell. It has a higher render priority
	# so it always appears on top of the other grid lines.
	im_highlight = ImmediateMesh.new()
	mesh_highlight = MeshInstance3D.new()
	mesh_highlight.mesh = im_highlight

	# --- Create material override for mesh colouring of central cell (boid=0 location) 
	var mat_highlight := StandardMaterial3D.new()
	mat_highlight.vertex_color_use_as_albedo = true
	mat_highlight.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_highlight.render_priority = 10  # draws on top
	mesh_highlight.material_override = mat_highlight

	add_child(mesh_highlight)
	mesh_highlight.set_as_top_level(true)
	
# ---------------------------------------------------------
# Lifecycle: _process()
# ---------------------------------------------------------
func _process(delta: float) -> void:

	im_grid.clear_surfaces()
	im_highlight.clear_surfaces()

	if positions.size() == 0:
		return

	#boid of interest and its neighbours
	var i : int = 0
	var pos: Vector3 = positions[i]
	var central_cell: Vector3i = grid.cell_from_pos(pos)
	neighbours = grid.get_neighbours(i, positions, velocities, sight_radius)

	_draw_debug_layers(i, pos, central_cell)


# ---------------------------------------------------------
# Draw all debug layers
# ---------------------------------------------------------
func _draw_debug_layers(i: int, pos: Vector3, central_cell: Vector3i) -> void:
	# Draw grid cells
	if show_grid:
		_draw_world_cells(central_cell)

	# Draw target boid
	if show_debug_boid:
		_draw_wire_sphere(im_grid, pos, sight_radius, Color(0.0, 0.0, 12.536, 1.0))
	
	# Draw neighbours
	if show_neighbours:
		_draw_neighbours(im_grid)

	# Draw velocity vectors
	if show_velocity_all:
		_draw_velocity_all(im_grid)
	elif show_velocity_single:
		_draw_velocity_single(im_grid, i)
		
	# Draw FOV cone
	if show_FOV_cone:
		_draw_fov_cone(im_grid, i, central_cell_color)

		
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
# Draw World Cells (3 by 3 by 3 about central_cell)
# ---------------------------------------------------------
func _draw_world_cells(central_cell):
	for x in range(central_cell.x - 1, central_cell.x + 2):
		for y in range(central_cell.y - 1, central_cell.y + 2):
			for z in range(central_cell.z - 1, central_cell.z + 2):
					var this_cell: Vector3i = Vector3i(x, y, z)
					var color: Color
					var target_im: ImmediateMesh

					if this_cell == central_cell:
						color = central_cell_color
						target_im = im_highlight
					else:
						color = cell_color
						target_im = im_grid

					_draw_cell(target_im, this_cell, color)

func _draw_cell(im: ImmediateMesh, cell: Vector3i, color: Color) -> void:
	# This is the highlighted central cell.
	# It is drawn into a separate ImmediateMesh with a higher render priority
	# so it always appears on top of the normal grid lines.
	var L : float = cell_length
	var nx : int = cell.x
	var ny : int = cell.y
	var nz : int = cell.z

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
# Draw Neighbours
# ---------------------------------------------------------
func _draw_neighbours(im: ImmediateMesh,) -> void:
	#keep sight radius for target boid and reduce sphere radius for highlightning purpose only
	for j in neighbours:
		_draw_wire_sphere(im, positions[j], 1.0, Color(0, 1, 0))


# ---------------------------------------------------------
# Draw Wireframe Sphere
# ---------------------------------------------------------
func _draw_wire_sphere(im: ImmediateMesh, center: Vector3, radius: float, color: Color) -> void:
	_draw_wire_circle(im, center, radius, color, "x")
	_draw_wire_circle(im, center, radius, color, "y")
	_draw_wire_circle(im, center, radius, color, "z")


func _draw_wire_circle(im: ImmediateMesh, center: Vector3, radius: float, color: Color, axis: String) -> void:
	var segments: int = 24
	begin_surface(im, Mesh.PRIMITIVE_LINES, color)

	for s in range(segments):
		var a1: float = float(s)/segments * TAU
		var a2: float = float(s+1)/segments * TAU

		var p1: Vector3
		var p2: Vector3

		if axis == "x":
			p1 = center + Vector3(0, cos(a1), sin(a1)) * radius
			p2 = center + Vector3(0, cos(a2), sin(a2)) * radius
		elif axis == "y":
			p1 = center + Vector3(cos(a1), 0, sin(a1)) * radius
			p2 = center + Vector3(cos(a2), 0, sin(a2)) * radius
		else:
			p1 = center + Vector3(cos(a1), sin(a1), 0) * radius
			p2 = center + Vector3(cos(a2), sin(a2), 0) * radius

		add_vertex(p1)
		add_vertex(p2)

	end_surface()

# ---------------------------------------------------------
# Draw Velocity Vectors (for single boid and for all boids)
# ---------------------------------------------------------
func _draw_velocity_single(im: ImmediateMesh, i: int) -> void:
	var p = positions[i]
	var v = velocities[i]

	begin_surface(im, Mesh.PRIMITIVE_LINES, velocity_color)
	add_vertex(p)
	add_vertex(p + v.normalized() * 3.0)
	end_surface()

func _draw_velocity_all(im: ImmediateMesh) -> void:
	begin_surface(im, Mesh.PRIMITIVE_LINES, velocity_color)

	var count: int = positions.size()
	for i in count:
		var p: Vector3 = positions[i]
		var v: Vector3 = velocities[i]
		add_vertex(p)
		add_vertex(p + v.normalized() * 3.0)

	end_surface()

# ---------------------------------------------------------
# Draw Boid Blind Spot (FOV Cone)
# ---------------------------------------------------------

#replaced by AI function below
func _draw_fov_cone_frustrum(im: ImmediateMesh, i, cone_color : Color) -> void:
		
	var phi : float = FOV_angle
	var p = positions[i]
	var cone_length = sight_radius
	var segments : int = 32
	var rim_points: PackedVector3Array= []
	
	#define boid direction, circle normal and perpendicular axis of rotation
	var forward_direction = velocities[i].normalized()
	var circle_normal: Vector3 = Vector3(0,0,1)
	var perpendicular_axis = circle_normal.cross(forward_direction).normalized()
	
	# remembering a.b = |a||b|cos(theta) but for unit vectors |a| = |b| = 1
 	# here we calculate the transform required to rotate between circle normal and the forward direction, about some origin p 
	var angle_between = acos(circle_normal.dot(forward_direction))
	var rotation_basis : Basis = Basis(perpendicular_axis, angle_between) 
	var transform = Transform3D(rotation_basis, p)
	
	for s in range(0, segments):
		var a : float = float(s)/segments * TAU
		var radius_scaled : float
		var r : float
		
		#FOV cone represents region as included regions
		if 2*phi < TAU/2:
			radius_scaled = cone_length * tan(phi)
			r = cone_length
			cone_color = Color(0.0, 0.0, 0.0, 1.0)

		#FOV cone represents region as excluded regions
		elif 2*phi >= TAU/2:
			radius_scaled = -cone_length * tan(phi)
			r = -1 * cone_length
			cone_color = Color(1.0, 0.0, 0.0, 1.0)
			
		var coord : Vector3 =  Vector3(radius_scaled * sin(a), radius_scaled * cos(a), r)
		var coord_transformed : Vector3 = transform * coord
		
		#apply our defined rotation and translation to the coordinate
		rim_points.append(coord_transformed)
		
	#draw blind spot as cone
	begin_surface(im, Mesh.PRIMITIVE_LINES, cone_color)
	for rp in rim_points:
		add_vertex(p)
		add_vertex(rp)
	end_surface()


func _draw_fov_cone(im: ImmediateMesh, i, cone_color : Color) -> void:
	var phi : float = FOV_angle
	var p = positions[i]
	var cone_length = sight_radius
	var segments : int = 32
	var rim_points: PackedVector3Array = []

	var forward_direction = velocities[i].normalized()
	var circle_normal: Vector3 = Vector3(0,0,1)
	var perpendicular_axis = circle_normal.cross(forward_direction).normalized()

	var angle_between = acos(circle_normal.dot(forward_direction))
	var rotation_basis : Basis = Basis(perpendicular_axis, angle_between)
	var transform = Transform3D(rotation_basis, p)

	var phi_vis : float
	var dir_sign : float

	# narrow FOV → draw visible cone
	if phi <= PI/2.0:
		phi_vis = phi
		dir_sign = 1.0
		cone_color = Color(0.0, 0.0, 0.0, 1.0)
	# wide FOV → draw blind spot cone behind
	else:
		phi_vis = PI - phi
		dir_sign = -1.0
		cone_color = Color(1.0, 0.0, 0.0, 1.0)

	var r = dir_sign * cone_length * cos(phi_vis)
	var radius_scaled = cone_length * sin(phi_vis)

	for s in range(segments):
		var a : float = float(s)/segments * TAU
		var coord : Vector3 = Vector3(
			radius_scaled * sin(a),
			radius_scaled * cos(a),
			r
		)
		var coord_transformed : Vector3 = transform * coord
		rim_points.append(coord_transformed)

	begin_surface(im, Mesh.PRIMITIVE_LINES, cone_color)
	for rp in rim_points:
		add_vertex(p)
		add_vertex(rp)
	end_surface()
