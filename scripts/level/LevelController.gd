extends Node
class_name LevelController

@export var config: LevelConfig

@export_group("Node Paths (del Level)")
@export var player_path: NodePath
@export var player_sprite_path: NodePath
@export var hud_path: NodePath
@export var dialog_box_path: NodePath
@export var parallax_path: NodePath
@export var camera_rig_path: NodePath
@export var enemies_root_path: NodePath
@export var spawns_root_path: NodePath

@export_group("Enemy Scenes")
@export var default_enemy: PackedScene
@export var enemy_scenes: Array[PackedScene] = []

@export_group("Spawner Timers (opcional)")
@export var wave_timer_path: NodePath
@export var spawn_timer_path: NodePath

# Estado
var _rng := RandomNumberGenerator.new()
var _timeline_running := false
var _restarting := false

var _spawn_enabled := false
var _alive_ids: Dictionary = {}
var _spawn_points: Array[Marker2D] = []

var _kills_total := 0

# Cache nodos
var player: Node2D
var sprite: AnimatedSprite2D
var hud: Node
var dialog
var parallax
var camera_rig
var enemies_root: Node2D
var spawns_root: Node
var wave_timer: Timer
var spawn_timer: Timer

func _ready() -> void:
	add_to_group("level_controller")
	_rng.randomize()

	_cache_nodes()
	_apply_initial_setup()

	# Conectar muerte (reusable)
	if config and config.restart_on_death and player and player.has_signal("died"):
		if not player.died.is_connected(_on_player_died):
			player.died.connect(_on_player_died)

	# Intro + PostIntro + HUD + Gameplay
	await _run_level_flow()

func _cache_nodes() -> void:
	player = get_node_or_null(player_path) as Node2D
	sprite = get_node_or_null(player_sprite_path) as AnimatedSprite2D
	hud = get_node_or_null(hud_path)
	dialog = get_node_or_null(dialog_box_path)
	parallax = get_node_or_null(parallax_path)
	camera_rig = get_node_or_null(camera_rig_path)
	enemies_root = get_node_or_null(enemies_root_path) as Node2D
	spawns_root = get_node_or_null(spawns_root_path)
	wave_timer = get_node_or_null(wave_timer_path) as Timer
	spawn_timer = get_node_or_null(spawn_timer_path) as Timer

func _apply_initial_setup() -> void:
	print("[LevelController] apply_initial_setup")

	print("[LevelController] HUD:", hud)
	if hud:
		print("[LevelController] hud.visible BEFORE:", hud.visible)

	if hud:
		if hud.has_method("set_player"):
			hud.set_player(player)


	# Cámara límites iniciales
	if config and config.apply_initial_camera_limits and camera_rig and camera_rig.has_method("set_limits"):
		camera_rig.call("set_limits",
			config.cam_limit_left,
			config.cam_limit_right,
			config.cam_limit_top,
			config.cam_limit_bottom
		)

	# Spawner points
	_setup_spawn_points()

	# Timers
	_setup_spawner_timers()

func _run_level_flow() -> void:
	if config and config.show_hud and hud:
		print("[LevelController] showing HUD")
		hud.visible = true
		print("[LevelController] hud.visible AFTER:", hud.visible)

	
	# Bloquear jugador al inicio (para intros)
	_player_lock(true)
	_set_player_components_enabled(false)
	_player_collision(false)

	# Intro
	if config:
		match config.intro_type:
			LevelConfig.IntroType.FALL:
				await _intro_fall()
			LevelConfig.IntroType.ANIM_PLAYER:
				await _intro_anim_player()
			_:
				pass

	# Post-intro: diálogo opcional
	if config and config.start_dialog_path != "" and dialog and dialog.has_method("start_dialog"):
		dialog.start_dialog(config.start_dialog_path, config.dialog_autoplay, config.dialog_skippable)
		while dialog.visible:
			await get_tree().process_frame

	# HUD intro
	if config and config.show_hud and hud:
		hud.visible = true
		# sincroniza opciones como hide_mana si tu HUD las expone
		if "hide_mana" in hud:
			hud.hide_mana = config.hide_mana


		if config.play_hud_intro and hud.has_method("play_intro"):
			await hud.call("play_intro")

	# Emitir hp al inicio para forzar actualización
	if config and config.emit_hp_on_start and player and player.has_signal("hp_changed"):
		if "hp" in player and "hp_max" in player:
			player.emit_signal("hp_changed", player.hp, player.hp_max)

	# Gameplay real
	_enable_gameplay()

