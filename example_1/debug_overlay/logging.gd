extends Node

# Enable/disable debug printing
const DEBUG_PRINT: bool = false

var start_time: float = 0.0
var recording_enabled: bool = false

var samples: Dictionary = {
	"FPS": [],
	"CPU": [],
	"RAM": [],
	"Draws": [],
	"Vertices": []
}

# ---------------------------------------------------------
# READY → START TIMER
# ---------------------------------------------------------
func _ready() -> void:
	start_time = Time.get_ticks_msec() / 1000.0


# ---------------------------------------------------------
# COLLECT SAMPLES (only after warm-up)
# ---------------------------------------------------------
func log_results(FPS: Label, CPU: Label, RAM: Label, Draws: Label, vertex_count: int) -> void:
	var runtime: float = (Time.get_ticks_msec() / 1000.0) - start_time

	# Only start recording after 2 seconds
	if not recording_enabled:
		if runtime >= 2.0:
			recording_enabled = true
		else:
			return

	samples["FPS"].append(_parse_int_label(FPS.text))
	samples["CPU"].append(_parse_float_ms_label(CPU.text))
	samples["RAM"].append(_parse_float_label(RAM.text))
	samples["Draws"].append(_parse_int_label(Draws.text))
	samples["Vertices"].append(vertex_count)

# ---------------------------------------------------------
# PARSING HELPERS
# ---------------------------------------------------------
func _parse_int_label(text: String) -> int:
	var parts: Array = text.split(":")
	if parts.size() < 2:
		return 0
	return int(parts[1].strip_edges())

func _parse_float_ms_label(text: String) -> float:
	var parts: Array = text.split(":")
	if parts.size() < 2:
		return 0.0
	var cleaned: String = parts[1].trim_suffix(" ms").strip_edges()
	return float(cleaned)

func _parse_float_label(text: String) -> float:
	var parts: Array = text.split(":")
	if parts.size() < 2:
		return 0.0
	var cleaned: String = parts[1].strip_edges()
	var first: String = cleaned.split(" ")[0]
	return float(first)


# ---------------------------------------------------------
# SUMMARY OF A SINGLE RUN
# ---------------------------------------------------------
func get_summary() -> Dictionary:
	return {
		"FPS": _summarize(samples["FPS"]),
		"CPU": _summarize(samples["CPU"]),
		"RAM": _summarize(samples["RAM"]),
		"Draws": _summarize(samples["Draws"]),
		"Vertices": _summarize(samples["Vertices"])
	}

func _summarize(arr: Array) -> Dictionary:
	var filtered: Array = []
	for v in arr:
		if float(v) > 0.0:
			filtered.append(v)

	if filtered.is_empty():
		return {"min": 0.0, "max": 0.0, "avg": 0.0}

	var total: float = 0.0
	for v in filtered:
		total += float(v)

	return {
		"min": float(filtered.min()),
		"max": float(filtered.max()),
		"avg": total / float(filtered.size())
	}


# ---------------------------------------------------------
# ITERATION HELPERS
# ---------------------------------------------------------
func _get_iteration_tag() -> String:
	var scene_path: String = get_tree().current_scene.scene_file_path
	var parts: Array = scene_path.split("/")
	for part: String in parts:
		if part.begins_with("example"):
			return part.replace(" ", "_")
	return "unknown_version"

func _get_iteration_number(version: String) -> int:
	var parts := version.split("_")
	if parts.size() >= 2:
		return int(parts[1])
	return -1

func _cleanup_old_logs(version: String) -> void:
	var iter := _get_iteration_number(version)
	if iter < 0:
		return

	var folder := "res://%s/debug_overlay/" % version
	var files := DirAccess.get_files_at(folder)

	for file in files:
		if file.begins_with("local_performance_log_") or file.begins_with("local_performance_summary_"):
			var base := file.get_basename()
			var num_str := base.split("_")[-1]
			var num := int(num_str)

			if num != iter:
				DirAccess.remove_absolute(folder + file)


# ---------------------------------------------------------
# SAVE RESULTS
# ---------------------------------------------------------
func save_performance_results() -> void:
	var runtime: float = (Time.get_ticks_msec() / 1000.0) - start_time

	if runtime < 2.0:
		print("Run ignored (runtime too short): ", runtime)
		return

	var version: String = _get_iteration_tag()

	# NEW: delete mismatched logs
	_cleanup_old_logs(version)

	var summary: Dictionary = get_summary()
	var timestamp: String = Time.get_datetime_string_from_system()

	_write_local_raw(version, summary, runtime, timestamp)
	_write_local_summary(version, summary, runtime)
	PerformanceTracker.update_global()

	if DEBUG_PRINT:
		_debug_print_local(version)
		_debug_print_global(version)

	print("Saved local + global performance for ", version)


