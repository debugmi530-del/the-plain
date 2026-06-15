extends Node

# ============================================================
# DeviceInfo.gd — получение данных устройства
# Используется для механик 4-й стены
# ============================================================

signal root_detected()

var _device_model: String = ""
var _is_rooted: bool = false

func _ready() -> void:
	_device_model = _read_model()

# ============================================================
# Данные устройства
# ============================================================

func get_model() -> String:
	if _device_model.is_empty():
		_device_model = _read_model()
	return _device_model

func get_battery_level() -> int:
	# Возвращает 0-100, -1 если недоступно
	if OS.get_name() == "Android":
		# Через Android API (требует плагин для точного значения)
		# Fallback: читаем из системного файла
		var f := FileAccess.open("/sys/class/power_supply/battery/capacity", FileAccess.READ)
		if f:
			var val := f.get_as_text().strip_edges().to_int()
			f.close()
			return val
	return -1

func get_system_hour() -> int:
	return Time.get_time_dict_from_system()["hour"]

func is_night() -> bool:
	var hour := get_system_hour()
	return hour >= 23 or hour < 6

func is_low_battery() -> bool:
	var level := get_battery_level()
	return level != -1 and level < 20

func get_total_playtime_formatted() -> String:
	var sec: float = SaveManager.get_value("total_playtime_sec", 0.0)
	var h := int(sec) / 3600
	var m := (int(sec) % 3600) / 60
	return "%d ч %d мин" % [h, m]

func get_launch_count() -> int:
	return SaveManager.get_value("launch_count", 1)

func get_death_count() -> int:
	return SaveManager.get_value("death_count", 0)

func get_total_kills() -> int:
	return SaveManager.get_value("total_kills", 0)

# ============================================================
# Множители характеристик врагов (стадия 3)
# ============================================================

func get_enemy_modifier() -> float:
	# Возвращает суммарный модификатор силы врагов (1.0 = нет бонуса)
	var modifier := 1.0
	if SaveManager.get_stage() == 3:
		if is_night():
			modifier += 0.10  # +10% ночью
		if is_low_battery():
			modifier += 0.15  # +15% при низком заряде
	return modifier

# ============================================================
# Проверка root (простая GDScript-проверка без плагина)
# ============================================================

func check_root_simple() -> bool:
	var root_paths := [
		"/sbin/su",
		"/system/bin/su",
		"/system/xbin/su",
		"/data/local/xbin/su",
		"/data/local/bin/su",
		"/system/app/Superuser.apk",
	]
	for path in root_paths:
		if FileAccess.file_exists(path):
			_is_rooted = true
			emit_signal("root_detected")
			# Атмосферный элемент — не блокируем игру
			get_node("/root/FourthWall").trigger_glitch_text("я вижу тебя.")
			return true
	return false

func is_rooted() -> bool:
	return _is_rooted

# ============================================================
# Внутренние методы
# ============================================================

func _read_model() -> String:
	var model := OS.get_model_name()
	if model.is_empty() or model == "":
		model = OS.get_name()
	return model
