extends Node
"""
ConfigHandler.gd — Stateless multi-file configuration loader.

Responsibilities:
 - Resolve file paths
 - Load JSON files
 - Return dictionaries exactly as-is
 - Load meshes directly from models folder
 - Store no internal state
"""

@export var debug_enabled: bool = true


# ---------------------------------------------------------
# PATH RESOLUTION
# ---------------------------------------------------------

func _get_config_folder() -> String:
	# Folder where this script lives
	var script_path: String = get_script().resource_path
	return script_path.get_base_dir()


func resolve_config_path(subfolder: String, file_name: String) -> String:
	# Build absolute path to config file inside a subfolder
	var base := _get_config_folder()
	var full_path := base + "/" + subfolder + "/" + file_name

	if debug_enabled:
		print("ConfigHandler: Resolved path:", full_path)

	return full_path


# ---------------------------------------------------------
# LOAD JSON CONFIG (STATELESS)
# ---------------------------------------------------------

func load_json_from_path(full_path: String) -> Dictionary:
	# Open file
	var file := FileAccess.open(full_path, FileAccess.READ)
	if file == null:
		push_error("ConfigHandler: Failed to open JSON file: " + full_path)
		return {}

	# Read text
	var text := file.get_as_text()

	# Parse JSON
	var json := JSON.new()
	var err := json.parse(text)

	if err != OK:
		push_error(
            "ConfigHandler: JSON parse error in file '%s' at line %d: %s"
			% [full_path, json.get_error_line(), json.get_error_message()]
		)
		return {}

	# Ensure dictionary
	var data = json.data
	if typeof(data) != TYPE_DICTIONARY:
		push_error(
            "ConfigHandler: JSON root in file '%s' is not a dictionary."
			% full_path
		)
		return {}

	if debug_enabled:
		print("ConfigHandler: Loaded JSON:", full_path)

	return data

# ---------------------------------------------------------
# CATEGORY-SPECIFIC EXTRACTORS
# ---------------------------------------------------------

func extract_swarm_constants(file_name: String) -> Dictionary:
	var path = resolve_config_path("swarm_constants", file_name)
	return load_json_from_path(path)


func extract_behaviour_weights(file_name: String) -> Dictionary:
	var path = resolve_config_path("behaviour_weights", file_name)
	return load_json_from_path(path)


func extract_behaviour_masks(file_name: String) -> Dictionary:
	var path = resolve_config_path("behaviour_masks", file_name)
	return load_json_from_path(path)


func extract_interaction_masks(file_name: String) -> Dictionary:
	var path = resolve_config_path("interaction_masks", file_name)
	return load_json_from_path(path)


# ---------------------------------------------------------
# MESH EXTRACTION
# ---------------------------------------------------------

func extract_mesh(mesh_file_name: String) -> Mesh:
	# Resolve path to the models folder (sibling to config folder)
	var base := _get_config_folder()        # e.g. res://configs
	var models_path := base.get_base_dir()  # go one level up
	models_path += "/models/" + mesh_file_name

	if debug_enabled:
		print("ConfigHandler: Loading mesh from:", models_path)

	var mesh: Resource = load(models_path)

	if mesh == null:
		push_error("ConfigHandler: Failed to load mesh: " + models_path)
		return null

	return mesh
