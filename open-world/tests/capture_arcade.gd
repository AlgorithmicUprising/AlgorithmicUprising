extends Node
## Arcade Phase 1 (LOCAL) review captures. Real renders of the HQ main scene.
##   OUT=dir [SHOT=name] [MODE=stills|clip] godot --path . --rendering-driver opengl3 --resolution 1920x1080 res://tests/capture_arcade.tscn
## stills: mockup angles A/B/C plus extra views, and per-view render stats with the Arcade on and off.
## clip:   gameplay camera, interact at the shutter -> roll-up -> fade -> interior -> leave -> fade -> roll-down.
##         Run with --fixed-fps 30 so every frame is captured.

const SHOTS := [
	["A_front_3q", Vector3(18, 2.1, 17), Vector3(38, 4.2, -8), 56.0],
	["B_aerial", Vector3(-6, 26, 34), Vector3(40, 3.0, -22), 50.0],
	["C_side_entry", Vector3(45.0, 1.75, 4.5), Vector3(57.0, 2.4, -8), 58.0],
	["D_shutter_closeup", Vector3(33.5, 1.7, 3.0), Vector3(32.0, 3.6, -8), 60.0],
	["E_west_mural", Vector3(-8.0, 3.0, -20.0), Vector3(8.0, 3.2, -27.0), 58.0],
	["F_back_mural", Vector3(39.0, 2.0, -49.6), Vector3(39.0, 2.8, -44.3), 62.0],
	["G_far_grazing", Vector3(66.0, 1.8, 2.0), Vector3(10.0, 4.0, -8.0), 50.0],
	["H_roof", Vector3(48.0, 16.0, 2.0), Vector3(40.0, 9.5, -26.0), 60.0],
]

## Interior views, in the room's local frame (arcade_interior.gd).
const INTERIOR_SHOTS := [
	["I_interior_wide", Vector3(31.0, 3.0, -9.6), Vector3(36.0, 1.2, -32.0), 66.0],
	["J_cabinet_rows", Vector3(29.0, 1.7, -13.0), Vector3(17.0, 1.3, -21.0), 60.0],
	["K_bars_per_watt_corner", Vector3(52.5, 2.2, -27.0), Vector3(63.5, 1.8, -40.0), 64.0],
	["L_featured_cabinet", Vector3(34.6, 2.0, -20.6), Vector3(32.0, 1.9, -25.0), 56.0],
	["M_counter_and_hq_cabinet", Vector3(25.0, 2.0, -29.5), Vector3(16.0, 1.4, -40.0), 62.0],
	["N_exit_view", Vector3(40.0, 2.4, -30.0), Vector3(36.0, 2.2, -8.3), 64.0],
]

var main: Node
var out := ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	out = OS.get_environment("OUT")
	if out.is_empty():
		out = "/tmp"
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	for _i in 20:
		await get_tree().process_frame
	if OS.get_environment("MODE") == "clip":
		await _clip()
	else:
		await _stills()
	get_tree().quit()

func _arcade_nodes() -> Array:
	var ws: Node = main.world_sim
	var nodes := []
	for n in ["ArcadeExterior", "SolarRoof", "ArcadeDoor"]:
		var node := ws.get_node_or_null(n)
		if node != null:
			nodes.append(node)
	return nodes

func _info() -> Dictionary:
	var vp := get_viewport()
	return {
		"draw_calls": vp.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME),
		"primitives": vp.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME),
		"objects": vp.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_OBJECTS_IN_FRAME),
		"shadow_draw_calls": vp.get_render_info(Viewport.RENDER_INFO_TYPE_SHADOW, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME),
		"shadow_primitives": vp.get_render_info(Viewport.RENDER_INFO_TYPE_SHADOW, Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME),
	}

func _static_tris() -> Dictionary:
	var tris := 0
	var meshes := 0
	for root in _arcade_nodes():
		var list: Array = root.find_children("*", "GeometryInstance3D", true, false)
		if root is GeometryInstance3D:
			list.append(root)
		for g in list:
			var mesh: Mesh = null
			var count := 1
			if g is MeshInstance3D:
				mesh = g.mesh
			elif g is MultiMeshInstance3D:
				mesh = g.multimesh.mesh
				count = g.multimesh.instance_count
			if mesh == null:
				continue
			meshes += 1
			for s in mesh.get_surface_count():
				var arr := mesh.surface_get_arrays(s)
				var idx = arr[Mesh.ARRAY_INDEX]
				var n: int = (idx.size() if idx != null and idx.size() > 0 else arr[Mesh.ARRAY_VERTEX].size()) / 3
				tris += n * count
	return {"tris": tris, "geometry_instances": meshes}

