extends Node

# ============================================================
# FourthWall.gd — механики 4-й стены
# Глючащий текст, реакции на состояние устройства
# ============================================================

signal glitch_triggered(text: String)

const GLITCH_MIN_INTERVAL := 120.0
const GLITCH_MAX_INTERVAL := 300.0

var _glitch_timer := 0.0
var _active := false

func _ready() -> void:
	_reset_glitch_timer()
	# Проверка fallback после нажатия "Не нажимай" без уведомлений
	_check_fallback_glitch()

func _process(delta: float) -> void:
	if not _active:
		return
	_glitch_timer -= delta
	if _glitch_timer <= 0.0:
		_fire_random_glitch()
		_reset_glitch_timer()

func activate() -> void:
	_active = true

func deactivate() -> void:
	_active = false

# ============================================================
# Публичный API
# ============================================================

func trigger_glitch_text(text: String) -> void:
	emit_signal("glitch_triggered", text)

func trigger_contextual_glitches() -> void:
	var save_manager := get_node("/root/SaveManager")
	if save_manager.get_stage() < 2:
		return

	# Громкость = 0
	var master_bus := AudioServer.get_bus_index("Master")
	if master_bus >= 0 and AudioServer.is_bus_mute(master_bus):
		trigger_glitch_text("ты не хочешь слышать — это не изменит того что происходит")
		return

	# FIX: убрана неиспользуемая переменная di
	# Иностранный язык системы
	if not OS.get_locale().begins_with("ru"):
		trigger_glitch_text("Интересно. Ты не отсюда.")
		return

# ============================================================
# Случайные глитч-тексты (хоррор, стадия 2+)
# ============================================================

func _fire_random_glitch() -> void:
	var save_manager := get_node("/root/SaveManager")
	var di := get_node("/root/DeviceInfo")
	var hero_name := save_manager.get_hero_name()
	var kill_count := di.get_total_kills()
	var launch_count := di.get_launch_count()

	var texts: Array[String] = []
	if not hero_name.is_empty():
		texts.append(hero_name)
	texts.append("ты убил %d существ" % kill_count)
	texts.append("%d запусков" % launch_count)

	var master_bus := AudioServer.get_bus_index("Master")
	if master_bus >= 0 and AudioServer.is_bus_mute(master_bus):
		texts.append("громкость выключена — это не поможет")

	var chosen := texts[randi() % texts.size()]
	trigger_glitch_text(chosen)

func _reset_glitch_timer() -> void:
	_glitch_timer = randf_range(GLITCH_MIN_INTERVAL, GLITCH_MAX_INTERVAL)

# ============================================================
# Финальная последовательность (стадия 3, у двери)
# ============================================================

func start_final_sequence() -> void:
	var di := get_node("/root/DeviceInfo")
	var model := di.get_model()
	var playtime := di.get_total_playtime_formatted()
	var launch_count := di.get_launch_count()

	var sequence: Array[String] = [
		"%s. Я всегда знала." % model,
		"Ты здесь уже %s. Я не выпущу тебя." % playtime,
		"Это твой %d-й запуск. Я ждала каждый раз." % launch_count,
	]
	_play_sequence(sequence, 15.0)

func _play_sequence(texts: Array[String], interval: float) -> void:
	for i in texts.size():
		await get_tree().create_timer(interval * i).timeout
		trigger_glitch_text(texts[i])

# ============================================================
# Fallback: глитч при следующем запуске если уведомления отклонены
# ============================================================

func _check_fallback_glitch() -> void:
	var save_manager := get_node("/root/SaveManager")
	if not save_manager.get_value("notification_fallback_pending", false):
		return
	save_manager.set_value("notification_fallback_pending", false)
	save_manager.save_game()
	await get_tree().create_timer(2.0).timeout
	trigger_glitch_text("пора возвращаться")

func mark_notification_fallback() -> void:
	var save_manager := get_node("/root/SaveManager")
	save_manager.set_value("notification_fallback_pending", true)
	save_manager.save_game()
