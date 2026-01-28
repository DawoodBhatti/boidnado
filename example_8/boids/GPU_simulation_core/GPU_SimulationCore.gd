extends Node

var device : Node
var buffers : Node

var pass_grid_assign : Node
var pass_grid_sort : Node
var pass_grid_mapping : Node
var pass_behaviour : Node
var pass_integration : Node

func _ready():
	device = get_node("GPU_Device")
	buffers = get_node("GPU_Buffers")
	var passes = get_node("GPU_Passes")
	
	pass_grid_assign = passes.get_node("Pass_GridAssign")
	pass_grid_sort = passes.get_node("Pass_GridSort")
	pass_grid_mapping = passes.get_node("Pass_GridMapping")
	pass_behaviour = passes.get_node("Pass_Behaviour")
	pass_integration = passes.get_node("Pass_Integration")

func simulate(delta):
	pass_grid_assign.run()
	pass_grid_sort.run()
	pass_grid_mapping.run()
	pass_behaviour.run(delta)
	pass_integration.run(delta)
