extends Button

@onready var anim := AnimationPlayer.new()

func _ready():
	add_child(anim)
	_create_anims()
	connect("mouse_entered", _on_hover)
	connect("mouse_exited", _on_exit)

func _on_hover():
	anim.play("hover")

func _on_exit():
	anim.play("idle")

func _create_anims():
	var idle = Animation.new()
	idle.length = 0.1
	idle.track_insert_key(idle.add_track(Animation.TYPE_VALUE), 0, scale)
	anim.add_animation("idle", idle)

	var hover = Animation.new()
	hover.length = 0.15
	var t = hover.add_track(Animation.TYPE_VALUE)
	hover.track_set_path(t, "scale")
	hover.track_insert_key(t, 0.0, Vector2.ONE)
	hover.track_insert_key(t, 0.15, Vector2(1.05, 1.05))
	anim.add_animation("hover", hover)
	
	
