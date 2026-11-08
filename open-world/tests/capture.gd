extends Node

func _ready() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	for _i in 25:
		await get_tree().process_frame
	var path := OS.get_environment("AU_SCREENSHOT")
	if path.is_empty():
		path = "/tmp/hq-greybox.png"
	var image := get_viewport().get_texture().get_image()
	var err := image.save_png(path)
	print("screenshot ", path, " err ", err, " ", image.get_width(), "x", image.get_height())
	get_tree().quit(0 if err == OK else 1)
