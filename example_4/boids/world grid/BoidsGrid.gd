extends Node3D

# FOV angle
# 260° field of view → 130° cutoff

const FOV_angle = deg_to_rad(89)
var FOV_DOT_THRESHOLD : float = cos(FOV_angle)

var cell_size: float #set by boidcontroller
var buckets: Dictionary = {} # key: Vector3i, value: PackedInt32Array

# Convert a given vector into a world cell
func cell_from_pos(p: Vector3) -> Vector3i:
	
	return Vector3i(
		int(floor(p.x / cell_size)),
		int(floor(p.y / cell_size)),
		int(floor(p.z / cell_size))
	)
	
	
# Convert array of Vector3 boid positions into dictionary of pair: (cell / boid index)
# i.e. generate cell positions of boids
func rebuild(positions: PackedVector3Array) -> void:
	buckets.clear()
	for i in positions.size():
		var cell : Vector3i = cell_from_pos(positions[i])
		if not buckets.has(cell):
			buckets[cell] = PackedInt32Array()
		buckets[cell].append(i)
		
		
# Determine neighbouring boids which influence behaviours.
# Given some boid index, look at boids within adjacent cells (3 by 3 by 3 cell structure)
# that fall inside FOV angle and sight radius
func get_neighbours(
	index: int,
	positions: PackedVector3Array,
	velocities: PackedVector3Array,
	sight_radius: float
) -> PackedInt32Array:
	var pos : Vector3 = positions[index]
	var forward : Vector3 = velocities[index].normalized()
	var cell : Vector3i = cell_from_pos(pos)
	var result : PackedInt32Array = PackedInt32Array()
	
	
	# Loop over adjacent cells. Current boid is at the center of 3 by 3 by 3 cuboid
	for x in range(cell.x - 1, cell.x + 2):
		for y in range(cell.y - 1, cell.y + 2):
			for z in range(cell.z - 1, cell.z + 2):
				var key : Vector3i = Vector3i(x, y, z)

				if not buckets.has(key):
					continue

				# Loop over all boids in a given cell
				for j in buckets[key]:
					if j == index:
						continue

					var to_other : Vector3 = (positions[j] - pos).normalized()

					
					var dot := forward.dot(to_other)
					var angle := rad_to_deg(acos(dot))
					var dist := positions[j].distance_to(pos)

					## FOV angle filter
					if forward.dot(to_other) <= FOV_DOT_THRESHOLD:
						continue

					# Distance filter
					if positions[j].distance_to(pos) > sight_radius:
						continue
						
					result.append(j)
					
	return result
