extends Node3D

# ---------------------------------------------------------
# Configuration
# ---------------------------------------------------------

var cage_radius: float  #set by boidcontroller
var cage_visible: bool = true
var cage_color: Color = Color(1.0, 0.486, 0.0, 0.659)

# ---------------------------------------------------------
# Internal State
# ---------------------------------------------------------

var cage_center: Vector3 = Vector3.ZERO

var im_cage: ImmediateMesh
var mesh_cage: MeshInstance3D

# Surface state
var surface_active := false
var vertex_count := 0
var active_im: ImmediateMesh = null

# ---------------------------------------------------------
# Ready
# ---------------------------------------------------------

func _ready() -> void:

	# instantiate immediate mesh for cage drawing
	im_cage = ImmediateMesh.new()
	mesh_cage = MeshInstance3D.new()
	mesh_cage.mesh = im_cage
	
	# --- Create material override for mesh colouring of neighbour cells
	var cage_material : StandardMaterial3D = StandardMaterial3D.new()
	cage_material.vertex_color_use_as_albedo = true
	cage_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh_cage.material_override = cage_material

	add_child(mesh_cage)
	mesh_cage.set_as_top_level(true)

# ---------------------------------------------------------
# Process
# ---------------------------------------------------------

func _process(delta: float) -> void:
	if not cage_visible:
		return

	# IMPORTANT: clear surfaces every frame
	im_cage.clear_surfaces()

	_draw_wire_sphere(im_cage, cage_center, cage_radius, cage_color)

# ---------------------------------------------------------
# Draw Wire Sphere:
# ---------------------------------------------------------
func _draw_wire_sphere(im: ImmediateMesh, center: Vector3, radius: float, color: Color) -> void:
	
	var segments : int = 16
	var theta : float = 0.0
	var phi : float = 0.0
	var num_rings_xy : int = 20
	var num_rings_yz : int = 20
	var num_rings_zx : int = 20
	var xy_rings : Array = []
	var yz_rings : Array = []
	var zx_rings : Array = []
	
	var rot_x = Basis(Vector3(1, 0, 0), deg_to_rad(90))
	var rot_y = Basis(Vector3(0, 1, 0), deg_to_rad(90))
	var rot_z = Basis(Vector3(0, 0, 1), deg_to_rad(90))
	
	# XY circles 
	for i in range(0,num_rings_xy+1):
		
		# reinstantiate ring each iteration to avoid using ring.clear() which also clears values from memory 
		var ring : PackedVector3Array = PackedVector3Array()
		
		# calculate sphere rings at even spacings of azimuthal angle, theta 
		theta = float(i) * (TAU/num_rings_xy)

		for s in range(segments+1):
			phi = float(s) / segments * TAU/2
			ring.append(center + Vector3(sin(theta) * cos(phi), sin(theta) * sin(phi), cos(theta))*radius)		
		xy_rings.append(ring)
		
	# YZ rings as 90 degree rotation of XY circles (about y axis)
	# XZ rings as 90 degree rotation of XY circles (about x axis)
	for r_array in xy_rings:
		var ring_rotated_xy : PackedVector3Array = PackedVector3Array()
		var ring_rotated_zx : PackedVector3Array = PackedVector3Array()
		for r in r_array:
			ring_rotated_xy.append(rot_y * r )
			ring_rotated_zx.append(rot_x * r)
		yz_rings.append(ring_rotated_xy)
		zx_rings.append(ring_rotated_zx)
		
	for ring in xy_rings:
		begin_surface(im_cage, Mesh.PRIMITIVE_LINES, cage_color)
		for i in len(ring)-1:
			add_vertex(ring[i])
			add_vertex(ring[i+1])
		end_surface()
		
	for ring in yz_rings:
		begin_surface(im_cage, Mesh.PRIMITIVE_LINES, cage_color)
		for i in len(ring)-1:
			add_vertex(ring[i])
			add_vertex(ring[i+1])
		end_surface()
		
	for ring in zx_rings:
		begin_surface(im_cage, Mesh.PRIMITIVE_LINES, cage_color)
		for i in len(ring)-1:
			add_vertex(ring[i])
			add_vertex(ring[i+1])
		end_surface()
		

# ---------------------------------------------------------
# Safe Surface API
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
	if surface_active:
		active_im.surface_add_vertex(v)
		vertex_count += 1

func end_surface() -> void:
	if surface_active and vertex_count > 0:
		active_im.surface_end()

	surface_active = false
	vertex_count = 0
