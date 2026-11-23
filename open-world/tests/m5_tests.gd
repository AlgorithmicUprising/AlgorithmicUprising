extends RefCounted
## Act I scenes (Nov 20 2026) headless tests: act1.gd + data/missions/act1_scenes.json + the new district packs.
## Each scene is driven step by step (goals completed at their spots, topics asked, ice carried, the phone raised;
## lines and cards fast-forwarded, cinematics played at speed), then its saves, flags and hand-off are checked.
## The walking review autopilot is covered by the browser run (tools/act1-check.mjs). AU_TEST_ONLY=m5 runs it alone.

const SaveScript = preload("res://contracts/save_record.gd")
const JsonFile = preload("res://scripts/json_file.gd")
const Act1 = preload("res://scripts/story/act1.gd")

const SAVE := "user://m5-test-save.json"

var t: Node

func run(host: Node) -> void:
	t = host
	_data()
	if OS.get_environment("AU_TEST_ONLY") == "traverse":
		await _scene_1_5()
		return
	await _scene_1_1()
	await _reload_after(["1.1"])
	await _scene_1_2()
	await _scene_1_3()
	await _scene_1_4()
	await _scene_1_5()
	await _scene_1_6()

func ok(cond: bool, name: String) -> void:
	t.expect(cond, "m5: " + name)

func frames(n: int) -> void:
	for _i in n:
		await t.get_tree().physics_frame

func _main() -> Node:
	for c in t.get_tree().root.find_children("*", "Node", true, false):
		if c.has_method("story_hides_prompts") and not c.is_queued_for_deletion():
			c.queue_free()
	await frames(3)
	var main = load("res://scenes/main.tscn").instantiate()
	t.add_child(main)
	await frames(10)
	main.flow.save_path = SAVE
	return main

func _done(main) -> void:
	main.get_node("Story").stop()
	main.queue_free()
	await frames(3)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))

## A save after CINEMATIC P.4 (the Prologue done); done_scenes: Act I scene ids already finished.
func _seed(done_scenes: Array) -> void:
	var s = SaveScript.new()
	var m: Dictionary = s.mission("p1_practice_run")
	m["state"] = "done"
	m["completions"] = 1
	for f in ["story_started", "p1_contact", "p1_deal_offered", "p2_heat_alert_seen", "p3_flagged_seen", "p2_run_started", "p2_run_done", "p3_power_started", "p3_power_done", "p4_zero_seen", "zero_named"]:
		s.set_flag(f)
	var d = JsonFile.read(Act1.DEF_PATH)
	for id in done_scenes:
		s.set_flag(str(d.scenes[id].flag))
	var f := FileAccess.open(SAVE, FileAccess.WRITE)
	f.store_string(JSON.stringify(s.to_dict()))
	f.close()

## Fast-forward lines and cards until cond() or n frames.
func _until(story, cond: Callable, n := 900) -> bool:
	for _i in n:
		story.talk_left = minf(story.talk_left, 0.001)
		story.card_left = minf(story.card_left, 0.001)
		if story.cinematic != null:
			story.cinematic.time_scale = 60.0
		await t.get_tree().physics_frame
		if cond.call():
			return true
	return cond.call()

## Drive the current step of the scene the way a player would (teleport to each spot, then E).
func _drive_step(story, main) -> void:
	var a = story.act1
	var st: Dictionary = a.step
	match str(st.get("do", "")):
		"goals":
			for g in st.goals:
				if bool(g.get("optional", false)) and not bool(g.get("pilot", false)):
					continue
				if str(g.get("traverse", "")) != "" or bool(g.get("skate", false)):
					a.pilot = {"on": true}
					var guard := 0
					var limit := 900
					if str(g.get("traverse", "")) == "launch":
						limit = 5200
					elif str(g.get("traverse", "")) != "":
						limit = 1000
					var watch := str(a.step.get("counter", a.step.get("id", "")))
					while not a.done_goals.has(str(g.id)) and str(a.step.get("counter", a.step.get("id", ""))) == watch and guard < limit:
						guard += 1
						await t.get_tree().physics_frame
					a.pilot = {}
					main.player.external_move_active = false
					main.player.external_move = Vector2.ZERO
					main.player.external_jump = false
				else:
					_put(main, g.at, float(g.get("min_y", -9.0)) + 1.5 if g.has("min_y") else 0.5)
					await frames(2)
					if not a.done_goals.has(str(g.id)):
						a.complete(str(g.id))
				await _until(story, func(): return story.queue.is_empty() and story.talking == "", 400)
		"topics":
			for tp in st.topics:
				a.ask(str(tp.key))
				await _until(story, func(): return story.queue.is_empty() and story.talking == "", 400)
			a.ask("")
		"carry":
			for dv in st.deliveries:
				if a.done_goals.has(str(dv.id)):
					continue
				_put(main, st.locker, 0.5)
				await frames(2)
				a.take_load()
				_put(main, dv.at, 0.5)
				await frames(2)
				a.deliver(str(dv.id))
				await _until(story, func(): return story.queue.is_empty() and story.talking == "", 400)
		"raise":
			await frames(2)
			a.raise_phone()
		"defend":
			var guard := 0
			while a.state == "step" and str(a.step.get("do", "")) == "defend" and not a.waiting and guard < 3000:
				guard += 1
				for dr in a.drones:
					if is_instance_valid(dr.node) and dr.node.global_position.y < 3.0:
						_put(main, [dr.node.global_position.x, dr.node.global_position.z], 0.5)
						break
				a.reroute = minf(1.0, a.reroute + 0.01)
				await t.get_tree().physics_frame

