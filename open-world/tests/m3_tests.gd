extends RefCounted
## Act I M3 (Nov 19 2026) headless tests: the polish (no prompts over cutscenes, the phone docked under the score
## stack), the A1 glass_row_edge district, and MISSION P.2 Run in the real park: the fence gap, the drones, caught ->
## checkpoint restart, both shortcut routes driven through the real physics, the culvert, the arcade door, the
## time-based Zero Score, reload and the end card. Run from test_main.gd or alone with AU_TEST_ONLY=m3.

const SaveScript = preload("res://contracts/save_record.gd")
const JsonFile = preload("res://scripts/json_file.gd")
const P2Run = preload("res://scripts/story/p2_run.gd")
const Hud = preload("res://scripts/story/story_hud.gd")

const SAVE := "user://m3-test-save.json"

var t: Node

func run(host: Node) -> void:
	t = host
	_data()
	_units()
	await _phone_dock()
	await _prompts_hidden()
	await _run_full()
	await _reload_mid_run()
	await _dock_after_restart()

func ok(cond: bool, name: String) -> void:
	t.expect(cond, "m3: " + name)

func frames(n: int) -> void:
	for _i in n:
		await t.get_tree().physics_frame

func _main() -> Node:
	# earlier suites can leave a park in the tree; its walls share this physics world (the east wall would block the gap)
	var left := 0
	for c in t.get_tree().root.find_children("*", "Node", true, false):
		if c.has_method("story_hides_prompts") and not c.is_queued_for_deletion():
			c.queue_free()
			left += 1
	if left > 0:
		print("m3: freed %d leftover park(s)" % left)
		await frames(3)
	var main = load("res://scenes/main.tscn").instantiate()
	t.add_child(main)
	await frames(10)
	main.flow.save_path = SAVE
	return main

func _done(main) -> void:
	var story = main.get_node("Story")
	story.stop()
	main.queue_free()
	await frames(3)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))

## A save that has played P.1 and both cinematics (the run is next).
func _seed_after_p3(extra := {}) -> void:
	var s = SaveScript.new()
	var m: Dictionary = s.mission("p1_practice_run")
	m["state"] = "done"
	m["completions"] = 1
	m["zero_score"] = 3500
	m["best_score"] = 4100
	for f in ["story_started", "p1_contact", "p1_deal_offered", "p2_heat_alert_seen", "p3_flagged_seen"]:
		s.set_flag(f)
	for k in extra:
		s.mission("p2_run")[k] = extra[k]
	var f := FileAccess.open(SAVE, FileAccess.WRITE)
	f.store_string(JSON.stringify(s.to_dict()))
	f.close()

# ------------------------------------------------------------------ data and units

func _data() -> void:
	var reg = JsonFile.read("res://data/districts.json")
	var a1: Dictionary = reg.get("districts", {}).get("glass_row_edge", {})
	ok(str(a1.get("pack", "")) == "districts/glass_row_edge.pck" and ResourceLoader.exists(str(a1.get("scene", ""))), "A1: glass_row_edge has its own pack and scene")
	ok(int(a1.get("budget_bytes", 0)) > 0 and int(a1.get("budget_bytes", 0)) <= 8 * 1024 * 1024 and a1.get("free_roam") == false, "A1: within the 8 MiB per-district cap, off in free roam")
	var b: Array = a1.get("bounds", [])
	ok(b.size() == 4 and float(b[0]) == 82.0 and float(b[2]) == 202.0 and float(b[1]) == -80.0 and float(b[3]) == 102.0, "A1: bounds x 82 .. 202, z -80 .. 102 (approved)")
	var presets := FileAccess.get_file_as_string("res://export_presets.cfg")
	ok(presets.contains("name=\"District glass_row_edge\"") and presets.contains("res://districts/glass_row_edge/glass_row_edge.tscn"), "A1: its own export preset (districts/ stay out of index.pck)")
	var cards = load("res://scripts/loading_cards.gd").read("res://data/loading_cards/glass_row_edge.json")
	ok(not cards.is_empty() and load("res://scripts/loading_cards.gd").validate(cards).get("ok") == true, "A1: loading cards are valid")
	var d: Dictionary = JsonFile.read("res://data/missions/p2_run.json")
	var ids: Array = d.get("checkpoints", []).map(func(c): return str(c.id))
	ok(ids == ["yard", "fence_gap", "plaza", "culvert"], "P.2 Run: checkpoints yard, fence gap, plaza, culvert %s" % [ids])
	ok(d.get("routes", {}).has("dock") and d.get("routes", {}).has("ramp"), "P.2 Run: two shortcut routes (dock ledge, parking ramp)")
	ok(d.get("toggles", {}).get("title_card") == false, "open call: no P.2 title card by default (toggle)")
	var p1: Dictionary = JsonFile.read("res://data/missions/p1_practice_run.json")
	ok(p1.get("toggles", {}).get("first_try_clean") == true, "open call: 6C \"Clean.\" plays on a first-try rail by default (toggle)")
	var said := JSON.stringify(d.get("lines", {})) + JSON.stringify(d.get("barks", {}))
	ok(said.contains("Comfort mist is available to Silver tier and above.") and said.contains("Left. The drain grate under the stairs is loose.") and said.contains("Drones scan faces, not backs."), "P.2 Run: script lines (kiosk, bus shelter, store window)")
	ok(not said.contains("VOICE"), "P.2 Run: Zero is ??? on screens and texts, no VOICE (O.S.)")

