extends Node2D
class_name ParallaxScroll

@export var city_speed: float = 120.0
@export var walls_speed: float = 2200.0
@export var enabled: bool = true

@onready var city_layer: Node2D = $CityBack
@onready var walls_layer: Node2D = $WallsFront

func _process(delta: float) -> void:
	if not enabled:
		return

	_scroll_layer(city_layer, city_speed, delta)
	_scroll_layer(walls_layer, walls_speed, delta)

func _scroll_layer(layer: Node2D, speed: float, delta: float) -> void:
	if layer.get_child_count() == 0:
		return

	for c in layer.get_children():
		if c is Node2D:
			c.position.x -= speed * delta

	# ancho real del tile
	var first := layer.get_child(0) as Node2D
	var width := _get_sprite_width(first)

	# reciclar los que salieron
	for c in layer.get_children():
		if c.position.x <= -width:
			# buscar el más a la derecha
			var max_x = c.position.x
			for other in layer.get_children():
				if other.position.x > max_x:
					max_x = other.position.x
			c.position.x = max_x + width


func _get_sprite_width(n: Node2D) -> float:
	if n is Sprite2D and n.texture:
		return n.texture.get_width() * n.scale.x
	return 0.0

func stop() -> void:
	enabled = false

func start() -> void:
	enabled = true
