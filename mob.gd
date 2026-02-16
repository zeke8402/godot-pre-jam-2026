extends CharacterBody3D

# Movement speed in meters per second.
@export var speed = 10;

var player: CharacterBody3D

func _physics_process(delta: float) -> void:
	if player:
		look_at(player.position)
	
		velocity = Vector3.FORWARD * speed;
		velocity = velocity.rotated(Vector3.UP, rotation.y);

		move_and_slide()

func initialize(spawn_location, p):
	player = p
	look_at_from_position(spawn_location, player.position, Vector3.UP)
