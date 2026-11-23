extends Node
## Before/after frames for Act I checklist items 4 and 5.
## AU_SHOT_DIR, AU_SHOT_TAG. A fill light is only for the dark arcade shots.

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var dir := OS.get_environment("AU_SHOT_DIR")
	if dir == "":
		dir = "/tmp/pz-act1-45"
	var tag := OS.get_environment("AU_SHOT_TAG")
	if tag == "":
		tag = "before"
	DirAccess.make_dir_recursive_absolute(dir)
	var world := Node3D.new()
	add_child(world)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("c4a090")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("ffe0c8")
	e.ambient_light_energy = 0.55
	env.environment = e
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, 40, 0)
	sun.light_energy = 1.1
	world.add_child(sun)
	var row: Node3D = load("res://districts/glass_row_edge/glass_row_edge.tscn").instantiate()
	world.add_child(row)
	var arcade: Node3D = load("res://districts/solar_arcade_dark/solar_arcade_dark.tscn").instantiate()
	world.add_child(arcade)
	var fill := OmniLight3D.new()
	fill.light_energy = 2.2
	fill.omni_range = 18.0
	fill.light_color = Color("fff2e0")
	arcade.add_child(fill)
	for _i in 8:
		await get_tree().process_frame
	var cam := Camera3D.new()
	cam.fov = 42.0
	world.add_child(cam)
	cam.current = true
	var shots := [
		["alley", Vector3(96.0, 3.2, 29.0), Vector3(112.0, 1.4, 29.0), Vector3.ZERO],
		["shoppers", Vector3(136.0, 2.4, 12.0), Vector3(148.0, 1.0, 7.0), Vector3.ZERO],
		["grate", Vector3(158.0, 2.6, 18.0), Vector3(165.0, 0.3, 15.4), Vector3.ZERO],
		["sheets", Vector3(224.0, 2.4, -34.0), Vector3(230.0, 1.1, -40.2), Vector3(226.0, 2.2, -36.0)],
		["climb", Vector3(232.0, 2.2, -20.0), Vector3(236.0, 1.2, -14.0), Vector3(236.0, 1.6, -16.0)],
	]
	var bad := false
	for shot in shots:
		fill.global_position = shot[3] if shot[3] != Vector3.ZERO else fill.global_position
		cam.global_position = shot[1]
		cam.look_at(shot[2])
		for _i in 3:
			await get_tree().process_frame
		if _save("%s/%s-45-%s.png" % [dir, shot[0], tag]) != OK:
			bad = true
	get_tree().quit(1 if bad else 0)

func _save(path: String) -> int:
	var image := get_viewport().get_texture().get_image()
	var err := image.save_png(path)
	print("screenshot ", path, " err ", err)
	return err
