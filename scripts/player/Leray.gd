extends CharacterBody2D

var mirando_derecha: bool = true
var en_ataque: bool = false

@onready var golpe_shape: CollisionShape2D = $Golpe/Golpe
@onready var sprite: AnimatedSprite2D = $Visual/Sprite

# =========================
# Referencias Componentes
# =========================
@onready var magic: MagicCaster = $Components/MagicCaster

@onready var movement: PlayerMovement = $PlayerMovement
@onready var vertical: VerticalPlayer = $Components/Vertical
@onready var dash: Dash = $Components/Dash
@onready var attack: Attack = $Components/Attack

# =========================
# COMBATE (mínimo)
# =========================
@export var hp_max: float = 100.0
var hp: float = 100.0
var invulnerable: bool = false
var golpe_offset_x: float = 0.0

# --- ESTADOS (animación) ---
var en_damage: bool = false
var en_dash: bool = false
var en_salto: bool = false


# =========================
# Config
# =========================
@export var gravedad_suelo: float = 0.0

# =========================
# Estado
# =========================
var bloqueando_input: bool = false

# =========================
# Ciclo principal
# =========================
func _ready() -> void:
	if attack:
		attack.ataque_ejecutado.connect(_on_ataque_ejecutado)


	add_to_group("jugador")
	hp = hp_max

	if sprite:
		sprite.animation_finished.connect(_on_animation_finished)

	golpe_offset_x = abs(golpe_shape.position.x)

func _physics_process(delta: float) -> void:
	# Estados para animación (se actualizan cada frame)
	en_salto = vertical.is_en_el_aire()
	en_dash = dash.esta_dasheando()
	en_ataque = attack.is_attacking

	_actualizar_animacion()

	# 1) Dash
	dash.process_dash(delta)

	# 2) Movimiento base (si no ataca)
	# 2) Movimiento base (si no ataca y si NO está bloqueado)
	var move_velocity := Vector2.ZERO
	if not bloqueando_input and not attack.is_attacking:
		move_velocity = movement.update_movement(delta)

	# 3) Dash sobreescribe X (solo si NO está bloqueado)
	var dash_velocity := dash.get_velocity()
	if not bloqueando_input and dash_velocity != Vector2.ZERO:
		move_velocity.x = dash_velocity.x


	velocity.x = move_velocity.x
	velocity.y = move_velocity.y

	move_and_slide()

	# 4) Salto visual / eje Z falso
	vertical.process_vertical(delta)

	# 5) Ataque (timers / combo reset)
	attack.process_attack(delta)

	_update_facing()
	z_index = int(global_position.y)

# =========================
# Input
# =========================
func _unhandled_input(event: InputEvent) -> void:
	if bloqueando_input:
		return

	dash.handle_input(event)

	if event.is_action_pressed("attack"):
		attack.ejecutar_golpe()

	if event.is_action_pressed("jump"):
		vertical.start_jump()

# =========================
# Facing
# =========================
func _update_facing() -> void:
	# Opcional: si no quieres que cambie de lado durante un golpe, descomenta:
	# if attack and attack.is_attacking:
	# 	return

	# 1) Si el dash está activo, manda el dash (se siente muy bien en beat em up)
	var dv := dash.get_velocity()
	if dv.x > 0.0:
		if not mirando_derecha:
			_set_facing(true)
		return
	elif dv.x < 0.0:
		if mirando_derecha:
			_set_facing(false)
		return

	# 2) Facing por input (instantáneo)
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

# =========================
# API para enemigos
# =========================
func recibir_dano(cantidad: float, atacante: Node = null, knockback_poder: float = 220.0) -> void:
	if invulnerable:
		return

	hp -= cantidad
	if hp < 0.0:
		hp = 0.0

	en_damage = true
	_play_if_not("damage")

func esta_en_el_aire() -> bool:
	return vertical.is_en_el_aire()

func get_altura_actual() -> float:
	return vertical.get_altura()

# =========================
# Animaciones por prioridad
# =========================
func _actualizar_animacion() -> void:
	# 1. DAMAGE: prioridad absoluta
	if en_damage:
		_play_if_not("damage")
		return

	# 2. ATAQUE: NO TOCAR animación
	# Attack.gd controla completamente los golpes
	if attack and attack.is_attacking:
		return

	# 3. SALTO
	if en_salto:
		_play_if_not("salto")
		return

	# 4. DASH
	if en_dash:
		_play_if_not("dash")
		return

	# 5. IDLE
	_play_if_not("idle")


func _play_if_not(anim: String) -> void:
	if sprite.animation != anim:
		if sprite.sprite_frames and sprite.sprite_frames.has_animation(anim):
			sprite.play(anim)

func _on_animation_finished() -> void:
	var anim := sprite.animation

	if anim == "damage":
		en_damage = false
		

func get_altura() -> float:
	return $Components/Vertical.get_altura()

func esta_dasheando() -> bool:
	return dash.esta_dasheando()


func _on_golpe_conectado(_enemigo: Node) -> void:
	if $Audio/golpe:
		$Audio/golpe.play()
		
func _on_ataque_ejecutado() -> void:
	$Audio/golpe.play()
