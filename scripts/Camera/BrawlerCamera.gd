extends Node2D
class_name BrawlerCamera

@export var target_path: NodePath
@export var deadzone_width: float = 420
@export var deadzone_up: float = -110
@export var deadzone_down: float = 200



@export var follow_speed: float = 3.0

@onready var camera: Camera2D = $Camera2D

var target: Node2D
var _desired_position: Vector2

func _ready():
	if camera:
		camera.make_current()

	if target_path != NodePath():
		target = get_node_or_null(target_path)

	if not target:
		push_error("BrawlerCamera: target_path inválido -> " + str(target_path))
		return

	global_position = target.global_position
	_desired_position = global_position
	
func _process(delta: float) -> void:
	if not target:
		return

	var target_pos: Vector2 = target.global_position
	var cam_pos: Vector2 = global_position
	var diff: Vector2 = target_pos - cam_pos

	var half_x := deadzone_width * 0.5

	if diff.x > half_x:
		_desired_position.x = target_pos.x - half_x
	elif diff.x < -half_x:
		_desired_position.x = target_pos.x + half_x

	if diff.y < -deadzone_up:
		_desired_position.y = target_pos.y + deadzone_up
	elif diff.y > deadzone_down:
		_desired_position.y = target_pos.y - deadzone_down

	global_position = global_position.lerp(
		_desired_position,
		follow_speed * delta
	)