func _put(main, at: Array, y: float) -> void:
	var pl = main.player
	pl.global_position = Vector3(float(at[0]), y, float(at[1]))
	pl.velocity = Vector3.ZERO

## Runs the scene that is playing to its end (or until the next scene starts).
func _play_scene(story, main, id: String) -> void:
	var a = story.act1
	var guard := 0
	while a.scene == id and a.active() and guard < 40:
		guard += 1
		await _until(story, func(): return a.scene != id or not a.active() or (a.state == "step" and not a.waiting and str(a.step.get("do", "")) in ["goals", "topics", "carry", "raise", "defend"]), 1200)
		if a.scene == id and a.active() and a.state == "step" and not a.waiting:
			await _drive_step(story, main)

func _data() -> void:
	var d = JsonFile.read(Act1.DEF_PATH)
	var want := ["1.1", "1.2", "1.3", "1.4", "1.5", "1.6"]
	ok(typeof(d) == TYPE_DICTIONARY and d.order.size() >= 5 and d.order == want.slice(0, d.order.size()) and d.scenes.size() == d.order.size(), "data: Act I scenes in script order (%s)" % ", ".join(d.order))
	for id in d.built:
		ok(d.order.has(id) and d.scenes.has(id), "data: built scene %s is in the order and defined" % id)
	var all := JSON.stringify(d)
	ok("held together by optimism" in all and "flag two hundred and six" in all and "Then go and see Nana Ines" not in all, "data: 1.1 Fine Print is the script's (1.1B's lines live in the cinematic)")
	var lines := JSON.stringify(d.scenes)
	ok(not "°C" in lines and not "at forty" in lines and "a hundred and four" in lines and "seventy-something degrees" in all, "data: Fahrenheit (no Celsius, the Flats at a hundred and four)")
	var cd = JsonFile.read("res://data/missions/prologue_cinematics.json")
	var plan := JSON.stringify(cd.cinematics.get("a1_plan", {}))
	ok("Bailey, say hello" in plan and "Then go and see Nana Ines." in plan and "a1_end_plan" in plan, "data: CINEMATIC 1.1B The plan (Bailey, the cooling center, Nana Ines; a skip lands the end state)")
	ok("{next}" in str(cd.slice_end.card) and "EARLY CUT" in str(cd.slice_end.card), "data: the end card names the next scene")
	var reg = JsonFile.read("res://data/districts.json")
	var presets := FileAccess.get_file_as_string("res://export_presets.cfg")
	for id in ["stillwater_flats", "cold_row"]:
		var e: Dictionary = reg.districts.get(id, {})
		ok(not e.is_empty() and int(e.budget_bytes) <= 8 * 1024 * 1024 and str(e.pack) == "districts/%s.pck" % id and ResourceLoader.exists(str(e.scene)) and ResourceLoader.exists(str(e.cards)), "registry: %s is its own pack inside the 8 MiB cap" % id)
		ok(("District " + id) in presets and ("build/web/districts/%s.pck" % id) in presets, "export: a District %s preset" % id)
	var room = load("res://districts/solar_arcade_dark/solar_arcade_dark.tscn").instantiate()
	t.add_child(room)
	ok(room.get_node_or_null("BaileyCabinet") != null and room.get_node_or_null("BaileySheet") != null and room.get_node_or_null("BaileySign").text == "GRIND THE TERMS" and room.get_node_or_null("Fan3") != null, "arcade pack: GRIND THE TERMS under a dust sheet, ceiling fans")
	room.queue_free()

