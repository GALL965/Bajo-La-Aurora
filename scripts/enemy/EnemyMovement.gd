extends Node
class_name EnemyMovement

var owner_enemy: Node2D
var jugador: Node2D
var vel: Vector2 = Vector2.ZERO

@export var aceleracion: float = 1800.0
@export var velocidad_max: float = 600.0
@export var frenado: float = 3600.0

# --- Combate / distancias ---
@export var attack_distance: float = 52.0
@export var attack_deadzone: float = 10.0
@export var lane_tol: float = 6.0

# Lane hysteresis (evita rebote)
@export var lane_tol_hi: float = 10.0   # umbral para empezar a corregir Y
@export var lane_tol_lo: float = 4.0    # umbral para dejar de corregir Y

# Arrival (evita magnet wobble)
@export var slow_radius_x: float = 70.0
@export var slow_radius_y: float = 55.0
@export var max_y_speed: float = 520.0

# --- Slots / spacing ---
@export var slot_refresh_cada: float = 0.35
@export var slot_spacing_x: float = 64.0
@export var slot_spacing_y: float = 22.0
@export var slot_max_por_lado: int = 3

# --- Orbit / táctica ---
@export var reserve_distance: float = 260.0

@export var replan_min: float = 0.55
@export var replan_max: float = 1.15
@export var lead_time_min: float = 0.15
@export var lead_time_max: float = 0.35

# Radios base (el plan los ajusta)
@export var orbit_radius_x: float = 200.0
@export var orbit_radius_y: float = 95.0

# Pausas robóticas
@export var pause_chance: float = 0.18
@export var pause_min: float = 0.10
@export var pause_max: float = 0.22

# --- Anti-mimetismo vertical (no copiar sube/baja del jugador) ---
@export var track_lane_speed: float = 220.0      # px/s
@export var track_lane_deadband: float = 14.0    # px

# --- Micro-waypoints (ruta única) ---
@export var wp_refresh_min: float = 0.28
@export var wp_refresh_max: float = 0.55
@export var wp_max_x: float = 140.0
@export var wp_max_y: float = 90.0
@export var wp_smooth: float = 10.0              # Hz aprox

# --- Backoff / rodeo amplio cuando NO atacan ---
@export var wide_orbit_chance: float = 0
@export var wide_orbit_mul_x: float = 0
@export var wide_orbit_mul_y: float = 0

@export var retreat_chance: float = 0
@export var retreat_extra_x: float = 140.0
@export var retreat_time_min: float = 0.35
@export var retreat_time_max: float = 0.70

# --- Flanqueo ---
@export var congest_threshold: int = 2
@export var flank_cooldown: float = 1.6

# --- Separación ---
@export var radio_separacion: float = 120.0
@export var fuerza_separacion: float = 1500.0
@export var sep_tangencial: float = 0.75
@export var sep_prediccion: float = 0.12
@export var sep_max_boost: float = 220.0
@export var sep_suavizado: float = 10.0 # Hz aprox (más alto = más reactivo)

# --- Lock melee ---
@export var y_snap_vel: float = 520.0
var _lock_activo: bool = false
var _lock_y: float = 0.0

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

# Plan táctico (commit)
var _plan_time_left: float = 0.0
var _plan_mode: int = 0         # 0=orbitar,1=interceptar,2=bloquear,3=retaguardia
var _plan_rx: float = 0.0
var _plan_ry: float = 0.0
var _plan_bias: Vector2 = Vector2.ZERO
var _lead_time: float = 0.25
var _orbit_dir: float = 1.0
var _orbit_angle: float = 0.0
var _pause_left: float = 0.0

# Separación filtrada (evita rebote)
var _sep_f: Vector2 = Vector2.ZERO

# Anti-mimetismo vertical
var _tracked_lane_y: float = 0.0

# Waypoints
var _wp_left: float = 0.0
var _wp_raw: Vector2 = Vector2.ZERO
var _wp_off: Vector2 = Vector2.ZERO

