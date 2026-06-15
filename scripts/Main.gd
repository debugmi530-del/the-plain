extends Node

# ============================================================
# Main.gd — корневой контроллер сцены
# Управляет переключением стадий и системными событиями Android
# ============================================================

enum Stage { ROGUELIKE = 1, HORROR = 2, FINAL = 3 }

const SCENE_MAIN_MENU := "res://scenes/ui/MainMenu.tscn"
const SCENE_ROGUELIKE  := "res://scenes/world/WorldRoguelike.tscn"
const SCENE_HORROR     := "res://scenes/world/WorldHorror.tscn"
const SCENE_FINAL      := "res://scenes/world/WorldFinal.tscn"

var _current_scene: Node = null
var _save_manager: Node = null
var _device_info: Node = null

func _ready() -> void:
	_save_manager = get_node("/root/SaveManager")
	_device_info  = get_node("/root/DeviceInfo")

	# Блокируем кнопку «Назад» на Android
	get_tree().set_auto_accept_quit(false)

	# Загружаем или инициализируем сохранение
	var save_data := _save_manager.load_or_init()
	_save_manager.start_session()

	# Root detection (GDScript-проверка)
	_device_info.check_root_simple()

	# Определяем точку входа
	var hero_name: String = save_data.get("hero_name", "")
	if hero_name.is_empty():
		_go_to_main_menu()
	else:
		_load_stage(save_data.get("stage", Stage.ROGUELIKE))

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_GO_BACK_REQUEST:
			# Кнопка «Назад» — открываем меню паузы вместо выхода
			var hud := get_tree().get_first_node_in_group("hud")
			if hud and hud.has_method("toggle_pause"):
				hud.toggle_pause()
		NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_APPLICATION_PAUSED:
			_save_manager.emergency_save()
			_save_manager.stop_session()
		NOTIFICATION_APPLICATION_RESUMED:
			_save_manager.start_session()
		NOTIFICATION_CRASH:
			_save_manager.emergency_save()

# ============================================================
# Навигация между сценами
# ============================================================

func _go_to_main_menu() -> void:
	_transition_to(SCENE_MAIN_MENU)

func _load_stage(stage: int) -> void:
	match stage:
		Stage.ROGUELIKE: _transition_to(SCENE_ROGUELIKE)
		Stage.HORROR:    _transition_to(SCENE_HORROR)
		Stage.FINAL:     _transition_to(SCENE_FINAL)
		_:               _transition_to(SCENE_MAIN_MENU)

func _transition_to(scene_path: String) -> void:
	if _current_scene:
		_current_scene.queue_free()
		_current_scene = null
	var packed := ResourceLoader.load(scene_path) as PackedScene
	if not packed:
		push_error("Main: не удалось загрузить сцену: " + scene_path)
		return
	_current_scene = packed.instantiate()
	add_child(_current_scene)

# ============================================================
# Публичный API для других скриптов
# ============================================================

func go_to_main_menu() -> void:
	_go_to_main_menu()

## Загружает сохранённую стадию (вызывается из MainMenu при «Продолжить» / «Начать»)
func trigger_roguelike_stage() -> void:
	_load_stage(_save_manager.get_stage())

func trigger_horror_stage() -> void:
	_save_manager.set_stage(Stage.HORROR)
	_load_stage(Stage.HORROR)

func trigger_final_stage() -> void:
	_save_manager.set_stage(Stage.FINAL)
	_load_stage(Stage.FINAL)

func on_player_death() -> void:
	_save_manager.reset_run()
	_go_to_main_menu()

func get_current_stage() -> int:
	return _save_manager.get_stage()
