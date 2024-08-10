extends CharacterBody3D

const SPEED = 25.0
const JUMP_VELOCITY = 4.5

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var player_body = $PlayerBody

func _physics_process(delta):
	# Add the gravity.
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Handle jump.
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()
	handle_rotation()
	
func handle_rotation():
	# Get the right joystick input using the "aim_left" convention
	var right_stick_input = Input.get_vector("aim_left", "aim_right", "aim_forward", "aim_back")
	
	# Check if there is any input
	if right_stick_input.length_squared() > 0:
		# Calculate the rotation angle
		var angle = atan2(right_stick_input.x, right_stick_input.y)
		
		# Rotate the character model
		self.rotation_degrees.y = rad_to_deg(angle)

