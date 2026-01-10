extends Area2D
class_name CombatZone

@export var kills_required: int = 3
@export var block_camera := true
@export var one_shot := true

var _kills := 0
var _active := false

func _ready():
	add_to_group("kill_listeners")
	body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	if _active:
		return
	if not body.is_in_group("player"):
		return

	_active = true

	var level := get_tree().get_first_node_in_group("level_controller")
	if level:
		level.set_combat_enabled(true)

	if block_camera:
		_block_camera(true)

func on_kill_count_changed(total_kills: int):
	if not _active:
		return

	_kills += 1

	if _kills >= kills_required:
		_finish_zone()

func _finish_zone():
	var level := get_tree().get_first_node_in_group("level_controller")
	if level:
		level.set_combat_enabled(false)

	_block_camera(false)

	if one_shot:
		queue_free()

func _block_camera(enable: bool):
	var cam := get_tree().get_first_node_in_group("camera_rig")
	if cam and cam.has_method("set_block"):
		cam.set_block(enable)
