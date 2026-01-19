extends Node

var global_path: String = "res://global performance tracker/global_performance_log.json"
var global_results: Dictionary = {}

func _ready() -> void:
	_load_global()

# ---------------------------------------------------------
# PUBLIC TRIGGER FUNCTION UPDATES GLOBAL LOG FROM LOCAL SUMMARIES
# ---------------------------------------------------------
func update_global() -> void:
	_refresh_from_local_summaries()
	_write_global()

# ---------------------------------------------------------
# LOAD EXISTING GLOBAL FILE
# ---------------------------------------------------------
func _load_global() -> void:
	if FileAccess.file_exists(global_path):
		var f: FileAccess = FileAccess.open(global_path, FileAccess.READ)
		var text: String = f.get_as_text()
		var parsed: Variant = JSON.parse_string(text)
		if typeof(parsed) == TYPE_DICTIONARY:
			global_results = parsed as Dictionary

# ---------------------------------------------------------
# REFRESH GLOBAL SUMMARY FROM LOCAL SUMMARY FILES
# ---------------------------------------------------------
func _refresh_from_local_summaries() -> void:
	var dir: DirAccess = DirAccess.open("res://")
	if dir == null:
		push_error("Could not open project root")
		return

	dir.list_dir_begin()

	while true:
		var folder: String = dir.get_next()
		if folder == "":
			break

		if dir.current_is_dir() and folder.begins_with("example_"):
			_load_example_summary(folder)

	dir.list_dir_end()

# ---------------------------------------------------------
# EXTRACT ITERATION NUMBER FROM FOLDER NAME
# example_20 → 20
# ---------------------------------------------------------
func _get_iteration_number(example_folder: String) -> int:
	var parts := example_folder.split("_")
	if parts.size() >= 2:
		return int(parts[1])
	return -1

# ---------------------------------------------------------
# LOAD ONE EXAMPLE'S LOCAL SUMMARY (NEW FORMAT)
# ---------------------------------------------------------
func _load_example_summary(example_folder: String) -> void:
	var iter := _get_iteration_number(example_folder)
	if iter < 0:
		return

	var summary_path: String = "res://%s/debug_overlay/local_performance_summary_%d.json" % [example_folder, iter]

	if not FileAccess.file_exists(summary_path):
		return

	var f: FileAccess = FileAccess.open(summary_path, FileAccess.READ)
	var text: String = f.get_as_text()
	var parsed: Variant = JSON.parse_string(text)

	if typeof(parsed) != TYPE_DICTIONARY:
		return

	var summary: Dictionary = parsed as Dictionary
	global_results[example_folder] = summary

# ---------------------------------------------------------
# WRITE GLOBAL FILE
# ---------------------------------------------------------
func _write_global() -> void:
	var file: FileAccess = FileAccess.open(global_path, FileAccess.WRITE)
	var json_text: String = JSON.stringify(global_results, "\t")
	file.store_string(json_text)
	file.close()
