extends Node
## Frames for the Act I checklist chunk (intro is a card, not a world shot).
## AU_SHOT_DIR, AU_SHOT_TAG. Renders under xvfb, not --headless.

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var dir := OS.get_environment("AU_SHOT_DIR")
	if dir == "":
		dir = "/tmp/pz-act1"
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
	var world: Node3D = main.get_node("WorldSim")
	var dressing := preload("res://scripts/story/story_world.gd").build(world)
	var cam := Camera3D.new()
	cam.fov = 42.0
	main.add_child(cam)
	cam.current = true
	var shots := [
		["mini", Vector3(-36.0, 4.2, -18.0), Vector3(-47.0, 0.8, -30.0)],
		["lanes", Vector3(-28.0, 2.6, -4.0), Vector3(-46.0, 0.1, -12.0)],
		["workshop", Vector3(-28.0, 6.0, -40.0), Vector3(-57.0, 2.4, -60.0)],
		["resistance", Vector3(-14.0, 5.0, -38.0), Vector3(2.0, 2.8, -58.0)],
		["docks", Vector3(-18.0, 5.0, -14.0), Vector3(2.0, 1.6, -24.0)],
		["billboard", Vector3(40.0, 18.0, -20.0), Vector3(110.0, 26.0, -20.0)],
	]
	var bad := false
	for shot in shots:
		cam.global_position = shot[1]
		cam.look_at(shot[2])
		for _i in 4:
			await get_tree().process_frame
		if _save("%s/%s-%s.png" % [dir, shot[0], tag]) != OK:
			bad = true
	dressing.queue_free()
	get_tree().quit(1 if bad else 0)

func _save(path: String) -> int:
	var image := get_viewport().get_texture().get_image()
	var err := image.save_png(path)
	print("screenshot ", path, " err ", err)
	return err
