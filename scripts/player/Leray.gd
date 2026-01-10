extends CharacterBody2D
class_name Leray

signal hp_changed(hp: float, hp_max: float)
signal died()
var en_cinematica: bool = false

var mirando_derecha: bool = true
var en_ataque: bool = false
var anim_forzada: String = ""

@onready var golpe_shape: CollisionShape2D = $Golpe/Golpe
@onready var sprite: AnimatedSprite2D = $Visual/Sprite
@export var death_restart_delay: float = 2.2
var is_dead: bool = false


@onready var magic: MagicCaster = $Components/MagicCaster
@onready var movement: PlayerMovement = $PlayerMovement
@onready var vertical: VerticalPlayer = $Components/Vertical
@onready var dash: Dash = $Components/Dash
@onready var attack: Attack = $Components/Attack

@onready var dodge_timer: Timer = $Timers/DodgeTimer
@onready var knockback_timer: Timer = $Timers/KnockbackTimer
@onready var death_timer: Timer = $Timers/DeathTimer


@export var hp_max: float = 100.0
var hp: float = 100.0
var invulnerable: bool = false
var golpe_offset_x: float = 0.0

var en_damage: bool = false
var en_dash: bool = false
var en_salto: bool = false

@export var i_frames_time: float = 0.45

@export var knockback_ref_dmg: float = 10.0
@export var knockback_min_mult: float = 0.35
@export var knockback_max_mult: float = 2.0

@export var knockback_duration: float = 0.12
@export var knockback_friction: float = 2600.0 # suaviza el empuje

@export var gravedad_suelo: float = 0.0

#
var bloqueando_input: bool = false
var _lock_damage: bool = false
var _lock_knockback: bool = false

var _en_knockback: bool = false
var _knockback_vel_x: float = 0.0


func _enter_tree() -> void:
	add_to_group("jugador")

func _ready() -> void:
	if attack:
		attack.ataque_ejecutado.connect(_on_ataque_ejecutado)
		
	

	add_to_group("jugador")

	if hp_max == null or float(hp_max) <= 0.0:
		hp_max = 100.0

	hp = hp_max
	emit_signal("hp_changed", hp, hp_max)

	if sprite:
		if sprite.sprite_frames:
			if sprite.sprite_frames.has_animation("damage"):
				sprite.sprite_frames.set_animation_loop("damage", false)
			if sprite.sprite_frames.has_animation("death"):
				sprite.sprite_frames.set_animation_loop("death", false)

		if not sprite.animation_finished.is_connected(_on_animation_finished):
			sprite.animation_finished.connect(_on_animation_finished)

	golpe_offset_x = abs(golpe_shape.position.x)

	if dodge_timer:
		dodge_timer.one_shot = true
		if not dodge_timer.timeout.is_connected(_on_iframes_timeout):
			dodge_timer.timeout.connect(_on_iframes_timeout)

	if knockback_timer:
		knockback_timer.one_shot = true
		if not knockback_timer.timeout.is_connected(_on_knockback_timeout):
			knockback_timer.timeout.connect(_on_knockback_timeout)

	if death_timer:
		death_timer.one_shot = true
		if not death_timer.timeout.is_connected(_on_death_timeout):
			death_timer.timeout.connect(_on_death_timeout)

func _physics_process(delta: float) -> void:
	if is_dead:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	en_salto = vertical.is_en_el_aire()
	en_dash = dash.esta_dasheando()
	en_ataque = attack.is_attacking

	_actualizar_animacion()

	dash.process_dash(delta)

	var move_velocity := Vector2.ZERO
	if not bloqueando_input and not attack.is_attacking:
		move_velocity = movement.update_movement(delta)

	var dash_velocity := dash.get_velocity()
	if not bloqueando_input and dash_velocity != Vector2.ZERO:
		move_velocity.x = dash_velocity.x

	if _en_knockback:
		_knockback_vel_x = move_toward(_knockback_vel_x, 0.0, knockback_friction * delta)
		move_velocity.x = _knockback_vel_x

	velocity.x = move_velocity.x
	velocity.y = move_velocity.y

	move_and_slide()

	vertical.process_vertical(delta)
	attack.process_attack(delta)

	_update_facing()
	z_index = int(global_position.y)


func _unhandled_input(event: InputEvent) -> void:
	if is_dead:
		return
	if bloqueando_input or en_cinematica:
		return

	dash.handle_input(event)

	if event.is_action_pressed("attack"):
		attack.ejecutar_golpe()

	if event.is_action_pressed("jump"):
		vertical.start_jump()




#facing
func _update_facing() -> void:
	if bloqueando_input:
		return

	# 1) Si el dash está activo, manda el dash
	var dv := dash.get_velocity()
	if dv.x > 0.0:
		if not mirando_derecha:
			_set_facing(true)
		return
	elif dv.x < 0.0:
		if mirando_derecha:
			_set_facing(false)
		return

	# 2) Facing por input
	var input_dir := movement.get_input()
	if input_dir.x > 0.0:
		if not mirando_derecha:
			_set_facing(true)
	elif input_dir.x < 0.0:
		if mirando_derecha:
			_set_facing(false)

func _set_facing(derecha: bool) -> void:
	mirando_derecha = derecha
	sprite.flip_h = not derecha

	var sign := 1
	if not derecha:
		sign = -1

	golpe_shape.position.x = golpe_offset_x * sign

# API para enemigos

