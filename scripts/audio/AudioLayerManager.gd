extends Node

# ============================================================
# AudioLayerManager.gd — многослойная динамическая музыка
# Рогалик: 8 слоёв | Хоррор: 6 слоёв
# Аналог системы из Hades — независимая громкость каждого слоя
# ============================================================

enum MusicMode { ROGUELIKE, HORROR }
enum GameState { CALM, COMBAT }

const ROGUELIKE_LAYERS := [
	"res://assets/audio/roguelike/layer_01.ogg",
	"res://assets/audio/roguelike/layer_02.ogg",
	"res://assets/audio/roguelike/layer_03.ogg",
	"res://assets/audio/roguelike/layer_04.ogg",
	"res://assets/audio/roguelike/layer_05.ogg",
	"res://assets/audio/roguelike/layer_06.ogg",
	"res://assets/audio/roguelike/layer_07.ogg",
	"res://assets/audio/roguelike/layer_08.ogg",
]

const HORROR_LAYERS := [
	"res://assets/audio/horror/layer_01.ogg",
	"res://assets/audio/horror/layer_02.ogg",
	"res://assets/audio/horror/layer_03.ogg",
	"res://assets/audio/horror/layer_04.ogg",
	"res://assets/audio/horror/layer_05.ogg",
	"res://assets/audio/horror/layer_06.ogg",
]

const IDX_BASS := 0
const IDX_PERC := 1
const IDX_ATMO := 4
const IDX_WARM := 6

var _layers: Array[AudioStreamPlayer] = []
var _target_volumes: Array[float] = []
var _current_mode: MusicMode = MusicMode.ROGUELIKE
var _current_state: GameState = GameState.CALM
var _mix_timer := 0.0
var _active := false

func _ready() -> void:
	_reset_mix_timer()

func _process(delta: float) -> void:
	if not _active or _layers.is_empty():
		return
	_mix_timer -= delta
	if _mix_timer <= 0.0:
		_randomize_one_layer()
		_reset_mix_timer()

# ============================================================
# Запуск / Остановка
# ============================================================

func start_roguelike() -> void:
	_stop_all()
	_current_mode = MusicMode.ROGUELIKE
	_load_layers(ROGUELIKE_LAYERS)
	_active = true

func start_horror() -> void:
	_stop_all()
	_current_mode = MusicMode.HORROR
	_load_layers(HORROR_LAYERS)
	_active = true

func stop_music(fade_time: float = 1.5) -> void:
	_active = false
	for layer in _layers:
		var tween := create_tween()
		tween.tween_property(layer, "volume_db", -80.0, fade_time)
	await get_tree().create_timer(fade_time + 0.1).timeout
	_stop_all()

# ============================================================
# Переход состояний (бой / покой)
# ============================================================

func set_combat_state() -> void:
	if _current_state == GameState.COMBAT:
		return
	_current_state = GameState.COMBAT
	_apply_state_mix()

func set_calm_state() -> void:
	if _current_state == GameState.CALM:
		return
	_current_state = GameState.CALM
	_apply_state_mix()

func _apply_state_mix() -> void:
	if _layers.is_empty():
		return
	var tween := create_tween()
	tween.set_parallel(true)
	if _current_state == GameState.COMBAT:
		if IDX_BASS < _layers.size():
			tween.tween_property(_layers[IDX_BASS], "volume_db", linear_to_db(1.0), 1.0)
		if IDX_PERC < _layers.size():
			tween.tween_property(_layers[IDX_PERC], "volume_db", linear_to_db(1.0), 1.0)
		if IDX_ATMO < _layers.size():
			tween.tween_property(_layers[IDX_ATMO], "volume_db", linear_to_db(0.2), 1.0)
	else:
		if IDX_PERC < _layers.size():
			tween.tween_property(_layers[IDX_PERC], "volume_db", linear_to_db(0.3), 2.0)
		if IDX_ATMO < _layers.size():
			tween.tween_property(_layers[IDX_ATMO], "volume_db", linear_to_db(0.9), 2.0)
		if IDX_WARM < _layers.size():
			tween.tween_property(_layers[IDX_WARM], "volume_db", linear_to_db(0.8), 2.0)

# ============================================================
# Процедурное микширование
# ============================================================

func _randomize_one_layer() -> void:
	if _layers.is_empty():
		return
	var idx := randi() % _layers.size()
	if _current_state == GameState.COMBAT and (idx == IDX_BASS or idx == IDX_PERC):
		return
	var target_vol := randf_range(0.4, 1.0)
	var duration := randf_range(8.0, 16.0)
	var tween := create_tween()
	tween.tween_property(_layers[idx], "volume_db", linear_to_db(target_vol), duration)

func _reset_mix_timer() -> void:
	_mix_timer = randf_range(8.0, 16.0)

# ============================================================
# Загрузка слоёв
# ============================================================

func _load_layers(paths: Array) -> void:
	_layers.clear()
	_target_volumes.clear()

	var world_seed: int = SaveManager.get_value("world_seed", 0)

	for i in paths.size():
		var player := AudioStreamPlayer.new()
		player.bus = "Music"

		if ResourceLoader.exists(paths[i]):
			# FIX: явное приведение типа для установки loop
			# AudioStream (базовый класс) не имеет свойства loop
			var stream := load(paths[i])
			if stream is AudioStreamOggVorbis:
				(stream as AudioStreamOggVorbis).loop = true
			player.stream = stream

		var rng := RandomNumberGenerator.new()
		rng.seed = world_seed ^ (i * 0xFF)
		var init_vol := rng.randf_range(0.4, 1.0)
		player.volume_db = linear_to_db(init_vol)
		add_child(player)
		_layers.append(player)
		_target_volumes.append(init_vol)

		if player.stream != null:
			player.play()

func _stop_all() -> void:
	for layer in _layers:
		layer.stop()
		layer.queue_free()
	_layers.clear()
	_target_volumes.clear()
