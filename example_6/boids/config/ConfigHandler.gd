extends Node
"""
============================================================
 ConfigHandler.gd — Pure Stateless Configuration Extractor
============================================================

This node provides *stateless* access to JSON config files
and mesh resources. It stores NO internal variables that
could leak between swarms.

Every call:
 - Loads the JSON file fresh
 - Extracts values into a new Dictionary
 - Loads the mesh fresh 
 - Returns everything to the caller
 - Retains nothing internally

This guarantees:
 - No shared config data
 - No accidental cross‑swarm contamination
"""

@export var debug_enabled: bool = true


# ---------------------------------------------------------
# PATH RESOLUTION
# ---------------------------------------------------------

func _get_config_folder() -> String:
	# Folder where this script lives
	var script_path: String = get_script().resource_path
	return script_path.get_base_dir()


func resolve_config_path(file_name: String) -> String:
	# Build absolute path to config file
	var folder := _get_config_folder()
	var full_path := folder + "/" + file_name

	if debug_enabled:
		print("ConfigHandler: Resolved config path:", full_path)

	return full_path


# ---------------------------------------------------------
# LOAD JSON CONFIG (STATELESS)
# ---------------------------------------------------------

func load_config_data(file_name: String) -> Dictionary:
	"""
    Loads the JSON config file and returns a fresh Dictionary.
    No internal state is stored.
	"""

	var full_path := resolve_config_path(file_name)

	var file := FileAccess.open(full_path, FileAccess.READ)
	if file == null:
		push_error("ConfigHandler: Failed to open config file: " + full_path)
		return {}

	var text := file.get_as_text()

	var json := JSON.new()
	var error_code := json.parse(text)

	if error_code != OK:
		push_error("ConfigHandler: JSON parse error at line %d: %s"
			% [json.get_error_line(), json.get_error_message()])
		return {}

	var result : Dictionary = json.data
	if typeof(result) != TYPE_DICTIONARY:
		push_error("ConfigHandler: JSON root is not a dictionary.")
		return {}

	if debug_enabled:
		print("ConfigHandler: Loaded JSON config:", full_path)

	return result


# ---------------------------------------------------------
# LOAD MESH (STATELESS)
# ---------------------------------------------------------

func load_mesh_from_config(config: Dictionary) -> Mesh:
	if not config.has("boid_mesh_path"):
		if debug_enabled:
			push_warning("ConfigHandler: No boid_mesh_path in config.")
		return null

	var mesh_path: String = config["boid_mesh_path"]
	var mesh: Resource = load(mesh_path)

	if mesh == null:
		push_error("ConfigHandler: Failed to load mesh at: " + mesh_path)
		return null

	if debug_enabled:
		print("ConfigHandler: Loaded mesh:", mesh_path)

	return mesh


# ---------------------------------------------------------
# PUBLIC API — EXTRACT PARAMS FOR SWARM MANAGER
# ---------------------------------------------------------

func extract_params(file_name: String) -> Dictionary:

	var config : Dictionary = load_config_data(file_name)

	if config.is_empty():
		push_warning("ConfigHandler: Config empty or failed to load.")
		return {}

	var mesh : Mesh = load_mesh_from_config(config)
	
	var c = config.get("boid_colour", [1,1,1,1])
	var color = Color(c[0], c[1], c[2], c[3])

	# Build the parameter dictionary expected by BoidSwarm
	return {
		"simulation_core": config.get("simulation_core", "CPU"),
		"boid_count": int(config.get("boid_count", 200)),
		"cell_size": float(config.get("cell_size", 4.0)),
		"sight_radius": float(config.get("sight_radius", 5.0)),
		"cage_radius": float(config.get("cage_radius", 40.0)),
		"max_speed": float(config.get("max_speed", 5.0)),
		"desired_separation": float(config.get("desired_separation", 0.5)),

		"alignment_weight": float(config.get("alignment_weight", 1.1)),
		"cohesion_weight": float(config.get("cohesion_weight", 4.5)),
		"separation_weight": float(config.get("separation_weight", 4.0)),
		"wander_strength": float(config.get("wander_strength", 2.0)),
		"boundary_strength": float(config.get("boundary_strength", 0.9)),

		"boid_mesh": mesh,
		"boid_colour": color,
	}