func _scene_1_1() -> void:
	_seed([])
	var main = await _main()
	var story = main.get_node("Story")
	story.start()
	await frames(3)
	var a = story.act1
	ok(story.phase == "act1" and a.scene == "1.1" and a.active() and main.player.global_position.x > 236.0 and not main.player.skating, "after P.4: 1.1 Fine Print starts on foot at the workbench (%s %s)" % [story.phase, a.scene])
	ok(story.power.zero != null and story.power.zero.current == "awake" and story.hud.phone_sender == "ZERO", "1.1: Zero awake on the bench, ZERO in the thread")
	await _until(story, func(): return a.state == "step" and str(a.step.get("do", "")) == "goals" and not a.waiting)
	ok(story.spoken.any(func(l): return "held together by optimism" in str(l)) and story.spoken.any(func(l): return str(l).begins_with("CARD|ACT I: RUST & SIGNAL")), "1.1: the act card, then the board on the bench")
	main.player.global_position = Vector3(239.0, 0.5, -20.0)
	await frames(2)
	ok(a.in_reach().is_empty() and not a.complete("nope"), "1.1: nothing to do away from the bench")
	_put(main, [243.2, -26.0], 0.5)
	await frames(2)
	ok(str(a.in_reach().get("id", "")) == "zero" and a.complete("zero"), "1.1: E at the bench talks to Zero")
	await _until(story, func(): return str(a.step.get("do", "")) == "topics" and not a.waiting)
	ok(str(a.step.do) == "topics" and a.ask("skate") and not a.ask("skate"), "1.1: the topic menu (each topic once)")
	await _until(story, func(): return story.queue.is_empty() and story.talking == "", 400)
	ok(story.spoken.any(func(l): return "I fell off in my head" in str(l)), "1.1: Can you skate? No.")
	a.ask("what")
	await _until(story, func(): return story.queue.is_empty() and story.talking == "", 400)
	a.ask("")
	await _until(story, func(): return str(a.step.get("do", "")) == "goals" and not a.waiting)
	ok(main.flow.save.flag("upgrade_grip_tape") and main.player.grip_tape and story.spoken.any(func(l): return "Upgrade one." in str(l)) and not story.spoken.any(func(l): return "six years watching weeds" in str(l)), "1.1: the board back with grip tape (topics are optional: the skipped ones never play)")
	ok(main.player.GRIP_TAPE_PUSH_MULT > 1.0 and main.player.GRIP_TAPE_FRICTION_MULT < 1.0 and story.P4_TITLE_SONG == "", "1.1: grip tape changes the board; the P.4 title song hook is empty")
	await _drive_step(story, main)
	await _until(story, func(): return story.in_cinematic() or a.scene != "1.1", 600)
	ok(main.flow.save.flag("workshop_unlocked") and story.spoken.any(func(l): return str(l).begins_with("CARD|WORKSHOP")), "1.1: the workshop opens (upgrade one shown)")
	ok(story.in_cinematic() and story.cinematic.id == "a1_plan" and story.hud.letterbox_top.visible, "1.1B: The plan plays")
	await _until(story, func(): return not story.in_cinematic(), 2400)
	var room = a._district("solar_arcade_dark")
	ok(story.cinematic.ran.has("a1_plan:CAM") and story.cinematic.ran.has("a1_plan:HOST") and room.get_node("BaileySheet").visible == false and main.flow.save.flag("cabinet_grind_the_terms"), "1.1B: the sheet comes off GRIND THE TERMS; the cabinet unlocks")
	var play = room.get_node("BaileyPlay")
	ok(play.prompt() == "Play Grind the Terms", "1.1B: the unlocked cabinet offers the real game")
	play.interact(main.flow)
	ok(play.overlay != null and play.overlay.opens == 1 and play.overlay.game_id == "grind-the-terms" and play.overlay.last_path == "games/grind-the-terms/demo/embed.html", "1.1B: E opens the existing Grind the Terms page")
	play.overlay.close()
	ok(story.spoken.any(func(l): return "BAILEY|" in str(l) and "deny insurance claims" in str(l)) and story.spoken.any(func(l): return "Then go and see Nana Ines." in str(l)), "1.1B: Bailey says hello; Nana Ines")
	await _until(story, func(): return a.scene != "1.1" or story.phase == "slice_end", 600)
	var r: Dictionary = main.flow.save.mission("a1_fine_print")
	ok(main.flow.save.flag("a1_fine_print_done") and r.state == "done" and int(r.completions) == 1, "1.1: done, saved")
	if not a.def.built.has("1.2"):
		await _until(story, func(): return story.phase == "slice_end" and story.queue.is_empty(), 600)
		ok(story.phase == "slice_end" and story.spoken.any(func(l): return str(l).begins_with("CARD|") and "1.2 WATER RUN" in str(l)), "end card after 1.1: 1.2 Water Run is next")
	else:
		ok(a.scene == "1.2", "1.1 hands off to 1.2 Water Run")
	await _done(main)

