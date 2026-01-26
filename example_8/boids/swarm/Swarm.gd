extends Node

var start_index = 0
var count = 0

var positions = []
var velocities = []

var renderer
var cage
var debug

func _ready():
	renderer = get_node("Renderer")
	cage = get_node("Cage")
	debug = get_node("VisualDebug")

func update():
	renderer.update(positions)
	debug.update(positions, velocities)
