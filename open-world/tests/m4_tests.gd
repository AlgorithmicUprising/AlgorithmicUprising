extends RefCounted
## Act I M4 (Nov 20 2026) headless tests: MISSION P.3 Power On in the dark Solar Arcade pack. Data and the pack, the
## hand-off from P.2 Run's door, the three fuses and the breaker walked by the autopilot through the real physics
## (climbing the toppled cabinet for the fixture), the thermal sweep's reset to the last fuse, reload mid-P.3 and the
## end card that hands off to CINEMATIC P.4 Zero. Run from test_main.gd or alone with AU_TEST_ONLY=m4.

const SaveScript = preload("res://contracts/save_record.gd")
const JsonFile = preload("res://scripts/json_file.gd")
const P3 = preload("res://scripts/story/p3_power_on.gd")
const Sfx = preload("res://scripts/story/sfx.gd")
const World = preload("res://scripts/story/story_world.gd")

const SAVE := "user://m4-test-save.json"

var t: Node

func run(host: Node) -> void:
	t = host
	_data()
	await _power_full()
	await _reload_mid()
	await _p4_skip_and_reload()

func ok(cond: bool, name: String) -> void:
	t.expect(cond, "m4: " + name)

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

## A save that has escaped in P.2 Run (P.3 is next).
func _seed_after_run(extra := {}) -> void:
	var s = SaveScript.new()
	var m: Dictionary = s.mission("p1_practice_run")
	m["state"] = "done"
	m["completions"] = 1
	m["zero_score"] = 3500
	for f in ["story_started", "p1_contact", "p1_deal_offered", "p2_heat_alert_seen", "p3_flagged_seen", "p2_run_started", "p2_run_done"]:
		s.set_flag(f)
	var r: Dictionary = s.mission("p2_run")
	r["state"] = "done"
	r["completions"] = 1
	r["zero_score"] = 30000
	r["best_score"] = 36000
	for k in extra:
		s.mission(P3.ID)[k] = extra[k]
	var f := FileAccess.open(SAVE, FileAccess.WRITE)
	f.store_string(JSON.stringify(s.to_dict()))
	f.close()

func _data() -> void:
	var d = JsonFile.read(P3.DEF_PATH)
	ok(typeof(d) == TYPE_DICTIONARY and d.get("fuses", {}).size() == 3 and d.has("breaker") and d.has("end_card"), "data: three fuses, the breaker, the end card")
	var intro := str(d.get("lines", {}).get("intro", []))
	ok("ninety-eight" in intro and "a hundred and fifteen" in intro and not "thirty-seven" in intro and not "forty-six" in intro, "data: the sweep line is in Fahrenheit (98.6 body, 115 room)")
	ok("DO NOT RECONNECT" in intro and "P.4" in str(d.get("end_card", "")), "data: the breaker label; the end card hands off to CINEMATIC P.4 Zero")
	var reg = JsonFile.read("res://data/districts.json")
	var e: Dictionary = reg.districts.get("solar_arcade_dark", {})
	ok(not e.is_empty() and int(e.budget_bytes) <= 8 * 1024 * 1024 and str(e.pack) == "districts/solar_arcade_dark.pck" and ResourceLoader.exists(str(e.scene)), "registry: the dark arcade is its own pack inside the 8 MiB cap")
	var presets := FileAccess.get_file_as_string("res://export_presets.cfg")
	ok("District solar_arcade_dark" in presets and "build/web/districts/solar_arcade_dark.pck" in presets, "export: a District solar_arcade_dark preset")
	var cd = JsonFile.read("res://data/missions/prologue_cinematics.json")
	var p4: Dictionary = cd.get("cinematics", {}).get("p4_zero", {})
	var steps := JSON.stringify(p4.get("steps", []))
	ok(not p4.is_empty() and "Hi. I'm Zero." in steps and "PROJECT ZERO: THE ALGORITHMIC UPRISING" in steps and "p4_header" in steps and str(p4.get("flag", "")) == "p4_zero_seen" and p4.get("end_state", {}).get("host", []).has("p4_end_state"), "data: CINEMATIC P.4 Zero (beats, the header hook, the title card; a skip lands the end state)")
	ok("eighty-five degrees" in steps and not "thirty degrees" in steps, "data: P.4 in Fahrenheit (the warehouse stays under eighty-five)")
	var Puppet = load("res://scripts/story/zero_puppet.gd")
	var z = Puppet.new()
	t.add_child(z)
	ok(z.body.texture != null and z.head_card.texture != null and z.face.texture != null and not z.body.double_sided and "ZR-0" in z.back_plate.text and z.back_plate.get_parent() == z.head, "Zero puppet: the sheet's layers as single-sided cards; the ZR-0 plate on the back of the CRT")
	z.stage("awake")
	ok(z.visible and z.face.visible, "Zero puppet: stages")
	z.queue_free()
	ok(Sfx.CUES.has("pickup") and Sfx.CUES.has("breaker") and Sfx.make("breaker").data.size() > 0, "sfx: synthesized pickup and breaker cues (no audio files)")
	ok(P3._bar(0.0) == "[----------]" and P3._bar(0.55) == "[#####-----]" and P3._bar(0.55).to_ascii_buffer().get_string_from_ascii() == P3._bar(0.55), "the sweep bar is plain ASCII (no tofu glyphs)")
	var room = load(str(e.scene)).instantiate()
	t.add_child(room)
	ok(room.get_node_or_null("BreakerLabel") != null and room.get_node_or_null("FuseCoinBox") != null and room.get_node_or_null("FuseToolbox") != null and room.get_node_or_null("FuseFixture") != null and room.get_node_or_null("ToppledCabinet") != null and room.get_node_or_null("BenchCRT") != null, "pack: breaker, three fuses, the toppled cabinet, the CRT on the workbench")
	ok(room.get_node_or_null("Cabinet0/Cloth") != null and room.get_node_or_null("ToppledCabinet/CabinetShell") != null, "pack: the cabinets wear cloth and the climb reads as the fallen cabinet")
	ok(P3.P3_SWEEP_S == 100.0 and P3.P3_SWEEP_FAIL == "last_fuse", "P.3: sweep length and the last-fuse reset are the named defaults")
	room.queue_free()

