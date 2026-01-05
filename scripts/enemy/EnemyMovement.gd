extends Node
class_name EnemyMovement

var owner_enemy: Node2D
var jugador: Node2D
var vel: Vector2 = Vector2.ZERO
@export var side_flip_deadzone_x: float = 24.0  # px (zona donde NO se permite cambiar de lado)
# === NUEVO: alineación tardía y lane de compromiso (evita que te copie Y) ===
@export var align_enter_dx: float = 140.0
@export var align_exit_dx: float = 190.0
@export var final_align_dx: float = 92.0
# --- Separación contra el jugador (anti-montaje) ---
@export var player_sep_radius: float = 46.0
@export var player_sep_strength: float = 1200.0
@export var player_sep_max: float = 220.0

@export var engage_lane_deadband: float = 44.0
@export var engage_lane_speed: float = 140.0

var _engage_lane_y: float = 0.0
var _was_attacker: bool = false

@export var aceleracion: float = 1800.0
@export var velocidad_max: float = 600.0
@export var frenado: float = 3600.0

# --- Combate / distancias ---
@export var attack_distance: float = 52.0
@export var attack_deadzone: float = 10.0
@export var lane_tol: float = 6.0

# Lane hysteresis
@export var lane_tol_hi: float = 10.0
@export var lane_tol_lo: float = 4.0

# Arrival
@export var slow_radius_x: float = 70.0
@export var slow_radius_y: float = 55.0
@export var max_y_speed: float = 520.0

# --- Slots / spacing ---
@export var slot_refresh_cada: float = 0.35
@export var slot_spacing_x: float = 64.0
@export var slot_spacing_y: float = 22.0
@export var slot_max_por_lado: int = 3

# --- Táctica / reserva ---
@export var reserve_distance: float = 260.0
@export var reserve_extra_min: float = 60.0      # distancia extra para no-atacantes
@export var reserve_extra_max: float = 130.0

@export var replan_min: float = 0.55
@export var replan_max: float = 1.15
@export var lead_time_min: float = 0.15
@export var lead_time_max: float = 0.35

@export var orbit_radius_x: float = 200.0
@export var orbit_radius_y: float = 95.0

# Pausas (bajamos lo robótico)
@export var pause_chance: float = 0.10
@export var pause_min: float = 0.08
@export var pause_max: float = 0.18

# --- Anti-mimetismo vertical ---
@export var track_lane_speed: float = 170.0
@export var track_lane_deadband: float = 18.0

# --- Micro-waypoints ---
@export var wp_refresh_min: float = 0.35
@export var wp_refresh_max: float = 0.70
@export var wp_max_x: float = 160.0
@export var wp_max_y: float = 110.0
@export var wp_smooth: float = 9.0

# --- Backoff / flanqueo ---
@export var retreat_chance: float = 0.10
@export var retreat_extra_x: float = 140.0
@export var retreat_time_min: float = 0.35
@export var retreat_time_max: float = 0.70

@export var congest_threshold: int = 2
@export var flank_cooldown: float = 1.6

# --- Separación ---
@export var radio_separacion: float = 120.0
@export var fuerza_separacion: float = 1500.0
@export var sep_tangencial: float = 0.75
@export var sep_prediccion: float = 0.12
@export var sep_max_boost: float = 220.0
@export var sep_suavizado: float = 10.0

# --- Lock melee ---
@export var y_snap_vel: float = 520.0
var _lock_activo: bool = false
var _lock_y: float = 0.0

# === NUEVO: Intención / commit (evita reacción instantánea) ===
@export var intent_follow_speed_attacker: float = 560.0
@export var intent_follow_speed_support: float = 260.0
@export var intent_smooth_hz: float = 10.0

var _intent_goal: Vector2 = Vector2.ZERO
var _intent_goal_f: Vector2 = Vector2.ZERO

# === NUEVO: Alinear lane sólo si estás cerca y atacando ===
@export var align_enter_dist: float = 240.0
@export var align_exit_dist: float = 310.0

# === NUEVO: Gait (pasos android) ===
@export var gait_period_min: float = 0.32
@export var gait_period_max: float = 0.48
@export var gait_depth: float = 0.40  # 0..0.6 aprox

var _gait_phase: float = 0.0
var _gait_period: float = 0.40
var _gait_f: float = 1.0

# Estado interno (slots / flank)
var _slot_side: int = 0
var _slot_rank: int = 0
var _t_slot: float = 0.0

var _flank_time_left: float = 0.0
var _want_flank: bool = false

