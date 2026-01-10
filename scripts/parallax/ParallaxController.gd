extends Node2D
class_name ParallaxController

@export var player_path: NodePath

var player: Node2D
var layers: Array[BGParallaxLayer] = []


func _ready() -> void:
	player = get_node_or_null(player_path)
	if not player:
		return

	for c in get_children():
		if c is BGParallaxLayer:
			layers.append(c)

			c.setup(player.global_position.x)

func start() -> void:
	set_process(true)

func _process(_delta: float) -> void:
	if not player:
		return

	var px := player.global_position.x
	for l in layers:
		l.update_layer(px)
