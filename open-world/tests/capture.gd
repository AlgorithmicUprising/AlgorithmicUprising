extends Node

func _ready() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	for _i in 20:
		await get_tree().process_frame
	var player = main.get_node("WorldSim/Player")
	player.global_position = Vector3(-48.0, 0.45, -12.0)
	player.camera_yaw = PI * 0.5
	player.external_move_active = true
	player.external_move = Vector2(0, 1)
	player.skating = true
	for _i in 16:
		await get_tree().physics_frame
	player.external_move = Vector2(0, 0.35)
	var gameplay := OS.get_environment("AU_SCREENSHOT")
	if gameplay.is_empty():
		gameplay = "/tmp/hq-gameplay.png"
	var concept := OS.get_environment("AU_CONCEPT")
	if concept.is_empty():
		concept = "/tmp/hq-concept.png"
	var err1 := _save(gameplay)
	for child in main.get_children():
		if child is CanvasLayer:
			child.visible = false
	var cam := Camera3D.new()
	cam.fov = 55.0
	main.add_child(cam)
	cam.global_position = Vector3(-42.0, 18.0, 36.0)
	cam.look_at(Vector3(-8.0, 1.5, -22.0))
	cam.current = true
	for _i in 12:
		await get_tree().process_frame
	var err2 := _save(concept)
	var duo := OS.get_environment("AU_CHARACTERS")
	if duo.is_empty():
		duo = "/tmp/hq-characters.png"
	player.global_position = Vector3(0.4, 0.2, -55.5)
	player.rotation.y = 0.15
	if player.rig != null:
		player.rig.rotation.y = 0.0
	cam.fov = 48.0
	cam.global_position = Vector3(3.6, 1.7, -49.5)
	cam.look_at(Vector3(-2.2, 1.2, -61.0))
	for _i in 8:
		await get_tree().process_frame
	var err3 := _save(duo)
	var fony_close := OS.get_environment("AU_FONY_CLOSE")
	if fony_close.is_empty():
		fony_close = "/tmp/hq-fony-close.png"
	player.global_position = Vector3(-8.0, 0.35, 8.0)
	player.velocity = Vector3.ZERO
	player.skating = true
	player.set_physics_process(false)
	if player.rig != null:
		player.rig.drive(0.1, 0.0, true, false, false)
		player.rig.rotation.y = atan2(-3.2, -3.4)
	var name_label = player.get_node_or_null("NameLabel")
	if name_label != null:
		name_label.visible = false
	cam.fov = 30.0
	cam.global_position = Vector3(-5.2, 1.45, 10.8)
	cam.look_at(Vector3(-8.0, 1.05, 8.0))
	for _i in 4:
		await get_tree().process_frame
	var err4 := _save(fony_close)
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
	var err5 := _save(zero_close)
	get_tree().quit(0 if err1 == OK and err2 == OK and err3 == OK and err4 == OK and err5 == OK else 1)

func _save(path: String) -> int:
	var image := get_viewport().get_texture().get_image()
	var err := image.save_png(path)
	print("screenshot ", path, " err ", err, " ", image.get_width(), "x", image.get_height())
	return err
