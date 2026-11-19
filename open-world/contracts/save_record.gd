extends RefCounted

const Result = preload("res://contracts/minigame_result.gd")
const CONTRACT := "au.world_save"
## M1 (Nov 19 2026): v2 adds the "story" section (missions, flags, day and time, Zero Score bests, Signal). A v1 file
## still loads: it is migrated in memory (empty story) and written back as v2 on the next save.
const VERSION := 2
const READS := [1, 2]
const STORY_VERSION := 1
const MAX_RESULTS := 20
const BANNED := ["viewport", "node", "texture", "renderer", "audio_context", "canvas"]

var met := {"zero": false, "fony": false}
var results: Array = []
## Exploration stats (M0, Nov 18 2026). Optional in the file, so saves written before M0 still load and older
## builds ignore the key. Read by the district loader (visit number picks the loading card) and kept for a
## future achievements / bonuses system. Shape: see EXPLORATION_VERSION and district_stats().
const EXPLORATION_VERSION := 1
var exploration := {"version": EXPLORATION_VERSION, "districts": {}}
var story := _fresh_story()
var migrated_from := 0              # 1 when the last apply_dict() read a v1 file

static func _fresh_story() -> Dictionary:
	return {"version": STORY_VERSION, "missions": {}, "flags": {}, "day": 1, "time_of_day": "dawn", "signal": 0}

## Mission record, created on first use. Keys: state, objective, checkpoint, done, completions, fails (from
## mission_runner.gd to_save()), plus best_score and zero_score (ints, 0 = none yet).
func mission(id: String) -> Dictionary:
	var missions: Dictionary = story["missions"]
	if not missions.has(id):
		missions[id] = {"state": "available", "objective": "", "checkpoint": "", "done": [], "completions": 0, "fails": 0, "best_score": 0, "zero_score": 0}
	return missions[id]

func set_mission(id: String, snapshot: Dictionary) -> void:
	var m := mission(id)
	for k in ["state", "objective", "checkpoint", "done", "completions", "fails"]:
		if snapshot.has(k):
			m[k] = snapshot[k]

## Keeps the higher score. Returns true when it is a new best.
func note_score(id: String, score: int) -> bool:
	var m := mission(id)
	if score > int(m.get("best_score", 0)):
		m["best_score"] = score
		return true
	return false

func set_flag(name: String, value := true) -> void:
	story["flags"][name] = value

func flag(name: String) -> bool:
	return bool(story["flags"].get(name, false))

func note_meeting(id: String) -> void:
	if met.has(id):
		met[id] = true

func add_result(result: Dictionary) -> Dictionary:
	var check: Dictionary = Result.validate(result)
	if not bool(check.get("ok", false)):
		return check
	results.append(result.duplicate(true))
	while results.size() > MAX_RESULTS:
		results.pop_front()
	return {"ok": true}

func to_dict() -> Dictionary:
	return {
		"contract": CONTRACT,
		"contract_version": VERSION,
		"slot": "local",
		"meetings": met.duplicate(true),
		"results": results.duplicate(true),
		"exploration": exploration.duplicate(true),
		"story": story.duplicate(true),
	}

## Stats for one district, created on first use. Keys:
##   visits            int, completed entries into the district (the loading card for visit N shows before N is recorded)
##   first_visit_unix  int, Unix seconds of the first completed visit (0 = never)
##   last_visit_unix   int, Unix seconds of the latest completed visit (0 = never)
##   discovered        {"shortcuts": [ids], "secrets": [ids]}, string ids, no duplicates; other lists may be added later
func district_stats(id: String) -> Dictionary:
	var districts: Dictionary = exploration["districts"]
	if not districts.has(id):
		districts[id] = {"visits": 0, "first_visit_unix": 0, "last_visit_unix": 0, "discovered": {"shortcuts": [], "secrets": []}}
	return districts[id]

func district_visits(id: String) -> int:
	var districts: Dictionary = exploration["districts"]
	return int(districts[id].get("visits", 0)) if districts.has(id) else 0

func record_district_visit(id: String, unix_time: int) -> int:
	var stats := district_stats(id)
	stats["visits"] = int(stats["visits"]) + 1
	if int(stats["first_visit_unix"]) <= 0:
		stats["first_visit_unix"] = unix_time
	stats["last_visit_unix"] = unix_time
	return int(stats["visits"])

## kind is a discovered list name ("shortcuts", "secrets", or a later one). Returns true the first time only.
func discover(id: String, kind: String, item: String) -> bool:
	var found: Dictionary = district_stats(id)["discovered"]
	if not found.has(kind):
		found[kind] = []
	if found[kind].has(item):
		return false
	found[kind].append(item)
	return true

