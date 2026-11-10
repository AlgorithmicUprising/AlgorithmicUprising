extends Node

## Headless-friendly yard shots of Fony. Not part of the game.
##   AU_SHOT_DIR=/tmp/fony-shots godot --path open-world res://tools/shot_fony.tscn

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	for _i in 30:
		await get_tree().process_frame
	for child in main.get_children():
		if child is CanvasLayer:
			child.visible = false
	var player = main.get_node("WorldSim/Player")
	var label = player.get_node_or_null("NameLabel")
	if label != null:
		label.visible = false
	var out := OS.get_environment("AU_SHOT_DIR")
	if out.is_empty():
		out = "/tmp/fony-shots"
	DirAccess.make_dir_recursive_absolute(out)
	player.external_move_active = true
	player.external_move = Vector2.ZERO
	player.skating = false
	player.global_position = Vector3(-22.0, 0.4, 4.0)
	player.rotation.y = 0.0
	player.velocity = Vector3.ZERO
	for _i in 40:
		await get_tree().physics_frame
	player.set_physics_process(false)
	player.rig.land_time = 0.0
	player.rig.was_airborne = false
	player.rig.rotation.y = 0.0
	player.rig.drive(0.05, 0.0, false, false, false)
	var cam := Camera3D.new()
	cam.fov = 32.0
	main.add_child(cam)
	cam.current = true
	_aim(cam, player, Vector3(0.0, 1.05, -3.4), Vector3(0.0, 0.95, 0.0))
	await _save(out + "/fony-front.png")
	_aim(cam, player, Vector3(3.3, 1.05, -0.35), Vector3(0.0, 0.95, 0.0))
	await _save(out + "/fony-side.png")
	_aim(cam, player, Vector3(0.15, 1.05, 3.4), Vector3(0.0, 0.95, 0.0))
	await _save(out + "/fony-back.png")
	_aim(cam, player, Vector3(-2.3, 1.15, -2.5), Vector3(0.0, 0.95, 0.0))
	await _save(out + "/fony-three-quarter.png")
	player.set_physics_process(true)
	player.skating = true
	player.external_move = Vector2(0, 1)
	player.camera_yaw = 0.0
	for _i in 40:
		await get_tree().physics_frame
		if player.rig.pose_name == "skate":
			break
	player.set_physics_process(false)
	player.rig.rotation.y = 0.35
	_aim(cam, player, Vector3(-2.4, 1.15, -2.6), Vector3(0.0, 0.85, 0.0))
	await _save(out + "/fony-skate.png")
	print("shots written ", out, " pose ", player.rig.pose_name)
	get_tree().quit(0)

func _aim(cam: Camera3D, player: Node3D, eye: Vector3, look: Vector3) -> void:
	var rig: Node3D = player.rig
	var basis := rig.global_transform.basis
	cam.global_position = rig.global_position + basis * eye
	cam.look_at(rig.global_position + basis * look)

func _save(path: String) -> void:
	for _i in 4:
		await get_tree().process_frame
	var image := get_viewport().get_texture().get_image()
	var err := image.save_png(path)
	print("screenshot ", path, " ", err, " ", image.get_width(), "x", image.get_height())
