extends Node
class_name MagicCaster

signal mode_changed(active: bool)
signal mana_changed(current: float, max_value: float)
signal spell_cast(spell_id: String)
signal spell_failed(reason: String)

# --- Config general ---
@export var time_scale_magic: float = 0.25
@export var min_runes: int = 2
@export var max_runes: int = 4

# --- Mana ---
@export var mana_max: float = 100.0
@export var mana: float = 100.0
@export var mana_regen_delay: float = 2.0
@export var mana_regen_per_sec: float = 25.0

# --- Referencias ---
@export var hud: MagicHUD
@onready var _hud: MagicHUD = hud
@export var beam_scene: PackedScene

@export var arc_bolt_scene: PackedScene # opcional (si luego creas la escena)

var _in_magic: bool = false
var _sequence: Array[String] = []

var _regen_delay_timer: Timer
var _regen_active: bool = false
@onready var _player := get_parent().get_parent()


class SpellDef:
	var id: String
	var cost: float
	var action: Callable

	func _init(_id: String, _cost: float, _action: Callable) -> void:
		id = _id
		cost = _cost
		action = _action

var _spells: Dictionary = {} # combo_string -> SpellDef

func _ready() -> void:
	set_process_input(true)

	# Timer para delay de regen (auto-creado)
	_regen_delay_timer = Timer.new()
	_regen_delay_timer.one_shot = true
	_regen_delay_timer.wait_time = mana_regen_delay
	add_child(_regen_delay_timer)
	_regen_delay_timer.timeout.connect(_on_regen_delay_timeout)

	_build_spellbook()

	# HUD init
	if _hud and _hud.has_method("set_active"):
		_hud.set_active(false)

	emit_signal("mana_changed", mana, mana_max)

func _exit_tree() -> void:
	# Por seguridad, restaurar time_scale si el nodo se elimina en pleno modo mágico
	if _in_magic:
		Engine.time_scale = 1.0

func _process(delta: float) -> void:
	# Regen gradual
	if _regen_active and mana < mana_max:
		mana = min(mana_max, mana + mana_regen_per_sec * delta)
		emit_signal("mana_changed", mana, mana_max)
		if mana >= mana_max:
			_regen_active = false

func _input(event: InputEvent) -> void:
	# Entrar / salir modo mágico
	if event.is_action_pressed("magic_mode"):
		_enter_magic_mode()
		return

	if event.is_action_released("magic_mode"):
		_exit_magic_mode_and_cast()
		return

	# Captura de runas (solo estando en modo mágico)
	if not _in_magic:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		var r := _rune_from_key(event.keycode)
		if r == "":
			# Extras útiles
			if event.keycode == KEY_BACKSPACE:
				_pop_rune()
				get_viewport().set_input_as_handled()


			elif event.keycode == KEY_ESCAPE:
				_cancel_magic_input()
				get_viewport().set_input_as_handled()


			return

		_push_rune(r)
		get_viewport().set_input_as_handled()


func _enter_magic_mode() -> void:
	if _in_magic:
		return

	_in_magic = true
	_sequence.clear()

	# slow-mo
	Engine.time_scale = time_scale_magic

	# bloquear controles normales del jugador
	if _player and "bloqueando_input" in _player:
		_player.bloqueando_input = true

	# HUD
	if _hud:
		_hud.set_active(true)
		_hud.set_sequence(_sequence)
	else:
		push_warning("MagicCaster: HUD no asignado")

	emit_signal("mode_changed", true)

func _exit_magic_mode_and_cast() -> void:
	if not _in_magic:
		return

	_in_magic = false

	# restaurar tiempo
	Engine.time_scale = 1.0

	# desbloquear jugador
	if _player and "bloqueando_input" in _player:
		_player.bloqueando_input = false

	# apagar HUD
	if _hud:
		if _hud.has_method("set_active"):
			_hud.set_active(false)

	# validar y castear
	_try_cast_sequence()

	_sequence.clear()
	emit_signal("mode_changed", false)

func _try_cast_sequence() -> void:
	if _sequence.size() < min_runes or _sequence.size() > max_runes:
		return

	var combo := "".join(_sequence)
	var def: SpellDef = _spells.get(combo, null)

	if def == null:
		emit_signal("spell_failed", "combo_no_existe")
		return

	if mana < def.cost:
		emit_signal("spell_failed", "sin_mana")
		return

	# pagar mana
	mana = max(0.0, mana - def.cost)
	emit_signal("mana_changed", mana, mana_max)

	# disparar regen con delay si falta mana
	_start_regen_delay_if_needed()

	# ejecutar spell
	def.action.call()

	emit_signal("spell_cast", def.id)

func _start_regen_delay_if_needed() -> void:
	_regen_active = false
	if mana >= mana_max:
		return
	_regen_delay_timer.stop()
	_regen_delay_timer.wait_time = mana_regen_delay
	_regen_delay_timer.start()

func _on_regen_delay_timeout() -> void:
	_regen_active = true

func _cancel_magic_input() -> void:
	_sequence.clear()
	if _hud and _hud.has_method("set_sequence"):
		_hud.set_sequence(_sequence)

func _push_rune(r: String) -> void:
	if _sequence.size() >= max_runes:
		return
	_sequence.append(r)
	if _hud and _hud.has_method("set_sequence"):
		_hud.set_sequence(_sequence)

func _pop_rune() -> void:
	if _sequence.is_empty():
		return
	_sequence.pop_back()
	if _hud and _hud.has_method("set_sequence"):
		_hud.set_sequence(_sequence)

func _rune_from_key(keycode: int) -> String:
	# WASD o IJKL equivalentes
	match keycode:
		KEY_W, KEY_I: return "W"
		KEY_A, KEY_J: return "A"
		KEY_S, KEY_K: return "S"
		KEY_D, KEY_L: return "D"
		_: return ""

func _build_spellbook() -> void:
	_spells["ASDW"] = SpellDef.new(
	"magic_beam",
	30.0,
	Callable(self, "_spell_magic_beam")
)

	_spells["WASD"] = SpellDef.new("arc_bolt", 25.0, Callable(self, "_spell_arc_bolt"))

	# WDAS -> convertir mana en vida
	_spells["WDAS"] = SpellDef.new("mana_to_hp", 15.0, Callable(self, "_spell_mana_to_hp"))


func _spell_arc_bolt() -> void:
	if arc_bolt_scene == null:
		return

	var inst := arc_bolt_scene.instantiate()
	get_tree().current_scene.add_child(inst)

	var dir := Vector2.RIGHT
	if _player and "mirando_derecha" in _player and not _player.mirando_derecha:
		dir = Vector2.LEFT

	inst.global_position = _player.global_position + Vector2(dir.x * 48.0, -18.0)

	if inst.has_method("setup"):
		inst.setup(dir, 18.0, 260.0)

func _spell_mana_to_hp() -> void:
	if _player == null:
		return
	if not ("hp" in _player and "hp_max" in _player):
		return

	var heal := 20.0
	_player.hp = min(_player.hp_max, _player.hp + heal)


func _spell_magic_beam() -> void:
	print("CAST MAGIC BEAM")
	if beam_scene == null:
		push_warning("MagicBeam scene not assigned")
		return

	var beam: MagicBeam = beam_scene.instantiate()
	get_tree().current_scene.add_child(beam)

	var dir := 1
	if _player and "mirando_derecha" in _player and not _player.mirando_derecha:
		dir = -1

	beam.global_position = _player.global_position + Vector2(40 * dir, -20)
	beam.setup(dir)
