extends Node
class_name PlayerMovement

@export var speed: float = 400.0
@export var acceleration: float = 1200.0
@export var friction: float = 1600.0
@export var permitir_cambio_profundidad_en_aire: bool = true

var velocity: Vector2 = Vector2.ZERO

@onready var player: Node = get_parent()
@onready var vertical: Node = player.get_node_or_null("Components/Vertical")

func get_input() -> Vector2:
	var dir := Vector2.ZERO
	dir.x = Input.get_action_strength("D") - Input.get_action_strength("A")
	dir.y = Input.get_action_strength("S") - Input.get_action_strength("W")

	if not permitir_cambio_profundidad_en_aire and vertical and vertical.get("en_el_aire") == true:
		dir.y = 0.0

	if dir.length_squared() > 0.0:
		return dir.normalized()
	return Vector2.ZERO

func update_movement(delta: float) -> Vector2:
	var input_dir := get_input()
	var target := input_dir * speed

	if input_dir != Vector2.ZERO:
		# Si cambia la dirección en X, girar instantáneo
		if sign(input_dir.x) != sign(velocity.x) and velocity.x != 0.0:
			velocity.x = target.x
		else:
			velocity = velocity.move_toward(target, acceleration * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)

	return velocity
