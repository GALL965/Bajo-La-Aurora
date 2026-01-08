extends Node2D

@onready var video: VideoStreamPlayer = $VideoPlayer

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN

	video.loop = false
	video.play()

	await video.finished

	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await Demoflow.goto_scene("res://scenes/demo/TutorialIntro.tscn")