## A reload after the given scenes: the next built scene starts, or the slice end names the next one.
func _reload_after(done: Array) -> void:
	_seed(done)
	var main = await _main()
	var story = main.get_node("Story")
	story.start()
	await frames(3)
	var a = story.act1
	var nxt: String = a.next_scene()
	if a.def.built.has(nxt):
		ok(story.phase == "act1" and a.scene == nxt, "reload after %s: %s starts" % [done, nxt])
	else:
		ok(story.phase == "slice_end" and story.power.zero != null, "reload after %s: the slice end in the lit arcade (%s next)" % [done, nxt])
	await _done(main)

## Starts the given scene from a save with the earlier scenes done (built or not: act1.start() runs any scene).
func _start_scene(id: String) -> Array:
	var d = JsonFile.read(Act1.DEF_PATH)
	var before: Array = []
	for x in d.order:
		if str(x) == id:
			break
		before.append(str(x))
	_seed(before)
	var main = await _main()
	var story = main.get_node("Story")
	story.start()
	await frames(3)
	if story.act1.scene != id:
		story.act1.start(id)
	await frames(3)
	return [main, story, story.act1]

func _talked(story) -> Callable:
	return func(): return story.queue.is_empty() and story.talking == ""

func _scene_1_2() -> void:
	var r = await _start_scene("1.2")
	var main = r[0]
	var story = r[1]
	var a = r[2]
	await _until(story, func(): return str(a.step.get("do", "")) == "carry" and not a.waiting)
	ok(a.scene == "1.2" and a._district("stillwater_flats") != null and main.player.global_position.x > 266.0 and preload("res://scripts/story/story_world.gd").sun_energy(main) > 1.0, "1.2: Stillwater Flats at noon (its own pack)")
	ok(story.spoken.any(func(l): return "You brought me a television" in str(l)) and story.hud.phone_sender == "ZERO", "1.2: Nana Ines meets Zero on the phone")
	var flats = a._district("stillwater_flats")
	var nana = flats.get_node_or_null("NanaInes")
	var tag = nana.get_node_or_null("Name") if nana != null else null
	var center: Dictionary = {}
	for dv in a.deliveries():
		if str(dv.id) == "center":
			center = dv
	ok(nana != null and nana.position.z > -18.5 and not center.is_empty() and float(center.at[1]) > -18.0, "1.2: the community center drop and Nana Ines stand clear of the wall (camera room)")
	var had_pilot: bool = not a.pilot.is_empty()
	a.pilot = {}
	main.player.external_move_active = false
	main.player.external_move = Vector2.ZERO
	main.player.global_position = Vector3(290.0, 0.5, -17.2)
	main.player.velocity = Vector3.ZERO
	main.player.camera_yaw = PI
	a._walk(center.get("via", []), center.at, "center-cam")
	a.pilot = {}
	main.player.external_move = Vector2.ZERO
	main.player.external_move_active = false
	await frames(8)
	ok(main.player.camera_distance() > 3.2, "1.2: the walk keeps the camera off the community-center wall (%.2f m)" % main.player.camera_distance())
	main.player.external_move = Vector2.ZERO
	main.player.external_move_active = false
	main.player.global_position = Vector3(310.0, 0.5, -40.0)
	main.player.velocity = Vector3.ZERO
	a.pilot = {"on": true} if had_pilot else {}
	ok(tag is Label3D and tag.visibility_range_begin >= 4.0, "name tags hide when the camera is right on them (close-ups)")
	a.bags = 0
	a.budget = int(a.step.budget)
	ok(a.delivery_in_reach().is_empty() and not a.deliver("delacroix"), "1.2: nothing to hand over with no ice")
	_put(main, a.step.locker, 0.5)
	await frames(2)
	ok(a.take_load() and a.bags == 8 and a.budget == 40 and a.melt > 70.0 and not a.take_load(), "1.2: a load of eight bags from the QuickDrop locker, melting")
	await _until(story, _talked(story), 400)
	ok(story.spoken.any(func(l): return "hostage situation with receipts" in str(l)), "1.2: Zero on surge comfort pricing")
	a.on_bail()
	await _until(story, _talked(story), 400)
	ok(a.bags == 7 and story.spoken.any(func(l): return "confusing and correct" in str(l)), "1.2: a bail drops a bag")
	_put(main, [280.0, -41.6], 0.5)
	await frames(2)
	ok(str(a.delivery_in_reach().get("id", "")) == "delacroix" and a.deliver("delacroix") and a.delivered == 7 and int(main.flow.save.story.signal) == 7, "1.2: delivered to Mr. Delacroix; Signal +7")
	await _until(story, _talked(story), 400)
	ok(story.spoken.any(func(l): return "For Biscuit?" in str(l)) and story.spoken.any(func(l): return str(l).begins_with("CARD|SIGNAL")), "1.2: his line, then the Signal tutorial card")
	_put(main, a.step.locker, 0.5)
	await frames(2)
	a.take_load()
	a.melt = 0.05
	await frames(4)
	ok(a.bags == 0 and a.log.has("melted"), "1.2: a load that melts is lost")
	await _drive_step(story, main)
	await _until(story, func(): return a.scene != "1.2" or not a.active() or story.phase == "slice_end", 1500)
	var rec: Dictionary = main.flow.save.mission("a1_water_run")
	ok(main.flow.save.flag("a1_water_run_done") and rec.state == "done" and int(rec.zero_score) == 12000 and int(rec.best_score) > 0, "1.2: all five delivered; done, Zero Score 12,000 saved (best %d)" % int(rec.best_score))
	ok(story.spoken.any(func(l): return "Your television is bossy." in str(l)) and int(main.flow.save.story.signal) >= 30, "1.2: the community center, afternoon; Signal %d" % int(main.flow.save.story.signal))
	await _done(main)

