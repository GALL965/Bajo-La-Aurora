extends Area2D
class_name LevelTrigger

@export var one_shot: bool = true
@export var require_kills: bool = false
@export var required_kills: int = 0

enum Action { GOTO_SCENE, CALL_METHOD, LOCK_CAMERA_LIMITS, UNLOCK_CAMERA_LIMITS }
@export var action: Action = Action.GOTO_SCENE

@export_group("GOTO_SCENE")
@export var target_scene: String
@export var loading_min_time: float = 1.2

@export_group("CALL_METHOD")
@export var method_name: String
@export var method_arg: Variant

@export_group("LOCK_CAMERA_LIMITS")
@export var cam_limit_left: float = -100000
@export var cam_limit_right: float = 100000
@export var cam_limit_top: float = -100000
@export var cam_limit_bottom: float = 100000

var _enabled := true
var _kill_count := 0

func _ready() -> void:
	# para escuchar kills si lo necesitas
	if require_kills:
		add_to_group("kill_listeners")

func on_kill_count_changed(kills: int) -> void:
	_kill_count = kills

func _on_body_entered(body: Node) -> void:
	if not _enabled:
		return
	if not body.is_in_group("jugador"):
		return

	if require_kills and _kill_count < required_kills:
		return

	var ctrl := get_tree().get_first_node_in_group("level_controller")
	if not ctrl:
		return

	match action:
		Action.GOTO_SCENE:
			if target_scene != "":
				SceneLoader.goto_scene(target_scene, loading_min_time)
		Action.CALL_METHOD:
			if method_name != "" and ctrl.has_method(method_name):
				if method_arg == null:
					ctrl.call(method_name)
				else:
					ctrl.call(method_name, method_arg)
		Action.LOCK_CAMERA_LIMITS:
			if ctrl.has_method("get_node") and ctrl.has_variable("camera_rig"):
				var cam = ctrl.camera_rig
				if cam and cam.has_method("set_limits"):
					cam.call("set_limits", cam_limit_left, cam_limit_right, cam_limit_top, cam_limit_bottom)
		Action.UNLOCK_CAMERA_LIMITS:
			if ctrl.has_variable("camera_rig"):
				var cam = ctrl.camera_rig
				if cam and cam.has_method("clear_limits"):
					cam.call("clear_limits")

	if one_shot:
		_enabled = false
		monitoring = false
