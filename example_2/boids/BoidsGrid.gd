# res://example_2/boids/BoidGrid.gd
extends Resource
class_name BoidGrid2

var cell_size: float = 5.0
var buckets: Dictionary = {} # key: Vector3i, value: PackedInt32Array

func _cell_from_pos(p: Vector3) -> Vector3i:
	return Vector3i(
		int(floor(p.x / cell_size)),
		int(floor(p.y / cell_size)),
		int(floor(p.z / cell_size))
	)

func rebuild(positions: PackedVector3Array) -> void:
	buckets.clear()
	for i in positions.size():
		var cell := _cell_from_pos(positions[i])
		if not buckets.has(cell):
			buckets[cell] = PackedInt32Array()
		buckets[cell].append(i)
		
		
func get_neighbours(
	index: int,
	positions: PackedVector3Array,
	velocities: PackedVector3Array,
	radius: float
) -> PackedInt32Array:
	var pos := positions[index]
	var forward := velocities[index].normalized()
	var cell := _cell_from_pos(pos)
	var result := PackedInt32Array()

	# 260° field of view → 130° cutoff
	# cos(130°) ≈ -0.6428
	const FOV_DOT_THRESHOLD := -0.6428

	for x in range(cell.x - 1, cell.x + 2):
		for y in range(cell.y - 1, cell.y + 2):
			for z in range(cell.z - 1, cell.z + 2):
				var key := Vector3i(x, y, z)
				if not buckets.has(key):
					continue

				for j in buckets[key]:
					if j == index:
						continue

					var to_other := (positions[j] - pos).normalized()

					# FOV filter (GPU‑friendly)
					if forward.dot(to_other) <= FOV_DOT_THRESHOLD:
						continue

					# Distance filter
					if positions[j].distance_to(pos) <= radius:
						result.append(j)

	return result
