extends Node

var min_bounds = Vector3(-10, -10, -10)
var max_bounds = Vector3(10, 10, 10)
var strength = 1.0

func _ready():
	print("Cage: ready with bounds", min_bounds, max_bounds)

func debug_draw():
	# placeholder for drawing cage gizmo
	pass
