extends RefCounted
## M1 (Nov 19 2026) headless tests: mission framework, combo meter, line, barks, save v2, and P.1 in the real park.
## Run from test_main.gd (full suite) or alone with AU_TEST_ONLY=m1.

const Runner = preload("res://scripts/mission/mission_runner.gd")
const Combo = preload("res://scripts/mission/combo_meter.gd")
const Line = preload("res://scripts/mission/line_tracker.gd")
const Barks = preload("res://scripts/mission/barks.gd")
const SaveScript = preload("res://contracts/save_record.gd")
const PracticeRun = preload("res://scripts/story/practice_run.gd")
const JsonFile = preload("res://scripts/json_file.gd")

const SAVE := "user://m1-test-save.json"

var t: Node

func run(host: Node) -> void:
	t = host
	_runner()
	_runner_fail_rules()
	_combo()
	_line()
	_barks()
	_save_v2()
	_bindings()
	await _free_roam()
	await _practice_run()
	await _reload()
	await _combo_speed()
	await autopilot_run()

func ok(cond: bool, name: String) -> void:
	t.expect(cond, "m1: " + name)

func frames(n: int) -> void:
	for _i in n:
		await t.get_tree().physics_frame

func _def() -> Dictionary:
	return JsonFile.read("res://data/missions/p1_practice_run.json")

# ------------------------------------------------------------------ framework units

func _runner() -> void:
	var r = Runner.new()
	ok(r.load_def({}).get("reason") == "id", "runner rejects a mission without an id")
	ok(r.load_def({"id": "x", "objectives": []}).get("reason") == "objectives", "runner rejects a mission without objectives")
	ok(r.load_def({"id": "x", "objectives": [{"id": "a", "event": "e"}, {"id": "a", "event": "e"}]}).get("reason") == "duplicate_objective", "runner rejects duplicate objective ids")
	ok(r.load_def({"id": "x", "fail_rule": "lives", "objectives": [{"id": "a", "event": "e"}]}).get("reason") == "fail_rule", "runner rejects an unknown fail rule")
	var def := _def()
	r = Runner.new()
	ok(bool(r.load_def(def).get("ok")), "P.1 definition loads")
	ok(r.fail_rule == "none" and r.required.size() == 7 and r.optional.size() == 1, "P.1: no fail, 7 required objectives, 1 optional")
	var started: Array = []
	var finished: Array = []
	var saves: Array = []
	r.objective_started.connect(func(id): started.append(id))
	r.objective_done.connect(func(id): finished.append(id))
	r.save_requested.connect(func(_id, snap): saves.append(snap))
	ok(r.start() and r.state == "active" and r.current_id() == "push", "start: active on the first objective")
	ok(saves.size() == 1, "start asks for a save")
	r.notify("kick_up")
	ok(r.current_id() == "push", "an event for a later objective does nothing")
	r.notify("speed", {"speed": 3.0})
	ok(r.current_id() == "push", "match: below the minimum speed does not count")
	ok(not r.prompt_due(), "no prompt before the hesitation time")
	r.tick(6.5)
	ok(r.prompt_due(), "prompt is due after hesitating on the objective (6 s)")
	ok(r.notify("speed", {"speed": 6.0}) == ["push"] and r.current_id() == "kick_up", "push completes and kick-up starts")
	ok(not r.prompt_due() and r.time_on == 0.0, "the hesitation clock restarts per objective")
	for e in ["kick_up", "drop_on", "trick_land"]:
		r.notify(e)
	ok(r.current_id() == "quarter" and r.checkpoint == "quarter", "starting a checkpoint objective (quarter) makes it the restart point")
	r.notify("quarter", {"peak": 0.3})
	ok(r.current_id() == "quarter", "a low quarter-pipe ride does not count")
	r.notify("line_beat", {"score": 9999})
	ok(not r.is_done("beat_zero"), "the optional Zero Score objective waits for the mission to finish")
	r.notify("quarter", {"peak": 1.2})
	r.notify("grind_clean", {"first": "board", "kind": "rail"})
	ok(r.current_id() == "rail", "a boardslide is not the 50-50")
	r.notify("grind_clean", {"first": "5050", "kind": "ledge"})
	ok(r.current_id() == "rail", "a ledge is not the rail")
	r.notify("grind_clean", {"first": "5050", "kind": "rail"})
	ok(r.current_id() == "line", "a clean 50-50 on the rail opens the line")
	var done := []
	r.mission_done.connect(func(id): done.append(id))
	r.notify("line_done", {"score": 3700})
	ok(r.state == "done" and done == ["p1_practice_run"] and r.completions == 1, "the line finishes the mission")
	ok(r.notify("line_beat", {"score": 4100}) == ["beat_zero"], "after the mission the optional objective counts")
	ok(started.size() == 7 and finished.size() == 8, "started %d / finished %d objectives" % [started.size(), finished.size()])
	ok(r.retry() and r.state == "done", "retry after completion is a replay (stays done)")
	# save snapshot and resume at the checkpoint
	var r2 = Runner.new()
	r2.load_def(def)
	r2.start()
	for e in [["speed", {"speed": 6.0}], ["kick_up", {}], ["drop_on", {}], ["trick_land", {}], ["quarter", {"peak": 1.0}]]:
		r2.notify(e[0], e[1])
	var snap: Dictionary = r2.to_save()
	ok(snap.state == "active" and snap.objective == "rail" and snap.checkpoint == "rail", "snapshot: on the rail, checkpoint rail")
	var r3 = Runner.new()
	r3.load_def(def)
	r3.from_save(snap)
	ok(r3.state == "active" and r3.current_id() == "rail" and r3.is_done("quarter") and not r3.is_done("rail"), "resume puts a saved run back at its checkpoint")
	var r4 = Runner.new()
	r4.load_def(def)
	r4.from_save({"state": "done", "completions": 2})
	ok(r4.state == "done" and r4.completions == 2, "resume of a finished mission stays done")
	# locked missions
	var r5 = Runner.new()
	r5.load_def({"id": "p2", "requires": ["p1_done"], "objectives": [{"id": "a", "event": "e"}]})
	ok(r5.state == "locked" and not r5.start(), "a mission with missing flags is locked")
	r5.refresh_lock({"p1_done": true})
	ok(r5.state == "available" and r5.start(), "the flag unlocks it")
	# counted objectives
	var r6 = Runner.new()
	r6.load_def({"id": "c", "objectives": [{"id": "three", "event": "hit", "count": 3}]})
	r6.start()
	r6.notify("hit")
	r6.notify("hit")
	ok(r6.state == "active" and int(r6.counts.three) == 2, "count: progress 2 of 3")
	r6.notify("hit")
	ok(r6.state == "done", "count: done at 3")

