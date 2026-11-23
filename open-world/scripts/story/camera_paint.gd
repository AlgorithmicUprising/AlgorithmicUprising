extends RefCounted
## Painted cameras stay blind until cleaning drones would have them back.
## The clock is data: play_time (default) or story_time. Which one is an open owner call.
## play_time keeps moving in free roam, so recovery still happens after the story.

const DATA := "res://data/camera_paint.json"

static var _loaded := false
static var _clock := "play_time"
static var _recover_s := 900.0

static func load_data() -> void:
	if _loaded:
		return
	_loaded = true
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(DATA)) if FileAccess.file_exists(DATA) else null
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	_apply_clock(str(parsed.get("clock", "play_time")))
	_recover_s = maxf(0.0, float(parsed.get("recover_s", _recover_s)))

static func reload() -> void:
	_loaded = false
	load_data()

## Tests pin a clock without editing the file. An unknown clock falls back to play_time.
static func use_for_tests(clock: String, recover: float) -> void:
	_loaded = true
	_apply_clock(clock)
	_recover_s = maxf(0.0, recover)

static func _apply_clock(clock: String) -> void:
	_clock = clock if clock == "play_time" or clock == "story_time" else "play_time"

static func clock_kind() -> String:
	load_data()
	return _clock

static func recover_s() -> float:
	load_data()
	return _recover_s

static func now_s(save, play_time_s: float) -> float:
	load_data()
	if _clock == "story_time" and save != null:
		var story: Dictionary = save.story
		return float(story.get("clock_s", 0.0))
	return play_time_s

## Story time moves only while a story mission is running. Play time is the session clock.
static func advance(save, delta: float, story_running: bool) -> void:
	load_data()
	if save == null or _clock != "story_time" or not story_running:
		return
	var story: Dictionary = save.story
	story["clock_s"] = float(story.get("clock_s", 0.0)) + delta
	save.story = story

static func mark(save, id: String, at_s: float) -> void:
	if save == null or id == "":
		return
	var story: Dictionary = save.story
	var cameras: Dictionary = story.get("cameras", {})
	cameras[id] = {"at_s": at_s}
	story["cameras"] = cameras
	save.story = story

static func fresh(save, id: String, at_now: float) -> bool:
	load_data()
	if save == null or id == "":
		return false
	var story: Dictionary = save.story
	var cameras: Dictionary = story.get("cameras", {})
	if typeof(cameras.get(id, null)) != TYPE_DICTIONARY:
		return false
	var entry: Dictionary = cameras[id]
	return at_now - float(entry.get("at_s", 0.0)) < _recover_s

## Writes dirty paint into the save, then shows or clears every camera currently in the world.
## No mission has to be running. Free roam uses the same save.
static func sync(tree: SceneTree, save, play_time_s: float) -> void:
	load_data()
	if tree == null:
		return
	var now := now_s(save, play_time_s)
	for node in tree.get_nodes_in_group("painted_camera"):
		if not (node is Node3D):
			continue
		var body := node as Node3D
		var id := str(body.get_meta("camera_id", ""))
		if id == "":
			continue
		if bool(body.get_meta("camera_paint_dirty", false)):
			mark(save, id, now)
			body.set_meta("camera_paint_dirty", false)
		var blind := fresh(save, id, now)
		body.set_meta("camera_painted", blind)
		_lens(body, blind)

static func _lens(body: Node3D, blind: bool) -> void:
	var lens := body.get_node_or_null("Lens") as MeshInstance3D
	if lens == null:
		return
	if body.has_meta("camera_paint_applied") and bool(body.get_meta("camera_paint_applied")) == blind:
		return
	body.set_meta("camera_paint_applied", blind)
	var Kit = preload("res://scripts/story/act1_kit.gd")
	var bare: Color = body.get_meta("camera_lens_color", Color("ff3b1f"))
	Kit.paint(lens, Color("111111") if blind else bare)