func _scene_1_3() -> void:
	var r = await _start_scene("1.3")
	var main = r[0]
	var story = r[1]
	var a = r[2]
	await _until(story, func(): return str(a.step.get("do", "")) == "goals" and not a.waiting)
	var pl = main.player
	ok(a.scene == "1.3" and pl.global_position.y > 5.0 and story.spoken.any(func(l): return "Black roofs drink the sun" in str(l)), "1.3: evening on the tar roofs, Nana Ines's speech")
	_put(main, [282.0, -70.0], 6.6)
	await frames(2)
	ok(a.complete("roof0"), "1.3: E coats the first roof")
	var room = a._district("stillwater_flats")
	var tar: MeshInstance3D = room.get_node("RoofTar0")
	ok(tar.material_override is StandardMaterial3D and tar.material_override.albedo_color.v > 0.9 and "97" in room.get_node("Temp0").text, "1.3: the roof turns white; the top floor drops to 97°F")
	_put(main, [290.0, -60.0], 0.5)
	await frames(3)
	ok(pl.global_position.y > 5.0 and a.log.has("reset:fell") and Vector2(pl.global_position.x - 282.0, pl.global_position.z + 70.0).length() < 1.0, "1.3: falling off puts him back on the last white roof")
	_put(main, [298.0, -70.0], 6.6)
	await frames(3)
	ok(pl.get_node_or_null("SprayCan") != null and pl.get_node("SprayCan").visible, "1.3: a spray can shows on a roof that still needs paint")
	var spray := InputEventAction.new()
	spray.action = "spray"
	spray.pressed = true
	Input.parse_input_event(spray)
	await frames(3)
	spray.pressed = false
	Input.parse_input_event(spray)
	ok(a.done_goals.has("roof1"), "1.3: the spray button coats the next roof")
	_put(main, [324.0, -70.0], 6.6)
	await frames(3)
	ok(a.done_goals.has("billboard_seen"), "1.3: near the billboard Zero describes the anatomy of a lie")
	ok(a.complete("billboard") and room.get_node("BillboardText").text.begins_with("AU") and not room.get_node("BillboardCam").visible and main.flow.save.flag("a1_billboard_tagged"), "1.3: the billboard tagged (camera sprayed over, AU and Zero X Humans)")
	await _drive_step(story, main)
	await _until(story, func(): return story.in_cinematic(), 900)
	ok(story.in_cinematic() and story.cinematic.id == "a1_first_night" and pl.global_position.x < 250.0 and a.root.get_node_or_null("Resident0") != null, "1.3B: First night in the arcade, the floor full of people")
	await _until(story, func(): return not story.in_cinematic(), 2400)
	ok(story.spoken.any(func(l): return "Watch what I do. Decide later." in str(l)) and story.spoken.any(func(l): return "I know where the power is." in str(l)), "1.3B: the little girl and Zero; I know where the power is")
	ok(story.power.zero != null and story.power.zero.global_position.x < 220.0, "1.3B: Zero by the entrance")
	await _until(story, func(): return a.scene != "1.3" or not a.active() or story.phase == "slice_end", 600)
	ok(main.flow.save.flag("a1_cool_roofs_done") and int(main.flow.save.mission("a1_cool_roofs").best_score) >= 15000, "1.3: done, saved")
	await _done(main)

