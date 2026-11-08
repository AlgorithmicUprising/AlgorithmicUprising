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

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 0.3
	floor_max_angle = deg_to_rad(50.0)
	camera_yaw = rotation.y
	_style_body()
	_update_camera(0.0)
	update_board()

func _style_body() -> void:
	if has_node("Body"):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color("f4e1b5")
		mat.roughness = 1.0
		mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		$Body.material_override = mat
	if has_node("Board"):
		var board_mat := StandardMaterial3D.new()
		board_mat.albedo_color = Color("241c18")
		board_mat.roughness = 1.0
		$Board.material_override = board_mat
	var label := Label3D.new()
	label.name = "NameLabel"
	label.text = "UNNAMED"
	label.position = Vector3(0, 1.95, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 32
	label.pixel_size = 0.008
	label.modulate = Color("fff8ef")
	label.outline_size = 6
	add_child(label)

func update_board() -> void:
	if has_node("Board"):
		$Board.visible = skating

func begin_grind(rail, along: float) -> void:
	grind = rail
	grind_progress = along
	velocity = rail.direction * rail.speed
	global_position = rail.point_at(along)

func _physics_process(delta: float) -> void:
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
		if has_node("Body"):
			var face := atan2(-wish.x, -wish.z)
			$Body.rotation.y = face
			if has_node("Board"):
				$Board.rotation.y = face
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
	update_board()

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
