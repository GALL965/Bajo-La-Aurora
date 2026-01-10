extends Node

const LOADING_SCENE := "res://scenes/ui/LoadingScreen.tscn"
const DEFAULT_LOADING_TIME := 6.5
const AUDIO_FADE_TIME := 0.8

var _target_path := ""
var _loading_instance: Node = null
var _is_loading := false
var _start_time := 0.0
var _loaded_scene: PackedScene = null
var _previous_scene: Node = null
var _min_loading_time := DEFAULT_LOADING_TIME

func _ready() -> void:
	# CRÍTICO: que el loader siga corriendo aunque congelemos lo demás
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)

func goto_scene(path: String, min_time := DEFAULT_LOADING_TIME) -> void:
	if _is_loading:
		return

	_is_loading = true
	set_process(true)

	_min_loading_time = min_time
	_target_path = path
	_loaded_scene = null
	_start_time = Time.get_ticks_msec() / 1000.0

	_previous_scene = get_tree().current_scene

	# 1) Congela escena anterior INMEDIATO (evita desfases y timers corriendo “debajo”)
	if _previous_scene:
		_previous_scene.process_mode = Node.PROCESS_MODE_DISABLED
		# Opcional (pero recomendado): evitar cualquier “flash” visual o UI residual
		if _previous_scene is CanvasItem:
			(_previous_scene as CanvasItem).visible = false

	# 2) Música: fade out (ok)
	_fade_out_all_music()

	# 3) Instancia loading y ponlo como current_scene (CLAVE)
	var loading_res := load(LOADING_SCENE)
	_loading_instance = loading_res.instantiate()
	_loading_instance.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child(_loading_instance)
	get_tree().current_scene = _loading_instance

	# 4) Carga threaded
	ResourceLoader.load_threaded_request(_target_path)

func _process(_delta: float) -> void:
	if not _is_loading:
		return

	var elapsed := (Time.get_ticks_msec() / 1000.0) - _start_time
	var visual_progress = clamp(elapsed / _min_loading_time, 0.0, 1.0)

	if _loading_instance and _loading_instance.has_method("set_progress"):
		_loading_instance.call("set_progress", visual_progress * 70.0)

	var status := ResourceLoader.load_threaded_get_status(_target_path)

	if status == ResourceLoader.THREAD_LOAD_LOADED and _loaded_scene == null:
		_loaded_scene = ResourceLoader.load_threaded_get(_target_path)

	if _loaded_scene != null and elapsed >= _min_loading_time:
		_finish_loading()

func _finish_loading() -> void:
	set_process(false)

	if _loading_instance and _loading_instance.has_method("play_fade_out"):
		_loading_instance.call("play_fade_out")
		await get_tree().create_timer(0.8).timeout

	# Borra escena anterior (ya estaba congelada)
	if _previous_scene:
		_previous_scene.queue_free()
		_previous_scene = null

	# Instancia nueva escena
	var next_scene := _loaded_scene.instantiate()
	get_tree().root.add_child(next_scene)
	get_tree().current_scene = next_scene

	# Borra loading
	if _loading_instance:
		_loading_instance.queue_free()
		_loading_instance = null

	_loaded_scene = null
	_is_loading = false

func _fade_out_all_music() -> void:
	var players := get_tree().get_nodes_in_group("music")
	for p in players:
		if p is AudioStreamPlayer or p is AudioStreamPlayer2D:
			var t := create_tween()
			t.tween_property(p, "volume_db", -80.0, AUDIO_FADE_TIME)
			t.tween_callback(p.stop)