# Retreat
var _retreat_left: float = 0.0


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

	if jugador and owner_enemy:
		_slot_side = -1 if owner_enemy.global_position.x < jugador.global_position.x else 1
	_slot_rank = _rng.randi_range(0, max(0, slot_max_por_lado - 1))
	_t_slot = _rng.randf_range(0.0, slot_refresh_cada)

	_tracked_lane_y = _lane_y(jugador)

	_wp_left = _rng.randf_range(wp_refresh_min, wp_refresh_max)
	_wp_raw = Vector2.ZERO
	_wp_off = Vector2.ZERO

	_replan()


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

	# Si el jugador está dasheando, congela al enemigo
	if jugador.has_method("esta_dasheando") and jugador.call("esta_dasheando"):
		vel = Vector2.ZERO
		return

	var est := _get_estado()
	var holding_pressure := (est == "esperando")


	# flank cooldown
	if _flank_time_left > 0.0:
		_flank_time_left -= delta
		if _flank_time_left <= 0.0:
			_want_flank = false

	# slots refresh
	_t_slot += delta
	if _t_slot >= slot_refresh_cada:
		_recalcular_slot()
		_t_slot = 0.0

	# ataca = quieto
	if est == "atacando":
		vel = Vector2.ZERO
		return

	# Lane del jugador “filtrado” para no copiar sube/baja
	var target_lane := _lane_y(jugador)
	var diff_lane := target_lane - _tracked_lane_y
	if abs(diff_lane) > track_lane_deadband:
		_tracked_lane_y += clamp(diff_lane, -track_lane_speed * delta, track_lane_speed * delta)

	# Retreat countdown
	if _retreat_left > 0.0:
		_retreat_left -= delta

	# commit de plan
	_plan_time_left -= delta
	if _plan_time_left <= 0.0:
		_replan()

	# pausa robótica
	if _pause_left > 0.0:
		_pause_left -= delta
		var sep_pause := _fuerza_separacion(est, delta)
		vel = vel.move_toward(Vector2.ZERO, frenado * delta)
		vel += sep_pause
		_clamp_vel()
		return

	# ¿soy atacante?
	var director = CombatDirector
	var soy_atacante := false
	if director and director.has_method("is_attacker"):
		soy_atacante = bool(director.call("is_attacker", owner_enemy))

	# Cooldown de ataque: si estoy “esperando” NO debo reservar cupo
	var en_cooldown := (est == "esperando")
	# En cooldown NO reservamos nuevos cupos,
	# pero si ya soy atacante, lo conservo
	if en_cooldown and not (director and director.call("is_attacker", owner_enemy)):
		soy_atacante = false


	# reservar cupo solo si NO cooldown y no preparando
	var dist_to_player := owner_enemy.global_position.distance_to(jugador.global_position)
	if (not soy_atacante) and (not en_cooldown) and dist_to_player <= reserve_distance and est != "preparando":
		if director and director.has_method("request_attack"):
			soy_atacante = bool(director.call("request_attack", owner_enemy))

	if est == "preparando":
		soy_atacante = true

	# objetivo
	var target := Vector2.ZERO

	# En cooldown post-ataque: se queda presionando cerca (no orbita ni retrocede)
	if est == "esperando":
		target = _objetivo_ataque()
	else:
		if soy_atacante:
			target = _objetivo_ataque()
		else:
			target = _objetivo_tactico_orbit()



	# lock Y real
	if _lock_activo:
		var off := _lane_offset_y(owner_enemy)
		target.y = (_lock_y - off)

	# en rango melee: frena
	var en_rango_melee := false
	var combat := owner_enemy.get_node_or_null("Combat")
	if combat and combat.has_method("_en_rango_ataque"):
		en_rango_melee = bool(combat.call("_en_rango_ataque"))

	if en_rango_melee and soy_atacante:
		vel = vel.move_toward(Vector2.ZERO, frenado * delta)
		return

	# Vector al target
	var to_target := target - owner_enemy.global_position

	# Lane hysteresis (evita flip-flop)
	var lane_diff = abs(_lane_y(owner_enemy) - _lane_y(jugador))
	if not _corrigiendo_lane:
		if lane_diff > lane_tol_hi:
			_corrigiendo_lane = true
	else:
		if lane_diff < lane_tol_lo:
			_corrigiendo_lane = false

	# Desired por eje con arrival (sin rebote)
	var desired := Vector2.ZERO

	# X arrival
	desired.x = _axis_arrive(to_target.x, velocidad_max, slow_radius_x)

	# Y arrival
	if _lock_activo:
		desired.y = _axis_arrive(to_target.y, y_snap_vel, slow_radius_y)
	else:
		var yspd := max_y_speed
		if _corrigiendo_lane:
			desired.x *= 0.30
			yspd = max_y_speed
		else:
			yspd = max_y_speed * 0.55

		desired.y = _axis_arrive(to_target.y, yspd, slow_radius_y)

	# preparando: no empujar fuerte en X
	if est == "preparando":
		desired.x *= 0.35

	# aceleración principal
	vel = vel.move_toward(desired, aceleracion * delta)

	# separación filtrada (evita rebote)
	var sep := _fuerza_separacion(est, delta)
	if _corrigiendo_lane or est == "preparando" or est == "atacando":
		sep.y *= 0.20
	vel += sep

	_clamp_vel()