var _rng := RandomNumberGenerator.new()
var _phase: float = 0.0

# Lane control
var _corrigiendo_lane: bool = false

# Plan táctico
var _plan_time_left: float = 0.0
var _plan_mode: int = 0
var _plan_rx: float = 0.0
var _plan_ry: float = 0.0
var _plan_bias: Vector2 = Vector2.ZERO
var _lead_time: float = 0.25
var _orbit_dir: float = 1.0
var _orbit_angle: float = 0.0
var _pause_left: float = 0.0
var _reserve_extra: float = 90.0

# Separación filtrada
var _sep_f: Vector2 = Vector2.ZERO

# Anti-mimetismo vertical
var _tracked_lane_y: float = 0.0

# Waypoints
var _wp_left: float = 0.0
var _wp_raw: Vector2 = Vector2.ZERO
var _wp_off: Vector2 = Vector2.ZERO

# Retreat
var _retreat_left: float = 0.0

# Preferencia de lane (para soportes; evita que todos copien tu Y exacta)
var _lane_pref: float = 0.0

# Rol (tick)
var _role_attacker: bool = false


func setup(enemy: Node2D, player: Node2D) -> void:
	owner_enemy = enemy
	jugador = player

	if owner_enemy and owner_enemy.has_method("get_velocidad_max"):
		velocidad_max = float(owner_enemy.call("get_velocidad_max"))
	elif owner_enemy and _has_prop(owner_enemy, &"velocidad_max"):
		velocidad_max = float(owner_enemy.get("velocidad_max"))

	_rng.randomize()
	_phase = _rng.randf_range(0.0, TAU)
	_orbit_angle = _phase

	_gait_period = _rng.randf_range(gait_period_min, gait_period_max)
	_gait_phase = _rng.randf_range(0.0, TAU)

	if jugador and owner_enemy:
		_slot_side = _pick_side(owner_enemy.global_position.x, jugador.global_position.x, _slot_side)

	_slot_rank = _rng.randi_range(0, max(0, slot_max_por_lado - 1))
	_t_slot = _rng.randf_range(0.0, slot_refresh_cada)

	_tracked_lane_y = _lane_y(jugador)

	_wp_left = _rng.randf_range(wp_refresh_min, wp_refresh_max)
	_wp_raw = Vector2.ZERO
	_wp_off = Vector2.ZERO

	_reserve_extra = _rng.randf_range(reserve_extra_min, reserve_extra_max)

	_lane_pref = float(_rank_lane_offset(_slot_rank)) * slot_spacing_y * 1.15 + _rng.randf_range(-10.0, 10.0)

	_replan()

	_intent_goal = owner_enemy.global_position
	_intent_goal_f = _intent_goal
	
	_engage_lane_y = _lane_y(jugador)
	_was_attacker = false





func activar_lock_melee(y_obj: float) -> void:
	_lock_activo = true
	_lock_y = y_obj


func desactivar_lock_melee() -> void:
	_lock_activo = false


func get_velocidad_actual() -> Vector2:
	return vel


