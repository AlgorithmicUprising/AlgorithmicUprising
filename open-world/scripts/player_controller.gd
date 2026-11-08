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

func _simulate(delta: float) -> void:
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
	var wish := _wish()
	var speed := SKATE_SPEED if skating else WALK_SPEED
	var accel := 22.0 if skating else 40.0
	var friction := 7.0 if skating else 30.0
	if wish.length() < 0.01:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)
		velocity.z = move_toward(velocity.z, 0.0, friction * delta)
	else:
		velocity.x = move_toward(velocity.x, wish.x * speed, accel * delta)
		velocity.z = move_toward(velocity.z, wish.z * speed, accel * delta)
		if rig != null and rig.has_method("face_world"):
			rig.face_world(atan2(-wish.x, -wish.z))
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
	var forward := Vector3(-sin(camera_yaw), 0.0, -cos(camera_yaw))
	var right := Vector3(cos(camera_yaw), 0.0, -sin(camera_yaw))
	var wish := right * move.x + forward * move.y
	if wish.length() > 1.0:
		wish = wish.normalized()
	return wish

func _hardware_move() -> Vector2:
	var vector := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	return Vector2(vector.x, -vector.y)

func _update_camera(delta: float) -> void:
	var yaw_input := external_camera_yaw_delta
	external_camera_yaw_delta = 0.0
	if not external_move_active:
		yaw_input += Input.get_action_strength("camera_right") - Input.get_action_strength("camera_left")
		var pitch_input := Input.get_action_strength("camera_down") - Input.get_action_strength("camera_up")
		camera_pitch = clampf(camera_pitch + pitch_input * 1.1 * delta, -1.0, 0.45)
	camera_yaw += yaw_input * 1.7 * delta
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

func _pose(delta: float) -> void:
	if rig == null or not rig.has_method("drive"):
		return
	var speed := Vector2(velocity.x, velocity.z).length()
	rig.drive(delta, speed, skating, not is_on_floor(), grind != null)
