extends Node3D

@onready var Player : CharacterBody3D = $Player
@onready var Floor : Node3D = $Floor

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	#offset to sit on ground
	Player.position.y += 1.5
	print("Example 8: skeleton of GPU centric rebuild")

	#We discovered that there is some read/write desync
	#between compute shaders in the same bass
	#Using textures which have implicit synchronizaion might be a way forward
	#Iteration 8 fleshed out the compute pipeline but iteration 9 needs to refine it
	#There might also be some bugs with regards to grid_scatter and grid_mapping?

	#marching cubes! 
	#tornado behaviours...
	#simulation overlay panel
