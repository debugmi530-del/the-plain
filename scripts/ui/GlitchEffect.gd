extends Label

# ============================================================
# GlitchEffect.gd — Label с эффектом глитча (хаотичный шрифт)
# Подключается к FourthWall.glitch_triggered
# ============================================================

const GLITCH_CHARS := ["█", "▓", "▒", "░", "▄", "▀", "■", "□", "◆", "◇"]
const LATIN_CONFUSE := {"а":"a","е":"e","о":"o","р":"p","с":"c","х":"x","у":"y"}

var _original_text := ""
var _glitch_active := false
var _timer := 0.0
var _duration := 0.0

func _process(delta: float) -> void:
	if not _glitch_active:
		return
	_timer -= delta
	if _timer <= 0.0:
		_apply_glitch()
		_timer = randf_range(0.05, 0.15)
	_duration -= delta
	if _duration <= 0.0:
		_end_glitch()

func show_glitch(msg: String, duration: float = 3.0) -> void:
	_original_text = msg
	_duration = duration
	_glitch_active = true
	_timer = 0.0
	visible = true
	modulate.a = 1.0

func _apply_glitch() -> void:
	var result := ""
	for i in _original_text.length():
		var ch := _original_text[i]
		var rand := randf()
		if rand < 0.08:
			result += GLITCH_CHARS[randi() % GLITCH_CHARS.size()]
		elif rand < 0.15 and LATIN_CONFUSE.has(ch.to_lower()):
			result += LATIN_CONFUSE[ch.to_lower()]
		else:
			result += ch
	text = result

func _end_glitch() -> void:
	_glitch_active = false
	text = _original_text
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 1.0)
	tween.tween_callback(hide)