func _units() -> void:
	ok(P2Run.zero_for(47300) == 45000 and P2Run.zero_for(45000) == 40000 and P2Run.zero_for(12000) == 30000, "Zero time: the next whole 5 s below the first escape, never under 30 s")
	ok(P2Run.fmt_time(65400) == "1:05.4" and P2Run.fmt_time(0) == "0:00.0", "Zero time: m:ss.t")

# ------------------------------------------------------------------ polish

func _phone_dock() -> void:
	var hud = Hud.new()
	t.add_child(hud)
	await frames(3)
	hud.set_zero(3500, 4100)
	hud.set_score(22555, 1.0, 6, 1.3)
	hud.phone_open()
	hud.say_text("???", "A concerned observer. You're cold. Everyone's late when they're cold. Warm up.", false)
	hud.say_text("Fony", "who is this", true)
	await frames(3)
	ok(hud.phone_panel.visible and hud.layout_ok(), "phone: docked under the score stack (no overlap)")
	var col_bottom: float = hud.right_column.get_global_rect().end.y
	ok(hud.phone_panel.get_global_rect().position.y >= col_bottom, "phone: top %.0f >= score stack bottom %.0f" % [hud.phone_panel.get_global_rect().position.y, col_bottom])
	# a taller stack (a longer best line wraps in, the run's time board) pushes the phone down with it
	hud.best_label.text = "BEST LINE  16,125\nBEST TIME  1:05.4\nCAUGHT x2"
	await frames(3)
	ok(hud.layout_ok() and hud.phone_panel.get_global_rect().position.y >= hud.right_column.get_global_rect().end.y, "phone: follows a taller score stack")
	hud.talk_panel.visible = true
	hud.say("???", "x".repeat(200))
	await frames(2)
	ok(hud.layout_ok(), "phone: clear of the talk box")
	hud.queue_free()
	await frames(2)

func _prompts_hidden() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	var main = await _main()
	var story = main.get_node("Story")
	story.start()
	await frames(3)
	main.player.look_captured = false
	await frames(2)
	ok(main.look_catch.visible, "prompts: Click to look shows in play (look not captured)")
	story.cinematic.play("p2_heat_alert")
	await frames(3)
	ok(main.story_hides_prompts() and not main.look_catch.visible and main.prompt_label.text == "", "prompts: no Click to look (or any prompt) during a cinematic")
	story.cinematic.skip()
	story.cinematic.skip()
	await frames(3)
	await _done(main)

# ------------------------------------------------------------------ the run

