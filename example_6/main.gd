extends Node3D

@onready var Player : CharacterBody3D = $Player
@onready var Floor : Node3D = $Floor

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	#offset to sit on ground
	Player.position.y += 1.5
	print("Example 6: GPU boids!")
	

	#in no particular order
	#simulation overlay panel
	#GPU behaviours
	#marching cubes!
	#double buffering optimisation/implementation
	#tornado behaviours...

	#things to keep an eye on:
	#velocity vector mesh mismatch...
	#apply forces one by one and investigate!
