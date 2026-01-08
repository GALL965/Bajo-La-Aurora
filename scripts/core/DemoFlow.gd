extends Node
class_name DemoFlow

func _get_fade() -> FadeTransition:
	return get_node_or_null("/root/Fade") as FadeTransition

func goto_scene(path: String) -> void:
	var fade := _get_fade()
	if fade:
		await fade.await_fade_out()

	var err := get_tree().change_scene_to_file(path)
	if err != OK:
		push_error("DemoFlow: change_scene_to_file falló. path=%s err=%s" % [path, str(err)])
		fade = _get_fade()
		if fade:
			await fade.await_fade_in()
		return

	await get_tree().process_frame

	fade = _get_fade()
	if fade:
		await fade.await_fade_in()
