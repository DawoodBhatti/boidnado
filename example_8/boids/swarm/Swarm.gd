extends Node

"""
Swarm.gd
--------
Represents a single swarm configuration in the scene.

Responsibilities:
 - Holds CPU‑side metadata for this swarm (mesh, colour, boid count)
 - Defines the boid index range assigned to this swarm (start_index → start_index + count)
 - Provides references to child systems (Cage, VisualDebug)
 - Wires its children so they know which swarm they belong to
 - Forwards per‑frame update calls to Renderer and VisualDebug

Does NOT:
 - Run simulation logic
 - Read or write GPU buffers
 - Manage GPU resources
"""


var start_index = 0        # First boid index for this swarm
var colour : Color         # Swarm colour
var count = 0              # Number of boids in this swarm

var renderer : Node3D      # GPU/CPU renderer
var cage : Node3D          # Optional cage visualisation
var debug : Node3D         # Debug visualiser
var mesh : ArrayMesh       # Mesh used for this swarm


func _ready():
	cage = get_node("Cage")
	debug = get_node("VisualDebug")

	# Tell children which swarm they belong to
	debug.swarm = self

func update():
	# Forward update calls to children
	#TODO renderer might be integrated into GPU pipeline next
	#renderer.update()
	debug.update()