func tick(delta: float) -> void:
	if jugador == null or owner_enemy == null:
		return

	if jugador.has_method("esta_dasheando") and jugador.call("esta_dasheando"):
		vel = Vector2.ZERO
		return

	var est := _get_estado()

	# --- Flank cooldown ---
	if _flank_time_left > 0.0:
		_flank_time_left -= delta
		if _flank_time_left <= 0.0:
			_want_flank = false

	# --- Slot refresh ---
	_t_slot += delta
	if _t_slot >= slot_refresh_cada:
		_recalcular_slot()
		_t_slot = 0.0

	# Si está atacando, no lo muevas desde aquí
	if est == "atacando":
		vel = Vector2.ZERO
		return

	# --- Director / rol atacante ---
	var director = CombatDirector
	var dist_to_player := owner_enemy.global_position.distance_to(jugador.global_position)

	# Por defecto: atacante si el director ya te tiene
	var soy_atacante := false
	if director and director.has_method("is_attacker"):
		soy_atacante = bool(director.call("is_attacker", owner_enemy))

	# Si entras a cooldown/esperando, suelta token (importante)
	if est == "esperando":
		if director and director.has_method("release_attack"):
			director.call("release_attack", owner_enemy)
		soy_atacante = false

	# Solicitar token sólo si NO estás en cooldown y estás razonablemente cerca
	if (not soy_atacante) and est != "esperando" and est != "atacando" and est != "preparando":
		if dist_to_player <= reserve_distance:
			if director and director.has_method("request_attack"):
				soy_atacante = bool(director.call("request_attack", owner_enemy))

	# Preparando = atacante “forzado”
	if est == "preparando":
		soy_atacante = true

	# Si eres atacante pero te alejaste demasiado, suelta token (evita bloquear a otros)
	if soy_atacante and est != "preparando" and dist_to_player > reserve_distance * 1.75:
		if director and director.has_method("release_attack"):
			director.call("release_attack", owner_enemy)
		soy_atacante = false

	_role_attacker = soy_atacante
	
	# --- Lane de compromiso: el atacante NO debe copiar tu Y en vivo ---
	if soy_atacante and not _was_attacker:
		_engage_lane_y = _lane_y(jugador) # snapshot al volverte atacante

	if soy_atacante:
		var dy := _lane_y(jugador) - _engage_lane_y
		if abs(dy) > engage_lane_deadband:
			_engage_lane_y += clamp(dy, -engage_lane_speed * delta, engage_lane_speed * delta)

	_was_attacker = soy_atacante


	# --- Anti-mimetismo vertical: track filtrado con deadband ---
	var target_lane := _lane_y(jugador)
	var diff_lane := target_lane - _tracked_lane_y
	if abs(diff_lane) > track_lane_deadband:
		_tracked_lane_y += clamp(diff_lane, -track_lane_speed * delta, track_lane_speed * delta)

	# --- Retreat timer ---
	if _retreat_left > 0.0:
		_retreat_left -= delta

	# --- Replan ---
	_plan_time_left -= delta
	if _plan_time_left <= 0.0:
		_replan()

	# --- Pausa breve “android” ---
	if _pause_left > 0.0:
		_pause_left -= delta
		var sep_pause := _fuerza_separacion(est, delta)
		vel = vel.move_toward(Vector2.ZERO, frenado * delta)
		vel += sep_pause
		_clamp_vel()
		return

	# === Objetivo raw por rol ===
	var raw_target: Vector2
	if soy_atacante:
		raw_target = _objetivo_ataque()
	else:
		raw_target = _objetivo_tactico_orbit(delta)

	# === Lane alignment sólo si atacante y cerca (evita “magnetismo” global) ===
	var lane_diff_abs = abs(_lane_y(owner_enemy) - _lane_y(jugador))
	var dx_abs = abs(owner_enemy.global_position.x - jugador.global_position.x)

	var want_align = soy_atacante and dist_to_player <= align_enter_dist and dx_abs <= align_enter_dx

	if _corrigiendo_lane:
		# salir por distancia o por tolerancia baja
		if dist_to_player > align_exit_dist or dx_abs > align_exit_dx or lane_diff_abs < lane_tol_lo:
			_corrigiendo_lane = false
	else:
		if want_align and lane_diff_abs > lane_tol_hi:
			_corrigiendo_lane = true

	# Lock melee: sólo si atacante y ya está relativamente alineado
	if soy_atacante and lane_diff_abs <= lane_tol_lo and dist_to_player <= (align_exit_dist + 20.0):
		activar_lock_melee(_lane_y(jugador))
	else:
		desactivar_lock_melee()

	# Si corrige lane, empuja Y fuerte, pero NO congeles X (sólo lo amortiguamos después)
	if _corrigiendo_lane or _lock_activo:
		var off := _lane_offset_y(owner_enemy)
		raw_target.y = (_lock_y if _lock_activo else _lane_y(jugador)) - off

	# === Intención/commit: el target se “persigue” con velocidad limitada (no instantáneo) ===
	var follow_spd := intent_follow_speed_attacker if soy_atacante else intent_follow_speed_support
	_intent_goal = _intent_goal.move_toward(raw_target, follow_spd * delta)

	var k_int := 1.0 - exp(-intent_smooth_hz * delta)
	_intent_goal_f = _intent_goal_f.lerp(_intent_goal, k_int)

	var target := _intent_goal_f

	# Si atacante en rango de melee, frena para no vibrar
	var en_rango_melee := false
	var combat := owner_enemy.get_node_or_null("Combat")
	if combat and combat.has_method("_en_rango_ataque"):
		en_rango_melee = bool(combat.call("_en_rango_ataque"))

	if en_rango_melee and soy_atacante:
		vel = vel.move_toward(Vector2.ZERO, frenado * delta)
		return

	# --- Steering ---
	var to_target := target - owner_enemy.global_position
	var desired := Vector2.ZERO

	desired.x = _axis_arrive(to_target.x, velocidad_max, slow_radius_x)

	# Y: atacante puede corregir rápido; soporte más suave
	if soy_atacante:
		desired.y = _axis_arrive(to_target.y, max_y_speed, slow_radius_y)
	else:
		desired.y = _axis_arrive(to_target.y, max_y_speed * 0.55, slow_radius_y)

	# Deadzones para evitar “micro-corrección” que se ve como vibración
	if _role_attacker:
		if abs(to_target.x) < attack_deadzone:
			desired.x = 0.0
		if _lock_activo and abs(to_target.y) < lane_tol:
			desired.y = 0.0


	# Si está corrigiendo lane, reduce X (pero no lo congeles)
	if _corrigiendo_lane and soy_atacante:
		desired.x *= 0.40

	# Preparando: entra más lento, más “táctico”
	if est == "preparando":
		desired.x *= 0.35
		desired.y *= 0.60

	# === Gait (pasos): modula la velocidad para “pisadas” ===
	_update_gait(delta, desired.length())
	desired *= _gait_f

	# Aplicar aceleración
	vel = vel.move_toward(desired, aceleracion * delta)

	# Separación
	var sep := _fuerza_separacion(est, delta)
	if _corrigiendo_lane or est == "preparando" or est == "atacando":
		sep.y *= 0.20
	vel += sep
	
	# Separación contra el jugador para evitar “pegarse / arrastrar”
	var d := owner_enemy.global_position.distance_to(jugador.global_position)
	if d < player_sep_radius and est != "atacando":
		var away := owner_enemy.global_position - jugador.global_position
		if away.length() > 0.001:
			var w := 1.0 - (d / player_sep_radius)
			var push := away.normalized() * (player_sep_strength * w)
			if push.length() > player_sep_max:
				push = push.normalized() * player_sep_max
			vel += push * delta


	_clamp_vel()

	# Hook opcional de salto espontáneo (si tu enemigo lo implementa)
	# Ejemplo: en tu EnemigoBase.gd define func try_spontaneous_hop(): ...
	if owner_enemy.has_method("try_spontaneous_hop"):
		# salto rarito si está moviéndose y NO es atacante (se siente táctico)
		if (not soy_atacante) and vel.length() > 120.0 and _rng.randf() < (0.25 * delta):
			owner_enemy.call("try_spontaneous_hop")


