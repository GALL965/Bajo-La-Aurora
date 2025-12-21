extends Node
class_name EnemyMovement

var owner_enemy: Node2D
var jugador: Node2D
var vel: Vector2 = Vector2.ZERO

@export var lock_y_alcance: float = 120.0
@export var lock_y_tolerancia: float = 4.0
@export var lock_y_vel: float = 900.0
@export var lock_micro_nudge_x: float = 220.0

var _lock_activo: bool = false
var _lock_y: float = 0.0

@export var y_lock_alcance: float = 96.0
@export var y_lock_tolerancia: float = 6.0
@export var y_snap_vel: float = 520.0

var _rng := RandomNumberGenerator.new()
var _ruta_modo: int = 0
var _ruta_y_base: float = 0.0
var _ruta_jitter: float = 0.0
var _fase_refresh: float = 0.0

@export var arranque_agresivo: bool = true
@export var radio_arrival: float = 48.0
@export var frenado: float = 3600.0
@export var velocidad_max: float = 600.0

@export var distancia_lateral: float = 32.0
@export var radio_separacion: float = 85.0
@export var fuerza_separacion: float = 1000.0

var _tiempo_ruta: float = 0.0
@export var cambiar_ruta_cada: float = 0.9
var _objetivo_actual: Vector2 = Vector2.ZERO


func setup(enemy: Node2D, player: Node2D) -> void:
	owner_enemy = enemy
	jugador = player

	if owner_enemy and owner_enemy.has_method("get_velocidad_max"):
		velocidad_max = float(owner_enemy.call("get_velocidad_max"))
	elif owner_enemy and _has_prop(owner_enemy, &"velocidad_max"):
		velocidad_max = float(owner_enemy.get("velocidad_max"))

	_objetivo_actual = owner_enemy.global_position

	_rng.randomize()
	_ruta_modo = _rng.randi_range(-1, 1)
	_ruta_y_base = float(_ruta_modo) * 56.0
	_ruta_jitter = _rng.randf_range(-18.0, 18.0)
	_fase_refresh = _rng.randf_range(0.0, cambiar_ruta_cada * 0.6)


func activar_lock_melee(y_obj: float) -> void:
	_lock_activo = true
	_lock_y = y_obj


func desactivar_lock_melee() -> void:
	_lock_activo = false


func tick(delta: float) -> void:
	if jugador == null or owner_enemy == null:
		return

	# 🔒 Si el jugador está dasheando, NO intentar seguirlo
	if jugador.has_method("esta_dasheando"):
		if jugador.call("esta_dasheando"):
			vel = Vector2.ZERO
			return

	var est := _get_estado()

	# FIX CLAVE: mientras ataca, NO debe “seguirte” ni reposicionarse
	if est == "atacando":
		vel = Vector2.ZERO
		return

	_tiempo_ruta += delta
	if _tiempo_ruta >= (cambiar_ruta_cada + _fase_refresh):
		_objetivo_actual = _objetivo_tactico()
		_tiempo_ruta = 0.0

		if est == "preparando" or est == "atacando":
			_fase_refresh = -cambiar_ruta_cada * 0.6
		else:
			_fase_refresh = _rng.randf_range(0.0, cambiar_ruta_cada * 0.6)

	var to_target := _objetivo_actual - owner_enemy.global_position
	var dist := to_target.length()
	var dir := Vector2.ZERO
	if dist > 0.0:
		dir = to_target / dist

	var deseada := dir * velocidad_max

	# Mientras prepara, no “arrastres” en X (opcional pero recomendado)
	if est == "preparando":
		deseada.x = 0.0

	# Lock Y cerca/combate (solo ajusta Y)
	var dist_to_player := owner_enemy.global_position.distance_to(jugador.global_position)
	var lockY := (est == "preparando" or est == "atacando" or dist_to_player <= y_lock_alcance)

	if lockY:
		var dy := jugador.global_position.y - owner_enemy.global_position.y
		if abs(dy) <= y_lock_tolerancia:
			vel.y = 0.0
		else:
			var dir_y := -1.0 if dy < 0.0 else 1.0

			vel.y = dir_y * min(abs(dy) / max(delta, 0.001), y_snap_vel)

	if _lock_activo or est == "preparando" or est == "atacando":
		var ref_y := jugador.global_position.y
		if _lock_activo:
			ref_y = _lock_y

		var dy2 := ref_y - owner_enemy.global_position.y
		if abs(dy2) <= lock_y_tolerancia:
			vel.y = 0.0
		else:
			var dir_y2 := -1.0 if dy2 < 0.0 else 1.0

			vel.y = dir_y2 * min(lock_y_vel, abs(dy2) / max(delta, 0.001))

		# Este micro-nudge también se siente como “arrastre”.
		# Si aún lo notas, comenta este bloque.
		if est == "preparando":
			var dx := jugador.global_position.x - owner_enemy.global_position.x
			if dx != 0.0:
				var dir_x := -1.0 if dx < 0.0 else 1.0

				vel.x += dir_x * lock_micro_nudge_x * delta

	if dist < radio_arrival and dist > 0.0:
		var esc = clamp(dist / radio_arrival, 0.35, 1.0)
		deseada = dir * (velocidad_max * esc)

	var mezcla := 0.95
	vel = vel.lerp(deseada, clamp(mezcla, 0.0, 1.0))

	var f_sep := _fuerza_separacion()
	if f_sep != Vector2.ZERO:
		var empuje := f_sep
		var max_boost := 120.0
		if empuje.length() > max_boost:
			empuje = empuje.normalized() * max_boost
		vel += empuje * delta

	if dir == Vector2.ZERO:
		var s := vel.length()
		if s > 0.0:
			s = max(s - frenado * delta, 0.0)
			if s == 0.0:
				vel = Vector2.ZERO
			else:
				vel = vel.normalized() * s

	if vel.length() > velocidad_max:
		vel = vel.normalized() * velocidad_max


