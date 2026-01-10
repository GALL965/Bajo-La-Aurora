extends CharacterBody2D
class_name EnemigoBase

enum VerticalMode { SUELO, VOLANDO }
@export var prob_salto_amenaza: float = 0.015    
@export var prob_salto_espejo: float = 0.35    
@export var aire_altura_min_para_reaccion: float = 40.0
@export var aire_rango_x_para_reaccion: float = 140.0
@export var salto_cooldown: float = 1.2
var _base_visual_pos: Vector2
var _visual_base_scale: Vector2
var _player_dead: bool = false

var _salto_cd_left: float = 0.0
var t_espera: float = 0.0
@export var espera_post_ataque := 0.45
var _facing_right: bool = true
@export var facing_deadzone_x: float = 10.0

@export var vertical_mode: VerticalMode = VerticalMode.SUELO
@export var altura_volando: float = 140.0
@export var bob_amp: float = 0.0
@export var bob_speed: float = 2.2

@export var ignorar_colision_con_unidades_en_aire: bool = true
@export_flags_2d_physics var capas_unidades: int = 0

var _bob_t: float = 0.0
var _mask_base: int = 0



var _hit_base_x: float = 0.0
var _det_base_x: float = 0.0

@onready var hit_shape: CollisionShape2D = $Facing/at/Hit
@onready var det_shape: CollisionShape2D = $Facing/Deteccion/CollisionShape2D

@onready var sprite: AnimatedSprite2D = get_node_or_null("Visual/Sprite") as AnimatedSprite2D


@onready var at_node: Node2D = $Facing/at
@onready var det_node: Node2D = $Facing/Deteccion

@export var velocidad_max: float = 420.0
@export var attack_damage: float = 10.0
@export var ataque_delay: float = 0.5

@export var fuerza_salto: float = 800.0
@export var gravedad: float = -1600.0

var jugador: Node2D = null
var estado: String = "patrulla"
var animacion_en_curso: bool = false
var en_anim_damage: bool = false

var en_el_aire: bool = false
var altura: float = 0.0
var velocidad_salto: float = 0.0

var kb_vel_x: float = 0.0
var kb_time_left: float = 0.0
@export var kb_decay: float = 2200.0

@onready var visual: Node2D = $Visual
@onready var facing: Node2D = $Facing

@onready var senses: EnemySenses = $Senses
@onready var move: EnemyMovement = $Movement
@onready var combat: EnemyCombatMelee = $Combat
@onready var health: EnemyHealth = $Health

@onready var t_muerte: Timer = $Timers/MuerteTimer
@onready var audio_dano: AudioStreamPlayer2D = get_node_or_null("dano")

func _ready() -> void:
	_mask_base = int(collision_mask)

	add_to_group("enemigos")
	add_to_group("enemigos_androides")

	_base_visual_pos = visual.position
	_visual_base_scale = visual.scale
	_visual_base_scale.x = abs(_visual_base_scale.x)

	var cand = get_tree().get_nodes_in_group("jugador")
	if cand.size() > 0:
		jugador = cand[0]

	if jugador:
		if jugador.has_signal("died") and not jugador.died.is_connected(_on_player_died):
			jugador.died.connect(_on_player_died)

		var v = jugador.get_node_or_null("Components/Vertical")
		if v and v.has_signal("jumped"):
			v.jumped.connect(_on_player_jumped)

	senses.setup(self, jugador)
	move.setup(self, jugador)
	combat.ataque_delay = ataque_delay
	combat.setup(self, jugador)
	health.setup(self, jugador)

	senses.jugador_detectado.connect(_on_jugador_detectado)
	combat.solicitar_animacion.connect(_on_solicitar_animacion)
	health.tomar_dano.connect(_on_tomar_dano)
	health.murio.connect(_on_murio)

	if sprite and not sprite.animation_finished.is_connected(_on_sprite_anim_finished):
		sprite.animation_finished.connect(_on_sprite_anim_finished)

	if hit_shape:
		_hit_base_x = abs(hit_shape.position.x)

	if det_shape:
		_det_base_x = abs(det_shape.position.x)

