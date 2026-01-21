extends Node3D 

static func apply_alignment(
	i: int,
	positions: PackedVector3Array,
	velocities: PackedVector3Array,
	accelerations: PackedVector3Array,
	neighbours: PackedInt32Array,
	weight: float
) -> void:
	if neighbours.is_empty():
		return

	var avg_vel := Vector3.ZERO
	for j in neighbours:
		avg_vel += velocities[j]
	avg_vel /= float(neighbours.size())

	var steer := (avg_vel - velocities[i])
	accelerations[i] += steer * weight


static func apply_cohesion(
	i: int,
	positions: PackedVector3Array,
	velocities: PackedVector3Array,
	accelerations: PackedVector3Array,
	neighbours: PackedInt32Array,
	weight: float
) -> void:
	if neighbours.is_empty():
		return

	var avg_pos := Vector3.ZERO
	for j in neighbours:
		avg_pos += positions[j]
	avg_pos /= float(neighbours.size())

	var desired := (avg_pos - positions[i])
	accelerations[i] += desired * weight


static func apply_separation(
	i: int,
	positions: PackedVector3Array,
	velocities: PackedVector3Array,
	accelerations: PackedVector3Array,
	neighbours: PackedInt32Array,
	desired_separation: float,
	weight: float
) -> void:
	if neighbours.is_empty():
		return

	var steer := Vector3.ZERO
	var count := 0

	for j in neighbours:
		var diff := positions[i] - positions[j]
		var dist := diff.length()
		if dist < desired_separation and dist > 0.0001:
			steer += diff.normalized() / dist
			count += 1

	if count > 0:
		steer /= float(count)
		accelerations[i] += steer * weight


static func apply_wander(
	i: int,
	velocities: PackedVector3Array,
	accelerations: PackedVector3Array,
	wander_strength: float
) -> void:
	# Random small vector
	var rand_vec := Vector3(
		randf_range(-1.0, 1.0),
		randf_range(-1.0, 1.0),
		randf_range(-1.0, 1.0)
	).normalized()

	# Scale by strength
	accelerations[i] += rand_vec * wander_strength
