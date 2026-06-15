extends CanvasLayer

# ============================================================
# HUD.gd — интерфейс во время игры
# HP-бар, выносливость, мини-карта, инвентарь, журнал 4-й стены
# ============================================================

add_to_group("hud")

@onready var _hp_bar: ProgressBar       = $HpBar
@onready var _stamina_bar: ProgressBar  = $StaminaBar
@onready var _level_label: Label        = $LevelLabel
@onready var _xp_bar: ProgressBar       = $XpBar
@onready var _glitch_label: Label       = $GlitchLabel
@onready var _pause_overlay: Control    = $PauseOverlay
@onready var _center_text: Label        = $CenterText

var _fourth_wall: Node
var _is_paused := false

func _ready() -> void:
	_fourth_wall = get_node("/root/FourthWall")
	_fourth_wall.glitch_triggered.connect(_on_glitch)
	_fourth_wall.activate()
	_pause_overlay.visible = false
	_glitch_label.visible = false
	_center_text.visible = false

# ============================================================
# Обновление статов
# ============================================================

func update_hp(current: float, max_hp: float) -> void:
	_hp_bar.value = (current / max_hp) * 100.0

func update_stamina(current: float, max_st: float) -> void:
	_stamina_bar.value = (current / max_st) * 100.0

func update_xp(xp: int, level: int) -> void:
	var max_xp := 100 * (level * level)
	_xp_bar.value = (float(xp) / float(max_xp)) * 100.0
	_level_label.text = "ур. %d" % level

# ============================================================
# Пауза
# ============================================================

func toggle_pause() -> void:
	_is_paused = not _is_paused
	_pause_overlay.visible = _is_paused
	get_tree().paused = _is_paused

func _on_btn_resume_pressed() -> void:
	toggle_pause()

func _on_btn_main_menu_pressed() -> void:
	get_tree().paused = false
	get_node("/root/SaveManager").emergency_save()
	get_node("/root/Main").go_to_main_menu()

# ============================================================
# Глитч-текст
# ============================================================

func _on_glitch(text: String) -> void:
	_glitch_label.text = text
	_glitch_label.visible = true
	var tween := create_tween()
	tween.tween_property(_glitch_label, "modulate:a", 0.0, randf_range(2.0, 4.0))
	tween.tween_callback(_glitch_label.hide)

func show_center_text(text: String, duration: float) -> void:
	_center_text.text = text
	_center_text.visible = true
	await get_tree().create_timer(duration).timeout
	_center_text.visible = false
