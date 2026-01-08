extends Node
class_name EnemySenses

signal jugador_detectado(jugador: Node2D)

var owner_enemy: Node = null
var jugador: Node2D = null
var area_deteccion: Area2D = null

func setup(enemy: Node, player: Node) -> void:
	owner_enemy = enemy
	jugador = player as Node2D

	area_deteccion = owner_enemy.get_node_or_null("Facing/Deteccion") as Area2D
	if area_deteccion:
		if not area_deteccion.body_entered.is_connected(_on_body_entered):
			area_deteccion.body_entered.connect(_on_body_entered)

func tick(_delta: float) -> void:
	# Fallback: si ya está adentro (o se solapó sin evento), lo detectamos igual
	if jugador == null and area_deteccion:
		for b in area_deteccion.get_overlapping_bodies():
			if b and b.is_in_group("jugador"):
				jugador = b as Node2D
				emit_signal("jugador_detectado", jugador)
				return

func _on_body_entered(body: Node) -> void:
	if body == null or not body.is_in_group("jugador"):
		return

	if jugador == body:
		return

	jugador = body as Node2D
	emit_signal("jugador_detectado", jugador)
