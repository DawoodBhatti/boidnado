extends Node

var device
var buffers

#TODO:
#Currently the integration step is coupled within the behaviour pass
# which might be causing issues...
# but it isn't a priority to unpick this yet
# will return to this in future hopefully

func _ready():
	device = get_node("../../GPU_Device")
	buffers = get_node("../../GPU_Buffers")

func run(delta):
	print("Pass_Integration: dispatch compute with delta", delta)
