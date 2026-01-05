extends CanvasLayer

# =========================
# Paths asignados en Inspector
# =========================
@export var hp_fill_path: NodePath
@export var mp_fill_path: NodePath
@export var anim_fast_time := 0.12
@export var anim_settle_time := 0.10
@export var overshoot := 0.04  # 4% de rebote

@export var anim_duration: float = 0.25
@export var intro_fade_time := 0.35
@export var intro_blink_count := 2
@export var intro_fill_time := 0.45
@export var hide_mana := true   # <-- para la demo

# =========================
# Nodos
# =========================
@onready var hp_fill: Sprite2D = get_node_or_null(hp_fill_path)
@onready var mp_fill: Sprite2D = get_node_or_null(mp_fill_path)
@onready var root: Control = $MarginContainer
@onready var mp_bar: Node2D = $MarginContainer/VBoxContainer/MPBar

var jugador: Node = null

# =========================
# Estado visual
# =========================
var hp_fill_width: float = 1.0
var mp_fill_width: float = 1.0

var hp_ratio_visual: float = 1.0
var mp_ratio_visual: float = 1.0

var hp_tween: Tween
var mp_tween: Tween


# =========================
# Init
# =========================
func _ready() -> void:
	if not hp_fill:
		push_error("HUD: hp_fill no asignado")
		return

	hp_fill_width = hp_fill.scale.x

	if mp_fill:
		mp_fill_width = mp_fill.scale.x

	# Ocultar mana si no se usa en la demo
	if hide_mana and mp_bar:
		mp_bar.visible = false

	# HUD inicia invisible (intro manual)
	visible = false
	root.modulate.a = 0.0

	# Barras inician vacías visualmente
	hp_ratio_visual = 0.0
	hp_fill.scale.x = 0.001

	if mp_fill:
		mp_ratio_visual = 0.0
		mp_fill.scale.x = 0.001

	# Cache jugador
	var jugadores = get_tree().get_nodes_in_group("jugador")
	if jugadores.size() > 0:
		jugador = jugadores[0]


# =========================
# Loop
# =========================
func _process(_delta: float) -> void:
	if not jugador:
		return

	_actualizar_hp()
	_actualizar_mp()


# =========================
# VIDA
# =========================
func _actualizar_hp() -> void:
	var ratio_objetivo = jugador.hp / jugador.hp_max
	ratio_objetivo = clamp(ratio_objetivo, 0.0, 1.0)

	if is_equal_approx(ratio_objetivo, hp_ratio_visual):
		return

	hp_ratio_visual = ratio_objetivo
	_animar_hp()


func _animar_hp() -> void:
	if is_instance_valid(hp_tween):
		hp_tween.kill()

	var target_scale := hp_fill_width * hp_ratio_visual
	var overshoot_scale := target_scale - (hp_fill_width * overshoot)

	hp_tween = create_tween()
	hp_tween.set_parallel(false)

	# Golpe rápido (caída fuerte)
	hp_tween.tween_property(
		hp_fill,
		"scale:x",
		overshoot_scale,
		anim_fast_time
	).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)

	# Asentado suave (rebote)
	hp_tween.tween_property(
		hp_fill,
		"scale:x",
		target_scale,
		anim_settle_time
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)



# =========================
# MANA
# =========================
func _actualizar_mp() -> void:
	if not jugador.magic:
		return

	if not jugador.magic.has_method("get_mana_actual"):
		return

	var ratio_objetivo = jugador.magic.get_mana_actual() / jugador.magic.get_mana_max()
	ratio_objetivo = clamp(ratio_objetivo, 0.0, 1.0)

	if is_equal_approx(ratio_objetivo, mp_ratio_visual):
		return

	mp_ratio_visual = ratio_objetivo
	_animar_mp()


func _animar_mp() -> void:
	if is_instance_valid(mp_tween):
		mp_tween.kill()

	var target_scale := mp_fill_width * mp_ratio_visual
	var overshoot_scale := target_scale - (mp_fill_width * overshoot)

	mp_tween = create_tween()
	mp_tween.set_parallel(false)

	mp_tween.tween_property(
		mp_fill,
		"scale:x",
		overshoot_scale,
		anim_fast_time
	).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)

	mp_tween.tween_property(
		mp_fill,
		"scale:x",
		target_scale,
		anim_settle_time
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func play_intro() -> void:
	if not jugador:
		return

	visible = true

	# === Parpadeo + fade in ===
	var t := create_tween()
	t.set_parallel(false)

	for i in intro_blink_count:
		t.tween_property(root, "modulate:a", 1.0, intro_fade_time * 0.5)
		t.tween_property(root, "modulate:a", 0.0, intro_fade_time * 0.5)

	t.tween_property(root, "modulate:a", 1.0, intro_fade_time)

	await t.finished

	# === Llenado inicial de vida ===
	var ratio_hp = clamp(jugador.hp / jugador.hp_max, 0.0, 1.0)
	hp_ratio_visual = ratio_hp

	var hp_target = hp_fill_width * ratio_hp
	var t_hp := create_tween()
	t_hp.tween_property(
		hp_fill,
		"scale:x",
		hp_target,
		intro_fill_time
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	await t_hp.finished
