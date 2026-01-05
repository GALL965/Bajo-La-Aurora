extends Control
class_name DialogBox

@onready var portrait: TextureRect = $DialogPanel/Padding/Row/Portrait
@onready var text_label: RichTextLabel = $DialogPanel/Padding/Row/TextCol/DialogText
@onready var voice_player: AudioStreamPlayer = $DialogPanel/VoicePlayer
signal dialog_finished

var skippable := true
var autoplay := false

var dialog_data: Array = []
var dialog_index := 0
var char_index := 0
var writing := false

@export var text_speed := 0.03
var current_text := ""

func start_dialog(json_path: String, _autoplay := false, _skippable := true) -> void:
	var file := FileAccess.open(json_path, FileAccess.READ)
	if file == null:
		push_error("No se pudo abrir el diálogo")
		return
	
	var parsed = JSON.parse_string(file.get_as_text())
	dialog_data = parsed["conversation"]
	dialog_index = 0

	autoplay = _autoplay
	skippable = _skippable

	show()
	_play_current()


func _play_current() -> void:
	var entry = dialog_data[dialog_index]
	
	current_text = entry["text"]
	char_index = 0

	text_label.text = ""
	writing = true
	
	if entry.has("expression"):
		portrait.texture = load(entry["expression"])
	
	if entry.has("voice"):
		voice_player.stream = load(entry["voice"])

func _process(_delta):
	if writing:
		if char_index < current_text.length():
			text_label.append_text(current_text[char_index])
			char_index += 1
			
			if voice_player.stream:
				voice_player.play()
			
			await get_tree().create_timer(text_speed).timeout
		else:
			writing = false
			if autoplay:
				await get_tree().create_timer(2.0).timeout
				_next()


func _input(event):
	if not skippable:
		return

	if event.is_action_pressed("ui_accept"):
		if writing:
			text_label.text = current_text
			writing = false
		else:
			_next()

func _next():
	dialog_index += 1
	if dialog_index >= dialog_data.size():
		hide()
		emit_signal("dialog_finished")
	else:
		_play_current()
