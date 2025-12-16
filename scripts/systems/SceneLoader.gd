extends Node

const LOADING_SCENE := "res://scenes/ui/LoadingScreen.tscn"
const MIN_LOADING_TIME := 6.5  # segundos visibles

var _target_path := ""
var _loading_instance: Node = null
var _is_loading := false
var _start_time := 0.0
var _loaded_scene: PackedScene = null
var _previous_scene: Node = null

func goto_scene(path: String):
	if _is_loading:
		return

	_is_loading = true
	_target_path = path
	_loaded_scene = null
	_start_time = Time.get_ticks_msec() / 1000.0

	_previous_scene = get_tree().current_scene

	var loading_res = load(LOADING_SCENE)
	_loading_instance = loading_res.instantiate()
	get_tree().root.add_child(_loading_instance)
	get_tree().current_scene = _loading_instance

	ResourceLoader.load_threaded_request(_target_path)

func _process(_delta):
	if not _is_loading:
		return

	var elapsed := (Time.get_ticks_msec() / 1000.0) - _start_time
	var visual_progress = clamp(elapsed / MIN_LOADING_TIME, 0.0, 1.0)

	# Progreso visual hasta 70%
	if _loading_instance and _loading_instance.has_method("set_progress"):
		_loading_instance.call("set_progress", visual_progress * 70.0)

	var status = ResourceLoader.load_threaded_get_status(_target_path)

	if status == ResourceLoader.THREAD_LOAD_LOADED and _loaded_scene == null:
		_loaded_scene = ResourceLoader.load_threaded_get(_target_path)

	# Cuando ya pasó el tiempo mínimo y la escena está lista
	if _loaded_scene != null and elapsed >= MIN_LOADING_TIME:
		_finish_loading()

func _finish_loading():
	if _loading_instance and _loading_instance.has_method("play_fade_out"):
		_loading_instance.call("play_fade_out")
		await get_tree().create_timer(0.8).timeout

	if _previous_scene:
		_previous_scene.queue_free()

	if _loading_instance:
		_loading_instance.queue_free()

	var next_scene = _loaded_scene.instantiate()
	get_tree().root.add_child(next_scene)
	get_tree().current_scene = next_scene

	_is_loading = false
