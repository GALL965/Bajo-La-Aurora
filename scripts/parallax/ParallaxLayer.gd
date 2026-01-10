extends Node2D
class_name BGParallaxLayer

@export var speed: float = 0.2
@export var repeat: bool = true
@export var texture_width: float = 512.0

var _last_player_x: float = 0.0

func setup(player_x: float) -> void:
	_last_player_x = player_x

func update_layer(player_x: float) -> void:
	var delta := player_x - _last_player_x
	position.x += delta * speed
	_last_player_x = player_x

	if not repeat:
		return

	for c in get_children():
		if c is Sprite2D:
			if c.global_position.x + texture_width < -texture_width:
				c.global_position.x += texture_width * get_child_count()
