extends Node
class_name DemoFlow

# Ajusta estas rutas a tus escenas reales
const SCN_CINE_1 := "res://scenes/demo/CineIntro.tscn"
const SCN_TUTORIAL := "res://scenes/demo/TutorialIntro.tscn"
const SCN_CINE_2 := "res://scenes/demo/CineMid.tscn"
const SCN_GAMEPLAY_2 := "res://scenes/demo/Gameplay2.tscn"
@onready var _fade: FadeTransition = Fade




func start_demo() -> void:
	await goto_scene(SCN_CINE_1)

func goto_scene(path: String) -> void:
	await _fade.await_fade_out()

	get_tree().change_scene_to_file(path)

	# Espera un frame para que la escena exista antes del fade in
	await get_tree().process_frame
	await _fade.await_fade_in()

# Helpers para el flujo de demo (se llaman desde escenas)
func on_cine1_finished() -> void:
	await goto_scene(SCN_TUTORIAL)

func on_tutorial_finished() -> void:
	await goto_scene(SCN_CINE_2)

func on_cine2_finished() -> void:
	await goto_scene(SCN_GAMEPLAY_2)
