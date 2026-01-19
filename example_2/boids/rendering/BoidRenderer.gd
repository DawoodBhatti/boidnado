extends MultiMeshInstance3D
class_name BoidRenderer2

func setup(mesh: Mesh, count: int) -> void:
	var mm := MultiMesh.new()
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
		var basis := Basis().looking_at(dir, Vector3.UP)
		var xform := Transform3D(basis, positions[i])
		multimesh.set_instance_transform(i, xform)
