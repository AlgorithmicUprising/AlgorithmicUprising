extends Node

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	for _i in 30:
		await get_tree().process_frame
	if main.player != null and main.player.boost != null:
		main.player.boost.amount = 0.62
		main.player.boost.chain = 3
		main._sync_boost()
	await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	img.save_png("/opt/cursor/artifacts/boost-meter.png")
	get_tree().quit()
