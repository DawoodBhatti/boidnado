extends CharacterBody3D


@onready var logger : Node = $"../DebugOverlay/Logging"

# -----------------------------------------
# Vertical thrust system
# -----------------------------------------
const VERTICAL_THRUST := 50.0
const VERTICAL_DAMP := 6.0   # Higher = stronger pull toward 0 y velocity

# -----------------------------------------
# Mouse look
# -----------------------------------------
func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _unhandled_input(event):
	if event is InputEventMouseMotion:
		rotation_degrees.y -= event.relative.x * 0.3
		%Camera3D.rotation_degrees.x -= event.relative.y * 0.3
		%Camera3D.rotation_degrees.x = clamp(%Camera3D.rotation_degrees.x, -60.0, 60.0)

	# We should really move things like this (global controls) to a top level node when we move away from prototyping
	elif event.is_action_pressed("escape_no_save"):
		get_tree().quit()

	# ... And this
	elif event.is_action_pressed("ui_cancel"):
		logger.save_performance_results()
		get_tree().quit()


# -----------------------------------------
# Movement + vertical thrust
# -----------------------------------------
func _physics_process(delta):
	const SPEED = 7.5

	# -------------------------------------
	# Horizontal movement
	# -------------------------------------
	var input_direction_2D = Input.get_vector(
		"move_left", "move_right", "move_forward", "move_back"
	)
	var input_direction_3D = Vector3(input_direction_2D.x, 0, input_direction_2D.y)
	var direction = transform.basis * input_direction_3D

	velocity.x = direction.x * SPEED
	velocity.z = direction.z * SPEED

	# -------------------------------------
	# Vertical thrust input
	# -------------------------------------
	if Input.is_action_pressed("shift"):
		velocity.y -= VERTICAL_THRUST * delta

	if Input.is_action_pressed("jump"):
		velocity.y += VERTICAL_THRUST * delta

	# -------------------------------------
	# Rubber-band velocity toward 0
	# -------------------------------------
	velocity.y = lerp(velocity.y, 0.0, delta * VERTICAL_DAMP)

	# -------------------------------------
	# Apply movement
	# -------------------------------------
	move_and_slide()
