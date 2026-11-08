extends Node

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	for _i in 20:
		await get_tree().process_frame
	var settings := OS.get_environment("AU_SETTINGS")
	if settings.is_empty():
		settings = "/tmp/hq-settings.png"
	main.get_node("Flow").set_paused(true)
	for _i in 4:
		await get_tree().process_frame
	var err_settings := _save(settings)
	main.get_node("Flow").set_paused(false)
	var controls := OS.get_environment("AU_CONTROLS")
	if controls.is_empty():
		controls = "/tmp/hq-controls.png"
	var err_controls := _save(controls)
	for child in main.get_children():
		if child is CanvasLayer:
			child.visible = false
	var player = main.get_node("WorldSim/Player")
	var label = player.get_node_or_null("NameLabel")
	if label != null:
		label.visible = false
	var chase := OS.get_environment("AU_CHASE")
	if chase.is_empty():
		chase = "/tmp/hq-chase.png"
	player.external_move_active = true
	player.external_move = Vector2(0, 1)
	player.skating = true
	for _i in 16:
		await get_tree().physics_frame
	player.external_move = Vector2.ZERO
	var err_chase := _save(chase)
	player.external_move_active = false
	var cam := Camera3D.new()
	cam.fov = 38.0
	main.add_child(cam)
	cam.current = true
	var stand := OS.get_environment("AU_FONY_STAND")
	if stand.is_empty():
		stand = "/tmp/hq-fony-stand.png"
	var skate := OS.get_environment("AU_FONY_SKATE")
	if skate.is_empty():
		skate = "/tmp/hq-fony-skate.png"
	var gameplay := OS.get_environment("AU_SCREENSHOT")
	if gameplay.is_empty():
		gameplay = "/tmp/hq-gameplay.png"
	player.global_position = Vector3(-22.0, 0.4, 4.0)
	player.rotation.y = 0.0
	player.velocity = Vector3.ZERO
	player.skating = false
	player.external_move_active = true
	player.external_move = Vector2.ZERO
	for _i in 40:
		await get_tree().physics_frame
	player.set_physics_process(false)
	player.rig.land_time = 0.0
	player.rig.was_airborne = false
	player.rig.drive(0.05, 0.0, false, false, false)
	player.rig.rotation.y = 0.15
	_frame(cam, player, Vector3(-1.25, 1.05, -3.5), Vector3(0.0, 0.85, 0.0))
	for _i in 4:
		await get_tree().process_frame
	print("stand sole ", player.rig.sole_y(), " ground ", player.global_position.y + 0.325, " pose ", player.rig.pose_name)
	var err_stand := _save(stand)
	player.set_physics_process(true)
	player.global_position = Vector3(-22.0, 0.4, -2.0)
	player.velocity = Vector3.ZERO
	player.skating = true
	player.camera_yaw = 0.0
	player.external_move = Vector2(0, 1)
	for _i in 50:
		await get_tree().physics_frame
		var speed: float = Vector2(player.velocity.x, player.velocity.z).length()
		if player.is_on_floor() and player.rig.pose_name == "skate" and speed > 2.0:
			break
	player.set_physics_process(false)
	player.rig.rotation.y = 0.15
	_frame(cam, player, Vector3(-1.25, 1.05, -3.5), Vector3(0.0, 0.8, 0.0))
	for _i in 4:
		await get_tree().process_frame
	print("skate sole ", player.rig.sole_y(), " deck ", player.rig.deck_top_y(), " pose ", player.rig.pose_name)
	var err_skate := _save(skate)
	player.set_physics_process(true)
	player.global_position = Vector3(-51.2, 0.5, -12.0)
	player.velocity = Vector3.ZERO
	player.skating = true
	player.camera_yaw = PI * 0.5
	player.external_move = Vector2(0, 1)
	for _i in 90:
		await get_tree().physics_frame
		if _i > 18 and player.global_position.x < -54.5 and player.is_on_floor():
			break
	player.set_physics_process(false)
	cam.fov = 40.0
	cam.global_position = Vector3(-55.2, 2.0, -5.5)
	cam.look_at(Vector3(-55.0, 0.9, -12.0))
	for _i in 4:
		await get_tree().process_frame
	print("ramp pos ", player.global_position, " floor_was_moving pose ", player.rig.pose_name)
	var err_ramp := _save(gameplay)
	var concept := OS.get_environment("AU_CONCEPT")
	if concept.is_empty():
		concept = "/tmp/hq-concept.png"
	cam.fov = 55.0
	cam.global_position = Vector3(-42.0, 18.0, 36.0)
	cam.look_at(Vector3(-8.0, 1.5, -22.0))
	for _i in 8:
		await get_tree().process_frame
	var err_concept := _save(concept)
	var zero_close := OS.get_environment("AU_ZERO_CLOSE")
	if zero_close.is_empty():
		zero_close = "/tmp/hq-zero-close.png"
	var zero = main.get_node_or_null("WorldSim/NPCZero")
	if zero != null:
		var zero_label = zero.get_node_or_null("NameLabel")
		if zero_label != null:
			zero_label.visible = false
	cam.fov = 26.0
	cam.global_position = Vector3(-2.6, 1.35, -58.6)
	cam.look_at(Vector3(-6.0, 1.15, -62.0))
	for _i in 6:
		await get_tree().process_frame
	var err_zero := _save(zero_close)
	get_tree().quit(0 if err_settings == OK and err_controls == OK and err_chase == OK and err_stand == OK and err_skate == OK and err_ramp == OK and err_concept == OK and err_zero == OK else 1)

func _frame(cam: Camera3D, player: Node3D, eye: Vector3, look: Vector3) -> void:
	cam.global_position = player.global_position + eye
	cam.look_at(player.global_position + look)

func _save(path: String) -> int:
	var image := get_viewport().get_texture().get_image()
	var err := image.save_png(path)
	print("screenshot ", path, " err ", err, " ", image.get_width(), "x", image.get_height())
	return err
