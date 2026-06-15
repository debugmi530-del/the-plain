extends Node3D

# ============================================================
# WorldFinal.gd — Этап 3 (Финал)
# Чёрный экран, монолог, полный сброс → quit()
# ============================================================

var _fourth_wall: Node
var _save_manager: Node
var _device_info: Node
var _audio: Node

func _ready() -> void:
	add_to_group("world")

	_fourth_wall  = get_node("/root/FourthWall")
	_save_manager = get_node("/root/SaveManager")
	_device_info  = get_node("/root/DeviceInfo")
	_audio        = get_node("/root/AudioLayerManager")

	_audio.stop_music(0.5)

	RenderingServer.set_default_clear_color(Color.BLACK)

	await get_tree().create_timer(1.0).timeout
	_play_monologue()

func _play_monologue() -> void:
	var playtime  := _device_info.get_total_playtime_formatted()
	var kills     := _device_info.get_total_kills()
	var deaths    := _device_info.get_death_count()
	var model     := _device_info.get_model()

	# FIX: строки с подстановкой вынесены отдельно
	# Финальная последовательность:
	var lines: Array[String] = [
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
		"но ты провёл со мной %s." % playtime,
		"ты убил %d существ." % kills,
		"ты умирал %d раз." % deaths,
		"",
		"%s. я запомню." % model,
		"",
		"до свидания.",
	]

	var canvas := CanvasLayer.new()
	add_child(canvas)

	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.add_theme_font_size_override("font_size", 28)
	label.modulate = Color.WHITE
	label.modulate.a = 0.0
	canvas.add_child(label)

	for line in lines:
		if line.is_empty():
			await get_tree().create_timer(1.5).timeout
			continue

		label.text = line
		label.modulate.a = 0.0
		var t1 := create_tween()
		t1.tween_property(label, "modulate:a", 1.0, 1.0)
		await t1.finished
		await get_tree().create_timer(3.5).timeout
		var t2 := create_tween()
		t2.tween_property(label, "modulate:a", 0.0, 1.0)
		await t2.finished
		await get_tree().create_timer(0.5).timeout

	# Финальный сброс и выход
	await get_tree().create_timer(2.0).timeout
	_save_manager.reset_all()
	get_tree().quit()