func _power_full() -> void:
	_seed_after_run()
	var main = await _main()
	var story = main.get_node("Story")
	var pl = main.player
	story.start()
	story.act1.def["built"] = []   # the Act I scenes are m5_tests.gd: here the slice ends after P.4
	await frames(3)
	var p = story.power
	ok(story.phase == "p3_power" and p.active() and p.state == "intro", "a save after the escape starts P.3 in the arcade (%s, %s)" % [story.phase, p.state])
	ok(pl.global_position.x > 210.0 and not pl.skating and story.hides_prompts(), "on foot inside the arcade; no prompts while the INT. lines play")
	for _i in 900:
		story.talk_left = minf(story.talk_left, 0.001)
		story.card_left = 0.0
		await t.get_tree().physics_frame
		if p.state == "play":
			break
	ok(p.state == "play" and pl.input_enabled and story.spoken.any(func(l): return "a hundred and fifteen" in str(l)), "intro: the CRT's whisper (Fahrenheit), then play")
	var room = null
	for c in main.world_sim.get_children():
		if c.has_meta("district_id") and c.get_meta("district_id") == "solar_arcade_dark":
			room = c
	ok(room != null, "the dark arcade pack is in")
	ok(World.sun_energy(main) == 0.0 and room.get_node_or_null("RoofPanel2") != null and room.get_node_or_null("CrtGlow") is OmniLight3D and room.get_node_or_null("ExitGlow") is OmniLight3D, "dark inside: no sun, the roof closed, lit by practicals (CRT, exit sign, bench lamp)")
	var shaft = room.get_node_or_null("LightShaft2")
	ok(shaft != null and shaft.material_override != null and shaft.material_override.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA, "the broken-panel light shafts are a thin haze, not solid pillars")
	var sign = room.get_node_or_null("BreakerLabel")
	var lever = room.get_node_or_null("BreakerLever")
	ok(lever != null and sign != null and lever.global_position.y + 0.17 < sign.global_position.y - 0.2, "the breaker lever sits under the sign (no longer covers IT TALKS)")
	ok(sign != null and sign.billboard == BaseMaterial3D.BILLBOARD_DISABLED and sign.pixel_size < 0.01 and "\n" in sign.text, "the breaker sign: flat on the box, two lines, small enough to fit on screen")
	await frames(2)
	ok(story.hud.zero_label.text.begins_with("FUSES") and story.hud.best_label.text.begins_with("SWEEP") and not "ZERO TIME" in story.hud.zero_label.text, "HUD: no ZERO TIME in the arcade; the score box shows the fuses and the sweep (%s)" % story.hud.zero_label.text)
	ok(not p.interact(), "nothing to take at the door")
	# the sweep finds him once (shortened), the room resets to the last fuse found
	p.def["sweep_s"] = 1000.0
	p.start_pilot(true)
	for _i in 60 * 40:
		story.talk_left = minf(story.talk_left, 0.001)
		await t.get_tree().physics_frame
		if p.fuses.size() >= 1:
			break
	ok(p.fuses.has("coin_box") and p.last_fuse == "coin_box" and main.flow.save.flag("p3_fuse_coin_box"), "fuse 1: the coin box (%s)" % [p.log])
	ok(room != null and not room.get_node("FuseCoinBox").visible, "the coin-box fuse is gone from the cabinet")
	p.sweep = 1.0
	for _i in 30:
		await t.get_tree().physics_frame
		if p.state == "found":
			break
	ok(p.state == "found" and p.fails == 1 and story.hides_prompts(), "the sweep reaches him: found, fade")
	for _i in 300:
		await t.get_tree().physics_frame
		if p.state == "play":
			break
	ok(p.state == "play" and p.fuses.has("coin_box") and p.sweep < 0.1 and Vector2(pl.global_position.x - 230.0, pl.global_position.z + 37.0).length() < 1.0 and p.log.has("reset:coin_box"), "reset to the last fuse found; the fuse stays found (%s)" % pl.global_position)
	p.def["sweep_s"] = 100.0
	story.cinematic.time_scale = 40.0
	for _i in 60 * 90:
		story.talk_left = minf(story.talk_left, 0.001)
		story.card_left = 0.0
		await t.get_tree().physics_frame
		if p.state == "done" or p.state == "power":
			break
	print("m4 pilot ", p.log, " pos=", pl.global_position, " fuses=", p.fuses.keys())
	ok(p.fuses.has("toolbox"), "fuse 2: the toolbox under the workbench")
	ok(p.fuses.has("fixture"), "fuse 3: the light fixture, up the toppled cabinet")
	ok(p.log.has("breaker") and story.spoken.any(func(l): return "CLUNK" in str(l)), "the breaker thrown with all three fuses")
	for _i in 900:
		story.talk_left = minf(story.talk_left, 0.001)
		story.card_left = 0.0
		await t.get_tree().physics_frame
		if story.phase == "slice_end" and story.queue.is_empty():
			break
	ok(p.state == "done" and main.flow.save.flag("p3_power_done") and main.flow.save.flag("p4_zero_seen") and story.phase == "slice_end", "P.3 done at the breaker; CINEMATIC P.4 plays; the slice ends after it (%s)" % story.phase)
	var ran: Array = story.cinematic.ran
	ok(ran.has("p4_zero:CAM") and ran.has("p4_zero:HOST") and ran.has("p4_zero:CARD"), "P.4: fixed cameras in the arcade, the story hooks, the title card")
	ok(story.spoken.any(func(l): return "Hi. I'm Zero." in str(l)) and story.spoken.any(func(l): return "The heat won't." in str(l)), "P.4: \"Hi. I'm Zero.\" ... \"The contest will wait. The heat won't.\"")
	ok(p.lit != null and p.log.has("power_on") and World.sun_energy(main) == 0.0, "P.4: the power cascade lights the room (still no sun inside)")
	ok(p.zero != null and p.zero.visible and p.zero.current == "awake" and p.zero.face.visible, "P.4: Zero, the cutout puppet, is awake on the workbench")
	var placeholder = room.get_node_or_null("BenchCRT") if room != null else null
	ok(placeholder != null and not placeholder.visible, "P.4: the blockout torso and CRT give way to the puppet")
	ok(story.hud.phone_sender == "ZERO" and story.hud.phone_name.text == "ZERO", "P.4: the phone thread header changes from ??? to ZERO")
	ok(story.spoken.any(func(l): return str(l).begins_with("CARD|") and "1.1" in str(l)), "end card: Act I 1.1 Fine Print is next")
	ok(story.sfx.played.has("pickup") and story.sfx.played.has("breaker"), "sfx: pickup and breaker played")
	story.retry()
	await frames(2)
	ok(story.phase == "p2_run" and World.sun_energy(main) > 0.5 and "ZERO TIME" in story.hud.zero_label.text, "T after the slice: back out to the Yard's dawn, ZERO TIME back on the HUD")
	await _done(main)

