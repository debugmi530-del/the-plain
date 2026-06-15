extends CharacterBody3D

# ============================================================
# PlayerMovement.gd — управление персонажем
# Свайп-камера (FPS), виртуальный джойстик, спринт
# ============================================================

@onready var _camera_pivot: Node3D  = $CameraPivot
@onready var _camera: Camera3D      = $CameraPivot/Camera3D
@onready var _stats: Node           = $PlayerStats
@onready var _vjoy_area: Control    = $HUDLayer/VJoyArea

const GRAVITY := 9.8
const SPRINT_MULTIPLIER := 1.7
const WATER_MULTIPLIER := 0.1    # Вода × 0.1 (подтверждено)
const SWAMP_MULTIPLIER := 0.3

var _camera_sensitivity := 0.8   # 0.1–2.0 (из настроек)
var _camera_rotation_x := 0.0
var _camera_rotation_y := 0.0

var _is_sprinting := false
var _in_water := false
var _in_swamp := false

# Виртуальный джойстик
var _joy_active := false
var _joy_start: Vector2 = Vector2.ZERO
var _joy_delta: Vector2 = Vector2.ZERO
var _joy_touch_index := -1

# Свайп-камера
var _cam_touch_index := -1
var _cam_last_pos: Vector2 = Vector2.ZERO

func _ready() -> void:
	_load_sensitivity()
	_stats.stats_changed.connect(_on_stats_changed)
	_stats.died.connect(_on_died)

func _physics_process(delta: float) -> void:
	_process_gravity(delta)
	_process_movement(delta)
	move_and_slide()

func _input(event: InputEvent) -> void:
	_process_touch_input(event)

# ============================================================
# Физика
# ============================================================

func _process_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

func _process_movement(delta: float) -> void:
	# Направление из виртуального джойстика
	var input_dir := _joy_delta.normalized() if _joy_active else Vector2.ZERO
	var forward := -_camera.global_transform.basis.z
	var right   := _camera.global_transform.basis.x
	forward.y = 0.0
	right.y   = 0.0
	forward   = forward.normalized()
	right     = right.normalized()

	var move_dir := (forward * (-input_dir.y) + right * input_dir.x)

	var base_speed := _stats.get_speed()

	# Спринт (у земли + есть выносливость)
	if _is_sprinting and is_on_floor() and move_dir.length() > 0.1:
		if _stats.use_stamina_sprint(delta):
			base_speed *= SPRINT_MULTIPLIER
		else:
			_is_sprinting = false

	# Вода/болото
	if _in_water:
		base_speed *= WATER_MULTIPLIER
	elif _in_swamp:
		base_speed *= SWAMP_MULTIPLIER

	if move_dir.length() > 0.01:
		velocity.x = move_dir.x * base_speed
		velocity.z = move_dir.z * base_speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, base_speed * 8.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, base_speed * 8.0 * delta)

# ============================================================
# Сенсорный ввод (свайп-камера + виртуальный джойстик)
# ============================================================

func _process_touch_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_handle_touch(event)
	elif event is InputEventScreenDrag:
		_handle_drag(event)

func _handle_touch(event: InputEventScreenTouch) -> void:
	var screen_w := float(get_viewport().get_visible_rect().size.x)

	if event.pressed:
		# Левая половина → джойстик
		if event.position.x < screen_w * 0.5 and _joy_touch_index == -1:
			_joy_touch_index = event.index
			_joy_start  = event.position
			_joy_delta  = Vector2.ZERO
			_joy_active = true
		# Правая половина → камера
		elif event.position.x >= screen_w * 0.5 and _cam_touch_index == -1:
			_cam_touch_index = event.index
			_cam_last_pos = event.position
	else:
		if event.index == _joy_touch_index:
			_joy_touch_index = -1
			_joy_delta  = Vector2.ZERO
			_joy_active = false
		elif event.index == _cam_touch_index:
			_cam_touch_index = -1

func _handle_drag(event: InputEventScreenDrag) -> void:
	if event.index == _joy_touch_index:
		_joy_delta = (event.position - _joy_start).normalized()
	elif event.index == _cam_touch_index:
		var delta := event.position - _cam_last_pos
		_cam_last_pos = event.position
		_rotate_camera(delta)

func _rotate_camera(delta: Vector2) -> void:
	_camera_rotation_y -= delta.x * _camera_sensitivity * 0.002
	_camera_rotation_x -= delta.y * _camera_sensitivity * 0.002
	_camera_rotation_x  = clamp(_camera_rotation_x, deg_to_rad(-80.0), deg_to_rad(80.0))
	rotation.y          = _camera_rotation_y
	_camera_pivot.rotation.x = _camera_rotation_x

# ============================================================
# Зоны воды и болота
# ============================================================

func enter_water() -> void:
	_in_water = true

func exit_water() -> void:
	_in_water = false

func enter_swamp() -> void:
	_in_swamp = true

func exit_swamp() -> void:
	_in_swamp = false

# ============================================================
# Настройки
# ============================================================

func _load_sensitivity() -> void:
	var sm := get_node("/root/SaveManager")
	_camera_sensitivity = sm.get_value("camera_sensitivity", 0.8)

func set_sensitivity(value: float) -> void:
	_camera_sensitivity = clamp(value, 0.1, 2.0)
	get_node("/root/SaveManager").set_value("camera_sensitivity", _camera_sensitivity)

# ============================================================
# Спринт (двойное касание по джойстику — Этап 4)
# ============================================================

func start_sprint() -> void:
	_is_sprinting = true

func stop_sprint() -> void:
	_is_sprinting = false

# ============================================================
# Сигналы Stats
# ============================================================

func _on_stats_changed(_hp, _max_hp, _st, _max_st, _xp, _level) -> void:
	pass  # HUD обновляется через WorldRoguelike

func _on_died() -> void:
	set_physics_process(false)
	set_process_input(false)