func _physics_process(delta: float) -> void:
	if estado == "esperando":
		t_espera -= delta
		if t_espera <= 0.0:
			estado = "orbitando"

	if health and not health.esta_vivo():
		return

	if _player_dead:
		velocity = Vector2.ZERO
		move_and_slide()
		if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("idle"):
			sprite.play("idle")
		return

	if _salto_cd_left > 0.0:
		_salto_cd_left -= delta

	_process_vertical(delta)

	senses.tick(delta)
	move.tick(delta)
	combat.tick(delta)

	var v := Vector2.ZERO
	if move:
		v = move.get_velocidad_actual()

	if kb_time_left > 0.0:
		v.x = kb_vel_x
		kb_time_left -= delta

		var signo = 0.0
		if kb_vel_x > 0.0:
			signo = 1.0
		elif kb_vel_x < 0.0:
			signo = -1.0

		if signo != 0.0:
			var dec = kb_decay * delta * signo
			kb_vel_x -= dec
			if (signo > 0.0 and kb_vel_x < 0.0) or (signo < 0.0 and kb_vel_x > 0.0):
				kb_vel_x = 0.0

	velocity = v

	if velocity.length() < 8.0:
		velocity = Vector2.ZERO

	if jugador and jugador.has_method("esta_en_el_aire") and bool(jugador.call("esta_en_el_aire")):
		const LAYER_PLAYER := 1 << 1
		collision_mask = _mask_base & ~LAYER_PLAYER
	else:
		collision_mask = _mask_base

	_try_threat_jump(delta)

	move_and_slide()

	_update_anim(v)
	_update_facing()

	z_index = int(global_position.y)


func _process_vertical(delta: float) -> void:
	if vertical_mode == VerticalMode.VOLANDO:
		en_el_aire = true
		velocidad_salto = 0.0

		_bob_t += delta * bob_speed
		altura = altura_volando + sin(_bob_t) * bob_amp

		_set_unit_collision_enabled(false)
		visual.position = _base_visual_pos + Vector2(0.0, -altura)
		return

	# Modo suelo/salto normal
	if not en_el_aire:
		_set_unit_collision_enabled(true)
		visual.position = _base_visual_pos
		return

	velocidad_salto += gravedad * delta
	altura += velocidad_salto * delta

	if altura <= 0.0:
		altura = 0.0
		velocidad_salto = 0.0
		en_el_aire = false
		_set_unit_collision_enabled(true)
	else:
		_set_unit_collision_enabled(false)

	visual.position = _base_visual_pos + Vector2(0.0, -altura)


func _update_anim(v: Vector2) -> void:
	if sprite == null:
		return
	if not health.esta_vivo():
		return
	if en_anim_damage:
		return
	if animacion_en_curso:
		return

	if v.length() > 20.0:
		if sprite.animation != "idle" and sprite.sprite_frames.has_animation("av"):
			sprite.play("idle")
	else:
		if sprite.animation != "idle" and sprite.sprite_frames.has_animation("idle"):
			sprite.play("idle")
			
			
	if hit_shape:
		_hit_base_x = abs(hit_shape.position.x)

	if det_shape:
		_det_base_x = abs(det_shape.position.x)

func recibir_dano(cantidad: float, atacante: Node = null, knockback_poder: float = 260.0) -> void:
	if health:
		health.recibir_dano(cantidad, atacante, knockback_poder)

func apply_knockback(f: Vector2) -> void:
	var dir_x = 0.0
	if f.x > 0.0:
		dir_x = 1.0
	elif f.x < 0.0:
		dir_x = -1.0
	_start_knockback(dir_x, abs(f.x), 0.14)

func _start_knockback(dir_x: float, fuerza: float, dur: float) -> void:
	kb_vel_x = dir_x * fuerza
	kb_time_left = max(dur, 0.0)

func get_altura_actual() -> float:
	return altura

func get_attack_damage() -> float:
	if attack_damage == null:
		return 10.0
	return float(attack_damage)


func get_velocidad_max() -> float:
	return velocidad_max

func _on_jugador_detectado(p: Node2D) -> void:
	if jugador == p and jugador != null:
		return

	jugador = p

	if estado == "patrulla":
		estado = "orbitando"

	if move:
		move.jugador = jugador
	if combat:
		combat.jugador = jugador

	combat.procesar_jugador_detectado()


func _on_solicitar_animacion(nombre: String) -> void:
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation(nombre):
		animacion_en_curso = true
		sprite.play(nombre)


func _on_tomar_dano(cantidad: float, atacante: Node, knockback_poder: float) -> void:
	HitfxPool.play_fx(global_position + Vector2(0, -30))

	DamagenumberPool.play_damage(cantidad, global_position + Vector2(0, -60))




	if audio_dano:
		audio_dano.play()

	en_anim_damage = true
	animacion_en_curso = true

	if sprite and sprite.sprite_frames.has_animation("damage"):
		sprite.play("damage")

	var dir := 0.0
	if atacante and atacante is Node2D:
		dir = 1.0 if atacante.global_position.x < global_position.x else -1.0

	_start_knockback(dir, knockback_poder, 0.18)


func _on_sprite_anim_finished() -> void:
	if sprite == null:
		return

	match sprite.animation:
		"damage":
			en_anim_damage = false
			animacion_en_curso = false
			if health.esta_vivo():
				_play_idle_safe()

		"attack":
			animacion_en_curso = false
			if health.esta_vivo():
				_play_idle_safe()

		"despl":
			animacion_en_curso = false
			if health.esta_vivo():
				_play_idle_safe()



