# GPUBehaviours.gd
extends Node

# These functions will eventually dispatch compute shaders
static func apply_alignment():
	pass

#TODO: coming soon
#GPU side will work slightly differently but at its core will be similar to CPU
#in that file we define ALL possible behaviuors and select which ones to apply.
#we take the preset behaviour mask and pass that to the GPU which filters out what is needed
