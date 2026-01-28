extends Node

var start_index = 0
var colour : Color
var count = 0

var renderer : Node3D
var cage : Node3D
var debug : Node3D
var mesh : ArrayMesh

func _ready():
	renderer = get_node("Renderer")
	cage = get_node("Cage")
	debug = get_node("VisualDebug")

func update():
	renderer.update()
	debug.update()
