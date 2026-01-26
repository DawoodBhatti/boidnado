extends Node

var device
var buffers

func _ready():
	device = get_node("../../GPU_Device")
	buffers = get_node("../../GPU_Buffers")

func run():
	print("Pass_GridSort: dispatch compute")
