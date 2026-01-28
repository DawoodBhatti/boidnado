# SimulationCore.gd
extends Node


func update(delta: float, data: Node3D) -> void:
	push_error("SimulationCore.update() must be implemented by a subclass")