## Only the exploration section of a save on disk. The free-roam flow writes the save but does not read it back at
## start, so the district loader merges exploration from disk before it counts a visit (free roam is unchanged).
func load_exploration_user(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": true, "fresh": true}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		return {"ok": false, "reason": "not_object"}
	return _apply_exploration(parsed.get("exploration", null))

func _apply_exploration(data) -> Dictionary:
	if data == null:
		return {"ok": true, "fresh": true}
	if typeof(data) != TYPE_DICTIONARY or typeof(data.get("districts", null)) != TYPE_DICTIONARY:
		return {"ok": false, "reason": "exploration"}
	var clean := {}
	for id in data["districts"]:
		var d = data["districts"][id]
		if typeof(d) != TYPE_DICTIONARY:
			return {"ok": false, "reason": "exploration_district"}
		var found := {"shortcuts": [], "secrets": []}
		var raw_found = d.get("discovered", {})
		if typeof(raw_found) == TYPE_DICTIONARY:
			for kind in raw_found:
				if typeof(raw_found[kind]) == TYPE_ARRAY:
					var items: Array = []
					for item in raw_found[kind]:
						if not items.has(str(item)):
							items.append(str(item))
					found[str(kind)] = items
		clean[str(id)] = {
			"visits": maxi(0, int(d.get("visits", 0))),
			"first_visit_unix": maxi(0, int(d.get("first_visit_unix", 0))),
			"last_visit_unix": maxi(0, int(d.get("last_visit_unix", 0))),
			"discovered": found,
		}
	exploration = {"version": EXPLORATION_VERSION, "districts": clean}
	return {"ok": true}

func apply_dict(data: Dictionary) -> Dictionary:
	for key in BANNED:
		if data.has(key):
			return {"ok": false, "reason": "renderer_field", "key": key}
	if str(data.get("contract", "")) != CONTRACT or not READS.has(int(data.get("contract_version", -1))):
		return {"ok": false, "reason": "contract"}
	migrated_from = 1 if int(data.get("contract_version", -1)) == 1 else 0
	var meetings = data.get("meetings", null)
	if typeof(meetings) != TYPE_DICTIONARY:
		return {"ok": false, "reason": "meetings"}
	met = {"zero": bool(meetings.get("zero", false)), "fony": bool(meetings.get("fony", false))}
	results.clear()
	var incoming = data.get("results", [])
	if typeof(incoming) != TYPE_ARRAY:
		return {"ok": false, "reason": "results"}
	for item in incoming:
		if typeof(item) != TYPE_DICTIONARY:
			return {"ok": false, "reason": "result_type"}
		var added := add_result(item)
		if not bool(added.get("ok", false)):
			return added
	var explored := _apply_exploration(data.get("exploration", null))
	if not bool(explored.get("ok", false)):
		return explored
	return _apply_story(data.get("story", null) if migrated_from == 0 else null)

## Only the story section of a save on disk (M1). Free roam does not read its save back at start, so main merges this
## (and only this) before anything persists, so a free-roam save never wipes mission progress.
func load_story_user(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": true, "fresh": true}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		return {"ok": false, "reason": "not_object"}
	if int(parsed.get("contract_version", -1)) == 1:
		story = _fresh_story()
		return {"ok": true, "migrated_from": 1}
	return _apply_story(parsed.get("story", null))

func _apply_story(data) -> Dictionary:
	if data == null:
		story = _fresh_story()
		return {"ok": true, "fresh": true}
	if typeof(data) != TYPE_DICTIONARY or typeof(data.get("missions", null)) != TYPE_DICTIONARY:
		return {"ok": false, "reason": "story"}
	var clean := _fresh_story()
	for id in data["missions"]:
		var m = data["missions"][id]
		if typeof(m) != TYPE_DICTIONARY:
			return {"ok": false, "reason": "story_mission"}
		var done: Array = []
		if typeof(m.get("done", [])) == TYPE_ARRAY:
			for d in m.get("done", []):
				done.append(str(d))
		clean["missions"][str(id)] = {
			"state": str(m.get("state", "available")),
			"objective": str(m.get("objective", "")),
			"checkpoint": str(m.get("checkpoint", "")),
			"done": done,
			"completions": maxi(0, int(m.get("completions", 0))),
			"fails": maxi(0, int(m.get("fails", 0))),
			"best_score": maxi(0, int(m.get("best_score", 0))),
			"zero_score": maxi(0, int(m.get("zero_score", 0))),
		}
	var flags = data.get("flags", {})
	if typeof(flags) == TYPE_DICTIONARY:
		for f in flags:
			clean["flags"][str(f)] = bool(flags[f])
	clean["day"] = maxi(1, int(data.get("day", 1)))
	clean["time_of_day"] = str(data.get("time_of_day", "dawn"))
	clean["signal"] = maxi(0, int(data.get("signal", 0)))
	story = clean
	return {"ok": true}

func apply_json(text: String) -> Dictionary:
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {"ok": false, "reason": "not_object"}
	return apply_dict(parsed)

func save_user(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "reason": "write"}
	file.store_string(JSON.stringify(to_dict()))
	return {"ok": true}

func load_user(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": true, "fresh": true}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false, "reason": "read"}
	return apply_json(file.get_as_text())