func _runner_fail_rules() -> void:
	var r = Runner.new()
	r.load_def(_def())
	r.start()
	ok(not r.fail("bail") and r.state == "active" and r.fails == 1, "P.1: a bail never fails the mission (counted only)")
	# the proposed P.2+ rule: caught -> restart at the last checkpoint, no lives
	var c = Runner.new()
	c.load_def({"id": "run", "fail_rule": "checkpoint", "fail_rule_status": "proposed", "objectives": [
		{"id": "fence", "event": "reach", "match": {"at": "fence"}, "checkpoint": true},
		{"id": "dock", "event": "reach", "match": {"at": "dock"}, "checkpoint": true},
		{"id": "plaza", "event": "reach", "match": {"at": "plaza"}},
		{"id": "door", "event": "reach", "match": {"at": "door"}}]})
	ok(c.fail_rule_status == "proposed", "a proposed fail rule is flagged provisional")
	c.start()
	c.notify("reach", {"at": "fence"})
	c.notify("reach", {"at": "dock"})
	c.notify("reach", {"at": "plaza"})
	var failed := []
	c.mission_failed.connect(func(_id, why): failed.append(why))
	ok(c.fail("caught") and c.state == "failed" and failed == ["caught"], "checkpoint rule: caught fails the run")
	ok(c.notify("reach", {"at": "door"}).is_empty(), "a failed run ignores events")
	ok(c.retry() and c.state == "active" and c.current_id() == "dock", "retry restarts at the last checkpoint reached (after the dock: %s)" % c.current_id())
	ok(not c.is_done("plaza") and c.is_done("fence"), "objectives after the checkpoint are reset, earlier ones kept")

