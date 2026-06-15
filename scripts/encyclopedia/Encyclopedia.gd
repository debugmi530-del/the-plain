extends Node

# ============================================================
# Encyclopedia.gd — бестиарий
# Разблокировка после первого убийства, живые статы с модификаторами
# ============================================================

const ENEMY_DATA := {
	"goblin": {
		"name": "Гоблин",
		"base_hp": 30,
		"base_damage": 5,
		"base_speed": 4.5,
		"description": "Мелкий, шустрый, смертельный в стае.",
	},
	"skeleton": {
		"name": "Скелет",
		"base_hp": 45,
		"base_damage": 8,
		"base_speed": 3.5,
		"description": "Медленный, но выносливый. Игнорирует страдание.",
	},
	"troll": {
		"name": "Тролль",
		"base_hp": 120,
		"base_damage": 20,
		"base_speed": 2.5,
		"description": "Регенерирует вне боя. Избегай воды.",
	},
	"forest_spirit": {
		"name": "Лесной Дух",
		"base_hp": 25,
		"base_damage": 3,
		"base_speed": 5.0,
		"description": "Появляется только в Этапе 2. Убить можно.",
	},
}

func _ready() -> void:
	pass

# ============================================================
# Получить данные врага с живыми модификаторами
# ============================================================

func get_enemy_entry(enemy_id: String) -> Dictionary:
	if not ENEMY_DATA.has(enemy_id):
		return {}

	var base: Dictionary = ENEMY_DATA[enemy_id].duplicate()
	var sm := get_node("/root/SaveManager")
	var di := get_node("/root/DeviceInfo")
	var enc: Dictionary = sm.get_value("encyclopedia", {})

	# Добавляем статистику убийств
	base["kills"]    = enc.get(enemy_id, {}).get("kills", 0)
	base["unlocked"] = enc.get(enemy_id, {}).get("unlocked", false)

	if not base["unlocked"]:
		# Возвращаем скрытую запись
		return {
			"name": "???",
			"kills": 0,
			"unlocked": false,
			"description": "Убейте это существо, чтобы узнать о нём больше.",
		}

	# Живые модификаторы от времени суток / батареи
	var mod := di.get_enemy_modifier()
	base["live_hp"]     = int(float(base["base_hp"]) * mod)
	base["live_damage"] = int(float(base["base_damage"]) * mod)
	base["live_speed"]  = base["base_speed"] * mod

	# Текст о модификаторах для UI
	var mod_notes := []
	if di.is_night():
		mod_notes.append("ночь: скорость +10%")
	if di.is_low_battery():
		mod_notes.append("низкий заряд: сила +15%")
	base["active_modifiers"] = mod_notes

	return base

func get_all_entries() -> Array:
	var result := []
	for id in ENEMY_DATA.keys():
		result.append(get_enemy_entry(id))
	return result

func is_unlocked(enemy_id: String) -> bool:
	var sm := get_node("/root/SaveManager")
	var enc: Dictionary = sm.get_value("encyclopedia", {})
	return enc.get(enemy_id, {}).get("unlocked", false)
