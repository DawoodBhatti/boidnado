extends MultiMeshInstance3D

# Adjust this depending on mesh's forward direction
var mesh_forward_correction : Basis

func _ready() -> void:
	#Boid mesh points along -y as forward direction in blender
	#But Godot expects forward as -z
	mesh_forward_correction = Basis().rotated(Vector3.RIGHT, PI)
	

func _query_mesh_position(mesh : Mesh) -> void:
	#P = position of the AABB’s minimum corner
	#S = size of the AABB
	print("mesh AABB:", mesh.get_aabb())


# Convert single input mesh into multimesh for boids visuals
func setup(mesh: Mesh, count: int) -> void:
	
	var mm : MultiMesh = MultiMesh.new()
	
	#_query_mesh_position(mesh)
	
	mm.mesh = mesh
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.instance_count = count
	multimesh = mm


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

		# 3. Apply transform
		var xform := Transform3D(basis, positions[i])
		multimesh.set_instance_transform(i, xform)
