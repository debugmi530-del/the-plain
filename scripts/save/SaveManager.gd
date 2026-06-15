extends Node

# ============================================================
# SaveManager — система сохранений
# Схема: XOR-шифрование + SHA-256 + монотонная валидация
#        + атомарная запись через temp-файл
# ============================================================

const SAVE_PATH := "user://save.dat"
const SAVE_TMP_PATH := "user://save.tmp"

# XOR-ключ — менять при каждом релизе
const XOR_KEY: PackedByteArray = [0x47, 0x6F, 0x64, 0x6F, 0x74, 0x34, 0x21, 0x21]

# Поля, которые не могут уменьшаться (монотонная валидация)
const MONOTONIC_FIELDS := ["death_count", "launch_count", "total_kills"]
const MONOTONIC_FLOAT_FIELDS := ["total_playtime_sec"]

# Сигналы
signal save_loaded(data: Dictionary)
signal save_reset()

# ---- Состояние ----
var _data: Dictionary = {}
var _loaded := false
var _playtime_timer := 0.0
var _is_running := false

# ============================================================
# Жизненный цикл
# ============================================================

func _ready() -> void:
	set_process(true)

func _process(delta: float) -> void:
	if _is_running and _loaded:
		_playtime_timer += delta
		if _playtime_timer >= 30.0:
			_update_playtime()
			_playtime_timer = 0.0

func start_session() -> void:
	_is_running = true

func stop_session() -> void:
	_is_running = false
	_update_playtime()

# ============================================================
# Загрузка и инициализация
# ============================================================

func load_or_init() -> Dictionary:
	if _loaded:
		return _data
	if FileAccess.file_exists(SAVE_PATH):
		var loaded := _load_from_disk()
		if not loaded.is_empty():
			_data = loaded
			_loaded = true
			_increment_launch_count()
			emit_signal("save_loaded", _data)
			return _data
	# Нет файла или повреждён — новая игра
	_data = _default_save()
	_loaded = true
	_increment_launch_count()
	save_game()
	return _data

func _default_save() -> Dictionary:
	return {
		# Постоянные данные (не сбрасываются при смерти)
		"stage": 1,
		"hero_name": "",
		"death_count": 0,
		"launch_count": 0,
		"total_kills": 0,
		"total_playtime_sec": 0.0,
		"last_save_timestamp": Time.get_unix_time_from_system(),
		"encyclopedia": {},
		"not_press_pressed": false,
		"notification_scheduled": false,
		"notification_timestamp": 0,
		# Данные за забег (сбрасываются при смерти)
		"player_level": 1,
		"player_xp": 0,
		"player_hp": 100,
		"player_stamina": 100,
		"player_damage": 10,
		"player_speed": 5.0,
		"player_armor": 0.0,
		"player_pos_x": 0.0,
		"player_pos_y": 0.0,
		"player_pos_z": 0.0,
		"inventory": {},
		"skills": [],
		"skill_points": 0,
		"skill_upgrades": {},
		"world_seed": randi(),
		"castle_spawned": false,
	}

func _increment_launch_count() -> void:
	_data["launch_count"] = _data.get("launch_count", 0) + 1
	save_game()

# ============================================================
# Сохранение
# ============================================================

func save_game() -> bool:
	if not _loaded:
		return false
	_update_playtime()
	_data["last_save_timestamp"] = Time.get_unix_time_from_system()
	return _write_atomic(_data)

func emergency_save() -> void:
	if not _loaded:
		return
	_update_playtime()
	_data["last_save_timestamp"] = Time.get_unix_time_from_system()
	_write_atomic(_data)

# ============================================================
# Сброс при смерти (только данные за забег)
# ============================================================

func reset_run() -> void:
	if not _loaded:
		return
	var persistent := {
		"stage": _data.get("stage", 1),
		"hero_name": _data.get("hero_name", ""),
		"death_count": _data.get("death_count", 0) + 1,
		"launch_count": _data.get("launch_count", 0),
		"total_kills": _data.get("total_kills", 0),
		"total_playtime_sec": _data.get("total_playtime_sec", 0.0),
		"last_save_timestamp": Time.get_unix_time_from_system(),
		"encyclopedia": _data.get("encyclopedia", {}),
		"not_press_pressed": _data.get("not_press_pressed", false),
		"notification_scheduled": _data.get("notification_scheduled", false),
		"notification_timestamp": _data.get("notification_timestamp", 0),
	}
	var run_defaults := {
		"player_level": 1,
		"player_xp": 0,
		"player_hp": 100,
		"player_stamina": 100,
		"player_damage": 10,
		"player_speed": 5.0,
		"player_armor": 0.0,
		"player_pos_x": 0.0,
		"player_pos_y": 0.0,
		"player_pos_z": 0.0,
		"inventory": {},
		"skills": [],
		"skill_points": 0,
		"skill_upgrades": {},
		"world_seed": randi(),
		"castle_spawned": false,
	}
	_data = persistent.merged(run_defaults)
	save_game()

