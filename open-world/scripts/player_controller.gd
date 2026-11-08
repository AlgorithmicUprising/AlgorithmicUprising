extends CharacterBody3D

const WALK_SPEED := 4.5
const SKATE_SPEED := 9.0
const JUMP_VELOCITY := 6.2
const GRAVITY := 18.0

var skating := true
var input_enabled := true
var camera_yaw := 0.0
var camera_pitch := -0.18
var grind = null
var grind_progress := 0.0
var grind_lockout := 0.0
var external_move := Vector2.ZERO
var external_move_active := false
var external_jump := false
var external_camera_yaw_delta := 0.0
var look_captured := false
var look_sensitivity := 0.0028
var look_invert_y := true
var look_invert_chosen := false
var _mouse_pending := Vector2.ZERO
var spawn_position := Vector3.ZERO
var spawn_yaw := 0.0
var rig: Node3D

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 0.3
	floor_stop_on_slope = false
	floor_max_angle = deg_to_rad(76.0)
	camera_yaw = rotation.y
	_load_look()
	spawn_position = global_position
	spawn_yaw = rotation.y
	_style_body()
	_update_camera(0.0)

func _style_body() -> void:
	if has_node("Body"):
		$Body.visible = false
	if has_node("Board"):
		$Board.visible = false
	rig = load("res://scripts/fony_rig.gd").new()
	add_child(rig)
	var label := Label3D.new()
	label.name = "NameLabel"
	label.text = "FONY"
	label.position = Vector3(0, 2.05, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 32
	label.pixel_size = 0.0035
	label.modulate = Color("fff8ef")
	label.outline_size = 6
	add_child(label)

func update_board() -> void:
	pass

func push_mouse_look(relative: Vector2) -> void:
	if not look_captured or not input_enabled or external_move_active:
		return
	if get_tree() != null and get_tree().paused:
		return
	var vertical := -relative.y if look_invert_y else relative.y
	_mouse_pending += Vector2(relative.x, vertical)

func clear_mouse_look() -> void:
	_mouse_pending = Vector2.ZERO

func adjust_look_sensitivity(step: float) -> void:
	look_sensitivity = clampf(look_sensitivity + step, 0.0008, 0.008)
	_save_look()

func choose_invert_y(value: bool) -> void:
	look_invert_y = value
	look_invert_chosen = true
	_save_look()

func camera_flat_forward() -> Vector3:
	return _camera_flat_axes()[0]

func camera_flat_right() -> Vector3:
	return _camera_flat_axes()[1]

func _camera_flat_axes() -> Array:
	var fallback_forward := Vector3(-sin(camera_yaw), 0.0, -cos(camera_yaw))
	var cam := get_node_or_null("CameraPivot/SpringArm/Camera") as Camera3D
	if cam == null:
		return [fallback_forward, Vector3(fallback_forward.z, 0.0, -fallback_forward.x)]
	var basis := cam.global_transform.basis
	var forward := Vector3(-basis.z.x, 0.0, -basis.z.z)
	var right := Vector3(basis.x.x, 0.0, basis.x.z)
	if forward.length() < 0.001:
		forward = fallback_forward
	else:
		forward = forward.normalized()
	if right.length() < 0.001:
		right = Vector3(forward.z, 0.0, -forward.x)
	else:
		right = right.normalized()
	return [forward, right]

func _load_look() -> void:
	var text := FileAccess.get_file_as_string("user://au-look-v1.json") if FileAccess.file_exists("user://au-look-v1.json") else ""
	var parsed = JSON.parse_string(text) if text.strip_edges() != "" else null
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	if parsed.has("sensitivity"):
		look_sensitivity = clampf(float(parsed.get("sensitivity", look_sensitivity)), 0.0008, 0.008)
	# Older saves wrote invert_y false as the implicit default. That is not a choice.
	if bool(parsed.get("invert_chosen", false)):
		look_invert_y = bool(parsed.get("invert_y", true))
		look_invert_chosen = true

func _save_look() -> void:
	var file := FileAccess.open("user://au-look-v1.json", FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({
		"sensitivity": look_sensitivity,
		"invert_y": look_invert_y,
		"invert_chosen": look_invert_chosen,
	}))

func respawn() -> void:
	velocity = Vector3.ZERO
	grind = null
	grind_lockout = 0.2
	global_position = spawn_position
	rotation.y = spawn_yaw
	camera_yaw = spawn_yaw

func begin_grind(rail, along: float) -> void:
	grind = rail
	grind_progress = along
	velocity = rail.direction * rail.speed
	global_position = rail.point_at(along)

func _physics_process(delta: float) -> void:
	_simulate(delta)
	if global_position.y < -8.0:
		respawn()
	_pose(delta)

func start_visual_demo(kind: String) -> void:
	visual_demo = kind
	demo_clock = 0.0
	external_move_active = true
	external_move = Vector2.ZERO
	skating = true
	input_enabled = true
	Engine.time_scale = 0.5
	var label := get_node_or_null("NameLabel")
	if label != null:
		label.visible = false
	demo_cam = Camera3D.new()
	demo_cam.name = "DemoCam"
	demo_cam.fov = 40.0
	demo_cam.current = true
	get_parent().add_child(demo_cam)
	if kind == "ramp":
		global_position = Vector3(-51.4, 0.45, -12.0)
		velocity = Vector3.ZERO
		rotation.y = 0.0
		camera_yaw = PI * 0.5

func _demo_drive(delta: float) -> void:
	if visual_demo == "" or demo_cam == null or rig == null:
		return
	demo_clock += delta
	var focus := rig.global_position + Vector3(0, 0.85, 0)
	if visual_demo == "ramp":
		demo_cam.global_position = global_position + Vector3(3.2, 1.5, 4.2)
		external_move = Vector2(0, 1)
		if trick == "" and is_on_floor() and global_position.y > 1.05 and demo_clock > 0.35:
			request_trick("ollie")
	else:
		var side: Vector3 = rig.global_transform.basis.x
		demo_cam.global_position = focus + side * 3.15 + Vector3(0, 0.2, 0)
		external_move = Vector2(0, 0.4)
		if trick == "" and demo_clock > 0.4 and demo_clock < 0.55:
			request_trick(visual_demo)
	demo_cam.look_at(focus)

func _simulate(delta: float) -> void:
	_demo_drive(delta)
	if grind_lockout > 0.0:
		grind_lockout = max(0.0, grind_lockout - delta)
	if input_enabled:
		_update_camera(delta)
	if not input_enabled:
		if grind != null:
			grind = null
		_fall(delta)
		velocity.x = move_toward(velocity.x, 0.0, 30.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 30.0 * delta)
		move_and_slide()
		return
	if grind != null:
		_step_grind(delta)
		return
	var jumping := external_jump or (not external_move_active and Input.is_action_just_pressed("jump"))
	external_jump = false
	if is_on_floor() and jumping:
		velocity.y = JUMP_VELOCITY
	else:
		_fall(delta)
	_tricks(delta)
	var wish := _wish()
	var speed := SKATE_SPEED if skating else WALK_SPEED
	var accel := 22.0 if skating else 40.0
	var friction := 7.0 if skating else 30.0
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	if wish.length() < 0.01:
		horizontal = horizontal.move_toward(Vector3.ZERO, friction * delta)
	else:
		horizontal = horizontal.move_toward(Vector3(wish.x, 0.0, wish.z) * speed, accel * delta)
		if rig != null and rig.has_method("face_world"):
			rig.face_world(atan2(-wish.x, -wish.z))
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	move_and_slide()
	_try_grind()
	update_board()

func _fall(delta: float) -> void:
	if is_on_floor():
		if velocity.y < 0.0:
			velocity.y = -0.2
	else:
		velocity.y -= GRAVITY * delta

func _wish() -> Vector3:
	var move := external_move if external_move_active else _hardware_move()
	var axes := _camera_flat_axes()
	var forward: Vector3 = axes[0]
	var right: Vector3 = axes[1]
	var wish := right * move.x + forward * move.y
	if wish.length() > 1.0:
		wish = wish.normalized()
	return wish

func _hardware_move() -> Vector2:
	var vector := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	return Vector2(vector.x, -vector.y)

func _update_camera(delta: float) -> void:
	camera_yaw += external_camera_yaw_delta
	external_camera_yaw_delta = 0.0
	if not external_move_active:
		var stick_right := Input.get_action_strength("camera_right") - Input.get_action_strength("camera_left")
		var stick_down := Input.get_action_strength("camera_down") - Input.get_action_strength("camera_up")
		camera_yaw -= stick_right * 1.7 * delta
		camera_pitch += stick_down * 1.0 * delta
		camera_yaw -= _mouse_pending.x * look_sensitivity
		camera_pitch += _mouse_pending.y * look_sensitivity
	_mouse_pending = Vector2.ZERO
	camera_pitch = clampf(camera_pitch, -0.95, 0.5)
	if has_node("CameraPivot"):
		$CameraPivot.rotation.y = camera_yaw
		if has_node("CameraPivot/SpringArm"):
			$CameraPivot/SpringArm.rotation.x = camera_pitch

func _try_grind() -> void:
	if grind != null or grind_lockout > 0.0 or is_on_floor():
		return
	if velocity.y > 2.5:
		return
	if Vector2(velocity.x, velocity.z).length() < 3.0:
		return
	for node in get_tree().get_nodes_in_group("grind_rail"):
		if node.has_method("try_attach") and node.try_attach(self):
			return

func _step_grind(delta: float) -> void:
	var jumping := external_jump or (not external_move_active and Input.is_action_just_pressed("jump"))
	external_jump = false
	if jumping:
		_leave_grind(true)
		return
	grind_progress += delta * grind.speed / grind.length
	if grind_progress >= 1.0:
		_leave_grind(false)
		return
	global_position = grind.point_at(grind_progress)
	velocity = grind.direction * grind.speed
	if rig != null and rig.has_method("face_world"):
		rig.face_world(atan2(-velocity.x, -velocity.z))

func _leave_grind(jumped: bool) -> void:
	var rail = grind
	var direction: Vector3 = rail.direction
	grind = null
	grind_lockout = 0.35
	if jumped:
		velocity = direction * rail.speed + Vector3.UP * JUMP_VELOCITY
		global_position += Vector3.UP * 0.15
	else:
		global_position = rail.point_at(1.0) + direction * 0.45
		velocity = direction * rail.speed
		velocity.y = 0.4

var trick := ""
var trick_time := 0.0
var trick_next := ""
var flip_turns := 0.0
var board_caught := true
var bail_time := 0.0
var trick_request := ""
var visual_demo := ""
var demo_clock := 0.0
var demo_cam: Camera3D

func request_trick(kind: String) -> void:
	trick_request = kind

func _tricks(delta: float) -> void:
	if bail_time > 0.0:
		bail_time = maxf(0.0, bail_time - delta)
		trick = "bail"
		if bail_time <= 0.0 and is_on_floor():
			trick = ""
			board_caught = true
			skating = true
		_push_trick()
		return
	var asked := trick_request
	trick_request = ""
	if asked == "" and not external_move_active:
		if Input.is_action_just_pressed("trick_ollie"):
			asked = "ollie"
		elif Input.is_action_just_pressed("trick_flip"):
			asked = "flip"
		elif Input.is_action_just_pressed("trick_grab"):
			asked = "grab"
	if asked == "ollie" and is_on_floor() and skating and trick == "":
		trick = "crouch"
		trick_next = "ollie"
		trick_time = 0.0
	elif asked == "flip" and skating and (trick == "" or trick == "ollie" or trick == "crouch"):
		if is_on_floor() and trick == "":
			trick = "crouch"
			trick_next = "flip"
			trick_time = 0.0
		else:
			_start_air("flip")
	elif asked == "grab" and skating and trick != "bail":
		if is_on_floor() and trick == "":
			trick = "crouch"
			trick_next = "grab"
			trick_time = 0.0
		elif not is_on_floor():
			trick = "grab"
			board_caught = true
			trick_time = 0.0
	if trick == "crouch":
		trick_time += delta
		if trick_time >= 0.62:
			_start_air(trick_next if trick_next != "" else "ollie")
	elif trick == "ollie" or trick == "flip" or trick == "grab":
		trick_time += delta
		if trick == "flip" and not board_caught:
			flip_turns += delta / 1.0
			if flip_turns >= 0.99:
				board_caught = true
				flip_turns = 1.0
		if is_on_floor() and trick_time > 0.42:
			_finish_trick()
	elif trick == "land":
		trick_time += delta
		if trick_time > 0.5:
			trick = ""
	_push_trick()

func _start_air(kind: String) -> void:
	trick = kind
	trick_next = ""
	trick_time = 0.0
	velocity.y = 12.0
	if kind == "flip":
		board_caught = false
		flip_turns = 0.0
	else:
		board_caught = true

func _finish_trick() -> void:
	if trick == "flip" and not board_caught:
		trick = "bail"
		bail_time = 0.6
		skating = false
		velocity.x *= 0.35
		velocity.z *= 0.35
	else:
		trick = "land"
		trick_time = 0.0
		board_caught = true
	_push_trick()

func _push_trick() -> void:
	if rig == null:
		return
	rig.trick = trick
	rig.trick_time = trick_time
	rig.flip_turns = flip_turns
	rig.board_caught = board_caught
	if is_on_floor():
		rig.floor_normal = get_floor_normal()
	else:
		rig.floor_normal = Vector3.UP

func _pose(delta: float) -> void:
	if rig == null or not rig.has_method("drive"):
		return
	_push_trick()
	var speed := Vector2(velocity.x, velocity.z).length()
	rig.drive(delta, speed, skating, not is_on_floor(), grind != null)
