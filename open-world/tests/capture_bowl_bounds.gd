extends Node
## Before/after frames of the yard bowl and the Glitchport edge (plaza north, fence-gap seam).
## AU_SHOT_DIR (default /tmp/pz-shots) and AU_SHOT_TAG (default before) name the pngs.
## Renders with a real viewport, so run under xvfb, not --headless.

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var dir := OS.get_environment("AU_SHOT_DIR")
	if dir == "":
		dir = "/tmp/pz-shots"
	var tag := OS.get_environment("AU_SHOT_TAG")
	if tag == "":
		tag = "before"
	DirAccess.make_dir_recursive_absolute(dir)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	for _i in 30:
		await get_tree().process_frame
	for child in main.get_children():
		if child is CanvasLayer:
			child.visible = false
	var player: Node3D = main.get_node("WorldSim/Player")
	var label := player.get_node_or_null("NameLabel")
	if label != null:
		label.visible = false
	player.set_physics_process(false)
	player.visible = false
	var cam := Camera3D.new()
	cam.name = "ShotCam"
	cam.fov = 46.0
	main.add_child(cam)
	cam.current = true
	# Three-quarter, high enough to see the floor of the pool and the deck around it.
	cam.fov = 42.0
	cam.global_position = Vector3(-24.0, 12.0, 30.0)
	cam.look_at(Vector3(-48.0, -1.5, 50.0))
	for _i in 8:
		await get_tree().process_frame
	var which := OS.get_environment("AU_SHOT_WHICH")
	var err1 := _save("%s/bowl-overview-%s.png" % [dir, tag])
	# From the north deck, looking down the transition so the curve, coping and flat bottom read.
	cam.fov = 36.0
	cam.global_position = Vector3(-48.0, 2.8, 18.0)
	cam.look_at(Vector3(-48.0, -0.6, 44.0))
	for _i in 6:
		await get_tree().process_frame
	var err2 := _save("%s/bowl-transition-%s.png" % [dir, tag])
	if which == "bowl":
		get_tree().quit(0 if err1 == OK and err2 == OK else 1)
		return
	# Glass Row is a district pack. Instance it beside the yard so the plaza edge and the seam are in frame.
	var edge: Node3D = load("res://districts/glass_row_edge/glass_row_edge.tscn").instantiate()
	main.get_node("WorldSim").add_child(edge)
	for _i in 4:
		await get_tree().process_frame
	# North edge of the plaza, east of the boutique, where the street used to open onto nothing.
	cam.fov = 42.0
	cam.global_position = Vector3(160.0, 3.6, 12.0)
	cam.look_at(Vector3(168.0, 0.6, -1.0))
	for _i in 6:
		await get_tree().process_frame
	var err3 := _save("%s/bounds-plaza-%s.png" % [dir, tag])
	# The yard's east wall / alley seam, just north of the run gap (z 26..32).
	cam.fov = 40.0
	cam.global_position = Vector3(90.0, 4.2, 16.0)
	cam.look_at(Vector3(81.0, 0.8, 24.0))
	for _i in 6:
		await get_tree().process_frame
	var err4 := _save("%s/bounds-seam-%s.png" % [dir, tag])
	var bad := err1 != OK or err2 != OK or err3 != OK or err4 != OK
	get_tree().quit(1 if bad else 0)

func _save(path: String) -> int:
	var image := get_viewport().get_texture().get_image()
	var err := image.save_png(path)
	print("screenshot ", path, " err ", err, " ", image.get_width(), "x", image.get_height())
	return err
