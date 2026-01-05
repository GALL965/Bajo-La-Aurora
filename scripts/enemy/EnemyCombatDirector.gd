extends Node
class_name EnemyCombatDirector

@export var max_attackers := 2
var attackers: Array = []

func request_attack(enemy: Node) -> bool:
	if enemy in attackers:
		return true
	if attackers.size() >= max_attackers:
		print("[DIRECTOR] DENEGADO", enemy.name, "| activos:", attackers.size())
		return false
	attackers.append(enemy)
	print("[DIRECTOR] PERMITIDO", enemy.name, "| activos:", attackers.size())
	return true

func release_attack(enemy: Node) -> void:
	if attackers.has(enemy):
		attackers.erase(enemy)
		print("[DIRECTOR] LIBERADO", enemy.name, "| activos:", attackers.size())

func is_attacker(enemy: Node) -> bool:
	return attackers.has(enemy)

func attackers_count() -> int:
	return attackers.size()