func _combo() -> void:
	var c = Combo.new()
	ok(c.meter == 0.0 and c.top_speed_mult() == 1.0 and c.push_mult() == 1.0, "combo: empty meter, no bonus")
	c.trick("OLLIE")
	ok(c.score == 0 and c.pending.size() == 1, "combo: a started trick is pending, not scored")
	ok(c.land() == 400 and c.score == 400 and absf(c.meter - 0.125) < 0.001, "combo: landing banks 400 x1 and fills 1/8")
	c.trick("KICKFLIP")
	ok(c.land() == 2000, "combo: the next landed trick scores x2 (kickflip 1,000 -> 2,000)")
	ok(c.top_speed_mult() > 1.1 and c.push_mult() > c.top_speed_mult(), "combo: the meter raises top speed and push power (%.3f / %.3f)" % [c.top_speed_mult(), c.push_mult()])
	var m: float = c.meter
	c.tick(2.0)
	ok(c.meter == m, "combo: the meter holds through the grace period")
	c.tick(1.0)
	ok(c.meter < m, "combo: then it decays when he stops landing tricks")
	c.grind_start()
	var before: float = c.meter
	c.tick(1.0)
	ok(c.meter > before, "combo: grinding fills the meter")
	var g: int = c.grind_done(["50-50"], 5.0)
	ok(g == 1200 * 3, "combo: a 5 m 50-50 banks (400 + 5 x 160) x3 = %d" % g)
	c.trick("MELON")
	c.bail()
	ok(c.meter == 0.0 and c.chain == 0 and c.pending.is_empty() and c.multiplier() == 1, "combo: a bail empties the meter, drops the pending trick and resets the chain")
	ok(c.top_speed_mult() == 1.0, "combo: no bonus after a bail")
	for i in 20:
		c.trick("BACKSIDE AIR")
		c.land()
	ok(c.meter == 1.0 and c.multiplier() == c.MULT_CAP and is_equal_approx(c.top_speed_mult(), 1.0 + c.TOP_BONUS), "combo: meter and multiplier cap (x%d, top speed x%.2f)" % [c.multiplier(), c.top_speed_mult()])
	c.tick(c.GRACE_S + 6.0)
	ok(c.meter == 0.0 and c.chain == 0, "combo: an empty meter ends the chain")
	ok(c.land() == 0, "combo: landing with nothing pending scores nothing")

func _line() -> void:
	var l = Line.new()
	l.setup(PackedStringArray(["bowl", "quarter", "rail"]), 60.0)
	ok(l.step("quarter", 0) == "" and l.at == 0, "line: must start in the bowl")
	ok(l.step("bowl", 100) == "step" and l.step("bowl", 150) == "step" and l.at == 1, "line: circling the bowl keeps the line at step 1")
	ok(l.step("rail", 200) == "" and l.at == 1, "line: steps must come in order")
	l.step("quarter", 300)
	ok(l.step("rail", 900) == "done" and l.finish(900) == 750, "line: bowl, quarter, rail is done; score counts from the bowl (750)")
	l.step("bowl", 0)
	ok(l.bail() and l.at == 0 and l.broken_by == "bail", "line: a bail breaks it")
	l.step("bowl", 0)
	ok(l.tick(61.0) and l.at == 0 and l.broken_by == "time", "line: 60 s runs out")

func _barks() -> void:
	var b = Barks.new()
	b.setup({"bail": {"cooldown": 10.0, "entries": [[["V", "a"]], [["V", "b"], ["F", "c"]]]}}, 7)
	var first: Array = b.pick("bail")
	ok(first.size() >= 1, "barks: a pick returns an exchange")
	ok(b.pick("bail").is_empty(), "barks: the pool cools down")
	b.tick(11.0)
	var second: Array = b.pick("bail")
	ok(not second.is_empty() and second != first, "barks: no repeat of the previous entry")
	ok(b.pick("nope").is_empty(), "barks: an unknown pool is silent")

