# GlobalComputeDevice.gd
extends Node

var rd: RenderingDevice

func _ready() -> void:
	if rd == null:
		rd = RenderingServer.create_local_rendering_device()
		print("GlobalComputeDevice: created local RenderingDevice")
