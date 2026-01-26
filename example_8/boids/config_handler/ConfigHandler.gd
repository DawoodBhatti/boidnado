extends Node

var presets = {}

func _ready():
	print("ConfigHandler: loading behaviour presets")

func get_preset(name):
	print("ConfigHandler: returning preset", name)
	return {}
