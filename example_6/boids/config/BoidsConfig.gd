extends Node3D

#purely a schema for creating config resource:
#create new .tres resource, attach this script to it and 
#edit values as needed

@export var boid_count: int = 350
@export var cell_size: float = 4.0
@export var sight_radius: float = 5.0
@export var cage_radius: float = 40.0
@export var max_speed: float = 25.0
@export var desired_separation: float = 0.5

@export var alignment_weight: float = 1.1
@export var cohesion_weight: float = 4.5
@export var separation_weight: float = 4.0
@export var wander_strength: float = 2.0
@export var boundary_strength: float = 0.9
