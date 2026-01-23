extends Node


func update(delta, data):
	var positions = data.positions
	var velocities = data.velocities
	var accelerations = data.accelerations
	var grid = data.grid
	var behaviours = data.behaviours
	var limits = data.limits
	var weights = data.weights
	var cage_radius = data.cage_radius

	# Reset accelerations
	for i in accelerations.size():
		accelerations[i] = Vector3.ZERO

	# Rebuild grid
	grid.rebuild(positions)

	# Apply behaviours
	for i in positions.size():
		var neighbours = grid.get_neighbours(i, positions, velocities, limits["sight_radius"])

		behaviours.apply_alignment(i, positions, velocities, accelerations, neighbours, weights["alignment"])
		behaviours.apply_cohesion(i, positions, velocities, accelerations, neighbours, weights["cohesion"])
		behaviours.apply_separation(i, positions, velocities, accelerations, neighbours, limits["desired_separation"], weights["separation"])
		behaviours.apply_wander(i, velocities, accelerations, weights["wander"])
		behaviours.apply_boundary_potential(i, positions, velocities, accelerations, cage_radius, weights["boundary"])

	# Integrate
	for i in positions.size():
		velocities[i] += accelerations[i] * delta

		if velocities[i].length() > limits["max_speed"]:
			velocities[i] = velocities[i].normalized() * limits["max_speed"]

		positions[i] += velocities[i] * delta