func _on_murio() -> void:
	set_physics_process(false)
	if sprite and sprite.sprite_frames.has_animation("death"):
		sprite.play("death")
	if t_muerte:
		t_muerte.timeout.connect(_on_muerte_timeout)
		t_muerte.start()

func _on_muerte_timeout() -> void:
	queue_free()
	
func _update_facing() -> void:
	if jugador == null:
		return

	# Hysteresis: evita flip-flop cuando estás “encima” del jugador en X
	var dx := jugador.global_position.x - global_position.x

	var derecha := _facing_right
	if abs(dx) > facing_deadzone_x:
		derecha = (dx > 0.0)

	_facing_right = derecha

	var sign := 1.0
	if not derecha:
		sign = -1.0

	# ====== VOLTEO VISUAL (robusto) ======
	# Volteamos el nodo Visual completo (mejor que flip_h del sprite)
	if visual:
		visual.scale = Vector2(_visual_base_scale.x * sign, _visual_base_scale.y)

	# Evita que el sprite “contraflippee” por algún otro ajuste
	if sprite:
		sprite.flip_h = false

	# ====== HITBOXES (NO scale, solo posición) ======
	if hit_shape:
		var p := hit_shape.position
		p.x = _hit_base_x * sign
		hit_shape.position = p

	if det_shape:
		var p2 := det_shape.position
		p2.x = _det_base_x * sign
		det_shape.position = p2



func start_jump() -> void:
	if vertical_mode == VerticalMode.VOLANDO:
		return
	if en_el_aire:
		return
	velocidad_salto = fuerza_salto
	en_el_aire = true
	_set_unit_collision_enabled(false)



func _set_unit_collision_enabled(enabled: bool) -> void:
	if not ignorar_colision_con_unidades_en_aire:
		return
	if capas_unidades == 0:
		return

	if enabled:
		collision_mask = _mask_base
	else:
		collision_mask = _mask_base & ~capas_unidades


func get_altura() -> float:
	return altura


func _try_threat_jump(delta: float) -> void:
	if vertical_mode == VerticalMode.VOLANDO:
		return
	if en_el_aire:
		return
	if _salto_cd_left > 0.0:
		return
	if jugador == null:
		return

	# Solo amenaza si está en “agro” (ajusta si tu estado cambia)
	if estado == "patrulla":
		return

	# Probabilidad por segundo -> convertida por delta
	var p = prob_salto_amenaza * delta
	if randf() < p:
		start_jump()
		_salto_cd_left = salto_cooldown


func _on_player_jumped() -> void:
	if vertical_mode == VerticalMode.VOLANDO:
		return
	if en_el_aire:
		return
	if _salto_cd_left > 0.0:
		return
	if jugador == null:
		return

	# Si el jugador va al aire y yo estoy relativamente alineado en X, intento contestar
	var h := 0.0
	if jugador.has_method("get_altura"):
		h = float(jugador.call("get_altura"))
	elif jugador.has_method("get_altura_actual"):
		h = float(jugador.call("get_altura_actual"))

	if h < aire_altura_min_para_reaccion:
		return

	var dx = abs(jugador.global_position.x - global_position.x)
	if dx > aire_rango_x_para_reaccion:
		return

	if randf() < prob_salto_espejo:
		start_jump()
		_salto_cd_left = salto_cooldown


func puede_atacar() -> bool:
	if not det_node:
		return false

	var bodies = det_node.get_overlapping_bodies()
	return jugador in bodies


func _exit_tree() -> void:
	if Engine.has_singleton("CombatDirector"):
		CombatDirector.release_attack(self)

func _play_idle_safe() -> void:
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("idle"):
		sprite.play("idle")

func play_spawn_animation() -> void:
	if sprite == null:
		return
	if not sprite.sprite_frames:
		return
	if not sprite.sprite_frames.has_animation("despl"):
		return

	animacion_en_curso = true
	sprite.play("despl")


func mostrar_hit_fx() -> void:
	var fx_scene := preload("res://scenes/fx/HitEffect.tscn")
	var fx := fx_scene.instantiate()

	get_parent().add_child(fx)
	fx.global_position = global_position + Vector2(0, -30)
	fx.rotation = randf_range(-0.2, 0.2)


func _on_player_died() -> void:
	_player_dead = true

	if combat and combat.has_method("cancel_attack"):
		combat.call("cancel_attack")

	jugador = null

	if move:
		move.jugador = null
	if combat:
		combat.jugador = null
	if senses:
		senses.jugador = null

	var det_area := det_node as Area2D
	if det_area:
		det_area.set_deferred("monitoring", false)
		det_area.set_deferred("monitorable", false)
