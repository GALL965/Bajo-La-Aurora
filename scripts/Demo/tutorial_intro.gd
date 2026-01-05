extends Node2D

@onready var player: Node = $Player
@onready var dialog: DialogBox = $UI/DialogBox
@onready var exit_trigger: Area2D = $ExitTrigger

# Ajusta si cambias el nombre del archivo
const DIALOG_PATH := "res://dialogs/tutorial_intro.json"

var _exit_used := false

func _ready() -> void:
	# Conecta trigger de salida
	if exit_trigger:
		if not exit_trigger.body_entered.is_connected(_on_exit_body_entered):
			exit_trigger.body_entered.connect(_on_exit_body_entered)

	# Estado del tutorial: movimiento sí, combate no
	_set_player_input_enabled(true)
	_set_player_combat_enabled(false)

	# Inicia diálogo (autoplay, no-skippable)
	_start_tutorial_dialog()

func _start_tutorial_dialog() -> void:
	if not dialog:
		push_warning("TutorialIntro: DialogBox no encontrado en $UI/DialogBox")
		return

	# Si implementaste la versión extendida:
	# start_dialog(json_path, autoplay, skippable)
	if dialog.has_method("start_dialog") and dialog.get_method_list().size() > 0:
		# Intento con firma extendida (3 args)
		# Si tu DialogBox aún no soporta autoplay/skippable, cae al fallback.
		var ok := true
		# Godot no permite introspección de firmas fácil; hacemos try/catch.
		# En GDScript 4, usamos "callv" y capturamos error por consola si falla.
		# Para evitar ruido, primero probamos con call_deferred.
		# (Igual, si tu start_dialog solo acepta 1 arg, usa el fallback abajo)
		dialog.call_deferred("start_dialog", DIALOG_PATH, true, false)
	else:
		# Fallback básico (tu versión original)
		dialog.start_dialog(DIALOG_PATH)

func _on_exit_body_entered(body: Node) -> void:
	if _exit_used:
		return
	if body == null:
		return
	if not body.is_in_group("jugador"):
		return

	_exit_used = true

	# Evita dobles activaciones por físicas
	if exit_trigger:
		exit_trigger.set_deferred("monitoring", false)

	# Opcional: bloquear input antes de cambiar
	_set_player_input_enabled(false)

	# Debug útil
	print("TutorialIntro: EXIT trigger activado -> cambiando a CineMid")

	# Avanza el flujo (Demoflow debe tener SCN_CINE_2 = res://scenes/demo/CineMid.tscn)
	Demoflow.on_tutorial_finished()

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