func _save_v2() -> void:
	var s = SaveScript.new()
	ok(s.VERSION == 3 and s.to_dict().contract_version == 3 and s.to_dict().has("story"), "save v3 (front end) still writes the v2 story section")
	var v1 = SaveScript.new()
	ok(v1.apply_dict({"contract": "au.world_save", "contract_version": 1, "meetings": {"zero": true}, "results": []}).get("ok") == true and v1.migrated_from == 1, "save: a v1 file loads and is marked migrated")
	ok(v1.met.zero == true and v1.story.missions.is_empty() and v1.to_dict().contract_version == 3, "save: v1 keeps its meetings and is written back as v3")
	ok(SaveScript.new().apply_dict({"contract": "au.world_save", "contract_version": 4, "meetings": {}, "results": []}).get("reason") == "contract", "save: an unknown version is refused")
	s.set_mission("p1_practice_run", {"state": "done", "completions": 1})
	ok(s.note_score("p1_practice_run", 3200) and not s.note_score("p1_practice_run", 3000) and s.mission("p1_practice_run").best_score == 3200, "save: best score only goes up")
	s.mission("p1_practice_run")["zero_score"] = 3500
	s.set_flag("p1_voice_heard")
	var round = SaveScript.new()
	ok(round.apply_json(JSON.stringify(s.to_dict())).get("ok") == true, "save v2 json round trip")
	var m: Dictionary = round.mission("p1_practice_run")
	ok(m.state == "done" and m.best_score == 3200 and m.zero_score == 3500 and round.flag("p1_voice_heard"), "save v2 keeps the mission, best, Zero Score and flags")
	ok(SaveScript.new().apply_dict({"contract": "au.world_save", "contract_version": 2, "meetings": {}, "results": [], "story": {"missions": 4}}).get("ok") == false, "save: a broken story block is refused")
	ok(PracticeRun.zero_for(3700) == 4000 and PracticeRun.zero_for(4000) == 4500 and PracticeRun.zero_for(0) == 500, "Zero Score: next 500 strictly above the first line (3,700 -> 4,000)")

func _bindings() -> void:
	ok(InputMap.has_action("story_toggle") and InputMap.has_action("mission_retry"), "story keys are bound")
	var keys := {}
	for action in InputMap.get_actions():
		if str(action).begins_with("ui_"):
			continue
		for e in InputMap.action_get_events(action):
			if e is InputEventKey:
				var k: int = e.physical_keycode
				if keys.has(k) and keys[k] != action:
					ok(false, "key %s bound to both %s and %s" % [OS.get_keycode_string(k), keys[k], action])
				keys[k] = action
	ok(keys.get(KEY_P) == "story_toggle" and keys.get(KEY_T) == "mission_retry", "P toggles story mode, T retries; no key clash")

# ------------------------------------------------------------------ in the park

func _main() -> Node:
	var main = load("res://scenes/main.tscn").instantiate()
	t.add_child(main)
	await frames(10)
	main.flow.save_path = SAVE
	return main

func _free_roam() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	var main = await _main()
	var story = main.get_node_or_null("Story")
	ok(story != null and not story.active, "free roam: story mode idle")
	ok(main.world_sim.get_node_or_null("DerelictDressing") == null and main.get_node_or_null("Story/StoryHud") == null, "free roam: no dressing and no story HUD")
	ok(main.player.combo_top_mult == 1.0 and main.player.combo_push_mult == 1.0 and main.player.locked_grinds.is_empty(), "free roam: no combo bonus and no locked grinds")
	ok(main.hint_label.visible and main.world_sim.get_node("NPCZero").visible, "free roam: controls hint and block Zero unchanged")
	main.queue_free()
	await frames(2)

## Ride toward -X from x0 at speed v, on z, optionally ollie at x_pop. Returns when the predicate holds or after n ticks.
func _drive(pl, from: Vector3, heading: float, v: float, ticks: int, until: Callable, pop := Callable()) -> bool:
	pl.global_position = from
	pl.rotation.y = heading
	pl.camera_yaw = 0.0
	pl.skating = true
	pl.trick = ""
	pl.bail_time = 0.0
	pl.velocity = Vector3(-sin(heading), 0, -cos(heading)) * v
	if pl.rig != null:
		pl.rig.face_world(heading)
	pl.external_move_active = true
	pl.external_move = Vector2(0, 1)
	var popped := not pop.is_valid()
	for _i in ticks:
		await t.get_tree().physics_frame
		if not popped and pop.call():
			pl.request_trick("ollie")
			popped = true
		if until.call():
			return true
	return false

