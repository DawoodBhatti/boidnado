extends Node

# ---------------------------------------------------------
# Debug Toggle
# ---------------------------------------------------------
@export var debug_enabled: bool = false

# ---------------------------------------------------------
# Config State
# ---------------------------------------------------------
@export var config_path: String = ""
var config_data: Dictionary = {}
var boid_mesh: Mesh = null


func _ready() -> void:
	load_config()
	load_boid_mesh()


# ---------------------------------------------------------
# Path Helpers
# ---------------------------------------------------------

func _get_config_folder() -> String:
	var script_path: String = get_script().resource_path
	var folder: String = script_path.get_base_dir()
	return folder


func set_config_file(file_name: String) -> void:
	var folder: String = _get_config_folder()
	config_path = folder + "/" + file_name
	if debug_enabled:
		print("ConfigHandler: Resolved config path to: ", config_path)


# ---------------------------------------------------------
# Load JSON Config
# ---------------------------------------------------------

func load_config() -> void:
	if config_path == "":
		push_warning("ConfigHandler: No config path set.")
		return

	var file: FileAccess = FileAccess.open(config_path, FileAccess.READ)
	if file == null:
		push_error("ConfigHandler: Failed to open config file: " + config_path)
		return

	var text: String = file.get_as_text()

	if debug_enabled:
		print("RAW JSON TEXT:\n", text)

	var json: JSON = JSON.new()
	var error_code: int = json.parse(text)

	if error_code != OK:
		push_error(
			"ConfigHandler: JSON parse error at line %d: %s" % [
				json.get_error_line(),
				json.get_error_message()
			]
		)
		return

	if debug_enabled:
		print("PARSE ERROR CODE: ", error_code)
		print("PARSE ERROR LINE: ", json.get_error_line())
		print("PARSE ERROR MESSAGE: ", json.get_error_message())

	var result: Variant = json.data

	if typeof(result) != TYPE_DICTIONARY:
		push_error("ConfigHandler: JSON root is not a dictionary.")
		return

	config_data = result as Dictionary

	print("ConfigHandler: Loaded JSON config: " + config_path)


# ---------------------------------------------------------
# Load Mesh
# ---------------------------------------------------------

func load_boid_mesh() -> void:
	if not config_data.has("boid_mesh_path"):
		if debug_enabled:
			push_warning("ConfigHandler: No boid_mesh_path in config.")
		return

	var mesh_path: String = config_data["boid_mesh_path"]
	var mesh: Resource = load(mesh_path)

	if mesh == null:
		push_error("ConfigHandler: Failed to load mesh at: " + mesh_path)
		return

	boid_mesh = mesh as Mesh

	if debug_enabled:
		print("ConfigHandler: Loaded boid mesh: " + mesh_path)


# ---------------------------------------------------------
# Debug Dump
# ---------------------------------------------------------

func print_all_values() -> void:
	if not debug_enabled:
		return

	print("----- CONFIG VALUES -----")

	for key: String in config_data.keys():
		var value: Variant = config_data[key]
		print(key, ": ", value)

	if boid_mesh != null:
		print("boid_mesh: [Mesh loaded successfully]")
	else:
		print("boid_mesh: null (not loaded)")

	print("--------------------------")


# ---------------------------------------------------------
# Public API
# ---------------------------------------------------------

func get_value(key: String, default_value: Variant) -> Variant:
	if config_data.has(key):
		return config_data[key]
	return default_value


func get_mesh() -> Mesh:
	return boid_mesh
