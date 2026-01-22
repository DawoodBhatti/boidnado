extends Node3D


@onready var Player : CharacterBody3D = $Player
@onready var Floor : Node3D = $Floor

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	#offset to sit on ground
	Player.position.y += 1.5
	print("Example 4: boid cage + bug fixes")
	print("Example 4: electrons orbiting atom?")
	
	
	#Example 5+
	#bounding behaviour
	#data layer
	#GPU
	#double buffering optimisation/implementation
	#marching cubes!


	#things to keep an eye on:
	#velocity vector mesh mismatch...
	#apply forces one by one and investigate!
