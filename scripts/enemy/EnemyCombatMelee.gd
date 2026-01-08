extends Node
class_name EnemyCombatMelee

signal solicitar_animacion(nombre: String)

@export var debug_hits: bool = false
var director: EnemyCombatDirector
@export var reaccion_al_detectar_min: float = 0.18
@export var reaccion_al_detectar_max: float = 0.32

@export var reaccion_al_entrar_rango_min: float = 0.10
@export var reaccion_al_entrar_rango_max: float = 0.18

@export var prep_time: float = 0.12 # telegraph extra (además del delay)

var _grace_detect_left: float = 0.0
var _grace_range_left: float = 0.0
var _pending_first_strike: bool = false

var _rng := RandomNumberGenerator.new()

@export var rango_melee: float = 92.0
@export var ataque_delay: float = 0.5
@export var ventana_golpe: float = 0.18
@export var banda_y_tolerancia: float = 48.0
@export var diff_alt_tolerancia: float = 60.0

var owner_enemy: Node2D = null
var jugador: Node2D = null

var area_hit: Area2D = null
var shape_hit: CollisionShape2D = null

var t_prep: Timer = null
var t_golpe_fin: Timer = null
var t_ataque: Timer = null

var en_rango_cache: bool = false
var puede_atacar: bool = true
var _en_secuencia: bool = false

var _golpe_activo: bool = false
var _golpeados: Dictionary = {} # instance_id -> true (evita multi-hit en la misma ventana)

func setup(enemy: Node2D, player: Node2D) -> void:
	
	director = CombatDirector
	owner_enemy = enemy
	jugador = player
	_rng.randomize()

	t_prep = owner_enemy.get_node_or_null("Timers/PrepTimer")
	if t_prep:
		t_prep.wait_time = prep_time
	


	area_hit = owner_enemy.get_node_or_null("Facing/at") as Area2D
	shape_hit = owner_enemy.get_node_or_null("Facing/at/Hit") as CollisionShape2D

	if area_hit and not area_hit.body_entered.is_connected(_on_hit_body_entered):
		area_hit.body_entered.connect(_on_hit_body_entered)

	if shape_hit:
		shape_hit.disabled = true

	t_prep = owner_enemy.get_node_or_null("Timers/PrepTimer") as Timer
	t_golpe_fin = owner_enemy.get_node_or_null("Timers/GolpeFinTimer") as Timer
	t_ataque = owner_enemy.get_node_or_null("Timers/AtaqueTimer") as Timer

	if t_ataque:
		t_ataque.one_shot = false
		t_ataque.autostart = false
		t_ataque.wait_time = ataque_delay

	if t_prep and not t_prep.timeout.is_connected(_on_prep_timeout):
		t_prep.timeout.connect(_on_prep_timeout)
	if t_golpe_fin and not t_golpe_fin.timeout.is_connected(_on_golpe_fin_timeout):
		t_golpe_fin.timeout.connect(_on_golpe_fin_timeout)
	if t_ataque and not t_ataque.timeout.is_connected(_on_ataque_timeout):
		t_ataque.timeout.connect(_on_ataque_timeout)

func tick(delta: float) -> void:
	if jugador == null or owner_enemy == null:
		return

	# grace timers
	if _grace_detect_left > 0.0:
		_grace_detect_left -= delta
	if _grace_range_left > 0.0:
		_grace_range_left -= delta

	var en_rango := _en_rango_ataque()

	# Al entrar a rango, NO pegues al instante: dale una fracción de segundo
	if en_rango and not en_rango_cache:
		_grace_range_left = _rng.randf_range(reaccion_al_entrar_rango_min, reaccion_al_entrar_rango_max)
		_pending_first_strike = true

	# Si sale de rango, resetea intención
	if (not en_rango) and en_rango_cache:
		_pending_first_strike = false
		_grace_range_left = 0.0

	# Mientras haya grace, no atacar ni iniciar timer
	var allow := (_grace_detect_left <= 0.0 and _grace_range_left <= 0.0)

	if en_rango:
		# Asegura timer de cadencia
		if allow and t_ataque and t_ataque.is_stopped():
			t_ataque.start()

		# Primer golpe: se consume apenas termina el grace MÁS CERCANO
		if _pending_first_strike and _grace_range_left <= 0.0:
			_pending_first_strike = false
			# Si estoy en rango y quiero atacar, aseguro cupo ANTES del disparo
			if en_rango and not _en_secuencia:
				if director and director.has_method("is_attacker"):
					if not director.call("is_attacker", owner_enemy):
						director.call("request_attack", owner_enemy)

			disparar_ataque_si_corresponde()

	else:
		# Solo detener si REALMENTE salí de rango
		if not en_rango and t_ataque and (not t_ataque.is_stopped()):
			t_ataque.stop()


	en_rango_cache = en_rango


func procesar_jugador_detectado() -> void:
	# Ventana para que el jugador pueda reaccionar al “agro”
	_grace_detect_left = _rng.randf_range(reaccion_al_detectar_min, reaccion_al_detectar_max)
	_pending_first_strike = true


func disparar_ataque_si_corresponde() -> void:
	if jugador == null:
		return
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
		
	# Cupo de ataque: si ya soy atacante, no re-solicitar.
	if director:
		var ok := true

		if director.has_method("is_attacker") and bool(director.call("is_attacker", owner_enemy)):
			ok = true
		elif director.has_method("request_attack"):
			ok = bool(director.call("request_attack", owner_enemy))

		if not ok:
			# Sin cupo: orbitando (no pegado al jugador)
			owner_enemy.set("estado", "orbitando")
			return



	_iniciar_ataque()