func _run_full() -> void:
	_seed_after_p3()
	var main = await _main()
	var story = main.get_node("Story")
	var pl = main.player
	story.start()
	await frames(3)
	var run = story.run
	ok(story.phase == "p2_run" and run.active() and run.checkpoint == "yard", "P.2 Run: a save after P.3 starts the run in the Yard (%s, %s)" % [story.phase, run.state])
	ok(main.districts.state("glass_row_edge") != "off", "A1: armed when the run starts (%s)" % main.districts.state("glass_row_edge"))
	var wall = main.world_sim.find_child("YardWallEast", true, false)
	ok(wall != null and wall.collision_layer == 0 and not wall.visible and run.dressing.get_node_or_null("EastWallNorth") != null, "fence gap: the east wall opens at z 26 .. 32 for the run")
	for _i in 120:
		await t.get_tree().physics_frame
		if run.state == "run":
			break
	ok(run.state == "run" and pl.input_enabled and run.chase.active_count() == 1, "drones: the welfare drone chases first (%d active)" % run.chase.active_count())
	var a1 = null
	for _i in 120:
		await t.get_tree().physics_frame
		for c in main.world_sim.get_children():
			if c.has_meta("district_id") and c.get_meta("district_id") == "glass_row_edge":
				a1 = c
		if a1 != null:
			break
	ok(a1 != null and a1.get_node_or_null("DeliveryVan") != null and a1.get_node_or_null("DockLedge") != null and a1.get_node_or_null("GarageDeck") != null, "A1: the district is in (van, dock ledge, garage deck)")
	ok(story.spoken.any(func(l): return "Nice name" in str(l)) or story.queue.any(func(q): return "Nice name" in str(q[1])), "P.2 Run: Zero texts as ??? at the start")
	# enforcement drones after their delay
	for d in run.chase.drones:
		if d.kind == "enforcement":
			d.delay = 0.05
	await frames(4)
	ok(run.chase.active_count() == 3 and run.fired.has("enforcers"), "drones: two Warden enforcement drones join")
	# caught: stand still, a drone on top of him
	run.chase.grace = 0.0
	pl.velocity = Vector3.ZERO
	run.chase.drones[0].node.global_position = pl.global_position + Vector3(0.5, 3.0, 0.0)
	await frames(2)
	ok(run.state == "caught" and run.fails == 1 and story.hides_prompts(), "caught: the net drops, the screen fades, no lives (fails %d)" % run.fails)
	for _i in 200:
		await t.get_tree().physics_frame
		if run.state == "run":
			break
	ok(run.state == "run" and pl.global_position.distance_to(Vector3(62, 0.5, 29)) < 1.5 and run.log.has("restart:yard"), "caught: restart at the last checkpoint (Yard)")
	# out through the gap, dock route, the real physics
	run.chase.los_override = 1
	run.start_pilot("dock")
	var t0: float = run.clock
	for _i in 60 * 70:
		await t.get_tree().physics_frame
		if run.state == "done" or run.state == "caught":
			break
	print("m3 pilot dock ", run.pilot.log, " log=", run.log, " pos=", pl.global_position, " state=", run.state)
	ok(run.log.has("checkpoint:fence_gap") and run.log.has("checkpoint:plaza"), "dock route: through the fence gap and into the plaza (checkpoints)")
	ok(run.routes.has("dock") and main.flow.save.flag("p2_route_dock"), "dock route: up on the loading dock")
	ok(run.log.has("kiosk_off"), "plaza: the mister kiosk switches off as he passes")
	ok(run.log.any(func(e): return str(e).begins_with("screen:meter:face")) and run.log.any(func(e): return str(e).begins_with("screen:store:face")) and run.log.any(func(e): return str(e).begins_with("screen:bus:face")), "Zero hops across Glass Row's screens (meter, store window, bus shelter) %s" % [run.log])
	ok(story.hud.phone_log.any(func(e): return "drain grate" in str(e.text)), "Zero's screen lines land in the ??? thread too")
	ok(run.log.has("culvert") and run.log.has("checkpoint:culvert") and run.log.has("door"), "the drain grate -> the culvert -> the arcade's side door")
	ok(run.state == "done" and main.flow.save.flag("p2_run_done"), "P.2 Run: escaped (%s)" % run.state)
	var rec: Dictionary = main.flow.save.mission("p2_run")
	ok(rec.state == "done" and int(rec.completions) == 1 and int(rec.best_score) > 0 and int(rec.zero_score) > 0 and int(rec.zero_score) < int(rec.best_score), "Zero time: set just under the first escape (best %d ms, Zero %d ms)" % [int(rec.best_score), int(rec.zero_score)])
	for _i in 60:
		await t.get_tree().process_frame
		if story.phase == "p3_power":
			break
	ok(story.phase == "p3_power" and story.power.active() and main.player.global_position.x > 210.0, "the side door hands off to P.3 Power On inside the arcade (M4)")
	# P.3 itself is m4_tests.gd; finish it here so the slice ends
	story.power.fuses = {"coin_box": true, "toolbox": true, "fixture": true}
	story.power._finish()
	await frames(2)
	if story.in_cinematic():
		story.cinematic.skip()   # CINEMATIC P.4 (m4_tests.gd covers it)
	for _i in 600:
		story.talk_left = 0.001
		story.card_left = 0.0
		await t.get_tree().process_frame
		if story.phase == "slice_end" and story.queue.is_empty():
			break
	ok(story.phase == "slice_end" and story.spoken.any(func(l): return str(l).begins_with("CARD|") and "1.1" in str(l)), "end card after P.4: Act I 1.1 Fine Print is next")
	var disk = SaveScript.new()
	disk.load_user(SAVE)
	ok(disk.flag("p2_run_done") and int(disk.mission("p2_run").zero_score) == int(rec.zero_score), "save: the escape and Zero's time are on disk")
	# T after the slice: run it again, this time up the parking ramp under the camera
	story.retry()
	await frames(2)
	ok(story.phase == "p2_run" and run.checkpoint == "yard", "T after the slice runs P.2 again")
	for _i in 120:
		await t.get_tree().physics_frame
		if run.state == "run":
			break
	run.chase.los_override = 1
	run.start_pilot("ramp")
	for _i in 60 * 70:
		await t.get_tree().physics_frame
		if run.state == "done" or run.state == "caught":
			break
	print("m3 pilot ramp ", run.pilot.log, " log=", run.log, " pos=", pl.global_position, " state=", run.state)
	ok(run.routes.has("ramp") and run.log.has("camera"), "ramp route: up the parking ramp, seen by the drone camera")
	ok(run.state == "done" and int(main.flow.save.mission("p2_run").completions) == 2, "ramp route: escaped again")
	await frames(2)
	ok(story.phase == "p3_power" and story.power.fuses.is_empty(), "a replay after the slice goes back into the arcade with the fuses back in place")
	story.stop()
	await frames(2)
	ok(wall.collision_layer != 0 and wall.visible, "fence gap: the east wall closes again when the story stops")
	main.queue_free()
	await frames(3)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))

