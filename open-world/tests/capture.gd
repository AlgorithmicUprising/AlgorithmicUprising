extends Node

func _ready() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	for _i in 30:
		await get_tree().process_frame
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
	get_tree().quit(0 if err1 == OK and err2 == OK else 1)

func _save(path: String) -> int:
	var image := get_viewport().get_texture().get_image()
	var err := image.save_png(path)
	print("screenshot ", path, " err ", err, " ", image.get_width(), "x", image.get_height())
	return err
