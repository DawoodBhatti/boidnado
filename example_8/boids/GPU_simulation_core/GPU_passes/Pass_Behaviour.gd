extends Node

var device
var buffers

func _ready():
	device = get_node("../../GPU_Device")
	buffers = get_node("../../GPU_Buffers")

func run(delta):
	print("Pass_Behaviour: dispatch compute with delta", delta)
