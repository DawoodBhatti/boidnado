extends Node3D


@onready var Player : CharacterBody3D = $Player
@onready var Floor : Node3D = $Floor


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	#offset to sit on ground
	Player.position.y += 1.5
	print("Example 3: housekeeping + visual debug layer")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