func _rail_ride(main, pl, lateral := 0.2, angle_off := 0.0) -> String:
	# GrindRail: 7 m bar along X at z 8, x -55.5 .. -48.5, top 0.30 m. Aim at a point 2.5 m in from the east end, riding
	# -X turned by angle_off, and ollie 2.6 m before reaching the bar (as tests/_grind_ride does).
	var heading := PI * 0.5 + angle_off
	var dir := Vector3(-sin(heading), 0, -cos(heading))
	var target := Vector3(-51.0, 0.0, 8.0 + lateral)
	var from := target - dir * (9.0 if angle_off == 0.0 else 6.0)
	from.y = 0.2
	var pop_d := 2.6 + 2.5 if angle_off == 0.0 else 2.4
	var hit := await _drive(pl, from, heading, 6.5, 200, func(): return pl.grind != null or pl.trick == "bail",
		func(): return Vector2(pl.global_position.x - target.x, pl.global_position.z - target.z).length() < pop_d)
	if pl.trick == "bail":
		await frames(60)
		return "bail"
	if not hit:
		return "miss"
	for _i in 200:
		await t.get_tree().physics_frame
		if pl.grind == null:
			break
	await frames(40)
	pl.external_move = Vector2.ZERO
	return "grind" if pl.grind_last.get("trick", "") != "bail" else "bail"

