extends CanvasLayer
class_name MagicHUD


@onready var r1 := get_node_or_null("Runes/R1") as Label
@onready var r2 := get_node_or_null("Runes/R2") as Label
@onready var r3 := get_node_or_null("Runes/R3") as Label
@onready var r4 := get_node_or_null("Runes/R4") as Label


func _ready() -> void:
	visible = false


func set_active(active: bool) -> void:
	visible = active
	if not active:
		set_sequence([])


func set_sequence(seq: Array) -> void:
	var slots := [r1, r2, r3, r4]

	for slot in slots:
		if slot:
			slot.text = ""

	for i in range(min(seq.size(), slots.size())):
		if slots[i]:
			slots[i].text = str(seq[i])
