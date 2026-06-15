extends Node

# ============================================================
# HorrorTrigger.gd — управление переходами между стадиями
# ============================================================

signal screamer_started()
signal stage_changed(new_stage: int)

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
	# Обрываем звук, вылет
	await get_tree().create_timer(0.1).timeout
	get_tree().quit()

func _play_screamer() -> void:
	# Обрываем текущую музыку
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), -80.0)

	# Создаём оверлей
	var overlay := ColorRect.new()
	overlay.color = Color.BLACK
	overlay.anchors_preset = Control.PRESET_FULL_RECT
	overlay.z_index = 100

	# Загружаем и показываем страшную картинку
	var texture_rect := TextureRect.new()
	if ResourceLoader.exists(SCREAMER_IMAGE):
		texture_rect.texture = load(SCREAMER_IMAGE)
	else:
		# Fallback: белый экран если файл ещё не предоставлен
		overlay.color = Color.WHITE
	texture_rect.anchors_preset = Control.PRESET_FULL_RECT
	texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture_rect.stretch_mode = TextureRect.STRETCH_SCALE
	overlay.add_child(texture_rect)

	# Громкий звук
	if ResourceLoader.exists(SCREAMER_SOUND):
		var audio := AudioStreamPlayer.new()
		audio.stream = load(SCREAMER_SOUND)
		audio.volume_db = 6.0
		overlay.add_child(audio)
		audio.play()

	get_tree().current_scene.add_child(overlay)
	await get_tree().create_timer(SCREAMER_DURATION).timeout

# ============================================================
# Переход в хоррор (вызывается при следующем запуске)
# ============================================================

func check_and_apply_stage() -> void:
	var save_manager := get_node("/root/SaveManager")
	var stage := save_manager.get_stage()
	if stage >= 2:
		_apply_horror_visuals()

func _apply_horror_visuals() -> void:
	# Применяется через WorldHorror.tscn — здесь логика флагов
	pass

# ============================================================
# Кнопка "Не нажимай"
# ============================================================

func trigger_do_not_press() -> void:
	var save_manager := get_node("/root/SaveManager")
	if save_manager.get_value("not_press_pressed", false):
		return  # Уже нажата, игнорируем

	save_manager.set_value("not_press_pressed", true)
	save_manager.save_game()
	emit_signal("stage_changed", 3)

	# Показываем сообщение "я предупреждала"
	_show_warning_text()

	# Планируем уведомление через 1-2 часа
	var notification_manager := get_node("/root/NotificationManager")
	var delay_sec := randi_range(3600, 7200)  # 1-2 часа
	notification_manager.schedule_return_notification(delay_sec)

func _show_warning_text() -> void:
	# Сигнал для HUD чтобы показать текст
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_center_text"):
		hud.show_center_text("я предупреждала", 3.0)

# ============================================================
# Финальная дверь
# ============================================================

func spawn_final_door() -> void:
	var world := get_tree().get_first_node_in_group("world")
	if world and world.has_method("spawn_final_door"):
		world.spawn_final_door()

func trigger_final_entry() -> void:
	# Финальная последовательность
	var main := get_node("/root/Main")
	main.trigger_final_stage()