func _practice_run() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	var main = await _main()
	var story = main.get_node("Story")
	var pl = main.player
	var sky_before: Color = main.get_child(0).environment.sky.sky_material.sky_top_color if main.get_child(0) is WorldEnvironment else Color()
	ok(story.start() and story.active, "P key path: story.start() enters P.1")
	ok(main.world_sim.get_node_or_null("DerelictDressing") != null and main.get_node_or_null("Story/StoryHud") != null, "story: the Yard is dressed derelict and the story HUD is up")
	var env_node = null
	for c in main.get_children():
		if c is WorldEnvironment:
			env_node = c
	ok(env_node != null and env_node.environment.sky.sky_material.sky_top_color != sky_before, "story: dawn lighting preset")
	ok(not main.hint_label.visible and not main.world_sim.get_node("NPCZero").visible, "story: the long controls hint and the block Zero step out")
	ok(pl.locked_grinds.has("5o") and pl.locked_grinds.has("board"), "story: 5-0 and boardslide are gated")
	ok(story.runner.current_id() == "push" and story.zero_score == 0, "story: P.1 starts on push with no Zero Score yet")
	# front end (Nov 19 2026): the intro video carries the flyer now; P.1 opens with no "fifty thousand" card
	await frames(30)
	ok(story.card_left <= 0.0 and not story.hud.card_panel.visible, "story: no flyer card at the start of P.1 (the intro video covers it)")
	var said := "\n".join(story.spoken)
	ok(not ("fifty thousand" in said.to_lower()) and not ("CARD|" in said), "story: nothing in P.1 still says fifty thousand")
	story.runner.time_on = 0.0
	# hesitation prompt: nothing until 6 s on push
	ok(not story.hud.prompt_panel.visible, "prompt: hidden while he has not hesitated")
	story.runner.time_on = 6.2
	await frames(3)
	ok(story.hud.prompt_panel.visible and "PUSH" in story.hud.prompt_label.text and "W" in story.hud.prompt_label.text, "prompt: shows PUSH [W] after hesitating")
	# push: real physics
	pl.external_move_active = true
	pl.external_move = Vector2(0, 1)
	for _i in 90:
		await t.get_tree().physics_frame
		if story.runner.current_id() != "push":
			break
	ok(story.runner.current_id() == "kick_up" and not story.hud.prompt_panel.visible, "push: reaching speed completes it (prompt clears)")
	pl.external_move = Vector2.ZERO
	await frames(40)
	pl.skate_toggle_pressed()
	await frames(2)
	ok(story.runner.current_id() == "drop_on" and not pl.skating, "kick up: Shift kicks the board up")
	pl.skate_toggle_pressed()
	await frames(2)
	ok(story.runner.current_id() == "ollie" and pl.skating, "drop on: Shift drops it and steps on")
	pl.external_move = Vector2(0, 0.6)
	await frames(20)
	pl.request_trick("ollie")
	for _i in 90:
		await t.get_tree().physics_frame
		if story.runner.current_id() != "ollie":
			break
	await frames(30)
	ok(story.runner.current_id() == "quarter", "ollie: a landed ollie completes it")
	ok(story.combo.score >= 400, "ollie: the landed ollie scored (%d)" % story.combo.score)
	# quarter pipe: SkateQuarter climbs toward -X
	story.retry()
	await frames(2)
	ok(pl.global_position.distance_to(Vector3(-43.5, 0.5, -12.0)) < 1.0, "retry (T): back to the quarter-pipe checkpoint")
	var rode: bool = await _drive(pl, Vector3(-44.0, 0.2, -12.0), PI * 0.5, 7.5, 400, func(): return story.runner.current_id() != "quarter")
	ok(rode and story.runner.current_id() == "rail", "quarter pipe: riding up SkateQuarter completes it")
	pl.external_move = Vector2.ZERO
	await frames(30)
	# rail: first a bad approach (the voice speaks), then a clean 50-50
	var first := await _rail_ride(main, pl, 0.0, 0.7)
	ok(first == "bail", "rail: a 40 deg approach bails (%s)" % first)
	await frames(5)
	ok(story.voice_heard and story.queue.size() + 1 >= 1, "rail: the bail wakes the VOICE")
	var heard := false
	for l in story.spoken + story.queue.map(func(q): return q[0] + "|" + q[1]):
		if str(l).begins_with("VOICE (O.S.)|(dry, staticky) Your approach angle is") and "degrees" in str(l):
			heard = true
	ok(heard, "rail: VOICE (O.S.) names the approach angle")
	await frames(50)
	var second := await _rail_ride(main, pl, 0.2, 0.0)
	ok(second == "grind" and story.runner.current_id() == "line", "rail: a clean 50-50 opens the line (%s, %s)" % [second, pl.grind_last])
	ok(story.face_on and main.world_sim.get_node("DerelictDressing/CrtFace").visible, "reveal: the faint face is on the CRT in the arcade window")
	# grind gating in the story: F / R on the rail do not switch to 5-0 / boardslide
	pl.grind = null
	# the line: bowl, quarter, rail
	story.retry()
	await frames(2)
	ok(pl.global_position.distance_to(Vector3(-48.0, 0.8, 20.5)) < 1.5, "retry (T) on the line: back to the bowl rim")
	var in_bowl: bool = await _drive(pl, Vector3(-48.0, 0.8, 20.5), PI, 7.0, 300, func(): return story.line.at >= 1)
	ok(in_bowl and story.line.at == 1, "line: dropping into the bowl starts the line")
	pl.external_move = Vector2.ZERO
	var rode2: bool = await _drive(pl, Vector3(-44.0, 0.2, -12.0), PI * 0.5, 7.5, 400, func(): return story.line.at >= 2)
	ok(rode2 and story.line.at == 2, "line: then the quarter pipe")
	await frames(40)
	var third := await _rail_ride(main, pl, 0.2, 0.0)
	await frames(5)
	ok(third == "grind" and story.runner.state == "done", "line: then the rail; P.1 is done (%s, line %d)" % [third, story.line.last_score])
	ok(story.zero_score > story.line.last_score and story.zero_score % 500 == 0, "Zero Score: %d set just above the first line (%d)" % [story.zero_score, story.line.last_score])
	ok(main.world_sim.get_node("DerelictDressing/ZeroScoreMarquee").text.contains(story.Hud.fmt(story.zero_score)), "Zero Score: on the arcade marquee")
	ok("ZERO SCORE" in story.hud.zero_label.text and story.Hud.fmt(story.zero_score) in story.hud.zero_label.text, "Zero Score: on the HUD board")
	var saved = SaveScript.new()
	saved.load_user(SAVE)
	var rec: Dictionary = saved.mission("p1_practice_run")
	ok(saved.migrated_from == 0 and rec.state == "done" and rec.zero_score == story.zero_score and rec.best_score == story.best_line and rec.completions == 1, "save: P.1 done, Zero Score and best line on disk %s" % rec)
	# beat it: give the line a big chain first
	story.retry()
	await frames(2)
	await _drive(pl, Vector3(-48.0, 0.8, 20.5), PI, 7.0, 300, func(): return story.line.at >= 1)
	for i in 6:
		story.combo.trick("KICKFLIP")
		story.combo.land()
	await _drive(pl, Vector3(-44.0, 0.2, -12.0), PI * 0.5, 7.5, 400, func(): return story.line.at >= 2)
	await frames(40)
	await _rail_ride(main, pl, 0.2, 0.0)
	await frames(5)
	ok(story.runner.is_done("beat_zero") and story.best_line > story.zero_score, "beat the Zero Score: best %d > %d" % [story.best_line, story.zero_score])
	var beaten := false
	for l in story.spoken + story.queue.map(func(q): return q[0] + "|" + q[1]):
		if "Hm. Fine. Saved." in str(l):
			beaten = true
	ok(beaten, "beat the Zero Score: the voice concedes")
	# let the queued lines play out (each holds 2 to 7.5 s on screen; skip the waits)
	for _i in 60:
		story.talk_left = 0.0
		story.card_left = 0.0
		await t.get_tree().process_frame
	ok(story.queue.is_empty() and story.spoken.size() >= 20, "talk: every queued line was shown (%d)" % story.spoken.size())
	var voice_lines: Array = story.spoken.filter(func(l): return str(l).begins_with("VOICE (O.S.)|"))
	ok(voice_lines.size() >= 7, "talk: the VOICE (O.S.) speaks as on-screen text (%d lines)" % voice_lines.size())
	# SFX only: the story cues played, nothing else
	ok(story.sfx.played.has("crt") and story.sfx.played.has("objective") and story.sfx.played.has("bank"), "sfx: CRT crackle, objective and score cues played %s" % [story.sfx.played.slice(0, 8)])
	ok(AudioServer.bus_count == 1, "sfx: still one audio bus, no music bus")
	# leaving story mode puts the free-roam park back
	story.stop()
	await frames(3)
	ok(not story.active and main.world_sim.get_node_or_null("DerelictDressing") == null and main.hint_label.visible, "P again: story mode ends, dressing gone, hint back")
	ok(env_node.environment.sky.sky_material.sky_top_color == sky_before and pl.combo_top_mult == 1.0 and pl.locked_grinds.is_empty(), "P again: sunset sky, no bonus, grinds unlocked")
	ok(main.world_sim.get_node("NPCZero").visible and main.world_sim.get_node("NPCZero").is_in_group("interactable"), "P again: the block Zero is back and can be talked to")
	main.queue_free()
	await frames(2)