func _iniciar_ataque() -> void:
	_en_secuencia = true
	if owner_enemy:
		owner_enemy.set("estado", "preparando")
		owner_enemy.set("animacion_en_curso", true)

	#var mv = owner_enemy.get_node_or_null("Movement")
	#if mv and mv.has_method("activar_lock_melee"):
	#	mv.call("activar_lock_melee", float(jugador.global_position.y))


	emit_signal("solicitar_animacion", "prep")
	if t_prep:
		t_prep.start()

func _on_prep_timeout() -> void:
	if not _en_secuencia:
		return
	if owner_enemy:
		owner_enemy.set("estado", "atacando")

	emit_signal("solicitar_animacion", "attack")

	_golpe_activo = true
	_golpeados.clear()

	_activar_hitbox()
	call_deferred("_resolver_golpe_next_physics")

	if t_golpe_fin:
		t_golpe_fin.start(ventana_golpe)

func _resolver_golpe_next_physics() -> void:
	await get_tree().physics_frame
	resolver_golpe()

func _on_golpe_fin_timeout() -> void:
	_golpe_activo = false
	_desactivar_hitbox()
	_fin_ataque()

func _on_ataque_timeout() -> void:
	disparar_ataque_si_corresponde()

func cancelar_ataque_en_curso() -> void:
	if director:
		director.release_attack(owner_enemy)

	_en_secuencia = false
	_golpe_activo = false
	_golpeados.clear()

	if t_prep:
		t_prep.stop()
	if t_golpe_fin:
		t_golpe_fin.stop()

	call_deferred("_desactivar_hitbox")

func _fin_ataque() -> void:
	if director:
		director.release_attack(owner_enemy)

	_en_secuencia = false
	if owner_enemy:
		owner_enemy.set("animacion_en_curso", false)
		owner_enemy.set("estado", "esperando")
	owner_enemy.set("t_espera", owner_enemy.get("espera_post_ataque"))


	var mv = owner_enemy.get_node_or_null("Movement")
	if mv and mv.has_method("desactivar_lock_melee"):
		mv.call("desactivar_lock_melee")

func resolver_golpe() -> void:
	if area_hit == null:
		return

	var cuerpos = area_hit.get_overlapping_bodies()

	if debug_hits:
		print("[COMBAT] overlaps=", cuerpos.size(),
			" hit_disabled=", (shape_hit.disabled if shape_hit else null),
			" golpe_activo=", _golpe_activo)

	for body in cuerpos:
		_intentar_golpear(body)

func _on_hit_body_entered(body: Node) -> void:
	# Esto ayuda cuando el overlap sucede justo al activar la hitbox
	_intentar_golpear(body)

func _intentar_golpear(body: Node) -> void:
	if not _golpe_activo:
		return
	if body == null:
		return
	if body.get_node_or_null("HitboxArea") == null:
		return


	var id := body.get_instance_id()
	if _golpeados.has(id):
		return

	# invulnerable
	if ("invulnerable" in body) and bool(body.get("invulnerable")):
		return

	# banda Y
	var hurtbox := body.get_node_or_null("HitboxArea") as Area2D
	var y_p = hurtbox.global_position.y if hurtbox else body.global_position.y
	var diff_y = abs(y_p - owner_enemy.global_position.y)
	if diff_y > banda_y_tolerancia:
		if debug_hits:
			print("[COMBAT] rechazado por diff_y=", diff_y)
		return

	# altura fake
	var alt_p = 0.0
	if body.has_method("get_altura_actual"):
		alt_p = float(body.call("get_altura_actual"))

	var alt_e = 0.0
	if owner_enemy and ("altura" in owner_enemy):
		alt_e = float(owner_enemy.get("altura"))

	if abs(alt_p - alt_e) > diff_alt_tolerancia:
		if debug_hits:
			print("[COMBAT] rechazado por diff_alt=", abs(alt_p-alt_e))
		return

	var dmg = 10.0
	if owner_enemy and owner_enemy.has_method("get_attack_damage"):
		dmg = float(owner_enemy.call("get_attack_damage"))

	_golpeados[id] = true

	if debug_hits:
		print("[COMBAT] HIT a jugador. dmg=", dmg)

	if body.has_method("recibir_dano"):
		body.call("recibir_dano", dmg, owner_enemy, 240.0)

func _activar_hitbox() -> void:
	if shape_hit:
		shape_hit.disabled = false

func _desactivar_hitbox() -> void:
	if shape_hit:
		shape_hit.disabled = true
func _en_rango_ataque() -> bool:
	if jugador == null or owner_enemy == null:
		return false

	# X (distancia de melee real)
	var dx = abs(owner_enemy.global_position.x - jugador.global_position.x)
	if dx > rango_melee:
		return false

	# Y por lane (CollisionShape2D) si existe
# Usar pivots, NO collision shapes grandes
	var y_e := owner_enemy.global_position.y
	var y_p := jugador.global_position.y

	var diff_y = abs(y_p - y_e)
	if diff_y > banda_y_tolerancia:
		return false

	# Altura fake (igual que ya tienes)
	var alt_p = 0.0
	if jugador.has_method("get_altura_actual"):
		alt_p = float(jugador.call("get_altura_actual"))
	elif jugador.has_method("get_altura"):
		alt_p = float(jugador.call("get_altura"))

	var alt_e = 0.0
	if "altura" in owner_enemy:
		alt_e = float(owner_enemy.get("altura"))

	if abs(alt_p - alt_e) > diff_alt_tolerancia:
		return false

	return true
