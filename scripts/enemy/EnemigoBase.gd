extends CharacterBody2D
class_name EnemigoBase


enum VerticalMode { SUELO, VOLANDO }

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

# “altura” estilo beat em up
@export var fuerza_salto: float = 800.0
@export var gravedad: float = -1600.0

var jugador: Node2D = null
var estado: String = "patrulla"
var animacion_en_curso: bool = false
var en_anim_damage: bool = false

var en_el_aire: bool = false
var altura: float = 0.0
var velocidad_salto: float = 0.0

# Knockback (solo X)
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

var _base_visual_pos: Vector2

func _ready() -> void:
	_mask_base = int(collision_mask)

	add_to_group("enemigos")
	add_to_group("enemigos_androides")

	_base_visual_pos = visual.position

	var cand = get_tree().get_nodes_in_group("jugador")
	if cand.size() > 0:
		jugador = cand[0]

	senses.setup(self, jugador)
	move.setup(self, jugador)
	combat.ataque_delay = ataque_delay
	combat.setup(self, jugador)
	health.setup(self, jugador)

	senses.jugador_detectado.connect(_on_jugador_detectado)
	combat.solicitar_animacion.connect(_on_solicitar_animacion)
	health.tomar_dano.connect(_on_tomar_dano)
	health.murio.connect(_on_murio)

	if sprite:
		sprite.animation_finished.connect(_on_sprite_anim_finished)


	# IMPORTANTE:
	# NO reescalar Facing aquí. Si lo escalaste en editor, queremos respetarlo.
	# Quita completamente:
	# facing.scale = Vector2(1, 1)
	
	if hit_shape:
		_hit_base_x = abs(hit_shape.position.x)

	if det_shape:
		_det_base_x = abs(det_shape.position.x)



func _physics_process(delta: float) -> void:
	if health and not health.esta_vivo():
		return

	_process_vertical(delta)

	senses.tick(delta)
	move.tick(delta)
	combat.tick(delta)

	var v := Vector2.ZERO
	if move:
		v = move.get_velocidad_actual()

	# Knockback manda en X
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
	
	if jugador and jugador.has_method("esta_en_el_aire") and bool(jugador.call("esta_en_el_aire")):
		# Quita la capa del jugador de tu máscara (AJUSTA ESTE BIT)
		const LAYER_PLAYER := 1 << 1  # si tu Player está en layer 2
		collision_mask = _mask_base & ~LAYER_PLAYER
	else:
		collision_mask = _mask_base

	
	move_and_slide()

	_update_anim(v)
	_update_facing()

	z_index = int(global_position.y)

func _process_vertical(delta: float) -> void:
	# Modo volando: altura fija (con bob opcional) y sin gravedad
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




# --- API para el jugador ---
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
	return attack_damage

func get_velocidad_max() -> float:
	return velocidad_max

# --- Señales internas ---
func _on_jugador_detectado() -> void:
	combat.procesar_jugador_detectado()

func _on_solicitar_animacion(nombre: String) -> void:
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation(nombre):
		sprite.play(nombre)

func _on_tomar_dano(_cantidad: float, atacante: Node, knockback_poder: float) -> void:
	if audio_dano:
		audio_dano.play()

	en_anim_damage = true
	animacion_en_curso = true

	if sprite and sprite.sprite_frames.has_animation("damage"):
		sprite.play("damage")

	# knockback desde el atacante
	var dir = 0.0
	if atacante and atacante is Node2D:
		if atacante.global_position.x < global_position.x:
			dir = 1.0
		else:
			dir = -1.0
	_start_knockback(dir, knockback_poder, 0.18)

func _on_sprite_anim_finished() -> void:
	if sprite == null:
		return

	if sprite.animation == "damage":
		en_anim_damage = false
		animacion_en_curso = false
		if health.esta_vivo() and sprite.sprite_frames.has_animation("idle"):
			sprite.play("idle")

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

	var derecha := true
	if jugador.global_position.x < global_position.x:
		derecha = false

	# Voltear solo el sprite (si existe)
	if sprite:
		sprite.flip_h = not derecha

	var sign := 1.0
	if not derecha:
		sign = -1.0

	# Reflejar hitboxes moviendo sus CollisionShape2D (NO scale)
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