func _reload() -> void:
	# a fresh park: free-roam save writes must keep the story, and P.1 restarts as a replay with the best still saved
	var main = await _main()
	var saved_best: int = SaveScript.new().apply_json(FileAccess.get_file_as_string(SAVE)).get("ok") and 0
	var disk = SaveScript.new()
	disk.load_user(SAVE)
	var best: int = disk.mission("p1_practice_run").best_score
	main.flow.save.load_story_user(SAVE)
	main.flow.persist()
	var after = SaveScript.new()
	after.load_user(SAVE)
	ok(best > 0 and after.mission("p1_practice_run").best_score == best, "reload: a free-roam save keeps the best line (%d)" % best)
	var story = main.get_node("Story")
	story.start()
	await frames(3)
	ok(story.runner.state == "done" and story.best_line == best and story.zero_score > 0, "reload: P.1 comes back as a replay, best %d, Zero Score %d" % [story.best_line, story.zero_score])
	ok(main.world_sim.get_node("DerelictDressing/ZeroScoreMarquee").text.contains("ZERO SCORE"), "reload: the marquee shows the Zero Score")
	ok(main.player.global_position.distance_to(Vector3(-48.0, 0.8, 20.5)) < 1.5, "reload: the replay starts at the bowl")
	story.stop()
	main.queue_free()
	await frames(2)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))