func _reload_mid_run() -> void:
	_seed_after_p3({"state": "active", "checkpoint": "plaza"})
	var main = await _main()
	var story = main.get_node("Story")
	story.start()
	await frames(3)
	ok(story.phase == "p2_run" and story.run.checkpoint == "plaza" and main.player.global_position.distance_to(Vector3(132, 0.5, 29)) < 1.5, "reload: a save mid-run resumes at its checkpoint (plaza)")
	await _done(main)
	_seed_after_p3({"state": "active", "checkpoint": "culvert"})
	main = await _main()
	story = main.get_node("Story")
	story.start()
	for _i in 90:
		await t.get_tree().physics_frame
		if story.run.state == "yard":
			break
	ok(story.run.state == "yard" and story.run.chase.active_count() == 0 and main.player.global_position.distance_to(Vector3(77.5, 0.5, -70)) < 1.5, "reload: from the culvert, no drones, straight to the door")
	await _done(main)


## The browser review path: caught at the fork, restarted at the fence gap, then the dock. Standing on the deck puts
## his origin at ~0.9 m (the ground reads -0.3), so the route check has to sit under that.
func _dock_after_restart() -> void:
	_seed_after_p3()
	var main = await _main()
	var story = main.get_node("Story")
	var pl = main.player
	story.start()
	var run = story.run
	for _i in 300:
		await t.get_tree().physics_frame
		if run.state == "run":
			break
	run.start_pilot("dock", true)
	var top := -9.0
	for _i in 60 * 40:
		await t.get_tree().physics_frame
		if pl.global_position.x > 104.0 and pl.global_position.x < 119.0:
			top = maxf(top, pl.global_position.y)
		if run.checkpoint == "plaza" or run.state == "done":
			break
	ok(run.log.has("restart:fence_gap") and run.checkpoint == "plaza", "dock after a restart: caught at the fork, back at the fence gap, on into the plaza %s" % [run.log])
	ok(run.routes.has("dock") and top > float(run.def.routes.dock.min_y), "dock after a restart: the deck counts as the dock route (top %.2f m)" % top)
	await _done(main)
