extends Node

# ============================================================
# PlayerStats.gd — характеристики персонажа
# XP-формула: 100 × level²
# ============================================================

signal stats_changed(hp: float, max_hp: float, stamina: float, max_st: float, xp: int, level: int)
signal level_up(new_level: int, skill_points_gained: int)
signal died()

const XP_FORMULA_MULTIPLIER := 100  # XP до следующего уровня = 100 × level²
const STAMINA_REGEN_RATE := 20.0    # единиц/сек в покое
const STAMINA_REGEN_DELAY := 1.5    # секунд после трат до начала регена
const STAMINA_SPRINT_COST := 15.0   # единиц/сек при спринте
const STAMINA_ATTACK_COST := 20.0   # за одну атаку

var level: int = 1
var xp: int = 0
var max_xp: int = 100

var base_hp: float = 100.0
var max_hp: float = 100.0
var current_hp: float = 100.0

var base_speed: float = 5.0
var speed: float = 5.0

var base_damage: float = 10.0
var damage: float = 10.0

var armor: float = 0.0          # 0.0–0.9 (90% максимум)
var stamina: float = 100.0
var max_stamina: float = 100.0

var _stamina_regen_timer: float = 0.0
var _is_dead := false

var _skill_upgrades: Dictionary = {}

func _ready() -> void:
	_load_from_save()

func _process(delta: float) -> void:
	_process_stamina(delta)

# ============================================================
# Загрузка из сохранения
# ============================================================

func _load_from_save() -> void:
	var sm := get_node("/root/SaveManager")
	level       = sm.get_value("player_level", 1)
	xp          = sm.get_value("player_xp", 0)
	current_hp  = sm.get_value("player_hp", 100.0)
	stamina     = sm.get_value("player_stamina", 100.0)
	_skill_upgrades = sm.get_value("skill_upgrades", {})
	_recalculate_stats()
	_emit_stats()

func save_to_save() -> void:
	var sm := get_node("/root/SaveManager")
	sm.set_value("player_level", level)
	sm.set_value("player_xp", xp)
	sm.set_value("player_hp", current_hp)
	sm.set_value("player_stamina", stamina)
	sm.set_value("skill_upgrades", _skill_upgrades)

# ============================================================
# XP и уровень
# ============================================================

func add_xp(amount: int) -> void:
	xp += amount
	while xp >= max_xp:
		xp -= max_xp
		_level_up()
	_emit_stats()

func _level_up() -> void:
	level += 1
	max_xp = XP_FORMULA_MULTIPLIER * (level * level)
	var sp := 3  # 3 очка за уровень
	get_node("/root/SaveManager").set_value("skill_points",
		get_node("/root/SaveManager").get_value("skill_points", 0) + sp)
	_recalculate_stats()
	emit_signal("level_up", level, sp)

func _recalculate_stats() -> void:
	max_xp = XP_FORMULA_MULTIPLIER * (level * level)
	# Базовые значения растут с уровнем
	max_hp = base_hp + (level - 1) * 15.0
	speed  = base_speed + (level - 1) * 0.1
	damage = base_damage + (level - 1) * 2.0
	armor  = clamp(float(_skill_upgrades.get("armor_rank", 0)) * 0.1, 0.0, 0.9)
	# Убеждаемся что текущие не превышают максимум
	current_hp = min(current_hp, max_hp)
	stamina    = min(stamina, max_stamina)

# ============================================================
# Урон и лечение
# ============================================================

func take_damage(raw: float) -> void:
	if _is_dead:
		return
	var mitigated := raw * (1.0 - armor)
	current_hp -= mitigated
	current_hp = max(current_hp, 0.0)
	_emit_stats()
	if current_hp <= 0.0:
		_die()

func heal(amount: float) -> void:
	current_hp = min(current_hp + amount, max_hp)
	_emit_stats()

# ============================================================
# Выносливость
# ============================================================

func _process_stamina(delta: float) -> void:
	if _stamina_regen_timer > 0.0:
		_stamina_regen_timer -= delta
		return
	if stamina < max_stamina:
		stamina = min(stamina + STAMINA_REGEN_RATE * delta, max_stamina)
		_emit_stats()

func use_stamina_sprint(delta: float) -> bool:
	var cost := STAMINA_SPRINT_COST * delta
	if stamina < cost:
		return false
	stamina -= cost
	_stamina_regen_timer = STAMINA_REGEN_DELAY
	_emit_stats()
	return true

func use_stamina_attack() -> bool:
	if stamina < STAMINA_ATTACK_COST:
		return false
	stamina -= STAMINA_ATTACK_COST
	_stamina_regen_timer = STAMINA_REGEN_DELAY
	_emit_stats()
	return true

func has_stamina_for_attack() -> bool:
	return stamina >= STAMINA_ATTACK_COST

# ============================================================
# Навыки
# ============================================================

func upgrade_skill(skill_id: String) -> bool:
	var sm := get_node("/root/SaveManager")
	var sp: int = sm.get_value("skill_points", 0)
	if sp <= 0:
		return false
	var rank: int = _skill_upgrades.get(skill_id, 0) + 1
	_skill_upgrades[skill_id] = rank
	sm.set_value("skill_upgrades", _skill_upgrades)
	sm.set_value("skill_points", sp - 1)
	_recalculate_stats()
	_emit_stats()
	return true

# ============================================================
# Смерть
# ============================================================

func _die() -> void:
	if _is_dead:
		return
	_is_dead = true
	emit_signal("died")

# ============================================================
# Утилиты
# ============================================================

func _emit_stats() -> void:
	emit_signal("stats_changed", current_hp, max_hp, stamina, max_stamina, xp, level)

func get_damage_output() -> float:
	# Финальный урон с учётом навыков
	var bonus := float(_skill_upgrades.get("damage_rank", 0)) * 0.15
	return damage * (1.0 + bonus)

func get_speed() -> float:
	var bonus := float(_skill_upgrades.get("speed_rank", 0)) * 0.05
	return speed * (1.0 + bonus)
