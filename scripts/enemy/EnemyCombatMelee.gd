extends Node
class_name EnemyCombatMelee

signal solicitar_animacion(nombre: String)

@export var rango_melee: float = 72.0
@export var ataque_delay: float = 0.5
@export var ventana_golpe: float = 0.18
@export var banda_y_tolerancia: float = 40.0
@export var diff_alt_tolerancia: float = 60.0

var owner_enemy: Node = null
var jugador: Node = null

var area_hit: Area2D = null
var shape_hit: CollisionShape2D = null

var t_prep: Timer = null
var t_golpe_fin: Timer = null
var t_ataque: Timer = null

var en_rango_cache: bool = false
var puede_atacar: bool = true
var _en_secuencia: bool = false

func setup(enemy: Node, player: Node) -> void:
	owner_enemy = enemy
	jugador = player

	area_hit = owner_enemy.get_node_or_null("Facing/at")
	shape_hit = owner_enemy.get_node_or_null("Facing/at/Hit")
	if shape_hit:
		shape_hit.disabled = true

	t_prep = owner_enemy.get_node_or_null("Timers/PrepTimer")
	t_golpe_fin = owner_enemy.get_node_or_null("Timers/GolpeFinTimer")
	t_ataque = owner_enemy.get_node_or_null("Timers/AtaqueTimer")

	if t_ataque:
		t_ataque.one_shot = false
		t_ataque.autostart = false
		t_ataque.wait_time = ataque_delay

	if t_prep:
		t_prep.timeout.connect(_on_prep_timeout)
	if t_golpe_fin:
		t_golpe_fin.timeout.connect(_on_golpe_fin_timeout)
	if t_ataque:
		t_ataque.timeout.connect(_on_ataque_timeout)

func tick(_delta: float) -> void:
	var en_rango = _en_rango_ataque()

	if en_rango and not en_rango_cache:
		if t_ataque and t_ataque.is_stopped():
			t_ataque.start()
		# ataque inmediato al entrar a rango (se siente mejor en beat em up)
		disparar_ataque_si_corresponde()
	elif (not en_rango) and en_rango_cache:
		if t_ataque and (not t_ataque.is_stopped()):
			t_ataque.stop()

	en_rango_cache = en_rango

func procesar_jugador_detectado() -> void:
	disparar_ataque_si_corresponde()

func disparar_ataque_si_corresponde() -> void:
	if not _en_rango_ataque():
		return
	if not puede_atacar:
		return
	if _en_secuencia:
		return
	if owner_enemy and ("en_anim_damage" in owner_enemy) and bool(owner_enemy.get("en_anim_damage")):
		return
	if owner_enemy and ("en_el_aire" in owner_enemy) and bool(owner_enemy.get("en_el_aire")):
		return

	_iniciar_ataque()

func _iniciar_ataque() -> void:
	_en_secuencia = true
	if owner_enemy:
		owner_enemy.set("estado", "preparando")
		owner_enemy.set("animacion_en_curso", true)

	# Lock Y justo al atacar
	var mv = owner_enemy.get_node_or_null("Movement")
	if mv and mv.has_method("activar_lock_melee"):
		mv.call("activar_lock_melee", float(jugador.position.y))

	emit_signal("solicitar_animacion", "prep")
	if t_prep:
		t_prep.start()

func _on_prep_timeout() -> void:
	if not _en_secuencia:
		return
	if owner_enemy:
		owner_enemy.set("estado", "atacando")

	emit_signal("solicitar_animacion", "golpe")
	_activar_hitbox()
	resolver_golpe()

	if t_golpe_fin:
		t_golpe_fin.start(ventana_golpe)

func _on_golpe_fin_timeout() -> void:
	_desactivar_hitbox()
	_fin_ataque()

func _on_ataque_timeout() -> void:
	disparar_ataque_si_corresponde()

func cancelar_ataque_en_curso() -> void:
	_en_secuencia = false
	if t_prep:
		t_prep.stop()
	if t_golpe_fin:
		t_golpe_fin.stop()
	call_deferred("_desactivar_hitbox")

func _fin_ataque() -> void:
	_en_secuencia = false
	if owner_enemy:
		owner_enemy.set("animacion_en_curso", false)
		owner_enemy.set("estado", "perseguir")

	var mv = owner_enemy.get_node_or_null("Movement")
	if mv and mv.has_method("desactivar_lock_melee"):
		mv.call("desactivar_lock_melee")

func resolver_golpe() -> void:
	if area_hit == null:
		return

	var cuerpos = area_hit.get_overlapping_bodies()
	for body in cuerpos:
		if body == null:
			continue
		if not body.is_in_group("jugador"):
			continue

		# invulnerable (si existe)
		if ("invulnerable" in body) and bool(body.get("invulnerable")):
			continue

		var diff_y = abs(body.global_position.y - owner_enemy.global_position.y)
		if diff_y > banda_y_tolerancia:
			continue

		var alt_p = 0.0
		if body.has_method("get_altura_actual"):
			alt_p = float(body.call("get_altura_actual"))

		var alt_e = 0.0
		if owner_enemy and ("altura" in owner_enemy):
			alt_e = float(owner_enemy.get("altura"))

		if abs(alt_p - alt_e) > diff_alt_tolerancia:
			continue

		var dmg = 10.0
		if owner_enemy and owner_enemy.has_method("get_attack_damage"):
			dmg = float(owner_enemy.call("get_attack_damage"))

		if body.has_method("recibir_dano"):
			body.call("recibir_dano", dmg, owner_enemy, 240.0)

func _activar_hitbox() -> void:
	if shape_hit:
		shape_hit.set_deferred("disabled", false)

func _desactivar_hitbox() -> void:
	if shape_hit:
		shape_hit.set_deferred("disabled", true)

func _en_rango_ataque() -> bool:
	if jugador == null or owner_enemy == null:
		return false

	var dist = owner_enemy.global_position.distance_to(jugador.global_position)
	if dist > rango_melee:
		return false

	var diff_y = abs(jugador.global_position.y - owner_enemy.global_position.y)
	if diff_y > banda_y_tolerancia:
		return false

	var alt_p = 0.0
	if jugador.has_method("get_altura_actual"):
		alt_p = float(jugador.call("get_altura_actual"))

	var alt_e = 0.0
	if "altura" in owner_enemy:
		alt_e = float(owner_enemy.get("altura"))

	if abs(alt_p - alt_e) > diff_alt_tolerancia:
		return false

	return true
