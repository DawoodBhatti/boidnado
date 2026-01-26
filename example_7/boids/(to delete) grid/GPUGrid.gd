extends Node

# ---------------------------------------------------------
# GPUGrid (Stub)
# ---------------------------------------------------------
# Responsibilities:
#   - Placeholder for future GPU-based spatial hashing
#   - Must match CPUGrid's public API
#
# Currently:
#   - Returns empty neighbour lists
#   - Performs no real work
# ---------------------------------------------------------

var global_positions_ref: PackedVector3Array = PackedVector3Array()


func set_global_positions_ref(ref: PackedVector3Array) -> void:
	global_positions_ref = ref


func cell_from_pos(pos: Vector3) -> Vector3i:
	# Placeholder: identical to CPU version for now
	var x: int = int(floor(pos.x / 4.0))
	var y: int = int(floor(pos.y / 4.0))
	var z: int = int(floor(pos.z / 4.0))
	return Vector3i(x, y, z)


func rebuild(global_positions: PackedVector3Array) -> void:
	# GPU implementation will go here
	pass


func get_neighbours(global_i: int) -> PackedInt32Array:
	# GPU implementation will go here
	return PackedInt32Array()
