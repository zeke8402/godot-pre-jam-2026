extends CharacterBody3D

@export var SPEED = 25.0
const JUMP_VELOCITY = 4.5

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var player_body = $PlayerBody
@onready var anim_player = $KennyModel/AnimationPlayer

var current_animation = 'idle'

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
	input_dir = -input_dir
	
	if input_dir.length() > 0.1:
		play_animation("running")
	else:
		play_animation("idle")
	
	var direction = Vector3(input_dir.x, 0, input_dir.y).normalized()
	
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()
	handle_rotation(delta)
	
func handle_rotation(delta):
	var aim_input = Input.get_vector("aim_left", "aim_right", "aim_forward", "aim_back")
	var move_input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	move_input = -move_input

	# 1️⃣ If right stick is active → INSTANT rotation (like your original)
	if aim_input.length_squared() > 0:
		var aim_angle = atan2(aim_input.x, aim_input.y)
		rotation_degrees.y = rad_to_deg(aim_angle)
		return

# 2️⃣ If no aim, but moving → gradual rotate toward movement direction
	if move_input.length_squared() > 0:
		var move_dir_3d = Vector3(move_input.x, 0, move_input.y).normalized()
	
		# Convert movement direction into a proper 3D facing basis
		var target_basis = Basis().looking_at(move_dir_3d, Vector3.UP)
	
		# Smoothly rotate toward it
		transform.basis = transform.basis.slerp(target_basis, 8.0 * delta)
		
		
func play_animation(name):
	if current_animation != name:
		current_animation = name
		anim_player.play(name)