func _combo_speed() -> void:
	var main = await _main()
	var story = main.get_node("Story")
	var pl = main.player
	story.start()
	story.card_left = 0.0
	# open flat ground in the plaza, heading -X
	var free_v := await _top_speed(pl, story, 0.0)
	var boosted_v := await _top_speed(pl, story, 1.0)
	ok(free_v < 9.2 and free_v > 8.5, "combo speed: empty meter tops out at the normal 9 m/s (%.2f)" % free_v)
	ok(boosted_v > free_v * 1.25, "combo speed: a full meter raises top speed (%.2f m/s)" % boosted_v)
	# push power: acceleration from 2 m/s over 10 ticks
	var a0 := await _accel(pl, story, 0.0)
	var a1 := await _accel(pl, story, 1.0)
	ok(a1 > a0 * 1.4, "combo speed: a full meter raises push power (%.2f vs %.2f m/s gained)" % [a1, a0])
	# a bail empties it
	story.combo.meter = 1.0
	pl.say("BAIL!", "bail")
	await frames(2)
	ok(story.combo.meter == 0.0 and pl.combo_top_mult == 1.0, "combo speed: a bail empties the meter and the bonus")
	# gating on a real rail lock
	pl.grind = null
	story.stop()
	main.queue_free()
	await frames(2)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))

func _top_speed(pl, story, meter: float) -> float:
	pl.global_position = Vector3(0.0, 0.3, 20.0)
	pl.rotation.y = PI * 0.5
	pl.camera_yaw = 0.0
	pl.velocity = Vector3.ZERO
	pl.skating = true
	pl.external_move_active = true
	pl.external_move = Vector2(0, 1)
	var top := 0.0
	for _i in 150:
		story.combo.meter = meter
		story.combo.since_bank = 0.0
		await t.get_tree().physics_frame
		top = maxf(top, Vector2(pl.velocity.x, pl.velocity.z).length())
	pl.external_move = Vector2.ZERO
	return top

func _accel(pl, story, meter: float) -> float:
	pl.global_position = Vector3(0.0, 0.3, 20.0)
	pl.rotation.y = PI * 0.5
	pl.camera_yaw = 0.0
	pl.skating = true
	story.combo.meter = meter
	story.combo.since_bank = 0.0
	await frames(2)
	pl.velocity = Vector3(-2.0, 0, 0)
	pl.external_move_active = true
	pl.external_move = Vector2(0, 1)
	for _i in 10:
		story.combo.meter = meter
		await t.get_tree().physics_frame
	var v := Vector2(pl.velocity.x, pl.velocity.z).length()
	pl.external_move = Vector2.ZERO
	return v - 2.0

## The whole of P.1 in one continuous run through the real physics (story_autopilot.gd): no teleports after the start.
func autopilot_run() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	var main = await _main()
	var story = main.get_node("Story")
	story.start()
	var pilot = story.start_autopilot()
	for _i in 60 * 200:
		await t.get_tree().physics_frame
		if pilot.finished:
			break
	for row in pilot.log:
		print("pilot ", row)
	print("pilot state=%s obj=%s zero=%d best=%d score=%d bails=%d" % [story.runner.state, story.runner.current_id(), story.zero_score, story.best_line, story.combo.score, story.combo.bails])
	ok(pilot.finished, "autopilot: P.1 played to the end")
	ok(story.runner.state == "done" and story.runner.completions == 1, "autopilot: every P.1 objective done in one continuous run")
	ok(story.voice_heard and story.face_on, "autopilot: the bad rail approach woke the voice, the clean 50-50 lit the face")
	ok(story.zero_score > 0 and story.line.runs >= 2, "autopilot: two full lines, Zero Score %d" % story.zero_score)
	ok(story.runner.is_done("beat_zero") and story.best_line > story.zero_score, "autopilot: the kickflip lap beats the Zero Score (%d > %d)" % [story.best_line, story.zero_score])
	story.stop()
	main.queue_free()
	await frames(2)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
