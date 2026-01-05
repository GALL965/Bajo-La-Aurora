extends Node2D

@onready var video: VideoStreamPlayer = $VideoPlayer

func _ready() -> void:
	# Bloquea inputs durante la cinemática
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	video.finished.connect(_on_video_finished)
	video.play()

func _on_video_finished() -> void:
	Demoflow.on_cine1_finished()
