extends Node
class_name Dash

signal dash_started
signal dash_finished

@export var dash_speed: float = 1200.0
@export var dash_duration: float = 0.30
@export var dash_cooldown: float = 0.25
@export var double_tap_max_delay: float = 0.25
@export var permitir_dash_en_aire: bool = true

var is_dashing: bool = false
var dash_dir: int = 0

var _time_left: float = 0.0
var _cooldown_left: float = 0.0
var _last_left_time: float = -999.0
var _last_right_time: float = -999.0
var _usado_en_el_aire: bool = false

@onready var components: Node = get_parent()
@onready var vertical: VerticalPlayer = components.get_node_or_null("Vertical")

func handle_input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo:
		return

	
	if event.is_action_pressed("A"):
		_process_tap(-1)
	elif event.is_action_pressed("D"):
		_process_tap(1)

func _process_tap(dir: int) -> void:
	var now := Time.get_ticks_msec() / 1000.0

	if dir < 0:
		if now - _last_left_time <= double_tap_max_delay:
			_try_start(-1)
		_last_left_time = now
	else:
		if now - _last_right_time <= double_tap_max_delay:
			_try_start(1)
		_last_right_time = now


func _try_start(dir: int) -> void:
	if _cooldown_left > 0.0:
		return
	if is_dashing:
		return

	var en_aire := false
	if vertical:
		en_aire = vertical.is_en_el_aire()

	if en_aire:
		if not permitir_dash_en_aire:
			return
		if _usado_en_el_aire:
			return
		_usado_en_el_aire = true

	dash_dir = dir
	is_dashing = true
	_time_left = dash_duration
	_cooldown_left = dash_cooldown

	emit_signal("dash_started")

func process_dash(delta: float) -> void:
	if _cooldown_left > 0.0:
		_cooldown_left -= delta
		if _cooldown_left < 0.0:
			_cooldown_left = 0.0

	if vertical and not vertical.is_en_el_aire():
		_usado_en_el_aire = false

	if not is_dashing:
		return

	_time_left -= delta
	if _time_left <= 0.0:
		_stop()

func _stop() -> void:
	if not is_dashing:
		return

	is_dashing = false
	dash_dir = 0
	_time_left = 0.0

	emit_signal("dash_finished")

#api pal jugador
func get_velocity() -> Vector2:
	if not is_dashing:
		return Vector2.ZERO
	return Vector2(dash_dir * dash_speed, 0.0)

func esta_dasheando() -> bool:
	return is_dashing
