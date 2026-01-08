extends Node2D

@export var dialog_scene: PackedScene
@export var dialog_json: String = "res://dialogs/kelly_intro.json"

var dialog_instance: Node = null
var dialog_started := false

func _input(event):
	if event is InputEventKey and event.pressed and not dialog_started:
		dialog_started = true
		_start_dialog()

func _start_dialog():
	if dialog_scene == null:
		push_error("No se asignó la escena de diálogo")
		return
	
	dialog_instance = dialog_scene.instantiate()
	add_child(dialog_instance)
	
	if dialog_instance.has_method("start_dialog"):
		dialog_instance.start_dialog(dialog_json)
	else:
		push_error("La escena de diálogo no tiene start_dialog()")
