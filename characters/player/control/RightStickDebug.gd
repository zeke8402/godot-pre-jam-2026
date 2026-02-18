extends MeshInstance3D  # Use MeshInstance3D or Node3D, depending on your node type

@export var distance_from_player: float = 5.0  # Distance to position the Arrow away from the Player
@export var rotation_y_angle: float = 0.0  # Rotation angle around the Y-axis in degrees
@export var rotation_x_angle: float = 90.0  # Rotation angle around the X-axis in degrees

func _ready():
	# Optionally set an initial local position if needed
	update_position()

func _process(delta: float):
	# Continuously update Arrow's position and rotation
	update_position()

func update_position():
	# Get the Player node
	var player = get_parent()
	
	if player == null:
		return

	# Get the direction vector from input
	var input_dir = Input.get_vector("aim_left", "aim_right", "aim_forward", "aim_back")
	if input_dir.x == 0 and input_dir.y == 0:
		visible = false
	else:
		visible = true
	
	# Calculate the opposite direction
	var opposite_dir = -input_dir

	# Set Arrow's global position to Player's global position plus an offset in the opposite direction
	global_transform.origin = player.global_transform.origin + Vector3(opposite_dir.x, 0, opposite_dir.y).normalized() * distance_from_player
