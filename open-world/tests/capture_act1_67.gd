extends Node
## Before/after frames of Zero's puppet and the grip-tape moment is not a world shot.
## AU_SHOT_DIR, AU_SHOT_TAG.

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var dir := OS.get_environment("AU_SHOT_DIR")
	if dir == "":
		dir = "/tmp/pz-67"
	var tag := OS.get_environment("AU_SHOT_TAG")
	if tag == "":
		tag = "before"
	DirAccess.make_dir_recursive_absolute(dir)
	var world := Node3D.new()
	add_child(world)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("1a1412")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("ffe0c8")
	e.ambient_light_energy = 0.85
	env.environment = e
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-28, 30, 0)
	sun.light_energy = 1.3
	world.add_child(sun)
	var puppet: Node3D = load("res://scripts/story/zero_puppet.gd").new()
	puppet.position = Vector3(0, 0, 0)
	world.add_child(puppet)
	var cam := Camera3D.new()
	cam.fov = 32.0
	world.add_child(cam)
	var bad := false
	var shots := [
		["zero-slump", "slump", 0.05, Vector3(0.0, 1.05, 2.4), Vector3(0.0, 0.7, 0.0)],
		["zero-shrug", "boot", 0.45, Vector3(0.35, 1.1, 2.35), Vector3(0.0, 0.75, 0.0)],
		["zero-awake", "awake", 0.1, Vector3(0.0, 1.15, 2.4), Vector3(0.0, 0.8, 0.0)],
		["zero-back", "awake", 0.05, Vector3(0.0, 1.15, -2.3), Vector3(0.0, 0.75, 0.0)],
	]
	for shot in shots:
		puppet.stage(str(shot[1]))
		var hold := float(shot[2])
		var steps := int(hold * 60.0)
		for _i in maxi(steps, 2):
			await get_tree().process_frame
		cam.global_position = shot[3]
		cam.look_at(shot[4])
		cam.current = true
		for _i in 3:
			await get_tree().process_frame
		if _save("%s/%s-67-%s.png" % [dir, shot[0], tag]) != OK:
			bad = true
	get_tree().quit(1 if bad else 0)

func _save(path: String) -> int:
	var image := get_viewport().get_texture().get_image()
	var err := image.save_png(path)
	print("screenshot ", path, " err ", err)
	return err