func _update_gait(delta: float, spd: float) -> void:
	# Si casi no se mueve, no “pisa”
	if spd < 30.0:
		_gait_f = lerp(_gait_f, 1.0, 1.0 - exp(-10.0 * delta))
		return

	_gait_phase += TAU * (delta / _gait_period)
	# Onda empujada: sube rápido, baja lento (paso)
	var s := sin(_gait_phase)
	var push = max(0.0, s)
	var f = 1.0 - gait_depth + gait_depth * (0.55 + 0.45 * push)
	_gait_f = lerp(_gait_f, f, 1.0 - exp(-12.0 * delta))


func _objetivo_ataque() -> Vector2:
	var p := jugador.global_position

	var side := _slot_side
	if _want_flank:
		side = -side

	# Atacante: distancia real de melee en X
	var tx := p.x + side * attack_distance

	var enemy_off := _lane_offset_y(owner_enemy)

	# Base: lane de compromiso (no tu lane en vivo)
	var base_lane_y := _engage_lane_y

	# Sólo en el “último paso” alinea al lane real del jugador
	var dx_abs = abs(owner_enemy.global_position.x - p.x)
	if dx_abs <= final_align_dx:
		base_lane_y = _lane_y(jugador)

	var ty := base_lane_y - enemy_off

	# offset visual por rank si está relativamente cerca en lane
	var alt := _rank_lane_offset(_slot_rank)
	if abs(_lane_y(owner_enemy) - base_lane_y) < lane_tol_hi:
		ty += alt * slot_spacing_y


	return Vector2(tx, ty)


