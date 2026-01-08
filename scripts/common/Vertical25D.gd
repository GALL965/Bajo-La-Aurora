extends Node
class_name Vertical25D

@export var visual_path: NodePath
@export var shadow_path: NodePath

@export var gravedad: float = 1600.0
@export var fuerza_salto: float = 800.0
@export var max_altura: float = 650.0

@export var volador: bool = false
@export var altura_base: float = 0.0
@export var fly_lerp: float = 6.0

@export var sombra_scale_min: float = 0.55
@export var sombra_alpha_min: float = 0.35

var altura: float = 0.0
var vel_altura: float = 0.0
var en_el_aire: bool = false

var _visual: Node2D
var _shadow: Node2D
var _visual_base_pos: Vector2 = Vector2.ZERO
var _shadow_base_scale: Vector2 = Vector2.ONE

func _ready() -> void:
	_visual = get_node_or_null(visual_path) as Node2D
	_shadow = get_node_or_null(shadow_path) as Node2D

	if _visual:
		_visual_base_pos = _visual.position
	if _shadow:
		_shadow_base_scale = _shadow.scale

	altura = altura_base
	vel_altura = 0.0
	en_el_aire = volador or altura > 0.001
	_update_visuals()

func request_jump() -> void:
	if volador:
		return
	if altura <= 0.001 and abs(vel_altura) <= 0.001:
		vel_altura = fuerza_salto
		en_el_aire = true

func set_flying(enabled: bool, base_height: float) -> void:
	volador = enabled
	altura_base = base_height
	if volador:
		altura = altura_base
		vel_altura = 0.0
		en_el_aire = true

func force_fall() -> void:
	if volador:
		volador = false

func knock_up(power: float) -> void:
	if power <= 0.0:
		return
	if not volador:
		if power > vel_altura:
			vel_altura = power
		en_el_aire = true

func physics_step(delta: float) -> void:
	if volador:
		altura = lerp(altura, altura_base, clamp(fly_lerp * delta, 0.0, 1.0))
		vel_altura = 0.0
		en_el_aire = true
	else:
		vel_altura -= gravedad * delta
		altura += vel_altura * delta

		if altura <= 0.0:
			altura = 0.0
			vel_altura = 0.0
			en_el_aire = false
		else:
			en_el_aire = true

		if altura > max_altura:
			altura = max_altura
			if vel_altura > 0.0:
				vel_altura = 0.0

	_update_visuals()

func _update_visuals() -> void:
	if _visual:
		_visual.position = _visual_base_pos + Vector2(0.0, -altura)

	if _shadow:
		var t: float = 0.0
		if max_altura > 0.0:
			t = clamp(altura / max_altura, 0.0, 1.0)

		var s: float = lerp(1.0, sombra_scale_min, t)
		_shadow.scale = _shadow_base_scale * Vector2(s, s)

		if _shadow is CanvasItem:
			var c: Color = (_shadow as CanvasItem).modulate
			c.a = lerp(1.0, sombra_alpha_min, t)
			(_shadow as CanvasItem).modulate = c

func get_altura() -> float:
	return altura

func is_airborne() -> bool:
	return en_el_aire or volador