func _scene_1_4() -> void:
	var r = await _start_scene("1.4")
	var main = r[0]
	var story = r[1]
	var a = r[2]
	a.def["built"] = ["1.1", "1.2", "1.3", "1.4"]  # this test ends on the slice card; 1.5 has its own
	await _until(story, func(): return str(a.step.get("do", "")) == "goals" and not a.waiting)
	ok(a.scene == "1.4" and a._district("cold_row") != null and a.drones.size() == 3 and story.spoken.any(func(l): return "seventy-something degrees" in str(l)), "1.4: Cold Row at night, three drones on patrol")
	var d0: Node3D = a.drones[0].node
	_put(main, [d0.global_position.x, d0.global_position.z], 0.5)
	await frames(2)
	ok(a.seen_by_drone(), "1.4: in a drone's range the WATCH meter fills")
	_put(main, [388.0, -71.0], 0.5)
	await frames(2)
	ok(a.in_mist(main.player.global_position), "1.4: the mist under a tower is a safe zone")
	a.watch = 0.99
	_put(main, [d0.global_position.x, d0.global_position.z], 0.5)
	await frames(30)
	ok(a.spotted == 1 and a.log.has("reset:spotted") and a.watch < 0.5, "1.4: WATCH full = SPOTTED, back to the start / last mark")
	await _drive_step(story, main)
	await _until(story, func(): return story.in_cinematic(), 900)
	ok(main.flow.save.mission("a1_cold_row").done.size() >= 3 and story.spoken.any(func(l): return "Mine too." in str(l)) and story.spoken.any(func(l): return "feel relaxed" in str(l)), "1.4: three marks; the workers overheard")
	ok(story.in_cinematic() and story.cinematic.id == "a1_benefactor" and a.root.get_node_or_null("Hologram") != null, "1.4B: the Benefactor broadcast, the hologram over the river")
	await _until(story, func(): return not story.in_cinematic(), 2400)
	ok(story.spoken.any(func(l): return "Introducing... the Warden Halo!" in str(l)) and a.root.get_node("Hologram").get_node_or_null("Halo") != null, "1.4B: Egon introduces the Warden Halo")
	await _until(story, func(): return str(a.step.get("do", "")) == "raise" and not a.waiting, 600)
	ok(str(a.step.get("do", "")) == "raise" and not main.flow.save.flag("zero_vision_unlocked"), "1.4B: waits until the phone is raised")
	ok(a.raise_phone() and a.vision and a.overlay.visible and a.root.get_node_or_null("Strings") != null and main.flow.save.flag("zero_vision_unlocked"), "Zero Vision: lime strings from his fingertips; unlocked")
	var strings = a.root.get_node_or_null("Strings")
	ok(strings is MultiMeshInstance3D and strings.multimesh.instance_count == 600 and (strings.multimesh.mesh.material as StandardMaterial3D).no_depth_test, "Zero Vision: 600 lime strands as boxes (they render on the web renderer), drawn over everything")
	ok(story.player.camera_pitch > 0.3, "Zero Vision: the camera tilts up at the hologram")
	ok(not story.hud.score_box.visible, "Act I scenes: the skate-combo SCORE box is hidden (scenes score in the box above)")
	await _until(story, func(): return not a.vision, 900)
	ok(story.spoken.any(func(l): return str(l).begins_with("CARD|ZERO VISION UNLOCKED")) and not a.overlay.visible, "Zero Vision: the unlock card, then the overlay fades")
	await _until(story, func(): return not a.active() or story.phase == "slice_end", 900)
	ok(story.spoken.any(func(l): return "Then we switch it." in str(l)) and story.spoken.any(func(l): return "whose power it was" in str(l)) and main.flow.save.flag("a1_cold_row_done"), "1.4B: Then we switch it. The slice is done.")
	await _until(story, func(): return story.phase == "slice_end" and story.queue.is_empty(), 600)
	ok(story.phase == "slice_end" and story.spoken.any(func(l): return str(l).begins_with("CARD|") and "1.5 THE BREAKER" in str(l) and "EARLY CUT" in str(l)), "end card after 1.4B: 1.5 The Breaker is next")
	await _done(main)

