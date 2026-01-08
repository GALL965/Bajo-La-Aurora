extends Node2D
@onready var extraction_ship: AnimatedSprite2D = $Cutscene/ExtractionShip

var _gameplay_time := 0.0
var _final_started := false
var _extraction_started := false
var _titles_started := false

var _timeline_running := false

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
# SPAWNER ENEMIGOS (DEMO)
# =========================
@export var spawn_initial_delay: float = 10.0
@export var max_enemies_alive: int = 3

@export var spawn_interval_min: float = 2.2
@export var spawn_interval_max: float = 4.6

# chance de que, si faltan enemigos, llegue otro rápido (1-2 seguidos)
@export var burst_chance: float = 0.35
@export var burst_delay_min: float = 0.45
@export var burst_delay_max: float = 0.95

# Escenas de enemigos (puedes meter varias para variar)
const DEFAULT_ENEMY := preload("res://scenes/enemies/Scout/Scout01.tscn")
@export var enemy_scenes: Array[PackedScene] = []

@onready var enemies_root: Node2D = $World/Enemies
@onready var spawns_root: Node2D = $World/Parallax/Node2D

var _rng := RandomNumberGenerator.new()
var _spawn_enabled := false
var _alive_ids: Dictionary = {} # id -> true
var _spawn_points: Array[Marker2D] = []
# =========================
# TIMELINE FINAL (SEGUNDOS DESDE GAMEPLAY)
# =========================

@export_group("Final Timeline")

@export var t_extraction_dialog: float = 90.0   # 1:40
@export var t_fade_black: float = 110.0           # 2:01
@export var t_titles_start: float = 116.0         # 2:06
@export var t_menu_return: float = 155.0          # 2:35

# Duraciones
@export var extraction_ship_time: float = 2.8
@export var title_display_time: float = 4.0
@export var title_gap_time: float = 0.0

# =========================
# CICLO PRINCIPAL
# =========================
func _ready() -> void:
	_rng.randomize()
	_setup_enemy_spawner()

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

	_start_enemy_spawner()
	_timeline_running = true



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


# =========================
# SPAWNER: SETUP
# =========================
func _setup_enemy_spawner() -> void:
	# fallback si no asignas nada en el inspector
	if enemy_scenes.is_empty():
		enemy_scenes = [DEFAULT_ENEMY]

	# Cache de puntos de spawn (P0,P1,P2)
	_spawn_points.clear()
	for name in ["P0", "P1", "P2"]:
		var m := spawns_root.get_node_or_null(name) as Marker2D
		if m:
			_spawn_points.append(m)

	if _spawn_points.is_empty():
		push_warning("Gameplay2: No hay Marker2D P0/P1/P2 en World/Parallax/Node2D")

	# Timers como one-shot, nosotros los reprogramamos
	if wave_timer:
		wave_timer.one_shot = true
		if not wave_timer.timeout.is_connected(_on_wave_timer_timeout):
			wave_timer.timeout.connect(_on_wave_timer_timeout)

	if spawn_timer:
		spawn_timer.one_shot = true
		if not spawn_timer.timeout.is_connected(_on_spawn_timer_timeout):
			spawn_timer.timeout.connect(_on_spawn_timer_timeout)


# =========================
# SPAWNER: START/STOP
# =========================
func _start_enemy_spawner() -> void:
	_spawn_enabled = false
	_alive_ids.clear()

	if wave_timer:
		wave_timer.stop()
		wave_timer.wait_time = spawn_initial_delay
		wave_timer.start()

	if spawn_timer:
		spawn_timer.stop()


func _stop_enemy_spawner() -> void:
	_spawn_enabled = false
	if wave_timer: wave_timer.stop()
	if spawn_timer: spawn_timer.stop()


# =========================
# SPAWNER: TIMER EVENTS
# =========================
func _on_wave_timer_timeout() -> void:
	_spawn_enabled = true

	var extra := 1 if _rng.randf() < 0.6 else 0
	var initial = min(max_enemies_alive, 2 + extra)

	for i in range(initial):
		_spawn_one_enemy()

	_schedule_next_spawn(_rng.randf_range(spawn_interval_min, spawn_interval_max))



