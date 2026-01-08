extends Control

@onready var fade := $Fade
@onready var logo := $Logo
@onready var gradient_bg := $GradientBG
@onready var continue_text := $ContinueText
@onready var anim := $AnimationPlayer

var step := 0

const SEQUENCE := [
	"res://assets/sprites/ui/miz.png",
	"res://assets/sprites/ui/godot.png",
	"res://assets/sprites/ui/Bajo la aurora.png"
]

func _ready():
	_play_step()

func _play_step():
	if step < SEQUENCE.size():
		logo.visible = true
		logo.modulate = Color(1, 1, 1, 0) # empiezar invisible
		logo.texture = load(SEQUENCE[step])
		anim.play("fade_in_out")
	else:
		_show_final_screen()


func _on_animation_finished(name):
	if name == "fade_in_out":
		step += 1
		_play_step()

func _show_final_screen():
	$Logo.texture = load("res://assets/sprites/ui/Bajo la aurora.png")
	gradient_bg.visible = true
	continue_text.visible = true
	anim.play("final_fade")

var _leaving := false

func _input(event):
	if _leaving:
		return

	if continue_text.visible and event.is_pressed():
		_leaving = true
		set_process_input(false)
		SceneLoader.goto_scene("res://scenes/menus/MainMenu.tscn")
