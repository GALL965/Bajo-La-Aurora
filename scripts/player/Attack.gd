extends Node
class_name Attack

@export var damage: float = 10.0
@export var knockback_fuerza: float = 180.0
signal golpe_conectado(body: Node)
signal ataque_ejecutado()


@export var banda_y_suelo: float = 55.0
@export var banda_y_aereo: float = 75.0

@export var tolerancia_altura_suelo: float = 35.0
@export var tolerancia_altura_aereo: float = 60.0

# Combo
@export var combo_max: int = 4
@export var combo_reset_time: float = 0.7

@export var hitbox_start_ratio: float = 0.18
@export var hitbox_end_ratio: float = 0.55
@export var anim_len_min: float = 0.05
@export var anim_len_max: float = 2.5
@export var input_buffer_time: float = 0.20

# rebote auereo
@export var rebote_aereo_habilitado: bool = true
@export var rebote_caida_min: float = 50.0          
@export var rebote_altura_min: float = 35.0        
@export var rebote_altura_max: float = 200.0        
@export var rebote_impulso: float = 600.0           
@export var rebote_requiere_frente: bool = true    
@export var levantar_enemigo_en_rebote: float = 0.0 

var is_attacking: bool = false

var _combo: int = 0
var _combo_time: float = 0.0
var _hit_ids: Dictionary = {}
var _attack_token: int = 0

var _buffered: bool = false
var _buffer_left: float = 0.0

var _modo_rebote_aereo: bool = false

# nodos
@onready var components: Node = get_parent()
@onready var owner_char: Node = components.get_parent()

@onready var vertical: Node = components.get_node_or_null("Vertical")
@onready var sprite: AnimatedSprite2D = owner_char.get_node_or_null("Visual/Sprite")

@onready var hit_area: Area2D = owner_char.get_node_or_null("Golpe") as Area2D
@onready var hitbox_shape: CollisionShape2D = owner_char.get_node_or_null("Golpe/Golpe") as CollisionShape2D

func _ready() -> void:

	if hit_area:
		hit_area.body_entered.connect(_on_Golpe_body_entered)

func process_attack(delta: float) -> void:
	if _combo_time > 0.0:
		_combo_time -= delta
		if _combo_time <= 0.0 and not is_attacking:
			_combo = 0

	if _buffer_left > 0.0:
		_buffer_left -= delta
		if _buffer_left <= 0.0:
			_buffer_left = 0.0
			_buffered = false

func ejecutar_golpe() -> void:
	if is_attacking:
		_buffered = true
		_buffer_left = input_buffer_time
		return

	while true:
		_attack_token += 1
		var token := _attack_token

		var en_aire := _is_airborne()

		var anim := ""
		if en_aire:
			_combo = 0
			anim = "salto"
		else:
			_combo = (_combo % combo_max) + 1
			anim = "golp" + str(_combo)

		_modo_rebote_aereo = _should_rebote_aereo()

		is_attacking = true
		emit_signal("ataque_ejecutado")

		if owner_char and owner_char.get("en_ataque") != null:
			owner_char.en_ataque = true

		_combo_time = combo_reset_time
		_hit_ids.clear()

		if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation(anim):
			sprite.play(anim)

		var anim_len := _get_anim_length(anim)
		var start_t = clamp(anim_len * hitbox_start_ratio, 0.01, anim_len)
		var end_t = clamp(anim_len * hitbox_end_ratio, start_t, anim_len)

		if hitbox_shape:
			hitbox_shape.disabled = true

		await get_tree().create_timer(start_t).timeout
		if token != _attack_token:
			return

		if hitbox_shape:
			hitbox_shape.disabled = false

		_check_overlaps_now()

		await get_tree().create_timer(end_t - start_t).timeout
		if token != _attack_token:
			return

		if hitbox_shape:
			hitbox_shape.disabled = true

		await get_tree().create_timer(max(0.0, anim_len - end_t)).timeout
		if token != _attack_token:
			return

		is_attacking = false
		_modo_rebote_aereo = false

		if owner_char and owner_char.get("en_ataque") != null:
			owner_char.en_ataque = false

		if _buffered and _buffer_left > 0.0:
			_buffered = false
			_buffer_left = 0.0
			continue

		break

func _check_overlaps_now() -> void:
	if not hit_area:
		return
	var bodies := hit_area.get_overlapping_bodies()
	for b in bodies:
		_apply_hit(b)

func _on_Golpe_body_entered(body: Node) -> void:
	_apply_hit(body)

