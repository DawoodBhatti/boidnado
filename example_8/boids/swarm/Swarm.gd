extends Node

var start_index = 0
var count = 0

var positions = []
var velocities = []

var renderer : Node3D
var cage : Node3D
var debug : Node3D
var mesh : ArrayMesh

func _ready():
	renderer = get_node("Renderer")
	cage = get_node("Cage")
	debug = get_node("VisualDebug")

func update():
	renderer.update(positions)
	debug.update(positions, velocities)
