extends Node

@export var mob_scene: PackedScene;

func _on_mob_timer_timeout() -> void:
	var mob = mob_scene.instantiate()
	var spawn_location = get_node("SpawnPath/SpawnLocation")
	var player = $Player
	
	spawn_location.progress_ratio = randf()
	
	mob.initialize(spawn_location.position, player)
	
	add_child(mob)