# ============================================================
# Полный сброс (финал игры)
# ============================================================

func reset_all() -> void:
	_data = {}
	_loaded = false
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	if FileAccess.file_exists(SAVE_TMP_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_TMP_PATH))
	emit_signal("save_reset")

# ============================================================
# Геттеры / Сеттеры
# ============================================================

func get_stage() -> int:
	return _data.get("stage", 1)

func set_stage(s: int) -> void:
	# Стадия может только расти
	if s > _data.get("stage", 1):
		_data["stage"] = s
		save_game()

func get_hero_name() -> String:
	return _data.get("hero_name", "")

func set_hero_name(name: String) -> void:
	_data["hero_name"] = name
	save_game()

func get_value(key: String, default = null) -> Variant:
	return _data.get(key, default)

func set_value(key: String, value: Variant) -> void:
	_data[key] = value

func increment_kills(count: int = 1) -> void:
	_data["total_kills"] = _data.get("total_kills", 0) + count

func add_encyclopedia_entry(enemy_id: String) -> bool:
	var enc: Dictionary = _data.get("encyclopedia", {})
	var was_new := not enc.has(enemy_id)
	if not enc.has(enemy_id):
		enc[enemy_id] = {"kills": 0, "unlocked": true}
	enc[enemy_id]["kills"] = enc[enemy_id].get("kills", 0) + 1
	_data["encyclopedia"] = enc
	return was_new

# ============================================================
# Шифрование / Дешифрование
# ============================================================

func _xor(data: PackedByteArray) -> PackedByteArray:
	var result := data.duplicate()
	for i in result.size():
		result[i] ^= XOR_KEY[i % XOR_KEY.size()]
	return result

# ============================================================
# Чтение с диска
# ============================================================

func _load_from_disk() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return {}
	var payload := file.get_buffer(file.get_length())
	file.close()

	if payload.size() < 32:
		_on_tamper_detected()
		return {}

	var stored_hash := payload.slice(0, 32)
	var encrypted := payload.slice(32)
	var raw := _xor(encrypted)

	if raw.sha256_buffer() != stored_hash:
		_on_tamper_detected()
		return {}

	var json_str := raw.get_string_from_utf8()
	var parsed := JSON.parse_string(json_str)
	if parsed == null or not parsed is Dictionary:
		_on_tamper_detected()
		return {}

	return _validated(parsed)

func _on_tamper_detected() -> void:
	push_warning("SaveManager: обнаружено повреждение или подделка файла — сброс.")

# ============================================================
# Запись на диск (атомарная)
# ============================================================

func _write_atomic(state: Dictionary) -> bool:
	var json_str := JSON.stringify(state)
	var raw := json_str.to_utf8_buffer()
	var hash := raw.sha256_buffer()
	var payload := hash + _xor(raw)

	# Пишем во временный файл
	var tmp := FileAccess.open(SAVE_TMP_PATH, FileAccess.WRITE)
	if not tmp:
		push_error("SaveManager: не удалось открыть tmp-файл")
		return false
	tmp.store_buffer(payload)
	tmp.close()

	# Атомарное переименование
	var dir := DirAccess.open("user://")
	if dir.rename(SAVE_TMP_PATH, SAVE_PATH) != OK:
		push_error("SaveManager: не удалось переименовать tmp -> save.dat")
		return false
	return true

# ============================================================
# Монотонная валидация (счётчики не уменьшаются, стадия не откатывается)
# ============================================================

func _validated(new_state: Dictionary) -> Dictionary:
	if _data.is_empty():
		return new_state
	for field in MONOTONIC_FIELDS:
		if new_state.get(field, 0) < _data.get(field, 0):
			new_state[field] = _data[field]
	for field in MONOTONIC_FLOAT_FIELDS:
		if new_state.get(field, 0.0) < _data.get(field, 0.0):
			new_state[field] = _data[field]
	if new_state.get("stage", 1) < _data.get("stage", 1):
		new_state["stage"] = _data["stage"]
	return new_state

# ============================================================
# Защита от перевода часов
# ============================================================

func _update_playtime() -> void:
	var current_unix := int(Time.get_unix_time_from_system())
	var last_unix: int = _data.get("last_save_timestamp", current_unix)
	var delta := current_unix - last_unix
	# Игнорируем прыжок > суток или назад
	if delta > 0 and delta < 86400:
		_data["total_playtime_sec"] = _data.get("total_playtime_sec", 0.0) + float(delta)
	_data["last_save_timestamp"] = current_unix