func _enable_gameplay() -> void:
	if config:
		set_combat_enabled(config.combat_enabled_on_start)
		set_attack_enabled(config.allow_attack_on_start)

	_player_collision(true)

	# reactivar player
	_player_lock(false)
	_set_player_components_enabled(true)

	# parallax start si existe
	if parallax and parallax.has_method("start"):
		parallax.start()

	# spawner
	if config and config.enable_spawner:
		_start_enemy_spawner()

	_timeline_running = true

# =========================
# Intro Implementations
# =========================
func _intro_fall() -> void:
	if not player:
		return

	# ground_y / fall params
	var ground_y := config.ground_y
	var fall_height := config.fall_height
	var fall_time := config.fall_time

	player.global_position = Vector2(player.global_position.x, ground_y - fall_height)

	_play_anim_if_exists(config.fall_anim_name)
	if sprite and sprite.sprite_frames and not sprite.sprite_frames.has_animation(config.fall_anim_name):
		_play_anim_if_exists(config.fallback_fall_anim)

	var t := create_tween()
	t.tween_property(player, "global_position:y", ground_y, fall_time)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await t.finished

func _intro_anim_player() -> void:
	if not config:
		return
	if config.intro_anim_player_path == NodePath():
		return

	var ap := get_node_or_null(config.intro_anim_player_path) as AnimationPlayer
	if not ap:
		return

	ap.play(config.intro_anim_name)
	await ap.animation_finished

# =========================
# Player Helpers
# =========================
func _player_lock(lock: bool) -> void:
	if not player:
		return

	# Si tu player usa estos flags, mantenlos
	if "bloqueando_input" in player:
		player.bloqueando_input = lock


	player.set_process_input(not lock)
	player.set_process(not lock)
	player.set_physics_process(not lock)

func _player_collision(enable: bool) -> void:
	if not player:
		return
	var col := player.get_node_or_null("CollisionShape2D")
	if col:
		col.disabled = not enable

func _set_player_components_enabled(enable: bool) -> void:
	if not player:
		return
	for p in ["PlayerMovement", "Components/Vertical", "Components/Dash", "Components/Attack"]:
		var n := player.get_node_or_null(p)
		if n:
			n.set_process(enable)
			n.set_physics_process(enable)

func _play_anim_if_exists(anim_name: String) -> void:
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation(anim_name):
		sprite.play(anim_name)

# =========================
# Spawner Setup
# =========================
func _setup_spawn_points() -> void:
	_spawn_points.clear()
	if not spawns_root:
		return

	for name in ["P0","P1","P2"]:
		var m := spawns_root.get_node_or_null(name) as Marker2D
		if m:
			_spawn_points.append(m)

func _setup_spawner_timers() -> void:
	if wave_timer:
		wave_timer.one_shot = true
		if not wave_timer.timeout.is_connected(_on_wave_timer_timeout):
			wave_timer.timeout.connect(_on_wave_timer_timeout)

	if spawn_timer:
		spawn_timer.one_shot = true
		if not spawn_timer.timeout.is_connected(_on_spawn_timer_timeout):
			spawn_timer.timeout.connect(_on_spawn_timer_timeout)

func _start_enemy_spawner() -> void:
	_spawn_enabled = false
	_alive_ids.clear()

	# fallback scenes
	if enemy_scenes.is_empty():
		if default_enemy:
			enemy_scenes = [default_enemy]

	if wave_timer:
		wave_timer.stop()
		wave_timer.wait_time = config.spawn_initial_delay
		wave_timer.start()

	if spawn_timer:
		spawn_timer.stop()

func _stop_enemy_spawner() -> void:
	_spawn_enabled = false
	if wave_timer: wave_timer.stop()
	if spawn_timer: spawn_timer.stop()

