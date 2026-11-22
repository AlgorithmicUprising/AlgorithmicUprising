extends Node
## Before/after frames of the skate-yard ground and the greybox ramps.
## AU_SHOT_DIR, AU_SHOT_TAG. Renders under xvfb, not --headless.

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var dir := OS.get_environment("AU_SHOT_DIR")
	if dir == "":
		dir = "/tmp/pz-park"
	var tag := OS.get_environment("AU_SHOT_TAG")
	if tag == "":
		tag = "before"
	DirAccess.make_dir_recursive_absolute(dir)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	for _i in 25:
		await get_tree().process_frame
	for child in main.get_children():
		if child is CanvasLayer:
			child.visible = false
	var player: Node3D = main.get_node("WorldSim/Player")
	player.set_physics_process(false)
	player.visible = false
	var cam := Camera3D.new()
	cam.fov = 42.0
	main.add_child(cam)
	cam.current = true
	var shots := [
		["ground", Vector3(-30.0, 3.4, -4.0), Vector3(-48.0, 0.15, -8.0)],
		["funbox", Vector3(-40.0, 2.4, 6.0), Vector3(-48.0, 0.5, -2.0)],
		["bank", Vector3(-56.0, 2.6, 8.0), Vector3(-66.0, 0.7, 0.0)],
		["pad", Vector3(-30.0, 2.0, -6.0), Vector3(-38.0, 0.35, -12.0)],
		["runup", Vector3(-68.0, 2.4, 8.0), Vector3(-74.0, 0.7, 2.0)],
	]
	var bad := false
	for shot in shots:
		cam.global_position = shot[1]
		cam.look_at(shot[2])
		for _i in 4:
			await get_tree().process_frame
		if _save("%s/%s-%s.png" % [dir, shot[0], tag]) != OK:
			bad = true
	if OS.get_environment("AU_SHOT_GRIND") == "1":
		bad = await _grind_shot(main, player, cam, dir, tag) or bad
	get_tree().quit(1 if bad else 0)

func _grind_shot(main: Node, player, cam: Camera3D, dir: String, tag: String) -> bool:
	var rail := main.find_child("CopingEast", true, false) as Node3D
	if rail == null:
		print("screenshot grind missing rail")
		return true
	player.visible = true
	player.set_physics_process(true)
	player.skating = true
	player.global_position = rail.global_position + Vector3(0.1, -0.2, -0.6)
	player.velocity = Vector3(0.0, -1.0, 5.5)
	for _i in 8:
		await get_tree().physics_frame
		if player.grind != null:
			break
	if player.grind == null:
		player.grind_check(rail)
	for _i in 10:
		await get_tree().physics_frame
	player.set_physics_process(false)
	var focus: Vector3 = player.global_position + Vector3(0, 0.8, 0)
	cam.global_position = focus + Vector3(3.2, 1.6, 2.4)
	cam.look_at(focus)
	for _i in 6:
		await get_tree().process_frame
	return _save("%s/coping-grind-%s.png" % [dir, tag]) != OK

func _save(path: String) -> int:
	var image := get_viewport().get_texture().get_image()
	var err := image.save_png(path)
	print("screenshot ", path, " err ", err)
	return err
