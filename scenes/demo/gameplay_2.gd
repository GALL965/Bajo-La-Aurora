extends Node2D

# =========================
# CONFIG
# =========================
@export var fall_height: float = 700.0
@export var fall_time: float = 1
@export var ground_y: float = 130.0

@export var dialog_path: String = "res://dialogs/gameplay2_intro.json"

# =========================
# NODOS
# =========================
@onready var player := $Leray
@onready var sprite: AnimatedSprite2D = $Leray/Visual/Sprite

@onready var camera_rig := $BrawlerCamera
@onready var parallax := $World/Parallax # no lo casteamos para evitar nulls raros

@onready var dialog := $UI/DialogBox
@onready var hud := $hud

@onready var spawn_timer := $Timers/SpawnTimer
@onready var wave_timer := $Timers/WaveTimer

# =========================
# CICLO PRINCIPAL
# =========================
func _ready() -> void:
	_setup_scene()
	await _fall_sequence()
	await _post_fall_sequence()
	if hud and hud.has_method("play_intro"):
		await hud.play_intro()

	_enable_gameplay()



# =========================
# FASE 0 – PREPARACIÓN
# =========================
func _setup_scene() -> void:
	# Bloquear jugador + componentes (para que NO sobreescriban animaciones)
	_player_lock(true)
	_set_player_components_enabled(false)

	# Sin colisión durante la caída (opcional, pero si lo apagas aquí, debes prenderlo al final)
	_player_collision(false)


	# UI
	if hud: hud.visible = false
	if dialog: dialog.hide()

# =========================
# FASE 1 – CAÍDA
# =========================
func _fall_sequence() -> void:
	# Posición inicial de caída (estable, no acumulativa)
	player.global_position = Vector2(player.global_position.x, ground_y - fall_height)

	# Animación de caída (si no existe, no pasa nada)
	_play_anim_if_exists("falling")
	# Si no tienes "falling", normalmente "salto" está en loop; NO esperes su finished.
	if not sprite.sprite_frames.has_animation("falling"):
		_play_anim_if_exists("salto")

	var t := create_tween()
	t.tween_property(
		player,
		"global_position:y",
		ground_y,
		fall_time
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	await t.finished

# =========================
# FASE 2 – IMPACTO / LEVANTARSE
# =========================
func _post_fall_sequence() -> void:
	# --- Animación de recuperación ---
	if sprite.sprite_frames.has_animation("recup"):
		sprite.play("recup")
	else:
		push_warning("Gameplay2: animación 'recup' no encontrada")

	# --- Inicia diálogo AUTOMÁTICO al aterrizar ---
	if dialog:
		# Firma extendida: start_dialog(path, autoplay, skippable)
		# autoplay = true, skippable = false
		dialog.start_dialog(dialog_path, true, false)

	# --- Esperar fin de animación (si no es loop) ---
	if sprite.sprite_frames.has_animation("recup"):
		await sprite.animation_finished
	else:
		await get_tree().create_timer(0.6).timeout

	# --- Esperar a que el diálogo termine ---
	if dialog:
		while dialog.visible:
			await get_tree().process_frame

	# Estado neutro
	_play_anim_if_exists("idle")


# =========================
# FASE 3 – DIÁLOGO
# =========================
func _dialog_sequence() -> void:
	if not dialog:
		return

	dialog.start_dialog(dialog_path)

	# Esperar a que realmente esté visible (si tu DialogBox lo muestra internamente)
	var guard := 0
	while not dialog.visible and guard < 120:
		guard += 1
		await get_tree().process_frame

	# Esperar hasta que se cierre
	while dialog.visible:
		await get_tree().process_frame

# =========================
# FASE 4 – UI ENTRADA
# =========================
func _hud_intro() -> void:
	if not hud:
		return

	# El CanvasLayer solo se muestra
	hud.visible = true

	# El fade se aplica al Control interno
	var root := hud.get_node_or_null("Root")
	if not root:
		push_warning("HUD: No se encontró nodo 'Root' (Control)")
		return

	root.modulate.a = 0.0

	var t := create_tween()
	t.tween_property(root, "modulate:a", 1.0, 0.6)\
		.set_trans(Tween.TRANS_SINE)
	await t.finished


# =========================
# FASE 5 – GAMEPLAY REAL
# =========================
func _enable_gameplay() -> void:
	# Reactivar colisiones (si las apagaste)
	_player_collision(true)

	# Restaurar gravedad (tu valor normal)
	player.gravedad_suelo = 1600.0

	# Limpiar inercia por si algo quedó sucio
	if player is CharacterBody2D:
		player.velocity = Vector2.ZERO

	# Reactivar jugador + componentes
	_player_lock(false)
	_set_player_components_enabled(true)

	# Forzar animación base
	_play_anim_if_exists("idle")

	# Reactivar parallax
	if parallax and parallax.has_method("start"):
		parallax.start()

	# Timers
	spawn_timer.start()
	wave_timer.start()

# =========================
# HELPERS
# =========================
func _player_lock(lock: bool) -> void:
	player.bloqueando_input = lock
	player.set_process_input(not lock)
	player.set_process(not lock)
	player.set_physics_process(not lock)

func _player_collision(enable: bool) -> void:
	var col := player.get_node_or_null("CollisionShape2D")
	if col:
		col.disabled = not enable

func _set_player_components_enabled(enable: bool) -> void:
	var paths := [
		"PlayerMovement",
		"Components/Vertical",
		"Components/Dash",
		"Components/Attack",
	]
	for p in paths:
		var n := player.get_node_or_null(p)
		if n:
			n.set_process(enable)
			n.set_physics_process(enable)

func _play_anim_if_exists(anim_name: String) -> void:
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation(anim_name):
		sprite.play(anim_name)
