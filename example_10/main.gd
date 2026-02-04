extends Node3D

@onready var Player : CharacterBody3D = $Player
@onready var Floor : Node3D = $Floor

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	#offset to sit on ground
	Player.position.y += 1.5
	print("Example 10: moving from line representation to point cloud with density colouring")
	
	#we might also need to rethink the visualisation part...?
	
	#"disable multiple swarms for now until we can find the bug")
	# We have a working simulation and are looking to flesh out the visual element of it
	# moved away from lines to point cloud representation and density based colouring
	# removed rendering layer for now and sticking to visual debugger
	
	#Iteration 8 fleshed out the compute pipeline but iteration 9 needs to refine it
	#There might also be some bugs with regards to grid_scatter and grid_mapping?

	#marching cubes! 
	#tornado behaviours...
	#simulation overlay panel
