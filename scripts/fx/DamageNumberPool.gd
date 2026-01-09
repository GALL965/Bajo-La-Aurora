extends Node
class_name DamageNumberPool

@export var pool_size := 32
@export var scene: PackedScene = preload("res://scenes/ui/DamageNumber.tscn")

var _pool: Array[DamageNumber] = []
var _index := 0

func _ready() -> void:
	for i in range(pool_size):
		var dn := scene.instantiate() as DamageNumber
		dn.visible = false
		add_child(dn)
		_pool.append(dn)

func play_damage(amount: float, world_pos: Vector2) -> void:
	if _pool.is_empty():
		return

	var dn := _pool[_index]
	_index = (_index + 1) % _pool.size()

	dn.global_position = world_pos
	dn.setup(amount, world_pos, false)