func _scene_1_5() -> void:
	var d = JsonFile.read(Act1.DEF_PATH)
	if not d.scenes.has("1.5"):
		return
	var r = await _start_scene("1.5")
	var main = r[0]
	var story = r[1]
	var a = r[2]
	a.def["built"] = ["1.1", "1.2", "1.3", "1.4", "1.5"]  # this test ends on the slice card; 1.6 has its own
	await _until(story, func(): return str(a.step.get("do", "")) == "goals" and not a.waiting)
	ok(a.scene == "1.5" and a._district("cold_row") != null and a.goals().size() == 6 and a.root.get_node_or_null("Cam0/Lens") != null and a.root.get_node_or_null("SwitchHouse") != null and a.drones.size() == 2, "1.5: six cameras around the substation, the switch house, two patrols")
	await _drive_step(story, main)
	await _until(story, func(): return str(a.step.get("counter", "")) == "GATE" and not a.waiting)
	ok(a.log.has("goal:cam5") and a.score >= 9000, "1.5: six cameras blinded (score %d)" % a.score)
	await _drive_step(story, main)
	await _until(story, func(): return str(a.step.get("counter", "")) == "PANEL" and not a.waiting)
	ok(main.player.global_position.x > 440.5 and str(main.player.grind_last.get("rail", "")) == "FenceRail", "1.5: he ground FenceRail to the switch house (x %.1f)" % main.player.global_position.x)
	await _drive_step(story, main)
	await _until(story, func(): return str(a.step.get("do", "")) == "defend", 900)
	ok(main.flow.save.flag("a1_switch_house_plugged") and story.spoken.any(func(l): return "I'm going to tell it the Flats are a hospital." in str(l)) and story.spoken.any(func(l): return "comfortable with the paperwork" in str(l)), "1.5: Zero on the panel (the hospital line)")
	await _until(story, func(): return a.drones.size() >= 1, 600)
	ok(a.drones.size() >= 1 and a.reroute > 0.0, "1.5: hold the line: drones fly in, the reroute climbs (step %s/%s drones %d reroute %.2f)" % [str(a.step.get("do", "")), str(a.step.get("counter", "")), a.drones.size(), a.reroute])
	if a.drones.is_empty():
		ok(false, "1.5: no drone spawned to knock down")
	else:
		var dr: Node3D = a.drones[0].node
		dr.global_position = Vector3(441.0, 1.4, -61.0)
		_put(main, [441.0, -61.0], 0.5)
		await frames(2)
		ok(a.knocked >= 1, "1.5: touching a drone knocks it down")
	await _drive_step(story, main)
	await _until(story, func(): return story.in_cinematic(), 900)
	ok(a.reroute >= 1.0 and story.spoken.any(func(l): return "Rerouting at sixty percent" in str(l)), "1.5: the reroute completes (Zero's sixty percent bark)")
	ok(story.cinematic.id == "a1_thermostat", "1.5B: the Thermostat cinematic")
	await _until(story, func(): return not story.in_cinematic(), 2400)
	ok(a.root.get_node_or_null("Thermostat/Capsule/EgonInCapsule") != null and story.spoken.any(func(l): return "Then they should have bought fans!" in str(l)) and a._frost_nodes().size() > 0, "1.5B: Egon in the Comfort Capsule; frost on the asphalt")
	await _until(story, func(): return str(a.step.get("counter", "")) == "VENTS" and not a.waiting)
	await _drive_step(story, main)
	await _until(story, func(): return str(a.step.get("counter", "")) == "EYES" and not a.waiting)
	ok(story.spoken.any(func(l): return "proprietary steam" in str(l)) and str((a.root.get_node("Thermostat/Dial") as Label3D).text) == "HEAT", "boss phase 1 done: three vents; the dial spins to HEAT")
	a.hz_t = 0.1
	_put(main, [414.0, -64.4], 0.5)
	await frames(2)
	ok(a.seen_by_drone(), "boss phase 2: the steam burns while it blows")
	a.hz_t = 2.2
	await frames(1)
	ok(not a.in_hazard(main.player.global_position), "boss phase 2: and stops")
	_put(main, [410.0, -77.0], 0.5)
	a.hz_t = 0.1
	await frames(1)
	ok(not a.seen_by_drone(), "boss phase 2: the tower mist hides him")
	await _drive_step(story, main)
	await _until(story, func(): return str(a.step.get("counter", "")) == "DIAL" and not a.waiting)
	ok(story.spoken.any(func(l): return "He thinks it's a personality." in str(l)), "boss phase 3: Zero calls the pattern")
	await _drive_step(story, main)
	await _until(story, func(): return a.goals().size() > 0 and str(a.goals()[0].id) == "dial" and not a.waiting)
	ok(main.player.global_position.y > 5.0 and str(main.player.get_meta("last_lip_pipe", "")) == "LoadingBayPipe", "boss phase 3: the loading-bay quarter pipe launches him onto the machine (y %.1f)" % main.player.global_position.y)
	await _drive_step(story, main)
	await _until(story, func(): return story.in_cinematic(), 900)
	ok(story.cinematic.id == "a1_lights_on", "1.5C: Lights on in the Flats")
	await _until(story, func(): return not story.in_cinematic(), 2400)
	ok(story.spoken.any(func(l): return "I'm logging a complaint!" in str(l)) and story.spoken.any(func(l): return "Already done." in str(l)) and main.flow.save.flag("a1_thermostat_beaten"), "1.5C: Egon flies off; Zero: Already done.")
	await _until(story, func(): return not a.active() or story.phase == "slice_end", 900)
	ok(main.flow.save.flag("a1_flats_lit") and story.spoken.any(func(l): return "THE YARD IS OPEN" in str(l)) and main.flow.save.flag("a1_the_breaker_done") and int(main.flow.save.mission("a1_the_breaker").best_score) >= 22000, "1.5: the Flats light up, Zero's billboard; done, saved (score %d)" % int(main.flow.save.mission("a1_the_breaker").get("best_score", 0)))
	await _until(story, func(): return story.phase == "slice_end" and story.queue.is_empty(), 600)
	var nxt := "1.6 HEAT BREAK" if d.order.has("1.6") else "ACT II"
	ok(story.phase == "slice_end" and story.spoken.any(func(l): return str(l).begins_with("CARD|") and nxt in str(l) and "EARLY CUT" in str(l)), "end card after 1.5C names %s" % nxt)
	await _done(main)

