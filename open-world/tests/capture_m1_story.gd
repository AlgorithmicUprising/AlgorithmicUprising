extends Node
## M1 (Nov 19 2026): story-mode evidence frames with a real renderer. Staged: it sets the P.1 state directly (Zero Score
## on the marquee, the face on the CRT) and parks a camera, because the arcade is ~100 m from the skate yard.
## Writes to $AU_M1_OUT: yard_free_roam.png, yard_dawn.png, marquee.png, crt_window.png. Run:
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --resolution 1280x720 res://tests/capture_m1_story.tscn

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var out := OS.get_environment("AU_M1_OUT")
	if out.is_empty():
		out = "/tmp/m1_story"
	DirAccess.make_dir_recursive_absolute(out)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _frames(20)
	main.flow.save_path = "user://m1-capture-save.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(main.flow.save_path))
	main.visual_demo = true          # hides the "Click to look" catcher
	var cam := Camera3D.new()
	cam.fov = 60.0
	main.world_sim.add_child(cam)
	cam.current = true
	var yard_from := Vector3(-30.0, 4.0, 14.0)
	var yard_at := Vector3(-50.0, 0.5, -4.0)
	await _shot(cam, yard_from, yard_at, out + "/yard_free_roam.png")
	var story = main.get_node("Story")
	story.start()
	story.queue.clear()
	story.card_left = 0.0
	story.hud.card("")
	await _frames(5)
	await _shot(cam, yard_from, yard_at, out + "/yard_dawn.png")
	await _shot(cam, Vector3(-48.0, 3.0, 26.0), Vector3(-48.0, -3.0, 48.0), out + "/bowl_dawn.png")
	story.zero_score = 4000
	story.World.marquee(story.dressing, "ZERO SCORE\n4,000")
	story.face_on = true
	story.World.crt(story.dressing, true, true)
	story.hud.say("VOICE (O.S.)", "A number. Beat it.")
	await _shot(cam, Vector3(32.0, 5.0, 22.0), Vector3(32.0, 6.5, -7.0), out + "/marquee.png")
	await _shot(cam, Vector3(58.3, 3.4, -4.4), Vector3(58.0, 1.6, -7.5), out + "/crt_window.png")
	get_tree().quit(0)

func _shot(cam: Camera3D, from: Vector3, at: Vector3, path: String) -> void:
	cam.global_position = from
	cam.look_at(at)
	await _frames(8)
	var img := get_viewport().get_texture().get_image()
	img.save_png(path)
	print("saved ", path)

func _frames(n: int) -> void:
	for _i in n:
		await get_tree().process_frame
