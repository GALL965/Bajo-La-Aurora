extends Node2D
class_name BaseLevel
const LOG := "[BaseLevel]"

@export var config: LevelConfig
@export var hud_path: NodePath
@export var dialog_path: NodePath
@export var player_path: NodePath

@onready var hud := get_node_or_null(hud_path)
@onready var dialog := get_node_or_null(dialog_path)
@onready var player := get_node_or_null(player_path)

func _ready() -> void:
	print(LOG, " READY")

	print(LOG, " config:", config)
	print(LOG, " hud_path:", hud_path)
	print(LOG, " dialog_path:", dialog_path)
	print(LOG, " player_path:", player_path)

	if not config:
		push_error("BaseLevel: config no asignado")
		return

	print(LOG, " HUD node:", hud)
	print(LOG, " PLAYER node:", player)

	if player and not player.is_in_group("jugador"):
		player.add_to_group("jugador")

	if hud and hud.has_method("set_player"):
		print(LOG, " calling hud.set_player()")
		hud.set_player(player)

	if hud and config.show_hud:
		print(LOG, " show_hud = true")
		if config.play_hud_intro:
			print(LOG, " playing HUD intro")
			await hud.play_intro()
		else:
			print(LOG, " showing HUD directly")
			hud.visible = true


func _apply_config() -> void:
	if hud:
		hud.visible = config.show_hud
		hud.hide_mana = config.hide_mana

	if player:
		player.bloqueando_input = not config.combat_enabled_on_start
		player.invulnerable = not config.allow_attack_on_start


#func _bind_signals() -> void:
	#if dialog:
		#if dialog.has_signal("dialog_started"):
		#	dialog.dialog_started.connect(_on_dialog_started)
		#if dialog.has_signal("dialog_finished"):
			#dialog.dialog_finished.connect(_on_dialog_finished)


#func _on_dialog_started() -> void:
#	if hud:
#		hud.visible = false


#func _on_dialog_finished() -> void:
#	if hud and config.show_hud:
#		hud.visible = true