func _objetivo_tactico_orbit(delta: float) -> Vector2:
	var p := _player_center_pred()

	# soporte: anillo más amplio (mantén distancia)
	var rx := _plan_rx
	var ry := _plan_ry
	rx = max(rx, reserve_distance + _reserve_extra + float(_slot_rank) * 25.0)
	ry = max(ry, orbit_radius_y + float(_slot_rank) * 18.0)

	_orbit_angle += (1.05 * _orbit_dir) * delta
	if _want_flank:
		_orbit_angle += PI

	var tx := p.x + cos(_orbit_angle) * rx + _plan_bias.x
	var ty := p.y + sin(_orbit_angle) * ry + _plan_bias.y

	# Preferencia de lane propia (no copiar tu Y exacta)
	ty += _lane_pref

	# micro-waypoints
	_wp_left -= delta
	if _wp_left <= 0.0:
		_wp_left = _rng.randf_range(wp_refresh_min, wp_refresh_max)
		_wp_raw = Vector2(
			_rng.randf_range(-wp_max_x, wp_max_x),
			_rng.randf_range(-wp_max_y, wp_max_y)
		)

	var k := 1.0 - exp(-wp_smooth * delta)
	_wp_off = _wp_off.lerp(_wp_raw, k)

	tx += _wp_off.x
	ty += _wp_off.y

	# Retreat ocasional: se abre en X
	if _retreat_left > 0.0:
		var away = sign(owner_enemy.global_position.x - jugador.global_position.x)
		tx += away * retreat_extra_x

	return Vector2(tx, ty)


func _replan() -> void:
	_plan_time_left = _rng.randf_range(replan_min, replan_max)
	_lead_time = _rng.randf_range(lead_time_min, lead_time_max)

	_orbit_dir = -1.0 if _rng.randf() < 0.5 else 1.0

	var r := _rng.randf()
	if r < 0.55:
		_plan_mode = 0
	elif r < 0.75:
		_plan_mode = 1
	elif r < 0.92:
		_plan_mode = 2
	else:
		_plan_mode = 3

	_plan_rx = orbit_radius_x + float(_slot_rank) * 34.0
	_plan_ry = orbit_radius_y + float(_slot_rank) * 18.0

	_plan_bias = Vector2.ZERO
	var lane_step := slot_spacing_y * 2.0
	_plan_bias.y = float(_rank_lane_offset(_slot_rank)) * lane_step

	if _want_flank:
		_plan_bias.x += float(_slot_side) * 48.0

	var pv := _player_velocity()
	if _plan_mode == 1 and pv.length() > 30.0:
		_plan_bias.x += pv.normalized().x * 110.0
		_plan_bias.y += pv.normalized().y * 60.0
	elif _plan_mode == 2:
		_plan_bias.x += float(_slot_side) * 120.0
	elif _plan_mode == 3:
		if pv.length() > 30.0:
			_plan_bias.x -= pv.normalized().x * 120.0
			_plan_bias.y -= pv.normalized().y * 60.0
		else:
			_plan_bias.x -= float(_slot_side) * 110.0

	# retreat ocasional
	if _rng.randf() < retreat_chance:
		_retreat_left = _rng.randf_range(retreat_time_min, retreat_time_max)

	# pausa ocasional
	if _rng.randf() < pause_chance:
		_pause_left = _rng.randf_range(pause_min, pause_max)


func _player_center_pred() -> Vector2:
	var p := jugador.global_position
	var pv := _player_velocity()

	# Predicción suave en X
	if pv.length() > 1.0:
		p.x += pv.x * _lead_time

	# Y filtrada (anti-mimetismo)
	p.y = _tracked_lane_y
	return p


func _player_velocity() -> Vector2:
	if jugador is CharacterBody2D:
		return (jugador as CharacterBody2D).velocity
	if jugador.has_method("get_velocity"):
		return Vector2(jugador.call("get_velocity"))
	if _has_prop(jugador, &"velocity"):
		return Vector2(jugador.get("velocity"))
	return Vector2.ZERO


func _fuerza_separacion(est: String, delta: float) -> Vector2:
	var aliados := _aliados_cercanos()
	if aliados.is_empty():
		_sep_f = _sep_f.move_toward(Vector2.ZERO, sep_suavizado * 20.0 * delta)
		return Vector2.ZERO

	var my_pos := owner_enemy.global_position + vel * sep_prediccion
	var ppos := jugador.global_position
	var rep := Vector2.ZERO

	for a in aliados:
		var a_vel := Vector2.ZERO
		var am = a.get_node_or_null("Movement")
		if am and am.has_method("get_velocidad_actual"):
			a_vel = Vector2(am.call("get_velocidad_actual"))

		var a_pos = a.global_position + a_vel * sep_prediccion
		var to_me = my_pos - a_pos
		var d = to_me.length()
		if d <= 0.001 or d >= radio_separacion:
			continue

		var n = to_me / d
		var w = 1.0 - (d / radio_separacion)
		w = w * w

		rep += n * w

		var t := Vector2(-n.y, n.x)
		var s = sign((a_pos - ppos).cross(my_pos - ppos))
		if s == 0:
			s = 1
		rep += t * (w * sep_tangencial * s)

	if est == "preparando" or est == "atacando":
		rep.y = 0.0

	var out := rep * fuerza_separacion
	if out.length() > sep_max_boost:
		out = out.normalized() * sep_max_boost

	var k := 1.0 - exp(-sep_suavizado * delta)
	_sep_f = _sep_f.lerp(out, k)
	return _sep_f


