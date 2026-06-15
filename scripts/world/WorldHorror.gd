extends Node3D

# ============================================================
# WorldHorror.gd — Этап 2 (Хоррор)
# Тот же мир: без деревни, без замка, Лесной Дух активен
# ============================================================

var _player: Node3D = null
var _player_stats: Node = null
var _hud: Node = null
var _save_manager: Node
var _audio: Node
var _fourth_wall: Node
var _autosave_timer := 0.0

func _ready() -> void:
	# FIX: add_to_group должен вызываться в _ready()
	add_to_group("world")

	_save_manager = get_node("/root/SaveManager")
	_audio        = get_node("/root/AudioLayerManager")
	_fourth_wall  = get_node("/root/FourthWall")

	# HUD
	var hud_scene := preload("res://scenes/ui/HUD.tscn")
	_hud = hud_scene.instantiate()
	add_child(_hud)

	# Игрок
	var player_scene := preload("res://scenes/player/Player.tscn")
	_player = player_scene.instantiate()
	add_child(_player)

	var px: float = _save_manager.get_value("player_pos_x", 0.0)
	var py: float = _save_manager.get_value("player_pos_y", 1.0)
	var pz: float = _save_manager.get_value("player_pos_z", 0.0)
	_player.global_position = Vector3(px, py, pz)

	# FIX: сигналы к PlayerStats (дочерний узел)
	_player_stats = _player.get_node_or_null("PlayerStats")
	if _player_stats:
		if _player_stats.has_signal("stats_changed"):
			_player_stats.stats_changed.connect(_on_player_stats_changed)
		if _player_stats.has_signal("died"):
			_player_stats.died.connect(_on_player_died)

	_audio.start_horror()
	_fourth_wall.activate()
	_apply_horror_environment()
	get_node("/root/NotificationManager").check_pending_notification()

func _process(delta: float) -> void:
	if _player:
		_auto_save_check(delta)

# ============================================================
# Хоррор-окружение
# ============================================================

func _apply_horror_environment() -> void:
	var env_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.05, 0.0, 0.0)
	environment.fog_density = 0.03
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.05, 0.0, 0.0)
	env_node.environment = environment
	add_child(env_node)

	var light := DirectionalLight3D.new()
	light.light_color = Color(0.6, 0.3, 0.3)
	light.light_energy = 0.3
	light.rotation_degrees = Vector3(-45.0, 0.0, 0.0)
	add_child(light)

# ============================================================
# Спавн финальной двери
# ============================================================

func spawn_final_door() -> void:
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

func _auto_save_check(delta: float) -> void:
	_autosave_timer += delta
	if _autosave_timer >= 60.0:
		_autosave_timer = 0.0
		if _player:
			var pos := _player.global_position
			_save_manager.set_value("player_pos_x", pos.x)
			_save_manager.set_value("player_pos_y", pos.y)
			_save_manager.set_value("player_pos_z", pos.z)
		if _player_stats:
			_player_stats.save_to_save()
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
