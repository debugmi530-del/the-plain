extends Node

# ============================================================
# NotificationManager.gd — системные уведомления Android
# Уведомление «пора возвращаться» через 1-2 часа
# Использует Android AlarmManager через GodotAndroidPlugin
# ============================================================

const NOTIFICATION_CHANNEL_ID := "the_plain_channel"
const NOTIFICATION_TITLE := "The Plain"
const NOTIFICATION_TEXT := "пора возвращаться"
const NOTIFICATION_ID := 1001

var _plugin: Object = null
var _permission_granted := false

func _ready() -> void:
	_try_init_plugin()
	_check_notification_permission()

# ============================================================
# Инициализация плагина
# ============================================================

func _try_init_plugin() -> void:
	if OS.get_name() != "Android":
		return
	if Engine.has_singleton("GodotNotifications"):
		_plugin = Engine.get_singleton("GodotNotifications")
	# Если плагин недоступен — используем fallback (glitch-текст при запуске)

# ============================================================
# Разрешения
# ============================================================

func _check_notification_permission() -> void:
	if OS.get_name() != "Android":
		_permission_granted = true
		return
	if OS.has_feature("android") and int(OS.get_version()) >= 33:
		# Android 13+ требует явного разрешения
		if OS.has_feature("PERMISSION_POST_NOTIFICATIONS"):
			_permission_granted = true
		else:
			OS.request_permissions()
	else:
		_permission_granted = true

func on_permissions_result(permissions: PackedStringArray, granted: PackedByteArray) -> void:
	for i in permissions.size():
		if permissions[i] == "android.permission.POST_NOTIFICATIONS":
			_permission_granted = granted[i] == 1
			if not _permission_granted:
				# Пользователь отклонил — ставим fallback
				get_node("/root/FourthWall").mark_notification_fallback()

# ============================================================
# Планирование уведомления
# ============================================================

func schedule_return_notification(delay_seconds: int) -> void:
	var save_manager := get_node("/root/SaveManager")

	# Запоминаем когда должно прийти уведомление
	var target_timestamp := int(Time.get_unix_time_from_system()) + delay_seconds
	save_manager.set_value("notification_scheduled", true)
	save_manager.set_value("notification_timestamp", target_timestamp)
	save_manager.save_game()

	if not _permission_granted:
		# Fallback: покажем глитч-текст при следующем запуске
		get_node("/root/FourthWall").mark_notification_fallback()
		return

	if _plugin:
		_send_via_plugin(delay_seconds)
	elif OS.get_name() == "Android":
		_send_via_java(delay_seconds)

func _send_via_plugin(delay_seconds: int) -> void:
	if not _plugin:
		return
	_plugin.scheduleNotification(
		NOTIFICATION_ID,
		NOTIFICATION_CHANNEL_ID,
		NOTIFICATION_TITLE,
		NOTIFICATION_TEXT,
		delay_seconds * 1000  # в миллисекундах
	)

func _send_via_java(delay_seconds: int) -> void:
	# Через JavaClassWrapper если доступен
	if not ClassDB.class_exists("JavaClassWrapper"):
		return
	# Получаем Context через AndroidRuntime
	var context = JavaClassWrapper.get_java_class("android.os.SystemClock")
	# Полная реализация через плагин в Этапе 5
	push_warning("NotificationManager: Java-путь требует Godot Android Plugin (Этап 5)")

# ============================================================
# Проверка при запуске: нужно ли показать уведомление в игре
# ============================================================

func check_pending_notification() -> void:
	var save_manager := get_node("/root/SaveManager")
	if not save_manager.get_value("notification_scheduled", false):
		return
	var target: int = save_manager.get_value("notification_timestamp", 0)
	var now := int(Time.get_unix_time_from_system())
	if now >= target:
		save_manager.set_value("notification_scheduled", false)
		save_manager.save_game()
		# Спавн финальной двери
		get_node("/root/HorrorTrigger").spawn_final_door()
