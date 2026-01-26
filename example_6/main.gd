extends Node3D

@onready var Player : CharacterBody3D = $Player
@onready var Floor : Node3D = $Floor

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	#offset to sit on ground
	Player.position.y += 1.5
	print("Example 6: deep architectural changes moving local logic to global logic")
	print("moved debug, grid and behaviours to live globally")
	print("introduce CPU/GPU path and GPU stubs for now")
	
	#GPU implementation of global grid and data update
	#in no particular order
	#GPU behaviours
	
	#marching cubes! (start on wednesday hopefully)
	#double buffering optimisation/implementation
	#tornado behaviours...
	#simulation overlay panel
