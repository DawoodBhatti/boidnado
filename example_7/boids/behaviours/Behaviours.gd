extends Node

var rd: RenderingDevice
var pipeline: RID
var shader: RID

func _ready() -> void:
	rd = RenderingServer.get_rendering_device()
	_load_shader()

func _load_shader() -> void:
	var folder: String = get_script().resource_path.get_base_dir()
	var shader_path: String = folder + "/Behaviours.glsl"

	print("Loading shader from: ", shader_path)

	var shader_file: RDShaderFile = load(shader_path)
	if shader_file == null:
		push_error("Failed to load shader at: " + shader_path)
		return

	shader = rd.shader_create_from_spirv(shader_file.get_spirv())
	pipeline = rd.compute_pipeline_create(shader)

func dispatch(
	buffers: Node,
	start_index: int,
	boid_count: int,
	delta: float,
	mask: Dictionary
) -> void:
	var uniform_set: RID = _create_uniform_set(
		buffers,
		start_index,
		boid_count,
		delta,
		mask
	)

	var compute_list: int = rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)

	var group_size: int = 256
	var group_count: int = int(ceil(float(boid_count) / float(group_size)))

	rd.compute_list_dispatch(compute_list, group_count, 1, 1)
	rd.compute_list_end()

func _create_uniform_set(
	buffers: Node,
	start_index: int,
	boid_count: int,
	delta: float,
	mask: Dictionary
) -> RID:
	var uniforms: Array = []

	# Global buffers
	uniforms.append({ "binding": 0, "resource": buffers.get_positions() })
	uniforms.append({ "binding": 1, "resource": buffers.get_velocities() })
	uniforms.append({ "binding": 2, "resource": buffers.get_swarm_ids() })
	uniforms.append({ "binding": 3, "resource": buffers.get_cell_ids() })
	uniforms.append({ "binding": 4, "resource": buffers.get_sorted_indices() })
	uniforms.append({ "binding": 5, "resource": buffers.get_cell_start() })
	uniforms.append({ "binding": 6, "resource": buffers.get_cell_end() })

	# Slice + delta
	var params: PackedFloat32Array = PackedFloat32Array()
	params.append(float(start_index))
	params.append(float(boid_count))
	params.append(delta)
	uniforms.append({ "binding": 7, "resource": params })

	# Behaviour mask
	var mask_values: PackedInt32Array = PackedInt32Array()
	mask_values.append(_bool_to_int(mask["alignment"]))
	mask_values.append(_bool_to_int(mask["cohesion"]))
	mask_values.append(_bool_to_int(mask["separation"]))
	mask_values.append(_bool_to_int(mask["wander"]))
	mask_values.append(_bool_to_int(mask["boundary"]))

	uniforms.append({ "binding": 8, "resource": mask_values })

	var uniform_set: RID = rd.uniform_set_create(uniforms, shader, 0)
	return uniform_set

func _bool_to_int(value: bool) -> int:
	if value:
		return 1
	return 0
