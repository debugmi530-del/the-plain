extends Control

# ============================================================
# MainMenu.gd — главное меню
# Первый запуск: ввод имени. Повторный: "Продолжить"
# ============================================================

@onready var _panel_new_game: Control  = $CanvasLayer/PanelNewGame
@onready var _panel_continue: Control  = $CanvasLayer/PanelContinue
@onready var _input_name: LineEdit     = $CanvasLayer/PanelNewGame/VBox/NameInput
@onready var _btn_start: Button        = $CanvasLayer/PanelNewGame/VBox/BtnStart
@onready var _btn_continue: Button     = $CanvasLayer/PanelContinue/VBox/BtnContinue
@onready var _btn_settings: Button     = $CanvasLayer/BtnSettings
@onready var _label_hint: Label        = $CanvasLayer/LabelHint
@onready var _glitch_label: Label      = $CanvasLayer/GlitchLabel
@onready var _btn_donotpress: Button   = $CanvasLayer/BtnDoNotPress

var _save_manager: Node
var _horror_trigger: Node
var _fourth_wall: Node
var _device_info: Node

func _ready() -> void:
	_save_manager   = get_node("/root/SaveManager")
	_horror_trigger = get_node("/root/HorrorTrigger")
	_fourth_wall    = get_node("/root/FourthWall")
	_device_info    = get_node("/root/DeviceInfo")

	_fourth_wall.glitch_triggered.connect(_on_glitch)

	var hero_name := _save_manager.get_hero_name()
	var stage     := _save_manager.get_stage()

	if hero_name.is_empty():
		_show_new_game()
	else:
		_show_continue(hero_name, stage)

	if stage >= 2:
		_apply_horror_tint()
		_fourth_wall.activate()
		_fourth_wall.trigger_contextual_glitches()

	get_node("/root/NotificationManager").check_pending_notification()

# ============================================================
# Отображение панелей
# ============================================================

func _show_new_game() -> void:
	_panel_new_game.visible = true
	_panel_continue.visible = false
	_btn_donotpress.visible = false
	_input_name.grab_focus()
	_label_hint.text = "введи своё имя"

func _show_continue(hero_name: String, stage: int) -> void:
	_panel_new_game.visible = false
	_panel_continue.visible = true
	_btn_donotpress.visible = (stage >= 2)
	_btn_continue.text = "продолжить, " + hero_name

	var deaths := _device_info.get_death_count()
	var kills  := _device_info.get_total_kills()
	_label_hint.text = "смерти: %d  |  убийства: %d" % [deaths, kills]

# ============================================================
# Кнопки
# ============================================================

func _on_btn_start_pressed() -> void:
	var name_text := _input_name.text.strip_edges()
	if name_text.is_empty() or name_text.length() > 20:
		_input_name.modulate = Color.RED
		# FIX: возвращаем цвет через tween
		var tween := create_tween()
		tween.tween_property(_input_name, "modulate", Color.WHITE, 1.0)
		return
	_save_manager.set_hero_name(name_text)
	get_node("/root/Main").trigger_roguelike_stage()

func _on_btn_continue_pressed() -> void:
	get_node("/root/Main").trigger_roguelike_stage()

func _on_btn_settings_pressed() -> void:
	# Открываем оверлей настроек (Этап 4)
	pass

func _on_btn_donotpress_pressed() -> void:
	_btn_donotpress.disabled = true
	_horror_trigger.trigger_do_not_press()

# ============================================================
# Хоррор-модификации (минимальный красный тинт)
# ============================================================

func _apply_horror_tint() -> void:
	var tween := create_tween()
	tween.tween_property(
		$CanvasLayer/BgRect,
		"color",
		Color(0.12, 0.0, 0.0, 1.0),
		2.0
	)

# ============================================================
# Глитч-текст поверх UI
# ============================================================

func _on_glitch(text: String) -> void:
	_glitch_label.text = text
	_glitch_label.modulate.a = 1.0
	_glitch_label.visible = true
	var tween := create_tween()
	tween.tween_property(_glitch_label, "modulate:a", 0.0, randf_range(2.0, 4.0))
	tween.tween_callback(_glitch_label.hide)

func show_center_text(text: String, _duration: float) -> void:
	_on_glitch(text)
