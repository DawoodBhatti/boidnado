extends Node3D

#Root node is a container for entire boids simulation logic


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	
	print("")
	print("######### master scene tree: ######### ")
	get_tree().get_root().print_tree()
	pass
