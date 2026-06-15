extends Node3D

# ============================================================
# WorldHorror.gd — Этап 2 (Хоррор)
# Тот же мир но: без деревни, без замка, жители исчезли,
# Лесной Дух активен, минимальный красный тинт
# ============================================================

add_to_group("world")

var _player: Node3D = null
var _hud: Node = null
var _save_manager: Node
var _audio: Node
var _fourth_wall: Node
var _device_info: Node

func _ready() -> void:
	_save_manager = get_node("/root/SaveManager")
	_audio        = get_node("/root/AudioLayerManager")
	_fourth_wall  = get_node("/root/FourthWall")
	_device_info  = get_node("/root/DeviceInfo")

	# Загружаем HUD
	var hud_scene := preload("res://scenes/ui/HUD.tscn")
	_hud = hud_scene.instantiate()
	add_child(_hud)

	# Загружаем игрока
	var player_scene := preload("res://scenes/player/Player.tscn")
	_player = player_scene.instantiate()
	add_child(_player)

	# Восстанавливаем позицию
	var px: float = _save_manager.get_value("player_pos_x", 0.0)
	var py: float = _save_manager.get_value("player_pos_y", 0.5)
	var pz: float = _save_manager.get_value("player_pos_z", 0.0)
	_player.global_position = Vector3(px, py, pz)

	# Соединяем сигналы
	if _player.has_signal("stats_changed"):
		_player.stats_changed.connect(_on_player_stats_changed)
	if _player.has_signal("died"):
		_player.died.connect(_on_player_died)

	# Хоррор-музыка
	_audio.start_horror()

	# Активируем 4-ю стену
	_fourth_wall.activate()

	# Применяем хоррор-эффекты окружения
	_apply_horror_environment()

	# Проверяем уведомление
	get_node("/root/NotificationManager").check_pending_notification()

func _process(_delta: float) -> void:
	if _player:
		_auto_save_check()

# ============================================================
# Хоррор-окружение
# ============================================================

func _apply_horror_environment() -> void:
	# Туман
	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.05, 0.0, 0.0)
	environment.fog_density = 0.03
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.05, 0.0, 0.0)
	env.environment = environment
	add_child(env)

	# Направленный свет (луна, красноватый)
	var light := DirectionalLight3D.new()
	light.light_color = Color(0.6, 0.3, 0.3)
	light.light_energy = 0.3
	light.rotation_degrees = Vector3(-45.0, 0.0, 0.0)
	add_child(light)

# ============================================================
# Спавн финальной двери
# ============================================================

func spawn_final_door() -> void:
	# Дверь появляется в 50м от игрока в случайном направлении
	if not _player:
		return
	var angle := randf_range(0.0, TAU)
	var dist := 50.0
	var door_pos := _player.global_position + Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)
	# TODO Этап 3: инстанцировать сцену двери
	push_warning("WorldHorror: spawn_final_door @ " + str(door_pos))

# ============================================================
# Автосохранение
# ============================================================

var _autosave_timer := 0.0

func _auto_save_check() -> void:
	_autosave_timer += get_process_delta_time()
	if _autosave_timer >= 60.0:
		_autosave_timer = 0.0
		if _player:
			var pos := _player.global_position
			_save_manager.set_value("player_pos_x", pos.x)
			_save_manager.set_value("player_pos_y", pos.y)
			_save_manager.set_value("player_pos_z", pos.z)
		_save_manager.save_game()

# ============================================================
# Сигналы
# ============================================================

func _on_player_stats_changed(hp: float, max_hp: float, stamina: float, max_st: float, xp: int, level: int) -> void:
	if _hud:
		_hud.update_hp(hp, max_hp)
		_hud.update_stamina(stamina, max_st)
		_hud.update_xp(xp, level)

func _on_player_died() -> void:
	_audio.stop_music()
	get_node("/root/Main").on_player_death()
