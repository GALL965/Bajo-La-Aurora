extends Area2D
class_name CombatBlockZone

@export var disable_attack_on_enter: bool = true
@export var disable_combat_on_enter: bool = false

@export var revert_on_exit: bool = true
@export var attack_enabled_on_exit: bool = true
@export var combat_enabled_on_exit: bool = true

func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("jugador"):
		return

	var ctrl := get_tree().get_first_node_in_group("level_controller")
	if not ctrl:
		return

	if disable_combat_on_enter and ctrl.has_method("set_combat_enabled"):
		ctrl.call("set_combat_enabled", false)

	if disable_attack_on_enter and ctrl.has_method("set_attack_enabled"):
		ctrl.call("set_attack_enabled", false)


func _on_body_exited(body: Node) -> void:
	if not revert_on_exit:
		return
	if not body.is_in_group("jugador"):
		return

	var ctrl := get_tree().get_first_node_in_group("level_controller")
	if not ctrl:
		return

	if ctrl.has_method("set_attack_enabled"):
		ctrl.call("set_attack_enabled", attack_enabled_on_exit)

	if ctrl.has_method("set_combat_enabled"):
		ctrl.call("set_combat_enabled", combat_enabled_on_exit)