func _p4_skip_and_reload() -> void:
	# saved between the breaker and P.4: P.4 plays; skipping it still lands power, Zero and the ZERO header
	var s = SaveScript.new()
	for f in ["story_started", "p1_contact", "p1_deal_offered", "p2_heat_alert_seen", "p3_flagged_seen", "p2_run_started", "p2_run_done", "p3_power_started", "p3_power_done"]:
		s.set_flag(f)
	var m: Dictionary = s.mission("p1_practice_run")
	m["state"] = "done"
	m["completions"] = 1
	var f := FileAccess.open(SAVE, FileAccess.WRITE)
	f.store_string(JSON.stringify(s.to_dict()))
	f.close()
	var main = await _main()
	var story = main.get_node("Story")
	story.start()
	story.act1.def["built"] = []   # the Act I scenes are m5_tests.gd: here the slice ends after P.4
	await frames(3)
	ok(story.in_cinematic() and story.cinematic.id == "p4_zero" and main.player.global_position.x > 210.0, "reload after the breaker: P.4 plays in the arcade")
	await frames(2)
	var hud = story.hud
	ok(not hud.chrome_on() and not hud.objective_panel.visible and not hud.right_column.visible, "cutscene: no objective box, score or SWEEP over P.4")
	hud.letterbox(true)
	hud.story_chrome(true)
	hud.dock_phone()
	ok(hud.right_column.offset_top >= hud.letterbox_top.offset_bottom and hud.phone_panel.offset_top > hud.letterbox_top.offset_bottom, "letterbox: the score stack and the phone sit below the bar, never clipped")
	hud.story_chrome(false)
	hud.dock_phone()
	ok(hud.phone_panel.offset_top >= hud.letterbox_top.offset_bottom, "letterbox: with the stack hidden, the phone still clears the bar")
	var cams: Array = story.cinematic.def("p4_zero").steps.filter(func(o): return str(o[0]) == "CAM")
	var near := 99.0
	for c in cams:
		near = minf(near, Vector3(float(c[1][0]), float(c[1][1]), float(c[1][2])).distance_to(P3.ZERO_AT + Vector3(0, 1.0, 0)))
	ok(near < 3.2, "P.4: a close shot frames Zero (camera %.1f m from him)" % near)
	story.cinematic.skip()
	await frames(3)
	await frames(2)
	ok(not story.hud.chrome_on(), "end card: no leftover P.3 HUD (objective, score, SWEEP)")
	ok(not main.zone_label.visible and not main.mode_label.visible, "end card: the district / WALK label is hidden")
	ok(story.spoken.any(func(l): return str(l).begins_with("CARD|") and "ACT I · EARLY CUT" in str(l) and not "LOCAL BUILD" in str(l)), "end card: public wording (ACT I · EARLY CUT), no LOCAL BUILD")
	ok(story.phase == "slice_end" and main.flow.save.flag("p4_zero_seen") and story.power.zero != null and story.power.zero.current == "awake" and story.hud.phone_sender == "ZERO" and story.power.lit != null, "skip P.4: power on, Zero awake, the ZERO header, then the slice end")
	await _done(main)
	# after P.4: straight to the slice end, in the lit arcade with Zero
	s.set_flag("p4_zero_seen")
	f = FileAccess.open(SAVE, FileAccess.WRITE)
	f.store_string(JSON.stringify(s.to_dict()))
	f.close()
	main = await _main()
	story = main.get_node("Story")
	story.start()
	await frames(3)
	ok(story.phase == "act1" and story.act1.scene == "1.1" and not story.in_cinematic() and story.power.zero != null and story.power.zero.visible and story.hud.phone_sender == "ZERO", "reload after P.4: Act I 1.1 Fine Print in the lit arcade, Zero on the bench, ZERO in the thread (%s)" % story.phase)
	await _done(main)

func _reload_mid() -> void:
	_seed_after_run({"state": "active", "done": ["coin_box", "toolbox"], "checkpoint": "toolbox"})
	var main = await _main()
	var story = main.get_node("Story")
	story.start()
	await frames(3)
	var p = story.power
	ok(story.phase == "p3_power" and p.fuses.size() == 2 and p.last_fuse == "toolbox" and Vector2(main.player.global_position.x - 241.5, main.player.global_position.z + 24.0).length() < 1.0, "reload mid-P.3: two fuses kept, back by the toolbox")
	ok(not story.spoken.any(func(l): return "a hundred and fifteen" in str(l)), "reload mid-P.3: the INT. lines don't replay")
	await _done(main)
