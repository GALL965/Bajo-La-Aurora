extends CanvasLayer
class_name PauseMenu

# =========================
# NODOS
# =========================
@onready var root: Control = $Root
@onready var buttons_panel: Control = $Root/Panel
@onready var pause_label: Label = $Pausa

@onready var resume_btn: Button = $Root/Panel/VBoxContainer/ResumeBtn
@onready var quit_btn: Button = $Root/Panel/VBoxContainer/QuitBtn

# =========================
# ESTADO
# =========================
var _panel_final_x: float
var _label_final_x: float
var _tween: Tween
var _prev_mouse_mode: int = Input.MOUSE_MODE_VISIBLE

# =========================
# READY
# =========================
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	root.mouse_filter = Control.MOUSE_FILTER_STOP

	# Guardar posiciones finales
	_panel_final_x = buttons_panel.position.x
	_label_final_x = pause_label.position.x

	# Sacarlos de pantalla
	buttons_panel.position.x = -buttons_panel.size.x - 40
	pause_label.position.x = get_viewport().get_visible_rect().size.x + 40

	hide()

	resume_btn.pressed.connect(_on_resume_pressed)
	quit_btn.pressed.connect(_on_quit_pressed)

# =========================
# INPUT
# =========================
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		toggle_pause()
		get_viewport().set_input_as_handled()

# =========================
# PAUSA
# =========================
func toggle_pause() -> void:
	if get_tree().paused:
		_resume()
	else:
		_pause()

func _pause() -> void:
	get_tree().paused = true
	_prev_mouse_mode = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	show()
	_animate_in()
	resume_btn.grab_focus()

func _resume() -> void:
	_animate_out(func ():
		hide()
		get_tree().paused = false
		Input.mouse_mode = _prev_mouse_mode
	)

# =========================
# BOTONES
# =========================
func _on_resume_pressed() -> void:
	_resume()

func _on_quit_pressed() -> void:
	_animate_out(func ():
		get_tree().paused = false
		get_tree().quit()
	)

# =========================
# ANIMACIONES
# =========================
func _animate_in() -> void:
	if _tween:
		_tween.kill()

	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.set_trans(Tween.TRANS_QUART)
	_tween.set_ease(Tween.EASE_OUT)

	_tween.tween_property(
		buttons_panel,
		"position:x",
		_panel_final_x,
		0.35
	)

	_tween.tween_property(
		pause_label,
		"position:x",
		_label_final_x,
		0.35
	)

func _animate_out(callback: Callable) -> void:
	if _tween:
		_tween.kill()

	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.set_trans(Tween.TRANS_QUART)
	_tween.set_ease(Tween.EASE_IN)

	_tween.tween_property(
		buttons_panel,
		"position:x",
		-buttons_panel.size.x - 40,
		0.25
	)

	_tween.tween_property(
		pause_label,
		"position:x",
		get_viewport().get_visible_rect().size.x + 40,
		0.25
	)

	_tween.finished.connect(callback)