func _apply_hit(body: Node) -> void:
	if not is_attacking:
		return
	if body == null or body == owner_char:
		return
	if not body.is_in_group("enemigos"):
		return

	var id := body.get_instance_id()
	if _hit_ids.has(id):
		return

	# Banda Y (profundidad)
	var dy = abs(body.global_position.y - owner_char.global_position.y)
	var banda := banda_y_suelo
	if _is_airborne():
		banda = banda_y_aereo
	if dy > banda:
		return

	if not _modo_rebote_aereo:
		if not _altura_compatible(owner_char, body):
			return
	else:
		var h := _get_altura(owner_char)
		if h < rebote_altura_min or h > rebote_altura_max:
			return
		if rebote_requiere_frente and not _enemigo_al_frente(body):
			return

	_hit_ids[id] = true
	emit_signal("golpe_conectado", body)

	var final_damage := damage
	if _modo_rebote_aereo:
		final_damage *= 1.10


	if _modo_rebote_aereo:
		final_damage *= 1.10

	if body.has_method("recibir_dano"):
		body.call("recibir_dano", final_damage, owner_char)

	if body.has_method("apply_knockback"):
		var dir := 1
		if body.global_position.x < owner_char.global_position.x:
			dir = -1
		body.call("apply_knockback", Vector2(dir * knockback_fuerza, 0.0))

		if vertical and vertical.has_method("bounce"):
			vertical.call("bounce", rebote_impulso)

		if levantar_enemigo_en_rebote > 0.0:
			_try_knock_up(body, levantar_enemigo_en_rebote)

func _try_knock_up(target: Node, power: float) -> void:
	if target == null:
		return
	if target.has_method("knock_up"):
		target.call("knock_up", power)
		return
	var can_set := (target.get("velocidad_salto") != null and target.get("en_el_aire") != null)
	if can_set:
		var vs = target.get("velocidad_salto")
		if typeof(vs) == TYPE_FLOAT or typeof(vs) == TYPE_INT:
			if float(vs) < power:
				target.set("velocidad_salto", power)
			target.set("en_el_aire", true)

func _enemigo_al_frente(body: Node) -> bool:
	var facing_right := true
	var v = owner_char.get("mirando_derecha")
	if typeof(v) == TYPE_BOOL:
		facing_right = v

	if facing_right:
		return body.global_position.x >= owner_char.global_position.x
	else:
		return body.global_position.x <= owner_char.global_position.x

func _altura_compatible(a: Node, b: Node) -> bool:
	var ha := _get_altura(a)
	var hb := _get_altura(b)

	var tol := tolerancia_altura_suelo
	if _is_airborne():
		tol = tolerancia_altura_aereo

	return abs(hb - ha) <= tol

func _get_altura(n: Node) -> float:
	if n == null:
		return 0.0
	if n.has_method("get_altura"):
		return float(n.call("get_altura"))
	if n.has_method("get_altura_actual"):
		return float(n.call("get_altura_actual"))
	var v = n.get("altura")
	if typeof(v) == TYPE_FLOAT or typeof(v) == TYPE_INT:
		return float(v)
	return 0.0

func _is_airborne() -> bool:
	if vertical and vertical.has_method("is_en_el_aire"):
		return bool(vertical.call("is_en_el_aire"))
	if vertical and vertical.has_method("is_airborne"):
		return bool(vertical.call("is_airborne"))
	return false

func _should_rebote_aereo() -> bool:
	if not rebote_aereo_habilitado:
		return false
	if not _is_airborne():
		return false

	var vs := 0.0
	if vertical and vertical.has_method("get_velocidad_salto"):
		vs = float(vertical.call("get_velocidad_salto"))
	else:
		var raw = vertical.get("velocidad_salto")
		if typeof(raw) == TYPE_FLOAT or typeof(raw) == TYPE_INT:
			vs = float(raw)

	if vs > -rebote_caida_min:
		return false

	var h := _get_altura(owner_char)
	if h < rebote_altura_min or h > rebote_altura_max:
		return false

	return true

func _get_anim_length(anim_name: String) -> float:
	var default_len := 0.25
	if not sprite or not sprite.sprite_frames:
		return default_len
	if not sprite.sprite_frames.has_animation(anim_name):
		return default_len

	var frames := sprite.sprite_frames.get_frame_count(anim_name)
	var speed := sprite.sprite_frames.get_animation_speed(anim_name)
	if speed <= 0.0:
		return default_len

	return clamp(float(frames) / speed, anim_len_min, anim_len_max)
	
	
func _on_golpe_conectado(_enemigo: Node) -> void:
	if $Audio/golpe:
		$Audio/golpe.play()

func cancel_attack() -> void:
	is_attacking = false

	_combo = 0
	_combo_time = 0.0
	_buffered = false
	_buffer_left = 0.0
	_modo_rebote_aereo = false

	_hit_ids.clear()
	_attack_token += 1

	if hitbox_shape:
		hitbox_shape.disabled = true
