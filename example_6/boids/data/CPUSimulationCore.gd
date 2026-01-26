extends Node

# ---------------------------------------------------------
# CPUSimulationCore
# ---------------------------------------------------------
# Responsibilities:
#   - Perform CPU simulation for a single swarm
#   - Use global grid + global buffers (passed explicitly)
#   - Compute neighbour lists (local indices)
#   - Write neighbour lists into BoidData for VisualDebug
#   - Apply behaviours (alignment, cohesion, separation, etc.)
#   - Integrate velocities + positions
#
# It does NOT:
#   - Own state (BoidData owns all state)
#   - Access scene tree
#   - Perform any rendering
# ---------------------------------------------------------

func update(	
	delta: float,
	data: Node,
	global_grid: Node,
	global_positions: PackedVector3Array,
	global_velocities: PackedVector3Array
) -> void:

	# -----------------------------------------------------
	# Local references for speed + clarity
	# -----------------------------------------------------
	var positions: PackedVector3Array = data.positions
	var velocities: PackedVector3Array = data.velocities
	var accelerations: PackedVector3Array = data.accelerations
	var neighbours: Array = data.neighbours   # Array[PackedInt32Array]

	var behaviours: Node = data.behaviours_CPU
	var mask : Dictionary = data.behaviours_mask
	var limits: Dictionary = data.limits
	var weights: Dictionary = data.weights
	var cage_radius: float = data.cage_radius

	var global_start: int = data.global_start
	var global_end: int = data.global_end

	var FOV_THRESHOLD: float = data.FOV_DOT_THRESHOLD
	var sight_radius: float = limits["sight_radius"]

	var boid_count: int = positions.size()
	

	# -----------------------------------------------------
	# Reset accelerations + neighbour lists
	# -----------------------------------------------------
	for i: int in boid_count:
		accelerations[i] = Vector3.ZERO
		neighbours[i].clear()

	# -----------------------------------------------------
	# Main simulation loop (per boid)
	# -----------------------------------------------------
	for local_i: int in boid_count:

		# Convert local index → global index
		var global_i: int = global_start + local_i

		# Forward direction for FOV filtering
		var forward: Vector3 = velocities[local_i].normalized()

		# Raw neighbour candidates from the global grid
		var raw_neighbours: PackedInt32Array = global_grid.get_neighbours(global_i)

		# Local neighbour list (local indices only)
		var local_neighbours: PackedInt32Array = PackedInt32Array()

		# -------------------------------------------------
		# Filter neighbours:
		#   - same swarm slice
		#   - inside FOV
		#   - inside sight radius
		# -------------------------------------------------
		for g: int in raw_neighbours:

			# Skip boids outside this swarm's global slice
			if g < global_start:
				continue
			if g >= global_end:
				continue

			# Convert global → local index
			var local_j: int = g - global_start

			var to_other: Vector3 = (positions[local_j] - positions[local_i]).normalized()

			# FOV filter
			if forward.dot(to_other) <= FOV_THRESHOLD:
				continue

			# Sight radius filter
			if positions[local_j].distance_to(positions[local_i]) > sight_radius:
				continue

			local_neighbours.append(local_j)

		# -------------------------------------------------
		# Store neighbour list for VisualDebug
		# -------------------------------------------------
		neighbours[local_i] = local_neighbours

		# -------------------------------------------------
		# Apply behaviours as listed by mask
		# -------------------------------------------------
		if mask["alignment"]:

			behaviours.apply_alignment(
				local_i, positions, velocities, accelerations,
				local_neighbours, weights["alignment"]
			)

		if mask["cohesion"]:

				behaviours.apply_cohesion(
					local_i, positions, velocities, accelerations,
					local_neighbours, weights["cohesion"]
				)

		if mask["separation"]:

			behaviours.apply_separation(
				local_i, positions, velocities, accelerations,
				local_neighbours, limits["desired_separation"],
				weights["separation"]
			)

			
		if mask["wander"]:

			behaviours.apply_wander(
				local_i, velocities, accelerations,
				weights["wander"]
			)

		
		
		if mask["boundary"]:

			behaviours.apply_boundary_potential(
				local_i, positions, velocities, accelerations,
				cage_radius, weights["boundary"]
			)

	# -----------------------------------------------------
	# Integrate velocities + positions
	# -----------------------------------------------------
	for i: int in boid_count:

		velocities[i] += accelerations[i] * delta

		# Clamp speed
		var max_speed: float = limits["max_speed"]
		if velocities[i].length() > max_speed:
			velocities[i] = velocities[i].normalized() * max_speed

		positions[i] += velocities[i] * delta