func _objetivo_ataque() -> Vector2:
	var p := jugador.global_position

	var side := _slot_side
	if _want_flank:
		side = -side

	# IMPORTANTE:
	# En X, el atacante se coloca a distancia de melee real (sin spacing),
	# para que pueda entrar a rango_melee.
	var tx := p.x + side * attack_distance

	# En Y sí puedes variar “rank” para que no se encimen visualmente
	var player_lane_y := _lane_y(jugador)
	var enemy_off := _lane_offset_y(owner_enemy)
	var ty := player_lane_y - enemy_off

	var alt := _rank_lane_offset(_slot_rank)
	ty += alt * slot_spacing_y

	return Vector2(tx, ty)



func _objetivo_tactico_orbit() -> Vector2:
	var p := _player_center_pred()

	# el plan decide “qué tipo” de rodeo hacemos
	var rx := _plan_rx
	var ry := _plan_ry

	# orbitar con ángulo interno (no con TIME global)
	_orbit_angle += (1.15 * _orbit_dir) * get_process_delta_time()
	if _want_flank:
		_orbit_angle += PI

	var tx := p.x + cos(_orbit_angle) * rx + _plan_bias.x
	var ty := p.y + sin(_orbit_angle) * ry + _plan_bias.y

	# micro-waypoints para que la ruta sea única
	_wp_left -= get_process_delta_time()
	if _wp_left <= 0.0:
		_wp_left = _rng.randf_range(wp_refresh_min, wp_refresh_max)
		_wp_raw = Vector2(
			_rng.randf_range(-wp_max_x, wp_max_x),
			_rng.randf_range(-wp_max_y, wp_max_y)
		)

	# suavizado del waypoint (evita saltos)
	var k := 1.0 - exp(-wp_smooth * get_process_delta_time())
	_wp_off = _wp_off.lerp(_wp_raw, k)

	tx += _wp_off.x
	ty += _wp_off.y

	# Retreat: se abre y se aleja un poco en X si no está atacando
	if _retreat_left > 0.0:
		var away = sign(owner_enemy.global_position.x - jugador.global_position.x)
		tx += away * retreat_extra_x

	return Vector2(tx, ty)


func _replan() -> void:
	_plan_time_left = _rng.randf_range(replan_min, replan_max)
	_lead_time = _rng.randf_range(lead_time_min, lead_time_max)

	# dirección de órbita estable por enemigo
	_orbit_dir = -1.0 if _rng.randf() < 0.5 else 1.0

	# modo táctico (discreto)
	var r := _rng.randf()
	if r < 0.55:
		_plan_mode = 0 # orbitar
	elif r < 0.75:
		_plan_mode = 1 # interceptar
	elif r < 0.92:
		_plan_mode = 2 # bloquear lateral
	else:
		_plan_mode = 3 # retaguardia

	# radios por “anillo”
	_plan_rx = orbit_radius_x + float(_slot_rank) * 34.0
	_plan_ry = orbit_radius_y + float(_slot_rank) * 18.0

	# bias discreto
	_plan_bias = Vector2.ZERO
	var lane_step := slot_spacing_y * 2.0
	_plan_bias.y = float(_rank_lane_offset(_slot_rank)) * lane_step

	if _want_flank:
		_plan_bias.x += float(_slot_side) * 48.0

	# ajustes por modo
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

	# wide orbit ocasional
	if _rng.randf() < wide_orbit_chance:
		_plan_rx *= wide_orbit_mul_x
		_plan_ry *= wide_orbit_mul_y

	# retreat ocasional
	if _rng.randf() < retreat_chance:
		_retreat_left = _rng.randf_range(retreat_time_min, retreat_time_max)

	# pausas robóticas ocasionales
	if _rng.randf() < pause_chance:
		_pause_left = _rng.randf_range(pause_min, pause_max)


func _player_center_pred() -> Vector2:
	var p := jugador.global_position
	var pv := _player_velocity()

	# Predicción suave solo en X
	if pv.length() > 1.0:
		p.x += pv.x * _lead_time

	# Y filtrada (no copia tu sube/baja)
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

	# filtro (quita rebote)
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


func _recalcular_slot() -> void:
	if jugador == null or owner_enemy == null:
		return

	var todos := get_tree().get_nodes_in_group("enemigos_androides")
	var player_x := jugador.global_position.x
	var player_lane := _lane_y(jugador)

	_slot_side = -1 if owner_enemy.global_position.x < player_x else 1

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
