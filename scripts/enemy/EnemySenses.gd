extends Node
class_name EnemySenses

signal jugador_detectado

var owner_enemy: Node = null
var jugador: Node = null
var area_deteccion: Area2D = null

func setup(enemy: Node, player: Node) -> void:
	owner_enemy = enemy
	jugador = player

	area_deteccion = owner_enemy.get_node_or_null("Facing/Deteccion")
	if area_deteccion:
		area_deteccion.body_entered.connect(_on_body_entered)

func tick(_delta: float) -> void:
	pass

func _on_body_entered(body: Node) -> void:
	if body and body.is_in_group("jugador"):
		emit_signal("jugador_detectado")