func _aliados_cercanos() -> Array:
	var todos = get_tree().get_nodes_in_group("enemigos_androides")
	var out: Array = []
	for n in todos:
		if n != owner_enemy and n is CharacterBody2D:
			if n.global_position.distance_to(owner_enemy.global_position) <= radio_separacion * 1.6:
				out.append(n)
	return out


func _axis_arrive(diff: float, max_speed: float, slow_radius: float) -> float:
	var ad = abs(diff)
	if ad < 0.001:
		return 0.0
	var spd := max_speed
	if ad < slow_radius:
		spd *= ad / slow_radius
	return sign(diff) * spd


func _clamp_vel() -> void:
	if vel.length() > velocidad_max:
		vel = vel.normalized() * velocidad_max

func _pick_side(enemy_x: float, player_x: float, current_side: int) -> int:
	var dx := enemy_x - player_x
	if abs(dx) <= side_flip_deadzone_x:
		# Mantén el lado actual para evitar flip-flop
		if current_side != 0:
			return current_side
		# Si aún no hay lado (0), elige uno estable
		return -1 if _rng.randf() < 0.5 else 1
	return -1 if enemy_x < player_x else 1


func _recalcular_slot() -> void:
	if jugador == null or owner_enemy == null:
		return

	var todos := get_tree().get_nodes_in_group("enemigos_androides")
	var player_x := jugador.global_position.x
	var player_lane := _lane_y(jugador)

	_slot_side = _pick_side(owner_enemy.global_position.x, player_x, _slot_side)


	var left: Array = []
	var right: Array = []
	for n in todos:
		if n == null or not (n is CharacterBody2D):
			continue
		if n.global_position.distance_to(jugador.global_position) > 520.0:
			continue
		if n.global_position.x < player_x:
			left.append(n)
		else:
			right.append(n)

	if _flank_time_left <= 0.0:
		var my_count := left.size() if _slot_side == -1 else right.size()
		var other_count := right.size() if _slot_side == -1 else left.size()
		if my_count >= congest_threshold and other_count + 1 < my_count:
			_want_flank = true
			_flank_time_left = flank_cooldown

	var my_side_list := left if _slot_side == -1 else right
	var my_score := _score_para_rank0(owner_enemy, player_x, player_lane)

	var rank := 0
	for n in my_side_list:
		if n == owner_enemy:
			continue
		if _score_para_rank0(n, player_x, player_lane) < my_score:
			rank += 1

	_slot_rank = clamp(rank, 0, max(0, slot_max_por_lado - 1))

	# lane prefered se ajusta suave (para que no “salte”)
	var desired_pref := float(_rank_lane_offset(_slot_rank)) * slot_spacing_y * 1.15
	desired_pref += _rng.randf_range(-8.0, 8.0)
	_lane_pref = lerp(_lane_pref, desired_pref, 0.35)


func _lane_y(n: Node2D) -> float:
	var cs := n.get_node_or_null("CollisionShape2D") as CollisionShape2D
	return cs.global_position.y if cs else n.global_position.y


func _lane_offset_y(n: Node2D) -> float:
	var cs := n.get_node_or_null("CollisionShape2D") as CollisionShape2D
	return (cs.global_position.y - n.global_position.y) if cs else 0.0


func _rank_lane_offset(rank: int) -> float:
	if rank <= 0:
		return 0.0
	var mag := int((rank + 1) / 2)
	var s := 1 if (rank % 2) == 1 else -1
	return float(mag * s)


func _score_para_rank0(n: Node2D, player_x: float, player_lane: float) -> float:
	var dy = abs(_lane_y(n) - player_lane) * 2.0
	var dx = abs(n.global_position.x - player_x) * 1.0
	return dy + dx


func _get_estado() -> String:
	if owner_enemy and _has_prop(owner_enemy, &"estado"):
		return str(owner_enemy.get("estado"))
	return ""


func _has_prop(obj: Object, prop: StringName) -> bool:
	for d in obj.get_property_list():
		if d.get("name") == prop:
			return true
	return false