func _on_spawn_timer_timeout() -> void:
	if not _spawn_enabled:
		return

	# Si ya estamos al cap, reintenta más tarde
	if _alive_ids.size() >= max_enemies_alive:
		_schedule_next_spawn(_rng.randf_range(0.9, 1.6))
		return

	_spawn_one_enemy()

	# Si aún faltan para llegar a max, a veces mete otro rápido (burst)
	var need_more := _alive_ids.size() < max_enemies_alive
	if need_more and _rng.randf() < burst_chance:
		_schedule_next_spawn(_rng.randf_range(burst_delay_min, burst_delay_max))
	else:
		_schedule_next_spawn(_rng.randf_range(spawn_interval_min, spawn_interval_max))


func _schedule_next_spawn(delay: float) -> void:
	if not spawn_timer:
		return
	spawn_timer.stop()
	spawn_timer.wait_time = max(0.05, delay)
	spawn_timer.start()


# =========================
# SPAWNER: SPAWN LOGIC
# =========================
func _spawn_one_enemy() -> void:
	if enemies_root == null or player == null:
		return
	if enemy_scenes.is_empty():
		return

	var scene := enemy_scenes[_rng.randi_range(0, enemy_scenes.size() - 1)]
	if scene == null:
		return

	var e := scene.instantiate()
	if e == null:
		return

	enemies_root.add_child(e)

	# Posición de spawn (marker + jitter)
	var pos := _pick_spawn_position()
	e.global_position = pos
		# Animación de aparición
	if e.has_method("play_spawn_animation"):
		e.call("play_spawn_animation")


	# Asegurar setup de módulos (por si el EnemigoBase no lo hace solo)
	var mv = e.get_node_or_null("Movement")
	if mv and mv.has_method("setup"):
		mv.call("setup", e, player)

	var cb = e.get_node_or_null("Combat")
	if cb and cb.has_method("setup"):
		cb.call("setup", e, player)

	var ss = e.get_node_or_null("Senses")
	if ss and ss.has_method("setup"):
		ss.call("setup", e, player)

	# Track de vivos: cuando muera/queue_free, lo contamos como “libre”
	var id := e.get_instance_id()
	_alive_ids[id] = true
	if not e.tree_exited.is_connected(_on_enemy_tree_exited):
		e.tree_exited.connect(_on_enemy_tree_exited.bind(id))


func _on_enemy_tree_exited(id: int) -> void:
	if _alive_ids.has(id):
		_alive_ids.erase(id)

	# Si ya estamos spawneando y quedó espacio, repón relativamente pronto
	if _spawn_enabled and _alive_ids.size() < max_enemies_alive:
		# si quedó muy vacío, repón rápido
		var d := 0.35 if _alive_ids.size() == 0 else _rng.randf_range(0.55, 1.35)
		_schedule_next_spawn(d)


func _pick_spawn_position() -> Vector2:
	# Si hay markers, úsalo
	if not _spawn_points.is_empty():
		var m := _spawn_points[_rng.randi_range(0, _spawn_points.size() - 1)]
		var p := m.global_position
		p.x += _rng.randf_range(-45.0, 45.0)
		p.y += _rng.randf_range(-35.0, 35.0)
		return p

	# fallback: cerca del jugador, pero no encima
	var base = player.global_position
	var dir := -1.0 if _rng.randf() < 0.5 else 1.0
	base.x += dir * _rng.randf_range(260.0, 420.0)
	base.y += _rng.randf_range(-60.0, 60.0)
	return base

func _process(delta: float) -> void:
	if not _timeline_running:
		return

	_gameplay_time += delta
	_check_final_timeline()

func _check_final_timeline() -> void:
	# 1) Diálogo de extracción
	if _gameplay_time >= t_extraction_dialog and not _final_started:
		_final_started = true
		await _start_extraction_dialog()

	# 2) Fade a negro
	if _gameplay_time >= t_fade_black:
		_start_fade_to_black()

	# 3) Títulos
	if _gameplay_time >= t_titles_start and not _titles_started:
		_titles_started = true
		await _play_titles_sequence()

