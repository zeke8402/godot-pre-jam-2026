extends CharacterBody3D

# Movement speed in meters per second.
@export var speed = 10.0

var player: CharacterBody3D

@onready var anim_player: AnimationPlayer = $"CollisionShape3D/enemy-zombie/AnimationPlayer"

func _ready() -> void:
	play_animation("idle")

func _physics_process(delta: float) -> void:
	var previous_position := global_position

	if player:
		look_at(player.global_position)
		velocity = Vector3.FORWARD * speed
		velocity = velocity.rotated(Vector3.UP, rotation.y)
	else:
		velocity = Vector3.ZERO

	move_and_slide()

	var moved_distance := global_position.distance_to(previous_position)
	if moved_distance > 0.001:
		play_animation("running")
	else:
		play_animation("idle")

func initialize(spawn_location, p):
	player = p
	look_at_from_position(spawn_location, player.global_position, Vector3.UP)

		
func play_animation(name: String) -> void:
	if anim_player and (anim_player.current_animation != name or not anim_player.is_playing()):
		anim_player.play(name)
