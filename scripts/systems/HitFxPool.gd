extends Node
class_name HitFxPool

@export var pool_size := 16
@export var fx_scene := preload("res://scenes/fx/HitEffect.tscn")

var _pool: Array[Node2D] = []
var _index := 0

func _ready() -> void:
	for i in pool_size:
		var fx := fx_scene.instantiate()
		fx.visible = false
		add_child(fx)
		_pool.append(fx)

func play_fx(pos: Vector2) -> void:
	if _pool.is_empty():
		return

	var fx := _pool[_index]
	_index = (_index + 1) % _pool.size()

	fx.global_position = pos
	fx.visible = true

	fx.play()
