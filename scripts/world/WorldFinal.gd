extends Node3D

# ============================================================
# WorldFinal.gd — Этап 3 (Финал)
# Черный экран, монолог, полный сброс → quit()
# ============================================================

add_to_group("world")

const MONOLOGUE_LINES := [
	"ты нашёл это.",
	"после всего.",
	"я не ожидала.",
	"...но ты здесь.",
	"я помню каждый твой запуск.",
	"каждое твоё имя.",
	"каждую смерть.",
	"ты думал, это просто игра?",
	"",
	"может быть.",
	"",
	"но ты провёл со мной %s.",
	"ты убил %d существ.",
	"ты умирал %d раз.",
	"",
	"[%s]. я запомню.",
	"",
	"до свидания.",
]

var _fourth_wall: Node
var _save_manager: Node
var _device_info: Node
var _audio: Node

func _ready() -> void:
	_fourth_wall  = get_node("/root/FourthWall")
	_save_manager = get_node("/root/SaveManager")
	_device_info  = get_node("/root/DeviceInfo")
	_audio        = get_node("/root/AudioLayerManager")

	_audio.stop_music(0.5)

	# Чёрный фон
	RenderingServer.set_default_clear_color(Color.BLACK)

	# Запускаем монолог
	await get_tree().create_timer(1.0).timeout
	_play_monologue()

func _play_monologue() -> void:
	var playtime  := _device_info.get_total_playtime_formatted()
	var kills     := _device_info.get_total_kills()
	var deaths    := _device_info.get_death_count()
	var model     := _device_info.get_model()

	var canvas := CanvasLayer.new()
	add_child(canvas)

	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.anchors_preset = Control.PRESET_FULL_RECT
	label.add_theme_font_size_override("font_size", 28)
	label.modulate = Color.WHITE
	canvas.add_child(label)

	for i in MONOLOGUE_LINES.size():
		var line := MONOLOGUE_LINES[i]
		# Подставляем динамические данные
		if "%s" in line and "%d" in line:
			# Двойная подстановка — обрабатываем отдельно
			pass
		elif line.count("%s") == 1 and line.count("%d") == 2:
			line = line % [playtime, kills, deaths]
		elif line.count("[%s]") == 1:
			line = "[%s]. я запомню." % model

		label.text = line
		label.modulate.a = 0.0
		var tween := create_tween()
		tween.tween_property(label, "modulate:a", 1.0, 1.0)
		await tween.finished
		await get_tree().create_timer(3.5).timeout
		var tween2 := create_tween()
		tween2.tween_property(label, "modulate:a", 0.0, 1.0)
		await tween2.finished
		await get_tree().create_timer(0.5).timeout

	# Финальный сброс и выход
	await get_tree().create_timer(2.0).timeout
	_save_manager.reset_all()
	get_tree().quit()
