extends Node

func _ready() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	for _i in 20:
		await get_tree().process_frame
	var player = main.get_node("WorldSim/Player")
	player.external_move_active = true
	player.external_move = Vector2(0, 1)
	for _i in 18:
		await get_tree().physics_frame
	player.external_move = Vector2.ZERO
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
	cam.fov = 62.0
	main.add_child(cam)
	cam.global_position = Vector3(-55, 7.5, 78)
	cam.look_at(Vector3(18, 3.5, -22))
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
	get_tree().quit(0 if err1 == OK and err2 == OK and err3 == OK else 1)

func _save(path: String) -> int:
	var image := get_viewport().get_texture().get_image()
	var err := image.save_png(path)
	print("screenshot ", path, " err ", err, " ", image.get_width(), "x", image.get_height())
	return err
