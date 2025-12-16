extends Node
class_name Vertical

signal jumped
signal landed

@export var fuerza_salto: float = 800.0
@export var gravedad: float = -1600.0

# Visual
@export var altura_max_visual: float = 220.0
@export var sombra_escala_min: float = 0.45
@export var sombra_alpha_max: float = 0.25
@export var sombra_alpha_min: float = 0.08

var en_el_aire: bool = false
var altura: float = 0.0
var velocidad_salto: float = 0.0
var dash_activo: bool = false

var _base_visual_pos: Vector2
var _base_sombra_pos: Vector2
var _base_sombra_scale: Vector2

@onready var components: Node = get_parent()
@onready var player: Node = components.get_parent()
@onready var visual: Node2D = player.get_node("Visual")
@onready var sombra: Node2D = player.get_node("Sombra")
@onready var dash: Dash = components.get_node_or_null("Dash")

# =========================
# Init
# =========================
func _ready() -> void:
	if dash:
		dash.dash_started.connect(_on_dash_started)
		dash.dash_finished.connect(_on_dash_finished)

	_base_visual_pos = visual.position
	_base_sombra_pos = sombra.position
	_base_sombra_scale = sombra.scale

	_apply_visuals()

# =========================
# Salto
# =========================
func start_jump() -> void:
	if en_el_aire:
		return

	velocidad_salto = fuerza_salto
	en_el_aire = true
	emit_signal("jumped")

# =========================
# Update vertical
# =========================
func process_vertical(delta: float) -> void:
	if not en_el_aire:
		return

	# Gravedad SOLO si no está en dash
	if not dash_activo:
		velocidad_salto += gravedad * delta
		altura += velocidad_salto * delta

	if altura <= 0.0:
		altura = 0.0
		velocidad_salto = 0.0
		en_el_aire = false
		dash_activo = false
		emit_signal("landed")

		if dash and dash.has_method("reset_air_usage"):
			dash.reset_air_usage()

	_apply_visuals()

# =========================
# Visual
# =========================
func _apply_visuals() -> void:
	visual.position = _base_visual_pos + Vector2(0, -altura)

	var t = clamp(altura / altura_max_visual, 0.0, 1.0)
	var escala = lerp(1.0, sombra_escala_min, t)

	sombra.position = _base_sombra_pos
	sombra.scale = _base_sombra_scale * Vector2(escala, escala)

	var c := sombra.modulate
	c.a = lerp(sombra_alpha_max, sombra_alpha_min, t)
	sombra.modulate = c

# =========================
# Estado
# =========================
func get_altura() -> float:
	return altura

func is_en_el_aire() -> bool:
	return en_el_aire

# =========================
# Dash hooks
# =========================
func _on_dash_started() -> void:
	dash_activo = true

func _on_dash_finished() -> void:
	dash_activo = false
