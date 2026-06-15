extends Node

# ============================================================
# FourthWall.gd — механики 4-й стены
# Глючащий текст, реакции на состояние устройства
# ============================================================

signal glitch_triggered(text: String)

const GLITCH_MIN_INTERVAL := 120.0  # 2 минуты
const GLITCH_MAX_INTERVAL := 300.0  # 5 минут
const GLITCH_DURATION_MIN := 2.0
const GLITCH_DURATION_MAX := 4.0

var _glitch_timer := 0.0
var _glitch_interval := 0.0
var _active := false
var _fallback_glitch_pending := false  # Если уведомления отклонены

# Ссылки (устанавливаются из Main)
var _device_info: Node = null

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
	_device_info = get_node("/root/DeviceInfo")

func deactivate() -> void:
	_active = false

# ============================================================
# Публичный API
# ============================================================

func trigger_glitch_text(text: String) -> void:
	emit_signal("glitch_triggered", text)

func trigger_contextual_glitches() -> void:
	# Реакция на состояние устройства
	var di := get_node("/root/DeviceInfo")
	var save_manager := get_node("/root/SaveManager")
	var stage := save_manager.get_stage()

	if stage < 2:
		return

	# Громкость = 0
	if AudioServer.is_bus_mute(AudioServer.get_bus_index("Master")):
		trigger_glitch_text("ты не хочешь слышать — это не изменит того что происходит")
		return

	# Иностранный язык системы
	var locale := OS.get_locale()
	if not locale.begins_with("ru"):
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

	var texts := [
		hero_name,
		"ты убил %d существ" % kill_count,
		"%d запусков" % launch_count,
	]

	# Особый глитч если звук выключен
	if AudioServer.is_bus_mute(AudioServer.get_bus_index("Master")):
		texts.append("громкость выключена — это не поможет")

	var chosen := texts[randi() % texts.size()]
	trigger_glitch_text(chosen)

func _reset_glitch_timer() -> void:
	_glitch_interval = randf_range(GLITCH_MIN_INTERVAL, GLITCH_MAX_INTERVAL)
	_glitch_timer = _glitch_interval

# ============================================================
# Финальная последовательность (стадия 3, у двери)
# ============================================================

func start_final_sequence() -> void:
	var save_manager := get_node("/root/SaveManager")
	var di := get_node("/root/DeviceInfo")
	var model := di.get_model()
	var playtime := di.get_total_playtime_formatted()
	var launch_count := di.get_launch_count()

	var sequence := [
		"[%s]. Я всегда знала." % model,
		"Ты здесь уже %s. Я не выпущу тебя." % playtime,
		"Это твой %d-й запуск. Я ждала каждый раз." % launch_count,
	]

	_play_sequence(sequence, 15.0)

func _play_sequence(texts: Array, interval: float) -> void:
	for i in texts.size():
		await get_tree().create_timer(interval * i).timeout
		trigger_glitch_text(texts[i])

# ============================================================
# Fallback: если уведомления отклонены, глитч при следующем запуске
# ============================================================

func _check_fallback_glitch() -> void:
	var save_manager := get_node("/root/SaveManager")
	if save_manager.get_value("notification_fallback_pending", false):
		save_manager.set_value("notification_fallback_pending", false)
		save_manager.save_game()
		# Показываем глитч-текст поверх экрана при запуске
		await get_tree().create_timer(2.0).timeout
		trigger_glitch_text("пора возвращаться")

func mark_notification_fallback() -> void:
	var save_manager := get_node("/root/SaveManager")
	save_manager.set_value("notification_fallback_pending", true)
	save_manager.save_game()
