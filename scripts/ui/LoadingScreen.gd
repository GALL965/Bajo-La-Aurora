extends CanvasLayer

@onready var anim := $AnimationPlayer
@onready var fade := $Fade

@onready var tip_label := $TipLabel
@onready var progress := $ProgressBar
@onready var tip_timer := Timer.new()


const TIP_INTERVAL := 4.0
var _last_tip_idx := -1


var _tips: PackedStringArray = []

func _ready():
	randomize()
	_load_tips()
	_set_random_tip()
	progress.value = 0

	fade.color.a = 1.0
	anim.play("fade_in")

	tip_timer.wait_time = TIP_INTERVAL
	tip_timer.one_shot = false
	tip_timer.autostart = true
	add_child(tip_timer)
	tip_timer.timeout.connect(_on_tip_timer_timeout)



func _load_tips():
	var path = "res://data/configs/loading_tips.txt"
	if FileAccess.file_exists(path):
		var f = FileAccess.open(path, FileAccess.READ)
		while not f.eof_reached():
			var line = f.get_line().strip_edges()
			if line != "":
				_tips.append(line)

func _set_random_tip():
	if _tips.size() == 0:
		return

	var idx := randi() % _tips.size()
	if _tips.size() > 1:
		while idx == _last_tip_idx:
			idx = randi() % _tips.size()

	_last_tip_idx = idx
	tip_label.text = _tips[idx]



func set_progress(p: float):
	progress.value = clamp(p, 0.0, 100.0)
	
	
func _on_tip_timer_timeout():
	_set_random_tip()
	
	
func play_fade_out():
	anim.play("fade_out")
