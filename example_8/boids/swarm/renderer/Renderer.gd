extends Node

# Renderer will use a shader to update the GPU positions
# and the shader runs every frame so there is no need
# to trigger updates externally

func update(positions):
	print("Renderer: drawing", positions.size(), "boids")
