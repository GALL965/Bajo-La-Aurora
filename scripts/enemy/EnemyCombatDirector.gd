extends Node
class_name EnemyCombatDirector

@export var max_attackers := 2
var attackers: Array = []

func _cleanup() -> void:
	for i in range(attackers.size() - 1, -1, -1):
		var e = attackers[i]
		if e == null or (typeof(e) == TYPE_OBJECT and not is_instance_valid(e)):
			attackers.remove_at(i)

func request_attack(enemy: Node) -> bool:
	_cleanup()
	if enemy in attackers:
		return true
	if attackers.size() >= max_attackers:
		return false
	attackers.append(enemy)
	return true

func release_attack(enemy: Node) -> void:
	_cleanup()
	if attackers.has(enemy):
		attackers.erase(enemy)

func is_attacker(enemy: Node) -> bool:
	_cleanup()
	return attackers.has(enemy)

func attackers_count() -> int:
	_cleanup()
	return attackers.size()