func _scene_1_6() -> void:
	var d = JsonFile.read(Act1.DEF_PATH)
	if not d.scenes.has("1.6"):
		return
	var r = await _start_scene("1.6")
	var main = r[0]
	var story = r[1]
	var a = r[2]
	var sig0 := int(main.flow.save.story.get("signal", 0))
	await _until(story, func(): return str(a.step.get("do", "")) == "goals" and not a.waiting)
	ok(a.scene == "1.6" and a._district("stillwater_flats") != null and a.root.get_node_or_null("Derelict") != null and a.root.get_node_or_null("DustyCabinet") != null and a.goals().size() == 4, "1.6: the heat-break days in the Flats (paint, aid, salvage, a cabinet)")
	_put(main, a.goals()[0].at, 0.5)
	main.player.skating = false
	ok(not a.complete("paint"), "1.6: standing still does not finish a skated beat")
	await _drive_step(story, main)
	await _until(story, func(): return str(a.step.get("counter", "")) == "MET" and not a.waiting, 900)
	ok(int(main.flow.save.story.get("signal", 0)) >= sig0 + 20 and main.flow.save.flag("a1_cabinet_found") and story.spoken.any(func(l): return str(l).begins_with("CARD|DAY 6 · SALVAGE")), "1.6: four days, Signal +20, a cabinet found")
	ok(main.player.input_enabled, "1.6: free to move again in the Yard (the browser pilot stalled here)")
	ok(main.flow.save.flag("a1_yard_grown") and a.root.get_node_or_null("ShadeCloth") != null and a.root.get_node_or_null("ClinicWoman") != null and main.player.global_position.z > 5.0 and absf(main.player.global_position.x - 32.0) < 6.0, "1.6: the Yard has grown (shade cloth, water, cots, the new people)")
	await _drive_step(story, main)
	await _until(story, func(): return story.in_cinematic(), 900)
	ok(story.cinematic.id == "a1_rain", "1.6B: The rain")
	await _until(story, func(): return not story.in_cinematic(), 2400)
	var mural := a.root.get_node_or_null("YardMural") as Node3D
	var on_wall := mural != null and mural.position.x > 24.4 and mural.position.x < 27.8 and mural.position.z > -7.75 and mural.position.z < -7.5
	ok(a.root.get_node_or_null("Rain") != null and mural != null and mural.get_node_or_null("TheYardSign") != null and on_wall and bool(mural.get_meta("placeholder", false)) and main.flow.save.flag("a1_the_yard_named") and story.spoken.any(func(l): return "harder to bulldoze" in str(l)) and story.spoken.any(func(l): return "You're going to need a coach." in str(l)), "1.6B: rain, the coach line, THE YARD painted on the wall beside the door")
	await _until(story, func(): return not a.active() or story.phase == "slice_end", 900)
	ok(story.spoken.any(func(l): return str(l).begins_with("CARD|END OF ACT I.")) and main.flow.save.flag("a1_heat_break_done"), "END OF ACT I.")
	await _until(story, func(): return story.phase == "slice_end" and story.queue.is_empty(), 600)
	ok(story.phase == "slice_end" and story.spoken.any(func(l): return str(l).begins_with("CARD|") and "ACT II · 2.1 BACK TO PRACTICE" in str(l)), "the end card points at Act II 2.1 Back to Practice")
	await _done(main)
