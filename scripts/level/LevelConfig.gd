extends Resource
class_name LevelConfig

# UI / HUD
@export_group("UI / HUD")
@export var show_hud := true
@export var play_hud_intro := true

@export var hide_mana: bool = true
@export_group("Combat / Player Restrictions")
@export var combat_enabled_on_start: bool = true
@export var allow_attack_on_start: bool = true

@export var emit_hp_on_start: bool = true   # fuerza primer update de HUD

# Intro (secuencia de entrada)

@export_group("Intro")
enum IntroType { NONE, FALL, ANIM_PLAYER }
@export var intro_type: IntroType = IntroType.NONE

# FALL
@export var fall_height: float = 700.0
@export var fall_time: float = 1.0
@export var ground_y: float = 130.0
@export var fall_anim_name: String = "falling"
@export var fallback_fall_anim: String = "salto"

# ANIM_PLAYER (cutscene/intro)
@export var intro_anim_player_path: NodePath
@export var intro_anim_name: String = "intro"

# Post-intro / diálogo
@export var start_dialog_path: String = ""
@export var dialog_autoplay: bool = true
@export var dialog_skippable: bool = false

# =========================
# Spawner
# =========================
@export_group("Spawner")
@export var enable_spawner: bool = true
@export var spawn_initial_delay: float = 10.0
@export var max_enemies_alive: int = 3
@export var spawn_interval_min: float = 2.2
@export var spawn_interval_max: float = 4.6
@export var burst_chance: float = 0.35
@export var burst_delay_min: float = 0.45
@export var burst_delay_max: float = 0.95

# =========================
# Restart / Death
# =========================
@export_group("Restart / Death")
@export var restart_on_death: bool = true
@export var restart_delay: float = 2.2
@export var restart_loading_min_time: float = 1.2
@export var restart_scene_path: String = "" # si vacío: current_scene.scene_file_path

# =========================
# Cámara (límites iniciales)
# =========================
@export_group("Camera")
@export var apply_initial_camera_limits: bool = false
@export var cam_limit_left: float = -100000
@export var cam_limit_right: float = 100000
@export var cam_limit_top: float = -100000
@export var cam_limit_bottom: float = 100000

# =========================
# Fondo estático (opcional)
# =========================
@export_group("Static Background")
@export var use_static_bg: bool = false
@export var static_bg_layer: int = -10
@export var static_bg_texture: Texture2D
@export var static_bg_scale: Vector2 = Vector2.ONE
