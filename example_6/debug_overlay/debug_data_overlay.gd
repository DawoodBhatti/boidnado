extends CanvasLayer

var update_interval: float = 0.5
var time_accum: float = 0.0

var FPS: Label
var CPU: Label
var RAM: Label
var Draws: Label
var BoidCount: Label

@onready var logger: Node = $Logging
@onready var SwarmManager : Node = $"../Boids/SwarmManager"

func _ready() -> void:

	FPS = $VboxContainer/FPS
	CPU = $VboxContainer/CPU
	RAM = $VboxContainer/RAM
	Draws = $VboxContainer/Draws
	BoidCount = $VboxContainer/BoidCount

func _process(delta: float) -> void:
	time_accum += delta
	if time_accum >= update_interval:
		time_accum = 0.0
		_update_stats()

func _update_stats() -> void:
	var fps: int = Engine.get_frames_per_second()
	var mem: float = OS.get_static_memory_usage() / (1024.0 * 1024.0)
	var mem_peak: float = OS.get_static_memory_peak_usage() / (1024.0 * 1024.0)
	var cpu_time: float = Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	var draw_calls: int = Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	var number_boids: int = SwarmManager.boid_count

	FPS.text = "FPS: %d" % fps
	CPU.text = "CPU frame time: %.2f ms" % cpu_time
	RAM.text = "RAM: %.2f MB (peak %.2f MB)" % [mem, mem_peak]
	Draws.text = "Draw Calls: %d" % draw_calls
	BoidCount.text = "Boid Count: %d" % number_boids

	# FPS color
	if fps < 55:
		FPS.add_theme_color_override("font_color", Color.ORANGE)
	else:
		FPS.add_theme_color_override("font_color", Color.WHITE)

	# CPU color
	if cpu_time > 18.18:
		CPU.add_theme_color_override( "font_color", Color.ORANGE)
	else:
		CPU.add_theme_color_override("font_color", Color.WHITE)

	# Logging (now includes vertex count)
	logger.log_results(FPS, CPU, RAM, Draws, BoidCount)

func get_iteration_tag() -> String:
	var scene_path: String = get_tree().current_scene.scene_file_path
	var parts: Array = scene_path.split("/")
	for part: String in parts:
		if part.begins_with("example"):
			return part.replace(" ", "_")
	return "unknown_version"