func _on_wave_timer_timeout() -> void:
	_spawn_enabled = true

	var extra := 1 if _rng.randf() < 0.6 else 0
	var initial = min(config.max_enemies_alive, 2 + extra)

	for i in range(initial):
		_spawn_one_enemy()

	_schedule_next_spawn(_rng.randf_range(config.spawn_interval_min, config.spawn_interval_max))

func _on_spawn_timer_timeout() -> void:
	if not _spawn_enabled:
		return
	if _alive_ids.size() >= config.max_enemies_alive:
		_schedule_next_spawn(_rng.randf_range(0.9, 1.6))
		return

	_spawn_one_enemy()

	var need_more := _alive_ids.size() < config.max_enemies_alive
	if need_more and _rng.randf() < config.burst_chance:
		_schedule_next_spawn(_rng.randf_range(config.burst_delay_min, config.burst_delay_max))
	else:
		_schedule_next_spawn(_rng.randf_range(config.spawn_interval_min, config.spawn_interval_max))

func _schedule_next_spawn(delay: float) -> void:
	if not spawn_timer:
		return
	spawn_timer.stop()
	spawn_timer.wait_time = max(0.05, delay)
	spawn_timer.start()

func _spawn_one_enemy() -> void:
	if not enemies_root or not player:
		return
	if enemy_scenes.is_empty():
		return

	var scene := enemy_scenes[_rng.randi_range(0, enemy_scenes.size() - 1)]
	if not scene:
		return

	var e := scene.instantiate()
	if not e:
		return

	enemies_root.add_child(e)
	e.global_position = _pick_spawn_position()

	# Setup módulos si existen
	for comp in ["Movement","Combat","Senses"]:
		var n := e.get_node_or_null(comp)
		if n and n.has_method("setup"):
			n.call("setup", e, player)

	# Track vivos
	var id := e.get_instance_id()
	_alive_ids[id] = true
	if not e.tree_exited.is_connected(_on_enemy_tree_exited):
		e.tree_exited.connect(_on_enemy_tree_exited.bind(id))

func _on_enemy_tree_exited(id: int) -> void:
	if _alive_ids.has(id):
		_alive_ids.erase(id)
		_kills_total += 1
		# Notifica para gates/zonas
		get_tree().call_group("kill_listeners", "on_kill_count_changed", _kills_total)

	if _spawn_enabled and _alive_ids.size() < config.max_enemies_alive:
		var d := 0.35 if _alive_ids.size() == 0 else _rng.randf_range(0.55, 1.35)
		_schedule_next_spawn(d)

func _pick_spawn_position() -> Vector2:
	if not _spawn_points.is_empty():
		var m := _spawn_points[_rng.randi_range(0, _spawn_points.size() - 1)]
		var p := m.global_position
		p.x += _rng.randf_range(-45.0, 45.0)
		p.y += _rng.randf_range(-35.0, 35.0)
		return p

	var base := player.global_position
	var dir := -1.0 if _rng.randf() < 0.5 else 1.0
	base.x += dir * _rng.randf_range(260.0, 420.0)
	base.y += _rng.randf_range(-60.0, 60.0)
	return base

# =========================
# Restart
# =========================
func _on_player_died() -> void:
	if _restarting:
		return
	_restarting = true

	_timeline_running = false
	_stop_enemy_spawner()

	_player_lock(true)
	_set_player_components_enabled(false)

	await get_tree().create_timer(config.restart_delay).timeout
	await get_tree().process_frame

	var path := config.restart_scene_path
	if path == "":
		path = get_tree().current_scene.scene_file_path

	SceneLoader.goto_scene(path, config.restart_loading_min_time)

func set_attack_enabled(enabled: bool) -> void:
	if not player:
		return

	# 1) Si tu Player tiene flag propio
	if "can_attack" in player:
		player.can_attack = enabled


	# 2) Deshabilita el componente Attack (lo más confiable)
	var attack := player.get_node_or_null("Components/Attack")
	if attack:
		attack.set_process(enabled)
		attack.set_physics_process(enabled)

	if not enabled and player.has_method("cancel_attack"):
		player.call("cancel_attack")


func set_combat_enabled(enabled: bool) -> void:
	if not player:
		return

	set_attack_enabled(enabled)

	if "combat_enabled" in player:
		player.combat_enabled = enabled
