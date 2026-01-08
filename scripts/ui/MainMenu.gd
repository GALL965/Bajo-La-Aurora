extends Control

@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var fade: ColorRect = $Fade
@onready var music: AudioStreamPlayer = $AudioStreamPlayer

@onready var new_game_btn: Button = $VBoxContainer/NewGameBtn
@onready var continue_btn: Button = $VBoxContainer/ContinueBtn
@onready var options_btn: Button = $VBoxContainer/OptionsBtn
@onready var exit_btn: Button = $VBoxContainer/ExitBtn

var _input_locked := false

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	get_tree().paused = false
	Engine.time_scale = 1.0

	fade.color.a = 1.0
	anim.play("fade_in")

	_setup_button(new_game_btn, _on_new_game_pressed)
	_setup_button(continue_btn, _on_continue_pressed)
	_setup_button(options_btn, _on_options_pressed)
	_setup_button(exit_btn, _on_exit_pressed)



func _setup_button(btn: Button, callback: Callable) -> void:
	var btn_anim: AnimationPlayer = btn.get_node_or_null("AnimationPlayer")
	var sfx: AudioStreamPlayer = btn.get_node_or_null("AudioStreamPlayer")

	if btn_anim:
		btn.mouse_entered.connect(func():
			btn_anim.play("hover_in")
			if sfx:
				sfx.play()
		)

		btn.mouse_exited.connect(func():
			btn_anim.play("hover_out")
		)

		btn.pressed.connect(func():
			btn_anim.play("press")
		)

	btn.pressed.connect(callback)

func _on_new_game_pressed() -> void:
	if _input_locked:
		return

	_input_locked = true

	if music.playing:
		music.stop()

	fade.visible = true

	if anim.has_animation("fade_out"):
		anim.play("fade_out")
		await anim.animation_finished
	elif anim.has_animation("fade_in"):
		anim.play_backwards("fade_in")
		await anim.animation_finished

	SceneLoader.goto_scene("res://scenes/demo/CineIntro.tscn")






func _on_continue_pressed() -> void:
	if _input_locked:
		return

	# Aquí luego conectas SaveSystem
	print("Continuar (pendiente)")


func _on_options_pressed() -> void:
	if _input_locked:
		return

	# Aquí luego cargas OptionsMenu
	print("Opciones (pendiente)")


func _on_exit_pressed() -> void:
	get_tree().quit()