# ---------------------------------------------------------
# LOCAL FILES
# ---------------------------------------------------------
func _write_local_raw(version: String, summary: Dictionary, runtime: float, timestamp: String) -> void:
	var iter := _get_iteration_number(version)
	var path: String = "res://%s/debug_overlay/local_performance_log_%d.json" % [version, iter]

	var entry: Dictionary = {
		"timestamp": timestamp,
		"runtime_seconds": runtime,
		"summary": summary
	}

	var existing: Array = []
	if FileAccess.file_exists(path):
		var f: FileAccess = FileAccess.open(path, FileAccess.READ)
		var parsed: Variant = JSON.parse_string(f.get_as_text())
		if typeof(parsed) == TYPE_ARRAY:
			existing = parsed

	existing.append(entry)

	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(existing, "\t"))
	file.close()

func _write_local_summary(version: String, last_summary: Dictionary, runtime: float) -> void:
	var iter := _get_iteration_number(version)

	var log_path: String = "res://%s/debug_overlay/local_performance_log_%d.json" % [version, iter]
	var summary_path: String = "res://%s/debug_overlay/local_performance_summary_%d.json" % [version, iter]

	if not FileAccess.file_exists(log_path):
		return

	var f: FileAccess = FileAccess.open(log_path, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()

	if typeof(parsed) != TYPE_ARRAY:
		return

	var entries: Array = parsed
	if entries.is_empty():
		return

	var metrics := ["FPS", "CPU", "RAM", "Draws"]

	var min_values := {}
	var max_values := {}
	var sum_weighted_avgs := {}
	var sum_weights := {}

	for metric in metrics:
		min_values[metric] = INF
		max_values[metric] = -INF
		sum_weighted_avgs[metric] = 0.0
		sum_weights[metric] = 0.0

	var total_runtime: float = 0.0

	for entry in entries:
		if typeof(entry) != TYPE_DICTIONARY:
			continue

		var run_summary: Dictionary = entry.get("summary", {})
		var run_runtime: float = float(entry.get("runtime_seconds", 0.0))
		if run_runtime <= 0.0:
			run_runtime = 1.0

		total_runtime += run_runtime

		for metric in metrics:
			if not run_summary.has(metric):
				continue

			var m: Dictionary = run_summary[metric]

			if m.has("min"):
				min_values[metric] = min(min_values[metric], float(m["min"]))
			if m.has("max"):
				max_values[metric] = max(max_values[metric], float(m["max"]))

			if m.has("avg"):
				var avg_val: float = float(m["avg"])
				sum_weighted_avgs[metric] += avg_val * run_runtime
				sum_weights[metric] += run_runtime

	var final_summary: Dictionary = {}

	for metric in metrics:
		var metric_min: float = min_values[metric]
		var metric_max: float = max_values[metric]
		var weight: float = sum_weights[metric]
		var metric_avg: float = 0.0
		if weight > 0.0:
			metric_avg = sum_weighted_avgs[metric] / weight

		if metric_min == INF:
			metric_min = 0.0
		if metric_max == -INF:
			metric_max = 0.0

		final_summary[metric] = {
			"min": metric_min,
			"max": metric_max,
			"avg": metric_avg
		}

	final_summary["runs"] = entries.size()
	final_summary["total_runtime_seconds"] = total_runtime

	var out: FileAccess = FileAccess.open(summary_path, FileAccess.WRITE)
	out.store_string(JSON.stringify(final_summary, "\t"))
	out.close()


# ---------------------------------------------------------
# DEBUG PRINTING
# ---------------------------------------------------------
func _debug_print_local(version: String) -> void:
	var iter := _get_iteration_number(version)
	var raw_path: String = "res://%s/debug_overlay/local_performance_log_%d.json" % [version, iter]
	var summary_path: String = "res://%s/debug_overlay/local_performance_summary_%d.json" % [version, iter]

	print("\n--- LOCAL RAW LOG ---")
	if FileAccess.file_exists(raw_path):
		var f: FileAccess = FileAccess.open(raw_path, FileAccess.READ)
		print(f.get_as_text())

	print("\n--- LOCAL SUMMARY ---")
	if FileAccess.file_exists(summary_path):
		var f2: FileAccess = FileAccess.open(summary_path, FileAccess.READ)
		print(f2.get_as_text())


func _debug_print_global(version: String) -> void:
	print("\n--- GLOBAL SUMMARY ---")
	print(JSON.stringify(PerformanceTracker.global_results, "\t"))
