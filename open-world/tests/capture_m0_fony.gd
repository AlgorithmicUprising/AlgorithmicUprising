extends Node
## M0 (Nov 18 2026): Fony atlas quality evidence. Writes $AU_M0_OUT/game.png (the normal chase camera, HUD hidden),
## $AU_M0_OUT/close.png (a long-lens camera close on Fony, so atlas pixels are magnified) and prints the error of the
## imported front atlas against its source PNG (0 = lossless). Run with a real renderer:
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --resolution 1280x720 res://tests/capture_m0_fony.tscn

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var out := OS.get_environment("AU_M0_OUT")
	if out.is_empty():
		out = "/tmp/m0_fony"
	DirAccess.make_dir_recursive_absolute(out)
	_atlas_error("res://assets/library/fony2d/fony2d_puppet_v1_front_atlas.png")
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	for _i in 20:
		await get_tree().process_frame
	for child in main.get_children():
		if child is CanvasLayer:
			child.visible = false
	var player = main.get_node("WorldSim/Player")
	var label = player.get_node_or_null("NameLabel")
	if label != null:
		label.visible = false
	player.global_position = Vector3(-22.0, 0.4, 4.0)
	player.rotation.y = 0.0
	player.velocity = Vector3.ZERO
	player.skating = false
	player.external_move_active = true
	player.external_move = Vector2.ZERO
	for _i in 60:
		await get_tree().physics_frame
	# Freeze so both builds show the same frame.
	player.set_physics_process(false)
	Engine.time_scale = 0.0
	for _i in 4:
		await get_tree().process_frame
	_save(out.path_join("game.png"))
	var cam := Camera3D.new()
	cam.fov = 14.0
	main.add_child(cam)
	cam.current = true
	cam.global_position = player.global_position + Vector3(-1.0, 1.6, -7.5)
	cam.look_at(player.global_position + Vector3(0.0, 1.45, 0.0))
	for _i in 6:
		await get_tree().process_frame
	_save(out.path_join("close.png"))
	print("frame ", player.sprite_frame)
	get_tree().quit(0)

func _save(path: String) -> void:
	var img := get_viewport().get_texture().get_image()
	print("saved ", path, " ", img.save_png(path))

func _atlas_error(path: String) -> void:
	var tex: Texture2D = load(path)
	var got := tex.get_image()
	if got.is_compressed():
		got.decompress()
	got.convert(Image.FORMAT_RGBA8)
	var src := Image.load_from_file(ProjectSettings.globalize_path(path))
	src.convert(Image.FORMAT_RGBA8)
	var se := 0.0
	var n := 0
	var worst := 0.0
	for y in range(0, src.get_height(), 3):
		for x in range(0, src.get_width(), 3):
			var a := src.get_pixel(x, y)
			if a.a8 < int(OS.get_environment("AU_M0_ALPHA_MIN") if OS.get_environment("AU_M0_ALPHA_MIN") != "" else "128"):
				continue
			var b := got.get_pixel(x, y)
			for d in [a.r - b.r, a.g - b.g, a.b - b.b, a.a - b.a]:
				se += d * d
				worst = maxf(worst, absf(d))
			n += 4
	var mse := se / maxf(1.0, float(n))
	var psnr := INF if mse == 0.0 else 10.0 * log(1.0 / mse) / log(10.0)
	print("atlas_error ", path.get_file(), " opaque_samples=", n / 4, " mse=", mse, " psnr_db=", psnr, " max_err_8bit=", int(round(worst * 255.0)))
