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

# LIMITES (para triggers)
var _use_limits := false
var _lim_left := -100000.0
var _lim_right := 100000.0
var _lim_top := -100000.0
var _lim_bottom := 100000.0

func set_limits(left: float, right: float, top: float, bottom: float) -> void:
	_use_limits = true
	_lim_left = left
	_lim_right = right
	_lim_top = top
	_lim_bottom = bottom

func clear_limits() -> void:
	_use_limits = false

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

	if _use_limits:
		_desired_position.x = clamp(_desired_position.x, _lim_left, _lim_right)
		_desired_position.y = clamp(_desired_position.y, _lim_top, _lim_bottom)

	global_position = global_position.lerp(_desired_position, follow_speed * delta)
