extends Node

# ============================================================
# NotificationManager.gd — системные уведомления Android
# Уведомление «пора возвращаться» через 1–2 часа
# ============================================================

const NOTIFICATION_CHANNEL_ID := "the_plain_channel"
const NOTIFICATION_TITLE := "The Plain"
const NOTIFICATION_TEXT := "пора возвращаться"
const NOTIFICATION_ID := 1001

var _plugin: Object = null
var _permission_granted := false
var _permission_requested := false

func _ready() -> void:
	_try_init_plugin()
	_request_permission_if_needed()

# ============================================================
# Инициализация плагина
# ============================================================

func _try_init_plugin() -> void:
	if OS.get_name() != "Android":
		return
	if Engine.has_singleton("GodotNotifications"):
		_plugin = Engine.get_singleton("GodotNotifications")

# ============================================================
# Разрешения
# ============================================================

func _request_permission_if_needed() -> void:
	if OS.get_name() != "Android":
		_permission_granted = true
		return

	# FIX: убран неверный OS.has_feature("PERMISSION_POST_NOTIFICATIONS")
	# Правильный способ: запрашиваем разрешение и ждём колбэка
	# Android < 13 (API < 33): разрешение не нужно
	# Android 13+: нужно явно запрашивать POST_NOTIFICATIONS

	# Проверяем текущий статус через правильный метод Godot 4
	var granted_permissions := OS.get_granted_permissions()
	if "android.permission.POST_NOTIFICATIONS" in granted_permissions:
		_permission_granted = true
		return

	# Запрашиваем разрешение
	if not _permission_requested:
		_permission_requested = true
		OS.request_permission("android.permission.POST_NOTIFICATIONS")

## Вызывается из Main или OS сигнала после ответа пользователя
func on_permissions_result(permissions: PackedStringArray, granted: PackedByteArray) -> void:
	for i in permissions.size():
		if permissions[i] == "android.permission.POST_NOTIFICATIONS":
			_permission_granted = (granted[i] == 1)
			if not _permission_granted:
				# Пользователь отклонил — ставим fallback-глитч
				get_node("/root/FourthWall").mark_notification_fallback()

# ============================================================
# Планирование уведомления
# ============================================================

func schedule_return_notification(delay_seconds: int) -> void:
	var save_manager := get_node("/root/SaveManager")

	var target_timestamp := int(Time.get_unix_time_from_system()) + delay_seconds
	save_manager.set_value("notification_scheduled", true)
	save_manager.set_value("notification_timestamp", target_timestamp)
	save_manager.save_game()

	if not _permission_granted:
		get_node("/root/FourthWall").mark_notification_fallback()
		return

	if _plugin:
		_send_via_plugin(delay_seconds)
	# Если плагин недоступен — сохранили timestamp, проверим при следующем запуске

func _send_via_plugin(delay_seconds: int) -> void:
	if not _plugin:
		return
	_plugin.scheduleNotification(
		NOTIFICATION_ID,
		NOTIFICATION_CHANNEL_ID,
		NOTIFICATION_TITLE,
		NOTIFICATION_TEXT,
		delay_seconds * 1000  # миллисекунды
	)

# ============================================================
# Проверка при запуске: нужно ли появиться финальной двери
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
		get_node("/root/HorrorTrigger").spawn_final_door()
