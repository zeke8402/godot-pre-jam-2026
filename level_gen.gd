extends Node

const WALL_DOOR: PackedScene = preload("res://kenney_retro-urban-kit/GLB format/wall-a-door.glb")
const WALL_WINDOW: PackedScene = preload("res://kenney_retro-urban-kit/GLB format/wall-a-window.glb")
const WALL_FLAT_WINDOW: PackedScene = preload("res://kenney_retro-urban-kit/GLB format/wall-a-flat-window.glb")
const WALL_DETAIL: PackedScene = preload("res://kenney_retro-urban-kit/GLB format/wall-a-detail.glb")
const CORNER: PackedScene = preload("res://kenney_retro-urban-kit/GLB format/wall-a-corner.glb")
const COLUMN: PackedScene = preload("res://kenney_retro-urban-kit/GLB format/wall-a-column.glb")
const ROOF: PackedScene = preload("res://kenney_retro-urban-kit/GLB format/wall-a-roof.glb")

@export var fly_speed := 16.0
@export var fast_fly_multiplier := 3.0
@export var look_sensitivity := 0.003

var build_delay_seconds := 0.15
var initial_delay_seconds := 0.0
var _build_token := 0
var _delay_label: Label
var _initial_delay_label: Label
var _camera: Camera3D
var _yaw := 0.0
var _pitch := 0.0

func _ready() -> void:
	_setup_free_camera()
	_setup_ui()
	_start_build()

func _on_mob_timer_timeout() -> void:
	# Intentionally blank: no mobs for this scene setup.
	pass

func _unhandled_input(event: InputEvent) -> void:
	if _camera == null:
		return
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		var motion := event as InputEventMouseMotion
		_yaw -= motion.relative.x * look_sensitivity
		_pitch = clamp(_pitch - motion.relative.y * look_sensitivity, -1.4, 1.4)
		_camera.rotation = Vector3(_pitch, _yaw, 0.0)

func _process(delta: float) -> void:
	if _camera == null:
		return
	var input_dir := -Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var vertical := 0.0
	if Input.is_action_pressed("jump") or Input.is_key_pressed(KEY_E):
		vertical += 1.0
	if Input.is_key_pressed(KEY_Q) or Input.is_key_pressed(KEY_CTRL):
		vertical -= 1.0

	var basis := _camera.global_transform.basis
	var move := basis.x * input_dir.x
	move += -basis.z * input_dir.y
	move += Vector3.UP * vertical

	if move.length_squared() > 0.0:
		move = move.normalized()
		var speed := fly_speed
		if Input.is_key_pressed(KEY_SHIFT):
			speed *= fast_fly_multiplier
		_camera.global_position += move * speed * delta

func _setup_free_camera() -> void:
	_camera = get_node_or_null("CameraPivot/Camera3D") as Camera3D
	if _camera == null:
		return
	_camera.current = true
	_pitch = _camera.rotation.x
	_yaw = _camera.rotation.y

func _setup_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "BuildUI"
	add_child(layer)

	var panel := PanelContainer.new()
	panel.anchor_left = 0.0
	panel.anchor_top = 0.0
	panel.anchor_right = 0.0
	panel.anchor_bottom = 0.0
	panel.offset_left = 16.0
	panel.offset_top = 16.0
	panel.offset_right = 260.0
	panel.offset_bottom = 120.0
	layer.add_child(panel)

	var box := VBoxContainer.new()
	panel.add_child(box)

	_initial_delay_label = Label.new()
	_initial_delay_label.text = _initial_delay_label_text()
	box.add_child(_initial_delay_label)

	var initial_slider := HSlider.new()
	initial_slider.min_value = 0.0
	initial_slider.max_value = 3.0
	initial_slider.step = 0.05
	initial_slider.value = initial_delay_seconds
	initial_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	initial_slider.value_changed.connect(_on_initial_delay_changed)
	box.add_child(initial_slider)

	_delay_label = Label.new()
	_delay_label.text = _delay_label_text()
	box.add_child(_delay_label)

	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.value = build_delay_seconds
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(_on_build_delay_changed)
	box.add_child(slider)

	var rebuild := Button.new()
	rebuild.text = "Rebuild House"
	rebuild.pressed.connect(_start_build)
	box.add_child(rebuild)

func _delay_label_text() -> String:
	return "Build Delay: %.2fs" % build_delay_seconds

func _initial_delay_label_text() -> String:
	return "Start Delay: %.2fs" % initial_delay_seconds

func _on_build_delay_changed(value: float) -> void:
	build_delay_seconds = value
	if _delay_label != null:
		_delay_label.text = _delay_label_text()

func _on_initial_delay_changed(value: float) -> void:
	initial_delay_seconds = value
	if _initial_delay_label != null:
		_initial_delay_label.text = _initial_delay_label_text()

func _start_build() -> void:
	_build_token += 1
	_spawn_house(_build_token)

func _spawn_house(token: int) -> void:
	var city_root := get_node_or_null("City") as Node3D
	if city_root == null:
		city_root = Node3D.new()
		city_root.name = "City"
		add_child(city_root)

	for child in city_root.get_children():
		child.queue_free()

	var lot := Node3D.new()
	lot.name = "House"
	lot.position = Vector3.ZERO
	lot.scale = Vector3.ONE * 2.0
	city_root.add_child(lot)

	var body := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.4, 2.2, 1.4)
	collider.shape = shape
	collider.position = Vector3(0, 1.1, 0)
	body.add_child(collider)
	lot.add_child(body)

	var half_extent := 0.52
	var corner_extent := 0.48

	var parts: Array[Dictionary] = [
		{"scene": WALL_DOOR, "pos": Vector3(0, 0, -half_extent), "yaw": 0.0},
		{"scene": WALL_WINDOW, "pos": Vector3(half_extent, 0, 0), "yaw": 90.0},
		{"scene": WALL_FLAT_WINDOW, "pos": Vector3(0, 0, half_extent), "yaw": 180.0},
		{"scene": WALL_DETAIL, "pos": Vector3(-half_extent, 0, 0), "yaw": 270.0},
		{"scene": CORNER, "pos": Vector3(corner_extent, 0, corner_extent), "yaw": 180.0},
		{"scene": COLUMN, "pos": Vector3(-corner_extent, 0, corner_extent), "yaw": 90.0},
		{"scene": CORNER, "pos": Vector3(-corner_extent, 0, -corner_extent), "yaw": 0.0},
		{"scene": COLUMN, "pos": Vector3(corner_extent, 0, -corner_extent), "yaw": 270.0},
		{"scene": ROOF, "pos": Vector3(0, 0.95, 0), "yaw": 0.0}
	]

	if initial_delay_seconds > 0.0:
		await get_tree().create_timer(initial_delay_seconds).timeout
		if token != _build_token:
			return

	for part in parts:
		if token != _build_token:
			return
		var scene := part["scene"] as PackedScene
		var pos := part["pos"] as Vector3
		var yaw := float(part["yaw"])
		_add_piece(lot, scene, pos, yaw)
		if build_delay_seconds > 0.0:
			await get_tree().create_timer(build_delay_seconds).timeout

func _add_piece(parent: Node3D, scene: PackedScene, local_pos: Vector3, yaw_deg: float) -> void:
	var piece := scene.instantiate() as Node3D
	if piece == null:
		return
	piece.position = local_pos
	piece.rotation_degrees.y = yaw_deg
	parent.add_child(piece)
