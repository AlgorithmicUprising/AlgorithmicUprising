extends RefCounted
## Painted cameras recover on a clock, and the reward hook is not granted. Headless.
## AU_TEST_ONLY=cameras runs it alone. No mission is required for the recovery check.

const JsonFile = preload("res://scripts/json_file.gd")
const SaveScript = preload("res://contracts/save_record.gd")
const Paint = preload("res://scripts/story/camera_paint.gd")
const Spray = preload("res://scripts/spray.gd")
const Schema = preload("res://scripts/mission/challenge_schema.gd")
const Runner = preload("res://scripts/mission/challenge_runner.gd")

var t: Node

func run(host: Node) -> void:
	t = host
	_data()
	_clocks()
	_save()
	_spray(host)
	_sync_without_a_mission(host)
	_reward()
	Paint.reload()

func _data() -> void:
	Paint.reload()
	var data = JsonFile.read("res://data/camera_paint.json")
	ok(str(data.get("clock", "")) == "play_time" and float(data.get("recover_s", 0)) == 900.0, "default clock is play time, 900 s, and the choice stays in the file")
	ok(str(data.get("open_call", "")).contains("OPEN"), "the clock choice is marked as an open owner call")
	ok(Paint.clock_kind() == "play_time" and is_equal_approx(Paint.recover_s(), 900.0), "the loader reads that default")

func _clocks() -> void:
	Paint.use_for_tests("season", 10.0)
	ok(Paint.clock_kind() == "play_time", "an unknown clock falls back to play time")
	var save = SaveScript.new()
	Paint.use_for_tests("story_time", 10.0)
	Paint.advance(save, 4.0, false)
	ok(is_equal_approx(float(save.story.get("clock_s", -1)), 0.0), "story time does not move in free roam")
	Paint.advance(save, 4.0, true)
	ok(is_equal_approx(float(save.story.get("clock_s", 0)), 4.0), "story time moves only while a story mission is running")
	Paint.mark(save, "parking", 4.0)
	ok(Paint.fresh(save, "parking", Paint.now_s(save, 9999.0)), "story time ignores play time while the paint is fresh")
	save.story["clock_s"] = 14.0
	ok(not Paint.fresh(save, "parking", Paint.now_s(save, 0.0)), "story time recovers the camera when its own clock runs out")
	Paint.use_for_tests("play_time", 10.0)
	Paint.mark(save, "parking", 100.0)
	ok(Paint.fresh(save, "parking", 109.0) and not Paint.fresh(save, "parking", 110.0), "play time recovers the camera after recover_s")

func _save() -> void:
	Paint.reload()
	var rec = SaveScript.new()
	Paint.mark(rec, "parking", 12.5)
	rec.story["clock_s"] = 4.0
	var dumped: Dictionary = rec.to_dict()
	var cams: Dictionary = dumped["story"]["cameras"]
	cams[""] = {"at_s": 1.0}
	cams["nope"] = "x"
	cams["cam0"] = {"at_s": 2.0}
	dumped["story"]["cameras"] = cams
	var again = SaveScript.new()
	ok(bool(again.apply_dict(dumped).get("ok", false)), "a save with camera paint loads")
	var kept: Dictionary = again.story["cameras"]
	ok(kept.has("parking") and kept.has("cam0") and not kept.has("nope") and not kept.has(""), "paint survives the round trip and junk entries drop")
	ok(is_equal_approx(float((kept["parking"] as Dictionary).get("at_s", 0)), 12.5) and is_equal_approx(float(again.story.get("clock_s", 0)), 4.0), "the paint time and the story clock come back")
	dumped["story"].erase("cameras")
	dumped["story"].erase("clock_s")
	var older = SaveScript.new()
	ok(bool(older.apply_dict(dumped).get("ok", false)) and (older.story["cameras"] as Dictionary).is_empty(), "an older save with no camera key loads as none painted")

func _spray(host: Node) -> void:
	var parent := Node3D.new()
	host.add_child(parent)
	var origin := Vector3(0, 1, 0)
	var dir := Vector3(0, 0, -1)
	var cam := Node3D.new()
	cam.add_to_group("spray_target")
	cam.add_to_group("painted_camera")
	cam.set_meta("camera_id", "parking")
	parent.add_child(cam)
	cam.global_position = origin + dir * 3.0
	var drone := Node3D.new()
	drone.add_to_group("spray_target")
	parent.add_child(drone)
	drone.global_position = origin + dir * 4.0
	ok(Spray.fire(host.get_tree(), origin, dir) == 2, "spray hits the camera and the drone")
	ok(bool(cam.get_meta("camera_painted", false)) and bool(cam.get_meta("camera_paint_dirty", false)) and float(cam.get_meta("spray_left", 0.0)) == 0.0, "a camera stays painted and does not use the 8 s drone timer")
	ok(float(drone.get_meta("spray_left", 0.0)) == Spray.DISABLE_S, "a drone still goes down for 8 s")
	parent.queue_free()

func _sync_without_a_mission(host: Node) -> void:
	Paint.use_for_tests("play_time", 10.0)
	var save = SaveScript.new()
	var parent := Node3D.new()
	host.add_child(parent)
	var cam := Node3D.new()
	cam.add_to_group("painted_camera")
	cam.set_meta("camera_id", "parking")
	cam.set_meta("camera_lens_color", Color("ff3b1f"))
	cam.set_meta("camera_paint_dirty", true)
	parent.add_child(cam)
	var lens := MeshInstance3D.new()
	lens.name = "Lens"
	cam.add_child(lens)
	Paint.sync(host.get_tree(), save, 5.0)
	ok(bool(cam.get_meta("camera_painted", false)) and Paint.fresh(save, "parking", 5.0), "free roam records the paint with no mission running")
	Paint.sync(host.get_tree(), save, 20.0)
	ok(not bool(cam.get_meta("camera_painted", false)) and not Paint.fresh(save, "parking", 20.0), "free roam clears the camera when play time runs out")
	parent.queue_free()

func _reward() -> void:
	var example = JsonFile.read("res://data/challenges/example_glass_prep.json")
	var reward: Dictionary = example.get("reward", {})
	ok(bool(Schema.validate(example).get("ok", false)) and str(reward.get("type", "")) == "placeholder" and str(reward.get("id", "")) == "tbd", "the example carries a reward hook and does not name a reward")
	var broken: Dictionary = example.duplicate(true)
	broken["reward"] = {"type": "skin"}
	ok(str(Schema.validate(broken).get("reason", "")) == "reward", "a reward without a type and an id is refused")
	var runner = Runner.new()
	runner.load_challenge(example)
	runner.start()
	var cleared: Dictionary = runner.notify("camera_painted", {"camera": "parking"})
	var state := runner.to_dict()
	ok(str(cleared.get("status", "")) == "clear" and not state.has("granted"), "clearing the example does not grant the hook")

func ok(cond: bool, name: String) -> void:
	t.expect(cond, "cameras: " + name)