func _stills() -> void:
	for child in main.get_children():
		if child is CanvasLayer:
			child.visible = false
	var player = main.player
	var label = player.get_node_or_null("NameLabel")
	if label != null:
		label.visible = false
	player.global_position = Vector3(30.6, 0.95, -4.6)
	player.velocity = Vector3.ZERO
	player.rotation.y = 0.5
	var cam := Camera3D.new()
	add_child(cam)
	cam.current = true
	cam.far = 1200.0
	var only := OS.get_environment("SHOT")
	var report := {"static": _static_tris(), "views": {}}
	for s in SHOTS:
		if only != "" and not String(s[0]).contains(only):
			continue
		cam.fov = s[3]
		cam.global_position = s[1]
		cam.look_at(s[2])
		for _i in 10:
			await get_tree().process_frame
		var with_info := _info()
		get_viewport().get_texture().get_image().save_png(out + "/" + s[0] + ".png")
		for n in _arcade_nodes():
			n.visible = false
		for _i in 4:
			await get_tree().process_frame
		var without := _info()
		for n in _arcade_nodes():
			n.visible = true
		report.views[s[0]] = {"with_arcade": with_info, "without_arcade": without}
		print("saved ", s[0], " ", with_info)
	var door = main.world_sim.get_node_or_null("ArcadeDoor")
	if door != null:
		var inner: Node3D = door.ensure_interior()
		inner.visible = true
		for s in INTERIOR_SHOTS:
			if only != "" and not String(s[0]).contains(only):
				continue
			cam.fov = s[3]
			cam.global_position = inner.to_global(s[1])
			cam.look_at(inner.to_global(s[2]))
			for _i in 12:
				await get_tree().process_frame
			get_viewport().get_texture().get_image().save_png(out + "/" + s[0] + ".png")
			report.views[s[0]] = {"with_arcade": _info()}
			print("saved ", s[0], " ", report.views[s[0]])
		inner.visible = false
		report["interior"] = inner.stats
	var f := FileAccess.open(out + "/render_stats.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(report, "  "))
	print("static ", report.static)

func _clip() -> void:
	var player = main.player
	var label = player.get_node_or_null("NameLabel")
	if label != null:
		label.visible = false
	var door = main.world_sim.get_node("ArcadeDoor")
	var pcam: Camera3D = player.get_node("CameraPivot/SpringArm/Camera")
	# fixed yard camera for the outside parts, the gameplay camera inside
	var ycam := Camera3D.new()
	add_child(ycam)
	ycam.fov = 58.0
	ycam.global_position = Vector3(35.5, 2.3, 3.5)
	ycam.look_at(Vector3(32.0, 3.0, -7.7))
	player.global_position = Vector3(32.0, 0.95, -5.6)
	player.velocity = Vector3.ZERO
	player.rotation.y = 0.0
	player.camera_yaw = 0.0
	var frame := 0
	for _i in 30:
		await get_tree().process_frame
	for _i in 20:
		frame = await _step(frame, player, ycam, pcam)
	main._nearest(2.5).interact(main.flow)
	for _i in 30 * 3:
		frame = await _step(frame, player, ycam, pcam)
	# turn round inside to face the way out, then leave
	player.rotation.y = PI
	player.camera_yaw = PI
	for _i in 25:
		frame = await _step(frame, player, ycam, pcam)
	var exit_t = main._nearest(2.5)
	if exit_t != null:
		exit_t.interact(main.flow)
	for _i in 30 * 3 + 10:
		frame = await _step(frame, player, ycam, pcam)
	print("clip frames ", frame, " door state ", door.state, " entries ", door.entries, " exits ", door.exits)

func _step(frame: int, player, ycam: Camera3D, pcam: Camera3D) -> int:
	if player.global_position.x < -300.0:
		var door = main.world_sim.get_node("ArcadeDoor")
		var icam: Camera3D = get_node_or_null("InteriorCam")
		if icam == null:
			icam = Camera3D.new()
			icam.name = "InteriorCam"
			icam.fov = 62.0
			add_child(icam)
			icam.global_position = door.interior.to_global(Vector3(37.0, 3.2, -20.0))
			icam.look_at(door.interior.to_global(Vector3(32.0, 2.0, -8.3)))
		icam.make_current()
	else:
		ycam.make_current()
	await get_tree().process_frame
	return _grab(frame)

func _grab(frame: int) -> int:
	get_viewport().get_texture().get_image().save_png("%s/clip_%04d.png" % [out, frame])
	return frame + 1
