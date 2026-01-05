extends Area2D
class_name ExitTrigger

@export var only_player: bool = true
@export var player_group: StringName = &"jugador"

# Si lo activas, solo avanza cuando el diálogo ya terminó (DialogBox oculto)
@export var require_dialog_finished: bool = false
@export var dialog_node_path: NodePath = NodePath("../UI/DialogBox")

var _used: bool = false

func _ready() -> void:
	monitoring = true
	monitorable = true
	# No hace falta conectar aquí si ya lo conectaste en el editor, pero no estorba:
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if _used:
		return

	# Debug rápido (déjalo hasta que ya funcione)
	print("ExitTrigger: body_entered ->", body.name)

	if only_player and not body.is_in_group(player_group):
		print("ExitTrigger: ignorado (no está en grupo '", player_group, "')")
		return

	if require_dialog_finished and not _is_dialog_finished():
		print("ExitTrigger: esperando a que termine el diálogo")
		return

	_used = true
	set_deferred("monitoring", false)

	# Llamada correcta al Autoload
	if has_node("/root/Demoflow"):
		get_node("/root/Demoflow").on_tutorial_finished()
	else:
		push_error("ExitTrigger: No existe el autoload /root/Demoflow (Project Settings > Autoload).")

func _is_dialog_finished() -> bool:
	if dialog_node_path == NodePath():
		return true

	var dlg := get_node_or_null(dialog_node_path)
	if dlg == null:
		push_warning("ExitTrigger: dialog_node_path no válido: " + str(dialog_node_path))
		return true

	if dlg is CanvasItem:
		return not (dlg as CanvasItem).visible

	return true
