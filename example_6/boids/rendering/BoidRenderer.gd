extends MultiMeshInstance3D

# ---------------------------------------------------------
# Configuration
# ---------------------------------------------------------

# Blender mesh points along -Y, Godot expects -Z as forward
var mesh_forward_correction : Basis



# some unpack function?

# we pass the mesh, positions and velocities to be rendered?

# ---------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------

func _ready() -> void:
	# Rotate mesh forward axis from -Y to -Z
	mesh_forward_correction = Basis().rotated(Vector3.RIGHT, PI)


# ---------------------------------------------------------
# Debug helper (optional)
# ---------------------------------------------------------

func _query_mesh_position(mesh : Mesh) -> void:
	print("mesh AABB:", mesh.get_aabb())


# ---------------------------------------------------------
# Setup MultiMesh
# ---------------------------------------------------------

func setup(mesh: Mesh, colour: Color, count: int) -> void:
	
	#one colour per swarm, for now
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	
	# Apply material to the mesh
	mesh.surface_set_material(0, material)
	
	var mm := MultiMesh.new()
	mm.mesh = mesh
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.instance_count = count
	multimesh = mm


# ---------------------------------------------------------
# Update transforms each frame
# ---------------------------------------------------------

func update_transforms(positions: PackedVector3Array, velocities: PackedVector3Array) -> void:
	if multimesh == null:
		return

	for i in positions.size():
		var dir := velocities[i].normalized()
		if dir == Vector3.ZERO:
			dir = Vector3.FORWARD

		# 1. Orient mesh to velocity
		var basis := Basis().looking_at(dir, Vector3.UP)

		# 2. Apply forward-axis correction
		basis = basis * mesh_forward_correction

		# 3. Build transform with position
		var xform := Transform3D(basis, positions[i])

		# 4. Assign to MultiMesh
		multimesh.set_instance_transform(i, xform)
