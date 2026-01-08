extends Node
class_name VerticalPlayer

signal jumped
signal landed
var _body_shape: CollisionShape2D = null


# Dash behavior
@export var atravesar_unidades_en_dash: bool = true
@export var invulnerable_en_dash: bool = true
@export var suspender_caida_en_dash_aereo: bool = true

var _hurtbox_shape: CollisionShape2D = null
var _vel_salto_guardada: float = 0.0


@export var fuerza_salto: float = 800.0
@export var gravedad: float = -1600.0

# Si haces dash en el aire, esto evita “flotar”
@export var gravedad_en_dash_mult: float = 1.0 # 1.0 = normal, 0.7 = cae más lento, 0.0 = flota

# Visual
@export var altura_max_visual: float = 220.0
@export var sombra_escala_min: float = 0.45
@export var sombra_alpha_max: float = 0.25
@export var sombra_alpha_min: float = 0.08

# Colisiones en aire (para pasar por encima de enemigos/jugador)
@export var ignorar_colision_con_unidades_en_aire: bool = true
@export_flags_2d_physics var capas_unidades: int = 0

# (Opcional) altura base para voladores si algún día lo usas en player
@export var altura_base: float = 0.0

var en_el_aire: bool = false
var altura: float = 0.0
var velocidad_salto: float = 0.0
var dash_activo: bool = false

var _base_visual_pos: Vector2
var _base_sombra_pos: Vector2
var _base_sombra_scale: Vector2

var _mask_base: int = 0

@onready var components: Node = get_parent()
@onready var player: CharacterBody2D = components.get_parent() as CharacterBody2D
@onready var visual: Node2D = player.get_node("Visual")
@onready var sombra: Node2D = player.get_node("Sombra")
@onready var dash: Node = components.get_node_or_null("Dash")

func _ready() -> void:
	_body_shape = player.get_node_or_null("CollisionShape2D")

	if dash:
		if dash.has_signal("dash_started"):
			dash.dash_started.connect(_on_dash_started)
		if dash.has_signal("dash_finished"):
			dash.dash_finished.connect(_on_dash_finished)

	_base_visual_pos = visual.position
	_base_sombra_pos = sombra.position
	_base_sombra_scale = sombra.scale

	_mask_base = int(player.collision_mask)

	_apply_visuals()

func start_jump() -> void:
	if en_el_aire:
		return

	velocidad_salto = fuerza_salto
	en_el_aire = true
	_set_unit_collision_enabled(false)
	emit_signal("jumped")

func process_vertical(delta: float) -> void:
	if not en_el_aire:
		return
	
	if dash_activo and suspender_caida_en_dash_aereo:
		_apply_visuals()
		return



	var gmult := 1.0
	if dash_activo:
		gmult = gravedad_en_dash_mult

	velocidad_salto += gravedad * delta * gmult
	altura += velocidad_salto * delta

	if altura <= 0.0:
		altura = 0.0
		velocidad_salto = 0.0
		en_el_aire = false
		dash_activo = false
		_set_unit_collision_enabled(true)
		emit_signal("landed")

		# Si tu Dash tiene esto, resetea el “air usage”
		if dash and dash.has_method("reset_air_usage"):
			dash.reset_air_usage()

	_apply_visuals()

func _apply_visuals() -> void:
	var h := altura_base + altura

	visual.position = _base_visual_pos + Vector2(0, -h)

	var t = clamp(h / altura_max_visual, 0.0, 1.0)
	var escala = lerp(1.0, sombra_escala_min, t)

	sombra.position = _base_sombra_pos
	sombra.scale = _base_sombra_scale * Vector2(escala, escala)

	var c := sombra.modulate
	c.a = lerp(sombra_alpha_max, sombra_alpha_min, t)
	sombra.modulate = c

func _set_unit_collision_enabled(enabled: bool) -> void:
	if not ignorar_colision_con_unidades_en_aire:
		return
	if capas_unidades == 0:
		return

	if enabled:
		player.collision_mask = _mask_base
	else:
		player.collision_mask = _mask_base & ~capas_unidades

func get_altura() -> float:
	return altura_base + altura

func is_en_el_aire() -> bool:
	return en_el_aire

func _on_dash_started() -> void:
	dash_activo = true

	if atravesar_unidades_en_dash and _body_shape:
		_body_shape.disabled = true

	if invulnerable_en_dash and _hurtbox_shape:
		_hurtbox_shape.disabled = true

	if en_el_aire and suspender_caida_en_dash_aereo:
		velocidad_salto = 0.0



func _on_dash_finished() -> void:
	dash_activo = false

	# restaurar colisión
	if atravesar_unidades_en_dash and _body_shape:
		_body_shape.disabled = false

	if invulnerable_en_dash and _hurtbox_shape:
		_hurtbox_shape.disabled = false


func bounce(power: float) -> void:
	if power <= 0.0:
		return

	if not en_el_aire:
		en_el_aire = true
		_set_unit_collision_enabled(false)
		emit_signal("jumped")

	if power > velocidad_salto:
		velocidad_salto = power

	_apply_visuals()


func get_velocidad_salto() -> float:
	return velocidad_salto
