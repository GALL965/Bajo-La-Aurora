extends CharacterBody2D

var mirando_derecha: bool = true

@onready var golpe_shape: CollisionShape2D = $Golpe/Golpe
# --- COMBATE (mínimo para pruebas) ---
@export var hp_max: float = 100.0
var hp: float = hp_max
var invulnerable: bool = false
var golpe_offset_x: float

# =========================
# Referencias
# =========================
@onready var movement: PlayerMovement = $PlayerMovement
@onready var vertical: Vertical = $Components/Vertical
@onready var dash: Dash = $Components/Dash
@onready var attack: Attack = $Components/Attack

@onready var sprite: AnimatedSprite2D = $Visual/Sprite

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
func _ready():
	add_to_group("jugador") # IMPORTANTE: EnemySenses busca este grupo
	golpe_offset_x = abs(golpe_shape.position.x)
	golpe_offset_x = abs(golpe_shape.position.x)


func _physics_process(delta: float) -> void:
	# 1) Dash (actualiza timers internos)
	dash.process_dash(delta)

	# 2) Movimiento base (suelo)
	var move_velocity := Vector2.ZERO
	# Si NO está atacando, puede moverse
	if not attack.is_attacking:
		move_velocity = movement.update_movement(delta)


	# 3) Si está en dash, sobreescribe X
	var dash_velocity := dash.get_velocity()
	if dash_velocity != Vector2.ZERO:
		move_velocity.x = dash_velocity.x

	velocity.x = move_velocity.x
	velocity.y = move_velocity.y

	# 4) Movimiento físico
	move_and_slide()

	# 5) Pseudo-eje vertical (salto visual)
	vertical.process_vertical(delta)

	# 6) Ataques (timers internos / combo reset)
	attack.process_attack(delta)

	# 7) Animación base simple
	_update_animation()
	_update_facing()


# =========================
# Input
# =========================
func _unhandled_input(event: InputEvent) -> void:
	if bloqueando_input:
		return

	# Dash (doble tap A / D)
	dash.handle_input(event)

	# Ataque
	if event.is_action_pressed("attack"):
		attack.ejecutar_golpe()

	# Salto
	if event.is_action_pressed("jump"):
		vertical.start_jump()

# =========================
# Animaciones básicas
# =========================
func _update_animation() -> void:
	if attack.is_attacking:
		return

	if vertical.is_en_el_aire():
		return

	if abs(velocity.x) > 10.0 or abs(velocity.y) > 10.0:
		if sprite.animation != "run":
			if sprite.sprite_frames.has_animation("run"):
				sprite.play("run")
	else:
		if sprite.animation != "idle":
			sprite.play("idle")

# =========================
# Señales
# =========================

func _update_facing() -> void:
	if velocity.x > 5.0 and not mirando_derecha:
		_set_facing(true)
	elif velocity.x < -5.0 and mirando_derecha:
		_set_facing(false)

func _set_facing(derecha: bool) -> void:
	mirando_derecha = derecha

	# Voltear sprite correctamente (SIN escalar)
	sprite.flip_h = not derecha

	# Mover hitbox del golpe
	var sign := 1 if derecha else -1
	golpe_shape.position.x = golpe_offset_x * sign
	

func is_dashing() -> bool:
	return dash.is_dashing


func recibir_dano(cantidad: float, atacante: Node = null, knockback_poder: float = 220.0) -> void:
	if invulnerable:
		return
	hp -= cantidad
	if hp < 0.0:
		hp = 0.0
	# (por ahora solo baja vida; luego metemos anim, i-frames, etc.)

func esta_en_el_aire() -> bool:
	if vertical:
		return vertical.is_en_el_aire()
	return false

func get_altura_actual() -> float:
	if vertical:
		return vertical.get_altura()
	return 0.0
