extends Node3D

# ============================================================
# WorldRoguelike.gd — Этап 1 (Рогалик)
# Процедурный мир в чанках 64×64м, 7×7 видимых чанков
# Все механики Этапа 2 — здесь точки расширения
# ============================================================

const CHUNK_SIZE  := 64
const VIEW_RADIUS := 3   # 7×7 видимых чанков (448×448м видимости)

var _player: Node3D = null
var _player_stats: Node = null
var _hud: Node = null
var _save_manager: Node
var _audio: Node
var _device_info: Node

# Чанки: ключ Vector2i → Node3D
var _loaded_chunks: Dictionary = {}
var _world_seed: int = 0
var _autosave_timer := 0.0

func _ready() -> void:
	# FIX: add_to_group должен вызываться в _ready(), не на уровне класса
	add_to_group("world")

	_save_manager = get_node("/root/SaveManager")
	_audio        = get_node("/root/AudioLayerManager")
	_device_info  = get_node("/root/DeviceInfo")

	_world_seed = _save_manager.get_value("world_seed", randi())

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
	var py: float = _save_manager.get_value("player_pos_y", 1.0)
	var pz: float = _save_manager.get_value("player_pos_z", 0.0)
	_player.global_position = Vector3(px, py, pz)

	# FIX: сигналы подключаем к PlayerStats (дочерний узел), а не к корню
	_player_stats = _player.get_node_or_null("PlayerStats")
	if _player_stats:
		if _player_stats.has_signal("stats_changed"):
			_player_stats.stats_changed.connect(_on_player_stats_changed)
		if _player_stats.has_signal("died"):
			_player_stats.died.connect(_on_player_died)
	else:
		push_error("WorldRoguelike: PlayerStats не найден у игрока")

	# Начинаем музыку
	_audio.start_roguelike()

	# Инициализируем начальные чанки
	_update_chunks()

var _last_player_chunk := Vector2i(999, 999)

func _process(delta: float) -> void:
	if _player:
		# FIX: обновляем чанки только при смене чанка игрока
		var current_chunk := _world_to_chunk(_player.global_position)
		if current_chunk != _last_player_chunk:
			_last_player_chunk = current_chunk
			_update_chunks()
		_auto_save_check(delta)

# ============================================================
# Чанк-система (заглушка, полная реализация в Этапе 2)
# ============================================================

func _update_chunks() -> void:
	if not _player:
		return
	var player_chunk := _world_to_chunk(_player.global_position)

	var needed: Dictionary = {}
	for dx in range(-VIEW_RADIUS, VIEW_RADIUS + 1):
		for dz in range(-VIEW_RADIUS, VIEW_RADIUS + 1):
			var coord := Vector2i(player_chunk.x + dx, player_chunk.y + dz)
			needed[coord] = true

	# Выгружаем дальние
	for coord in _loaded_chunks.keys():
		if not needed.has(coord):
			_unload_chunk(coord)

	# Загружаем нужные
	for coord in needed.keys():
		if not _loaded_chunks.has(coord):
			_load_chunk(coord)

func _load_chunk(coord: Vector2i) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _world_seed ^ (coord.x * 7919 + coord.y * 4591)
	var mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(CHUNK_SIZE, CHUNK_SIZE)
	mesh.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(
		rng.randf_range(0.2, 0.5),
		rng.randf_range(0.3, 0.6),
		rng.randf_range(0.1, 0.3)
	)
	mesh.material_override = mat
	# Центрируем чанк
	mesh.position = Vector3(
		coord.x * CHUNK_SIZE + CHUNK_SIZE * 0.5,
		0.0,
		coord.y * CHUNK_SIZE + CHUNK_SIZE * 0.5
	)
	# Добавляем коллизию к плоскости
	var static_body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(CHUNK_SIZE, 0.1, CHUNK_SIZE)
	collision.shape = box
	static_body.add_child(collision)
	mesh.add_child(static_body)
	add_child(mesh)
	_loaded_chunks[coord] = mesh

func _unload_chunk(coord: Vector2i) -> void:
	if _loaded_chunks.has(coord):
		_loaded_chunks[coord].queue_free()
		_loaded_chunks.erase(coord)

func _world_to_chunk(world_pos: Vector3) -> Vector2i:
	return Vector2i(
		floori(world_pos.x / CHUNK_SIZE),
		floori(world_pos.z / CHUNK_SIZE)
	)

# ============================================================
# Спавн финальной двери (вызывается NotificationManager)
# ============================================================

func spawn_final_door() -> void:
	# TODO Этап 3: спавним дверь рядом с игроком
	push_warning("WorldRoguelike: spawn_final_door — запланировано Этап 3")

# ============================================================
# Автосохранение каждые 60 секунд
# ============================================================

func _auto_save_check(delta: float) -> void:
	_autosave_timer += delta
	if _autosave_timer >= 60.0:
		_autosave_timer = 0.0
		_save_position()
		if _player_stats:
			_player_stats.save_to_save()
		_save_manager.save_game()

func _save_position() -> void:
	if not _player:
		return
	var pos := _player.global_position
	_save_manager.set_value("player_pos_x", pos.x)
	_save_manager.set_value("player_pos_y", pos.y)
	_save_manager.set_value("player_pos_z", pos.z)

# ============================================================
# Сигналы игрока
# ============================================================

func _on_player_stats_changed(hp: float, max_hp: float, stamina: float, max_st: float, xp: int, level: int) -> void:
	if _hud:
		_hud.update_hp(hp, max_hp)
		_hud.update_stamina(stamina, max_st)
		_hud.update_xp(xp, level)

func _on_player_died() -> void:
	_audio.stop_music()
	get_node("/root/Main").on_player_death()
