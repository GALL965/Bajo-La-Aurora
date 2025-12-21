extends CanvasLayer
class_name MagicHUD

@onready var r1: Label = $Runes/R1
@onready var r2: Label = $Runes/R2
@onready var r3: Label = $Runes/R3
@onready var r4: Label = $Runes/R4

func _ready() -> void:
	visible = false


func set_active(active: bool) -> void:
	visible = active
	if not active:
		set_sequence([])


func set_sequence(seq: Array) -> void:
	var slots := [r1, r2, r3, r4]
	for i in range(slots.size()):
		slots[i].text = ""
	for i in range(min(seq.size(), slots.size())):
		slots[i].text = str(seq[i])
