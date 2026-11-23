extends RefCounted
## Challenge contract. Headless, no world. AU_TEST_ONLY=challenges runs it alone.

const JsonFile = preload("res://scripts/json_file.gd")
const Schema = preload("res://scripts/mission/challenge_schema.gd")
const Catalog = preload("res://scripts/mission/challenge_catalog.gd")
const Runner = preload("res://scripts/mission/challenge_runner.gd")

var t: Node

func run(host: Node) -> void:
	t = host
	var loaded := Catalog.load_all()
	ok(bool(loaded.get("ok", false)), "catalog loads (%s)" % str(loaded.get("reason", "")))
	if not bool(loaded.get("ok", false)):
		return
	var rows: Array = loaded.get("challenges", [])
	ok(rows.size() == 10, "nine Act I missions plus one example")
	var example := Catalog.by_id(rows, "example_glass_prep")
	ok(str(example.get("story", [{}])[0].get("text", "")).contains("PLACEHOLDER"), "example text is marked PLACEHOLDER")
	ok(Schema.validate({"contract": "au.challenge", "contract_version": 2, "id": "x", "title": "t", "mechanic": "timed", "district": "d", "spawn": {}, "goals": [{"id": "a", "event": "e"}]}).get("reason") == "version", "an unknown version is refused")
	ok(Schema.validate({"contract": "au.challenge", "contract_version": 1, "id": "x", "title": "t", "mechanic": "fly", "district": "d", "spawn": {}, "goals": [{"id": "a", "event": "e"}]}).get("reason") == "mechanic", "an unknown mechanic is refused")
	_matches_sources(rows)
	_example(example)
	_templates(rows)

func ok(cond: bool, name: String) -> void:
	t.expect(cond, "challenge: " + name)

func _matches_sources(rows: Array) -> void:
	var p1 = JsonFile.read("res://data/missions/p1_practice_run.json")
	var p2 = JsonFile.read("res://data/missions/p2_run.json")
	var p3 = JsonFile.read("res://data/missions/p3_power_on.json")
	var act = JsonFile.read("res://data/missions/act1_scenes.json")
	var c1 := Catalog.by_id(rows, "p1_practice_run")
	var c2 := Catalog.by_id(rows, "p2_run")
	var c3 := Catalog.by_id(rows, "p3_power_on")
	var cold := Catalog.by_id(rows, "a1_cold_row")
	ok(str(c1.get("parameters", {}).get("fail_rule", "")) == str(p1.get("fail_rule", "")), "P.1 fail rule matches the mission file")
	var params2: Dictionary = c2.get("parameters", {})
	ok(float(params2.get("welfare_speed", -1)) == float(p2.get("drones", {}).get("welfare", {}).get("speed", -2)), "P.2 welfare speed matches")
	ok(float(params2.get("enforcer_speed", -1)) == float(p2.get("drones", {}).get("enforcement", {}).get("speed", -2)), "P.2 enforcer speed matches")
	ok(float(params2.get("enforcer_delay_s", -1)) == float(p2.get("drones", {}).get("enforcement", {}).get("delay_s", -2)), "P.2 enforcer delay matches")
	ok(float(params2.get("camera_boost_s", -1)) == float(p2.get("camera", {}).get("boost_s", -2)), "P.2 camera burst matches")
	ok(int(params2.get("zero_round_s", -1)) == int(p2.get("zero_time", {}).get("round_s", -2)), "P.2 Zero Score rounding matches")
	ok(float(c3.get("parameters", {}).get("sweep_s", -1)) == float(p3.get("sweep_s", -2)), "P.3 sweep time matches")
	var det := -1.0
	for step in act.get("scenes", {}).get("1.4", {}).get("steps", []):
		if typeof(step) == TYPE_DICTIONARY and (step as Dictionary).has("det_r"):
			det = float((step as Dictionary).get("det_r", -1))
	ok(float(cold.get("parameters", {}).get("det_r", -2)) == det, "1.4 watch radius matches")
	for key in ["1.1", "1.2", "1.3", "1.4", "1.5", "1.6"]:
		var scene: Dictionary = act.get("scenes", {}).get(key, {})
		var row := Catalog.by_id(rows, str(scene.get("id", "")))
		ok(str(row.get("title", "")) == str(scene.get("title", "")), "title matches " + key)

func _example(example: Dictionary) -> void:
	var runner = Runner.new()
	ok(bool(runner.load_challenge(example).get("ok", false)) and bool(runner.start().get("ok", false)), "example starts")
	var painted: Dictionary = runner.notify("camera_painted", {"camera": "parking"})
	ok(str(painted.get("status", "")) == "clear" and int(painted.get("points", 0)) == 1, "painting the parking camera clears the example for 1 point")
	ok(bool(runner.start().get("ok", false)), "the example can be run again")
	var missed: Dictionary = runner.notify("camera_painted", {"camera": "other"})
	ok(str(missed.get("status", "")) == "active" and int(missed.get("points", 0)) == 0, "a different camera does not clear it")
	var saved := runner.to_dict()
	var again = Runner.new()
	ok(bool(again.from_dict(saved).get("ok", false)) and again.status == "active", "a saved run loads back as a dictionary")

func _templates(rows: Array) -> void:
	var chase := Catalog.by_id(rows, "p2_run")
	var runner = Runner.new()
	runner.load_challenge(chase)
	runner.start()
	var caught: Dictionary = runner.notify("caught", {})
	ok(str(caught.get("status", "")) == "active" and int(caught.get("fails", 0)) == 1, "P.2 caught restarts at the checkpoint and does not end the run")
	var done: Dictionary = runner.notify("door", {})
	ok(str(done.get("status", "")) == "clear", "P.2 door clears the chase")
	var sneak := Catalog.by_id(rows, "a1_cold_row")
	var quiet = Runner.new()
	quiet.load_challenge(sneak)
	quiet.start()
	quiet.notify("mark", {})
	quiet.notify("mark", {})
	var spotted: Dictionary = quiet.notify("spotted", {})
	ok(str(spotted.get("status", "")) == "fail", "1.4 sneak fails when WATCH fills")
	var timed = Runner.new()
	timed.load_challenge({
		"contract": "au.challenge", "contract_version": 1, "id": "timed_probe", "title": "probe",
		"mechanic": "timed", "district": "glass_row_edge", "spawn": {},
		"goals": [{"id": "door", "event": "door"}],
		"scoring": {"par_s": {"gold": 70, "silver": 90, "bronze": 120}},
		"points": {"gold": 3, "silver": 2, "bronze": 1},
	})
	timed.start()
	timed.tick(80.0)
	var rank: Dictionary = timed.notify("door", {})
	ok(str(rank.get("rank", "")) == "silver" and int(rank.get("points", 0)) == 2, "timed run scores against the par")
	var combo = Runner.new()
	combo.load_challenge({
		"contract": "au.challenge", "contract_version": 1, "id": "combo_probe", "title": "probe",
		"mechanic": "combo", "district": "yard", "spawn": {},
		"goals": [{"id": "finish", "event": "finish"}],
		"scoring": {"chain": {"2": "bronze", "4": "silver", "6": "gold"}},
		"points": {"bronze": 1, "silver": 2, "gold": 3},
	})
	combo.start()
	combo.notify("chain", {"chain": 4})
	combo.notify("bail", {})
	var banked: Dictionary = combo.notify("finish", {})
	ok(str(banked.get("rank", "")) == "silver" and int(banked.get("points", 0)) == 2, "combo keeps the peak chain after a bail")
