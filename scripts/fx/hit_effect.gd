extends Node2D
class_name HitEffect

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func play() -> void:
	visible = true
	z_index = 1000

	if not sprite:
		return

	sprite.stop()
	sprite.frame = 0
	sprite.play()

	# Limpio conexiones previas para evitar leaks
	if sprite.animation_finished.is_connected(_on_finished):
		sprite.animation_finished.disconnect(_on_finished)

	sprite.animation_finished.connect(_on_finished)

func _on_finished() -> void:
	visible = false
