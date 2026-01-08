extends Node2D

@onready var player: Node = $Player
@onready var dialog: DialogBox = $UI/DialogBox
@onready var exit_trigger: Area2D = $ExitTrigger
@onready var fade_transition: FadeTransition = get_node_or_null("/root/Fade") as FadeTransition

const DIALOG_PATH := "res://dialogs/tutorial_intro.json"

var _exit_used := false

func _ready() -> void:
	# Conecta trigger de salida
	if exit_trigger:
		if not exit_trigger.body_entered.is_connected(_on_exit_body_entered):
			exit_trigger.body_entered.connect(_on_exit_body_entered)

	_set_player_input_enabled(true)
	_set_player_combat_enabled(false)

	_start_tutorial_dialog()

func _start_tutorial_dialog() -> void:
	if not dialog:
		push_warning("TutorialIntro: DialogBox no encontrado en $UI/DialogBox")
		return

	if dialog.has_method("start_dialog") and dialog.get_method_list().size() > 0:
		var ok := true
		dialog.call_deferred("start_dialog", DIALOG_PATH, true, false)
	else:
		dialog.start_dialog(DIALOG_PATH)

func _on_exit_body_entered(body: Node) -> void:
	if _exit_used:
		return
	if body == null:
		return
	if not body.is_in_group("jugador"):
		return

	_exit_used = true

	if exit_trigger:
		exit_trigger.set_deferred("monitoring", false)

	_set_player_input_enabled(false)

	print("TutorialIntro: EXIT trigger activado -> cambiando a CineMid")

	Demoflow.goto_scene("res://scenes/demo/CineMid.tscn")


# =========================
# Helpers: input/combat (compatibles con tu Leray.gd actual)
# =========================
func _set_player_input_enabled(enabled: bool) -> void:
	if player == null:
		return

	# Si agregaste set_input_enabled en Leray:
	if player.has_method("set_input_enabled"):
		player.call("set_input_enabled", enabled)
		return

	# Fallback (tu variable ya existe)
	if player.has_variable("bloqueando_input"):
		player.set("bloqueando_input", not enabled)

func _set_player_combat_enabled(enabled: bool) -> void:
	if player == null:
		return

	# Si agregaste set_combat_enabled en Leray:
	if player.has_method("set_combat_enabled"):
		player.call("set_combat_enabled", enabled)
		return

	# Fallback: desactivar el componente Attack si existe
	# (en tu Leray.tscn parece estar en $Components/Attack)
	if player.has_node("Components/Attack"):
		var atk := player.get_node("Components/Attack")
		if atk:
			atk.set_process(enabled)
			atk.set_physics_process(enabled)


func _on_exit_trigger_body_entered(body: Node2D) -> void:
	pass # Replace with function body.
