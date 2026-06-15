extends Node

# ============================================================
# HorrorTrigger.gd — управление переходами между стадиями
# ============================================================

signal screamer_started()

const SCREAMER_IMAGE := "res://assets/sprites/ui/screamer.png"
const SCREAMER_SOUND := "res://assets/audio/sfx/screamer.ogg"
const SCREAMER_DURATION := 0.5  # 500 мс

var _screamer_active := false

# ============================================================
# Триггер замка (вход → скример → вылет)
# ============================================================

func trigger_castle_entry() -> void:
	if _screamer_active:
		return
	_screamer_active = true
	emit_signal("screamer_started")
	await _play_screamer()
	await get_tree().create_timer(0.1).timeout
	get_tree().quit()

func _play_screamer() -> void:
	# FIX: обрываем музыку через audio bus (проверяем что bus существует)
	var music_bus := AudioServer.get_bus_index("Music")
	if music_bus >= 0:
		AudioServer.set_bus_volume_db(music_bus, -80.0)

	# FIX: CanvasLayer как корень оверлея — чтобы отображалось поверх 3D
	var canvas := CanvasLayer.new()
	canvas.layer = 128  # максимальный приоритет
	get_tree().current_scene.add_child(canvas)

	var overlay := ColorRect.new()
	overlay.color = Color.BLACK
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(overlay)

	# Загружаем страшную картинку если есть
	if ResourceLoader.exists(SCREAMER_IMAGE):
		var texture_rect := TextureRect.new()
		texture_rect.texture = load(SCREAMER_IMAGE)
		texture_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		texture_rect.stretch_mode = TextureRect.STRETCH_SCALE
		overlay.add_child(texture_rect)
	else:
		# Fallback: белый экран с красным текстом
		overlay.color = Color.WHITE
		var lbl := Label.new()
		lbl.text = "."
		lbl.add_theme_color_override("font_color", Color.RED)
		lbl.add_theme_font_size_override("font_size", 200)
		lbl.set_anchors_preset(Control.PRESET_CENTER)
		overlay.add_child(lbl)

	# Громкий звук
	if ResourceLoader.exists(SCREAMER_SOUND):
		var audio := AudioStreamPlayer.new()
		audio.stream = load(SCREAMER_SOUND)
		audio.volume_db = 6.0
		canvas.add_child(audio)
		audio.play()

	await get_tree().create_timer(SCREAMER_DURATION).timeout

# ============================================================
# Кнопка "Не нажимай"
# ============================================================

func trigger_do_not_press() -> void:
	var save_manager := get_node("/root/SaveManager")
	# Идемпотентная проверка
	if save_manager.get_value("not_press_pressed", false):
		return

	save_manager.set_value("not_press_pressed", true)
	save_manager.save_game()

	# FIX: убран premare emit_signal("stage_changed", 3)
	# Стадия 3 наступает только при ВХОДЕ в дверь, не при нажатии кнопки

	_show_warning_text()

	var notification_manager := get_node("/root/NotificationManager")
	var delay_sec := randi_range(3600, 7200)  # 1–2 часа
	notification_manager.schedule_return_notification(delay_sec)

func _show_warning_text() -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_center_text"):
		hud.show_center_text("я предупреждала", 3.0)
	else:
		# Если HUD недоступен (например, в главном меню), используем 4th wall
		get_node("/root/FourthWall").trigger_glitch_text("я предупреждала")

# ============================================================
# Финальная дверь
# ============================================================

func spawn_final_door() -> void:
	var world := get_tree().get_first_node_in_group("world")
	if world and world.has_method("spawn_final_door"):
		world.spawn_final_door()

func trigger_final_entry() -> void:
	get_node("/root/Main").trigger_final_stage()

# ============================================================
# Проверка и применение стадии при запуске
# ============================================================

func check_and_apply_stage() -> void:
	var save_manager := get_node("/root/SaveManager")
	if save_manager.get_stage() >= 2:
		_apply_horror_visuals()

func _apply_horror_visuals() -> void:
	# Применяется через WorldHorror.tscn — здесь заглушка
	pass
