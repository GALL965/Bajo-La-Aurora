extends Node2D
class_name DamageNumber

@onready var label: Label = $Label
@export var y_offset := 60.0
var _ttl := 0.65
var _t := 0.0
var _vel := Vector2.ZERO
var _active := false

func setup(amount: float, world_pos: Vector2, is_heal := false) -> void:
	z_index = 1000
	global_position = world_pos + Vector2(0, -y_offset)


	var v := int(round(amount))
	label.text = "-%d" % abs(v)

	# IMPORTANTE: el Label en la escena está en alpha 0
	label.visible = true
	label.modulate = Color(1, 1, 1, 1)

	label.add_theme_color_override("font_color", Color(1.0, 0.25, 0.25))

	_t = 0.0
	_active = true
	_vel = Vector2(randf_range(-25, 25), randf_range(-140, -170))

	visible = true
	modulate = Color(1, 1, 1, 1)
	scale = Vector2.ONE
	set_process(true)


func _process(delta: float) -> void:
	if not _active:
		return

	_t += delta
	global_position += _vel * delta
	_vel.y += 520 * delta

	var k = clamp(_t / _ttl, 0.0, 1.0)
	label.modulate.a = 1.0 - k
	scale = Vector2.ONE * lerp(1.05, 0.95, k)


	if _t >= _ttl:
		_active = false
		visible = false
		set_process(false)