func _start_extraction_dialog() -> void:
	_stop_enemy_spawner()

	player.invulnerable = true   # ← CLAVE
	# NO bloquear input aquí

	if dialog:
		dialog.start_dialog("res://dialogs/intro/Extraction.json", true, false)
		while dialog.visible:
			await get_tree().process_frame

	await _start_extraction_ship()



func _start_extraction_ship() -> void:
	if _extraction_started:
		return
	_extraction_started = true

	_freeze_enemies(true) # por si acaso

	# Aquí sí bloqueamos para que la anim "tel" no la sobreescriba Movement/Vertical
	_player_lock(true)
	_set_player_components_enabled(false)

	if extraction_ship == null:
		push_error("Gameplay2: ExtractionShip no encontrado en Cutscene")
		return
	
	# Congelar enemigos visualmente
	#for e in enemies_root.get_children():
	#	e.set_process(false)
	#	e.set_physics_process(false)


	extraction_ship.visible = true

	var ref_x = player.global_position.x
	var start_x = ref_x + 900.0
	var end_x = ref_x - 900.0

	extraction_ship.global_position = Vector2(start_x, ground_y - 40.0)
	extraction_ship.flip_h = true

	player.force_animation("tel")

	var t := create_tween()
	t.tween_property(extraction_ship, "global_position:x", end_x, extraction_ship_time)\
		.set_trans(Tween.TRANS_SINE)

	await t.finished

	player.visible = false
	if player.is_in_group("jugador"):
		player.remove_from_group("jugador")

	# Opcional extra: si no quieres que “tomen target”, lo sacas del grupo
	# if player.is_in_group("jugador"):
	# 	player.remove_from_group("jugador")


func _start_fade_to_black() -> void:
	var fade := $Cutscene/Fade as ColorRect
	if fade == null:
		return

	# Si ya está negro, no rehacer tween
	if fade.color.a >= 0.99:
		return

	fade.visible = true

	var from := fade.color
	var to := fade.color
	to.a = 1.0

	var t := create_tween()
	t.tween_property(fade, "color", to, 0.3)



func _play_titles_sequence() -> void:
	var titles := $Cutscene/Titles
	if titles == null:
		return

	var t1 := titles.get_node_or_null("Title1") as TextureRect
	var t2 := titles.get_node_or_null("Title2") as TextureRect
	var t3 := titles.get_node_or_null("Title3") as TextureRect

	if t1 == null or t2 == null or t3 == null:
		push_warning("Gameplay2: faltan Title1/Title2/Title3 en Cutscene/Titles")
		return

	# Asegurar que se vean (por si quedaron apagados)
	t1.visible = false
	t2.visible = false
	t3.visible = false

	var titles_list = [t1, t2, t3]

	for i in range(titles_list.size()):
		var tr = titles_list[i]
		tr.visible = true

		if i < titles_list.size() - 1:
			await get_tree().create_timer(title_display_time).timeout
			tr.visible = false


		if title_gap_time > 0.0:
			await get_tree().create_timer(title_gap_time).timeout

	await get_tree().create_timer(3.0).timeout

	var remaining = max(0.0, t_menu_return - t_titles_start - (3 * title_display_time))
	if remaining > 0.0:
		await get_tree().create_timer(remaining).timeout

	Demoflow.goto_scene("res://scenes/menus/MainMenu.tscn")



func _freeze_enemies(freeze: bool) -> void:
	if enemies_root == null:
		return

	for e in enemies_root.get_children():
		if e == null:
			continue

		# Congelar módulos (recomendado)
		for p in ["Movement", "Combat", "Senses"]:
			var n := e.get_node_or_null(p)
			if n:
				n.set_process(not freeze)
				n.set_physics_process(not freeze)

		# Fallback: si algún enemigo no usa módulos, congela el root
		e.set_process(not freeze)
		e.set_physics_process(not freeze)
