extends CanvasLayer
class_name FadeTransition

@onready var fade: ColorRect = $ColorRect
@onready var anim: AnimationPlayer = $AnimationPlayer


func _ready() -> void:
	layer = 1000
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Estado inicial: transparente
	fade.color.a = 0.0


func fade_out() -> void:
	anim.play("fade_out")

func fade_in() -> void:
	anim.play("fade_in")

func await_fade_out() -> void:
	anim.play("fade_out")
	await anim.animation_finished

func await_fade_in() -> void:
	anim.play("fade_in")
	await anim.animation_finished