func recibir_dano(cantidad: float, atacante: Node = null, knockback_poder: float = 220.0) -> void:
	if is_dead:
		return
	if invulnerable:
		return
	if hp <= 0.0:
		return

	HitfxPool.play_fx(global_position + Vector2(0, -30))
	DamagenumberPool.play_damage(cantidad, global_position + Vector2(0, -60))

	hp = max(hp - cantidad, 0.0)
	emit_signal("hp_changed", hp, hp_max)

	en_damage = true
	_lock_damage = true
	_refresh_input_lock()

	if attack:
		attack.cancel_attack()

	$Audio/dano.play()
	_play_if_not("damage")

	invulnerable = true
	if dodge_timer:
		dodge_timer.start(i_frames_time)

	_aplicar_knockback(cantidad, atacante, knockback_poder)

	if hp <= 0.0:
		_die()




func _aplicar_knockback(dmg: float, atacante: Node, knockback_poder: float) -> void:
	var dir_x := 0.0

	if atacante != null and atacante is Node2D:
		dir_x = sign(global_position.x - (atacante as Node2D).global_position.x)
	else:
		dir_x = -1.0 if mirando_derecha else 1.0

	if dir_x == 0.0:
		dir_x = 1.0

	var mult := 1.0
	if knockback_ref_dmg > 0.0:
		mult = clamp(dmg / knockback_ref_dmg, knockback_min_mult, knockback_max_mult)

	var kb_vel := knockback_poder * mult

	_en_knockback = true
	_knockback_vel_x = dir_x * kb_vel

	_lock_knockback = true
	_refresh_input_lock()

	if knockback_timer:
		knockback_timer.start(knockback_duration)

func _on_iframes_timeout() -> void:
	invulnerable = false

func _on_knockback_timeout() -> void:
	_en_knockback = false
	_knockback_vel_x = 0.0
	_lock_knockback = false
	_refresh_input_lock()

func _refresh_input_lock() -> void:
	bloqueando_input = is_dead or _lock_damage or _lock_knockback


func esta_en_el_aire() -> bool:
	return vertical.is_en_el_aire()

func get_altura_actual() -> float:
	return vertical.get_altura()

func _actualizar_animacion() -> void:
	if is_dead:
		_play_if_not("death")
		return

	if anim_forzada != "":
		_play_if_not(anim_forzada)
		return

	if en_damage:
		_play_if_not("damage")
		return

	if attack and attack.is_attacking:
		return

	if en_salto:
		_play_if_not("salto")
		return

	if en_dash:
		_play_if_not("dash")
		return

	_play_if_not("idle")



func _play_if_not(anim: String) -> void:
	if sprite.animation != anim:
		if sprite.sprite_frames and sprite.sprite_frames.has_animation(anim):
			sprite.play(anim)

func _on_animation_finished() -> void:
	var anim := sprite.animation

	if anim == "damage":
		en_damage = false
		_lock_damage = false
		_refresh_input_lock()
		return

	if anim == "death":
		return


func get_altura() -> float:
	return $Components/Vertical.get_altura()

func esta_dasheando() -> bool:
	return dash.esta_dasheando()

func _on_golpe_conectado(_enemigo: Node) -> void:
	if $Audio/golpe:
		$Audio/golpe.play()

func _on_ataque_ejecutado() -> void:
	$Audio/golpe.play()

func set_combat_enabled(enabled: bool) -> void:
	if attack:
		attack.set_process(enabled)
		attack.set_physics_process(enabled)
	
	if not enabled:
		en_ataque = false

func set_input_enabled(enabled: bool) -> void:
	bloqueando_input = not enabled

func force_animation(anim: String) -> void:
	en_cinematica = true
	anim_forzada = anim

	invulnerable = true
	bloqueando_input = true

	en_damage = false
	en_ataque = false
	_lock_damage = false
	_lock_knockback = false
	_en_knockback = false

	if attack:
		attack.cancel_attack()
		attack.set_process(false)
		attack.set_physics_process(false)

	_refresh_input_lock()
	_play_if_not(anim)



func clear_forced_animation() -> void:
	anim_forzada = ""

func end_cinematic_state() -> void:
	en_cinematica = false
	anim_forzada = ""

	invulnerable = false
	bloqueando_input = false

	if attack:
		attack.set_process(true)
		attack.set_physics_process(true)



func mostrar_hit_fx() -> void:
	var fx_scene := preload("res://scenes/fx/HitEffect.tscn")
	var fx := fx_scene.instantiate()

	get_parent().add_child(fx)
	fx.global_position = global_position + Vector2(0, -30)
	fx.rotation = randf_range(-0.2, 0.2)

func _die() -> void:
	if is_dead:
		return

	is_dead = true
	invulnerable = true
	en_cinematica = true

	anim_forzada = ""
	en_damage = false
	en_ataque = false

	_lock_damage = false
	_lock_knockback = false
	_en_knockback = false
	_knockback_vel_x = 0.0
	_refresh_input_lock()

	if attack:
		attack.cancel_attack()
		attack.set_process(false)
		attack.set_physics_process(false)

	if dash:
		dash.set_process(false)
		dash.set_physics_process(false)

	if movement:
		movement.set_process(false)
		movement.set_physics_process(false)

	if vertical:
		vertical.set_process(false)
		vertical.set_physics_process(false)

	if magic:
		magic.set_process(false)
		magic.set_physics_process(false)

	velocity = Vector2.ZERO
	_play_if_not("death")

	emit_signal("died")



func _on_death_timeout() -> void:
	SceneLoader.goto_scene("res://scenes/demo/Gameplay2.tscn")
