extends Node
class_name EnemyHealth

signal tomar_dano(cantidad: float, atacante: Node, knockback_poder: float)
signal murio

@export var hp_max: float = 45.0
var hp: float
var _muerto: bool = false

func setup(_enemy: Node, _player: Node) -> void:
	hp = hp_max

func esta_vivo() -> bool:
	return not _muerto

func recibir_dano(cantidad: float, atacante: Node, knockback_poder: float = 260.0) -> void:
	if _muerto:
		return

	hp -= cantidad
	emit_signal("tomar_dano", cantidad, atacante, knockback_poder)

	if hp <= 0.0:
		hp = 0.0
		_muerto = true
		emit_signal("murio")