func _objetivo_tactico() -> Vector2:
	var player_pos := jugador.global_position
	var target := player_pos

	var dist := owner_enemy.global_position.distance_to(player_pos)
	var est := _get_estado()
	var en_combate := (est == "preparando" or est == "atacando")
	var cerca_para_lock := dist <= lock_y_alcance or _lock_activo

	if en_combate or cerca_para_lock:
		var lado := 1
		if owner_enemy.global_position.x < player_pos.x:
			lado = -1
		target.x = player_pos.x + float(lado) * distancia_lateral
		target.y = _lock_y if _lock_activo else player_pos.y

		return target

	# Aire (si tu player/enemigo exponen algo de “en el aire”)
	var jugador_en_aire := _is_airborne(jugador)
	var enemigo_en_aire := _is_airborne(owner_enemy)

	if jugador_en_aire or enemigo_en_aire:
		var lado_air = sign(owner_enemy.global_position.x - player_pos.x)
		if lado_air == 0:
			lado_air = 1
		target.x = player_pos.x + float(lado_air) * distancia_lateral
		target.y = player_pos.y
		return target

	target.y += _ruta_y_base + _ruta_jitter
	target.x += _rng.randf_range(-14.0, 14.0)
	return target


func _aliados_cercanos() -> Array:
	var todos = get_tree().get_nodes_in_group("enemigos_androides")
	var out: Array = []
	for n in todos:
		if n != owner_enemy and n is CharacterBody2D:
			if n.global_position.distance_to(owner_enemy.global_position) <= radio_separacion * 1.5:
				out.append(n)
	return out


func _fuerza_separacion() -> Vector2:
	var aliados = _aliados_cercanos()
	var repulsion := Vector2.ZERO

	for a in aliados:
		var to_me = owner_enemy.global_position - a.global_position
		var d = to_me.length()
		if d > 0.0 and d < radio_separacion:
			repulsion += to_me.normalized() * (1.0 - (d / radio_separacion))

	var est := _get_estado()
	if est == "preparando" or est == "atacando":
		repulsion.y = 0.0

	return repulsion * fuerza_separacion


func get_velocidad_actual() -> Vector2:
	return vel


func _get_estado() -> String:
	if owner_enemy and _has_prop(owner_enemy, &"estado"):
		return str(owner_enemy.get("estado"))
	return ""


func _is_airborne(n: Node) -> bool:
	if n == null:
		return false
	if n.has_method("is_en_el_aire"):
		return bool(n.call("is_en_el_aire"))
	if n.has_method("esta_en_el_aire"):
		return bool(n.call("esta_en_el_aire"))
	if n.has_method("is_airborne"):
		return bool(n.call("is_airborne"))
	if _has_prop(n, &"en_el_aire"):
		return bool(n.get("en_el_aire"))
	return false


func _has_prop(obj: Object, prop: StringName) -> bool:
	for d in obj.get_property_list():
		if d.get("name") == prop:
			return true
	return false
