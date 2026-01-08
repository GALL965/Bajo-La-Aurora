extends Node2D
class_name MagicBeam

@export var damage: float = 40.0
@export var duration: float = 0.35

@onready var area: Area2D = $Area2D
@onready var timer: Timer = $Timer
@onready var sprite: AnimatedSprite2D = $Visual

var _dir: int = 1
var _hit_ids := {}

func setup(direction: int) -> void:
	_dir = direction
	scale.x = direction

func _ready() -> void:
	if sprite.sprite_frames and sprite.sprite_frames.has_animation("default"):
		sprite.play("default")

	
	area.body_entered.connect(_on_body_entered)

	timer.one_shot = true
	timer.wait_time = duration
	timer.timeout.connect(queue_free)
	timer.start()

func _on_body_entered(body: Node) -> void:
	if body == null:
		return

	var id := body.get_instance_id()
	if _hit_ids.has(id):
		return
	_hit_ids[id] = true

	if body.has_method("recibir_dano"):
		body.recibir_dano(damage, self)
