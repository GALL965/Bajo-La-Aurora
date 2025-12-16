extends Node2D
class_name BrawlerCamera

@export var target_path: NodePath
@export var deadzone_width: float = 420
@export var deadzone_up: float = -20
@export var deadzone_down: float = 30


#@export var deadzone_size: Vector2 = Vector2(420, 220)
@export var follow_speed: float = 3.0
@export var max_follow_speed: float = 1200.0
@export var dash_lag_multiplier: float = 0.6

@onready var camera: Camera2D = $Camera2D
var target: Node2D
var _desired_position: Vector2

func _ready():
	camera.enabled = true

	if target_path != NodePath():
		target = get_node_or_null(target_path)

	if not target:
		push_warning("BrawlerCamera: target no asignado")
		return

	global_position = target.global_position
	_desired_position = global_position

func _process(delta):
	if not target:
		return

	var target_pos: Vector2 = target.global_position
	var cam_pos: Vector2 = global_position
	var diff: Vector2 = target_pos - cam_pos

	# =========================
	# Dead zone X (simétrica)
	# =========================
	var half_x := deadzone_width * 0.5

	if diff.x > half_x:
		_desired_position.x = target_pos.x - half_x
	elif diff.x < -half_x:
		_desired_position.x = target_pos.x + half_x

	# =========================
	# Dead zone Y (asimétrica)
	#   - más margen arriba
	#   - menos margen abajo
	# =========================
	if diff.y < -deadzone_up:
		_desired_position.y = target_pos.y + deadzone_up
	elif diff.y > deadzone_down:
		_desired_position.y = target_pos.y - deadzone_down

	# =========================
	# Seguimiento suave
	# =========================
	global_position = global_position.lerp(
		_desired_position,
		follow_speed * delta
	)
