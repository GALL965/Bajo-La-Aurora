extends Node
class_name Attack

@export var damage: float = 12.0
@export var knockback_fuerza: float = 180.0

@export var banda_y_suelo: float = 55.0
@export var banda_y_aereo: float = 75.0
@export var tolerancia_altura_suelo: float = 35.0
@export var tolerancia_altura_aereo: float = 60.0

@export var combo_max: int = 4
@export var combo_reset_time: float = 0.7

@export var hitbox_start_ratio: float = 0.18
@export var hitbox_end_ratio: float = 0.55

var is_attacking: bool = false
var golpe_aereo_activado: bool = false

var _combo: int = 0
var _combo_time: float = 0.0
var _hit_ids: Dictionary = {}
var _attack_token: int = 0

@onready var components: Node = get_parent()
@onready var player: Node = components.get_parent()
@onready var vertical: Node = components.get_node_or_null("Vertical")
@onready var sprite: AnimatedSprite2D = player.get_node_or_null("Visual/Sprite") as AnimatedSprite2D
@onready var hitbox_shape: CollisionShape2D = player.get_node_or_null("Golpe/Golpe") as CollisionShape2D

func _ready() -> void:
	var area := player.get_node_or_null("Golpe")
	if area and area is Area2D:
		area.body_entered.connect(_on_Golpe_body_entered)




func process_attack(delta: float) -> void:
	if _combo_time > 0.0:
		_combo_time -= delta
		if _combo_time <= 0.0 and not is_attacking:
			_combo = 0

func ejecutar_golpe() -> void:
	if is_attacking:
		return

	_attack_token += 1
	var token := _attack_token

	var en_aire := false
	if vertical and vertical.get("en_el_aire") == true:
		en_aire = true

	var anim := ""
	if en_aire:
		anim = "golpe_air"
		golpe_aereo_activado = true
		_combo = 0
	else:
		golpe_aereo_activado = false
		_combo = (_combo % combo_max) + 1
		anim = "golpe" + str(_combo)

	_combo_time = combo_reset_time
	is_attacking = true
	_hit_ids.clear()
	if sprite:
		if sprite.sprite_frames and sprite.sprite_frames.has_animation(anim):
			sprite.play(anim)
		else:
			sprite.play("idle")

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

	await get_tree().create_timer(end_t - start_t).timeout
	if token != _attack_token:
		return
	if hitbox_shape:
		hitbox_shape.disabled = true

	await get_tree().create_timer(max(0.0, anim_len - end_t)).timeout
	if token != _attack_token:
		return

	is_attacking = false

func _get_anim_length(anim_name: String) -> float:
	var default_len := 0.25
	if not sprite:
		return default_len
	if not sprite.sprite_frames:
		return default_len
	if not sprite.sprite_frames.has_animation(anim_name):
		return default_len

	var frames := sprite.sprite_frames.get_frame_count(anim_name)
	var speed := sprite.sprite_frames.get_animation_speed(anim_name)
	if speed <= 0.0:
		return default_len

	var length := float(frames) / speed
	return clamp(length, 0.12, 0.8)

func reset_golpe_aereo() -> void:
	golpe_aereo_activado = false

func _on_Golpe_body_entered(body: Node) -> void:
	if not is_attacking:
		return
	if body == null:
		return

	var id := body.get_instance_id()
	if _hit_ids.has(id):
		return

	# Ajusta este grupo si tu proyecto usa otro nombre
	if not body.is_in_group("enemigos"):
		return

	# 1) Profundidad (carril en Y del suelo)
	var dy = abs(body.global_position.y - player.global_position.y)
	var banda := banda_y_suelo
	var en_aire := false
	if vertical and vertical.get("en_el_aire") == true:
		en_aire = true
		banda = banda_y_aereo
	if dy > banda:
		return

	# 2) Altura simulada
	var alt_player := 0.0
	if vertical:
		alt_player = float(vertical.get("altura"))

	var alt_enemy := 0.0
	if body.has_method("get_altura_actual"):
		alt_enemy = float(body.call("get_altura_actual"))
	elif body.has_method("get_altura"):
		alt_enemy = float(body.call("get_altura"))

	var tol := tolerancia_altura_suelo
	if en_aire:
		tol = tolerancia_altura_aereo
	if abs(alt_enemy - alt_player) > tol:
		return

	_hit_ids[id] = true

	var final_damage := damage
	if golpe_aereo_activado:
		final_damage = damage * 1.2

	if body.has_method("recibir_dano"):
		body.call("recibir_dano", final_damage, player)
	elif body.has_method("take_damage"):
		body.call("take_damage", final_damage, player)

	if body.has_method("apply_knockback"):
		var dir = sign(body.global_position.x - player.global_position.x)
		body.call("apply_knockback", Vector2(dir * knockback_fuerza, 0.0))
