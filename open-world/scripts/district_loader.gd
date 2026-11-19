extends Node
## District packs (M0, Nov 18 2026). Each district ships as its own Godot pack next to index.pck
## (build/web/districts/<id>.pck, listed in data/districts.json) and streams in while the player keeps skating:
## nothing here pauses the tree, takes input, or touches the player's velocity or state.
##
## Flow for an armed district:
##   approach (player within prefetch_m of its bounds) -> show the loading card for visit N = visits + 1 and start
##   fetching -> fetch (web: HTTPRequest to <page dir>/districts/<id>.pck, saved to user://district_cache/) -> mount
##   (ProjectSettings.load_resource_pack, replace_files = false so the main pack always wins) -> threaded scene load ->
##   instance at the registry origin under WorldSim, and drop the temporary edge apron.
##   Crossing into the bounds records the visit in save.exploration (visits, first/last visit time) and persists.
## Until the district arrives, a flat apron from the main pack (registry "apron") sits past the edge so the wheels never
## drop. A failed fetch shows a "no signal" card, leaves the apron, and retries on the next approach.
## M0 arms a district only with ?district=<id> (web) or the district=<id> user arg, or "free_roam": true in the registry,
## so free roam and the HQ are unchanged.

signal state_changed(id: String, state: String)
signal entered(id: String, visit: int)

const JsonFile = preload("res://scripts/json_file.gd")
const Cards = preload("res://scripts/loading_cards.gd")
const CardView = preload("res://scripts/loading_card_view.gd")
const Blocks = preload("res://scripts/world_blocks.gd")
const REGISTRY := "res://data/districts.json"
const CACHE_DIR := "user://district_cache"
const RETRY_COOLDOWN_S := 8.0

var main: Node            # hq_main (world_sim, player, flow)
var registry: Dictionary = {}
var armed: Array[String] = []
var info: Dictionary = {}  # id -> runtime record
var view: CanvasLayer
## Tests: a directory holding <id>.pck to load from disk instead of HTTP; "" = auto.
var pack_dir := ""
## Tests: always go through a pack even when running from source.
var force_pack := false
var showing := ""
var card_since := 0.0

func bind(owner_main: Node) -> void:
	main = owner_main

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var data = JsonFile.read(REGISTRY)
	registry = data.get("districts", {}) if typeof(data) == TYPE_DICTIONARY else {}
	view = CardView.new()
	view.name = "LoadingCard"
	add_child(view)
	for id in registry:
		if bool(registry[id].get("free_roam", false)):
			arm(id)
	for id in _requested():
		arm(id)
	if not armed.is_empty() and _demo_requested():
		demo = 1

## Browser / capture check (district_demo=1 with district=<id>): put Fony on Rust Avenue skating east at full push so
## he rolls across the district edge while the pack streams in. Opt-in only.
var demo := 0
var demo_ticks := 0

func _demo_requested() -> bool:
	if OS.get_cmdline_user_args().has("district_demo=1"):
		return true
	if OS.has_feature("web"):
		return "district_demo=1" in str(JavaScriptBridge.eval("window.location.search", true))
	return false

func _step_demo() -> void:
	var pl = main.player
	demo_ticks += 1
	if demo == 1 and demo_ticks > 30:
		pl.global_position = Vector3(36.0, 0.5, 90.0)   # west end of Rust Avenue (x 34 .. 70)
		pl.velocity = Vector3.ZERO
		pl.camera_yaw = -PI * 0.5 - pl.rotation.y   # relative to the body: face +X (east)
		pl.skating = true
		pl.external_move_active = true
		pl.external_move = Vector2(0, 1)
		demo = 2
	elif demo == 2 and pl.global_position.x > 104.0:
		pl.external_move = Vector2.ZERO
		demo = 3

## Turn a district on in this session (edge apron + approach watch). Returns false for an unknown id.
func arm(id: String) -> bool:
	if not registry.has(id):
		push_warning("district: unknown id " + id)
		_publish(id, "unknown")
		return false
	if armed.has(id):
		return true
	armed.append(id)
	info[id] = {"state": "idle", "approach": false, "entered": false, "visit": 0, "card": {}, "root": null,
		"apron": null, "http": null, "path": "", "failed_at": -1000.0, "reason": "", "bytes": 0, "total": -1}
	if main != null and main.flow != null:
		main.flow.save.load_exploration_user(main.flow.save_path)
	_add_apron(id)
	_publish(id, "idle")
	return true

func state(id: String) -> String:
	return str(info[id]["state"]) if info.has(id) else "off"

func zone_for(p: Vector3) -> String:
	for id in armed:
		if _inside(id, p):
			return str(registry[id].get("zone", id.to_upper()))
	return ""

## Start (or restart after a failure) loading a district now, with its card. Used by the approach watch and by tests.
func request(id: String) -> void:
	if not info.has(id) and not arm(id):
		return
	var rec: Dictionary = info[id]
	_show_card(id)
	if rec["state"] in ["fetching", "mounting", "instancing", "ready"]:
		return
	rec["reason"] = ""
	var path := _local_pack(id)
	if path != "":
		rec["path"] = path
		_mount(id)
	elif _web_url(id) != "":
		_fetch(id, _web_url(id))
	elif not force_pack and ResourceLoader.exists(str(registry[id]["scene"])):
		# Running from source (editor / headless without a built pack): the scene is already in res://.
		_instance(id)
	else:
		_fail(id, "no_source")

func _physics_process(_delta: float) -> void:
	if main == null or main.player == null:
		return
	if demo > 0 and demo < 3:
		_step_demo()
	var p: Vector3 = main.player.global_position
	for id in armed:
		var rec: Dictionary = info[id]
		var d := _distance(id, p)
		var near := d <= float(registry[id].get("prefetch_m", 40.0))
		if near and not rec["approach"]:
			rec["approach"] = true
			if rec["state"] != "failed" or _now() - float(rec["failed_at"]) >= RETRY_COOLDOWN_S:
				request(id)
			else:
				_show_card(id)
		elif not near and d > float(registry[id].get("prefetch_m", 40.0)) + 20.0 and rec["approach"]:
			rec["approach"] = false
			rec["entered"] = false
		if _inside(id, p) and not rec["entered"]:
			rec["entered"] = true
			var visit: int = main.flow.save.record_district_visit(id, int(Time.get_unix_time_from_system()))
			main.flow.persist()
			entered.emit(id, visit)
			_publish(id, rec["state"])
	if OS.has_feature("web") and not armed.is_empty():
		# Live readout for the browser check: game-time ticks and the body's ground speed (m/s).
		JavaScriptBridge.eval("if(window.AU_DISTRICT){window.AU_DISTRICT.tick=%d;window.AU_DISTRICT.speed=%.3f;window.AU_DISTRICT.px=%.3f;}" % [Engine.get_physics_frames(), Vector2(main.player.velocity.x, main.player.velocity.z).length(), p.x], true)

func _process(_delta: float) -> void:
	for id in armed:
		var rec: Dictionary = info[id]
		match str(rec["state"]):
			"fetching":
				var http: HTTPRequest = rec["http"]
				if http != null:
					rec["bytes"] = http.get_downloaded_bytes()
					rec["total"] = http.get_body_size()
			"instancing":
				_poll_instance(id)
	_update_card()

## --- sources --------------------------------------------------------------------------------------------------------

func _requested() -> Array[String]:
	var out: Array[String] = []
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("district="):
			out.append(arg.trim_prefix("district="))
	if OS.has_feature("web"):
		var search := str(JavaScriptBridge.eval("window.location.search", true))
		for part in search.trim_prefix("?").split("&"):
			if part.begins_with("district="):
				out.append(part.trim_prefix("district=").uri_decode())
	return out

func _local_pack(id: String) -> String:
	var name := str(registry[id]["pack"]).get_file()
	var dirs: Array[String] = []
	if pack_dir != "":
		dirs.append(pack_dir)
	elif not OS.has_feature("web"):
		if OS.get_environment("AU_DISTRICT_DIR") != "":
			dirs.append(OS.get_environment("AU_DISTRICT_DIR"))
		if OS.has_feature("template"):
			dirs.append(OS.get_executable_path().get_base_dir().path_join("districts"))
		else:
			dirs.append(ProjectSettings.globalize_path("res://build/web/districts"))
	for dir in dirs:
		var path := dir.path_join(name)
		if FileAccess.file_exists(path):
			return path
	return ""

func _web_url(id: String) -> String:
	if not OS.has_feature("web") or pack_dir != "":
		return ""
	var rel := str(registry[id]["pack"]).replace("'", "")
	return str(JavaScriptBridge.eval("new URL('%s', document.baseURI).href" % rel, true))

func _fetch(id: String, url: String) -> void:
	var rec: Dictionary = info[id]
	DirAccess.make_dir_recursive_absolute(CACHE_DIR)
	var http := HTTPRequest.new()
	http.name = "Fetch_" + id
	http.timeout = 60.0
	http.body_size_limit = int(registry[id].get("budget_bytes", 8 * 1024 * 1024)) * 2
	add_child(http)
	rec["http"] = http
	rec["path"] = CACHE_DIR.path_join(id + ".pck")
	# The body arrives in memory and is written (and closed) here before mounting, so the pack file is complete.
	http.request_completed.connect(func(result: int, code: int, _h, body: PackedByteArray): _fetched(id, result, code, body))
	var err := http.request(url)
	if err != OK:
		_fail(id, "request_%d" % err)
		return
	_set_state(id, "fetching")

func _fetched(id: String, result: int, code: int, body: PackedByteArray) -> void:
	var rec: Dictionary = info[id]
	if rec["http"] != null:
		(rec["http"] as Node).queue_free()
		rec["http"] = null
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		_fail(id, "http_%d_%d" % [result, code])
		return
	var f := FileAccess.open(rec["path"], FileAccess.WRITE)
	if f == null:
		_fail(id, "cache_write")
		return
	f.store_buffer(body)
	f.close()
	_mount(id)

func _mount(id: String) -> void:
	var rec: Dictionary = info[id]
	_set_state(id, "mounting")
	var path: String = rec["path"]
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null or f.get_length() < 16 or f.get_buffer(4).get_string_from_ascii() != "GDPC":
		_fail(id, "not_a_pack")
		return
	rec["bytes"] = f.get_length()
	rec["total"] = f.get_length()
	f.close()
	if not ProjectSettings.load_resource_pack(path, false):
		_fail(id, "mount")
		return
	if not ResourceLoader.exists(str(registry[id]["scene"])):
		_fail(id, "scene_missing")
		return
	_instance(id)

func _instance(id: String) -> void:
	var err := ResourceLoader.load_threaded_request(str(registry[id]["scene"]), "PackedScene")
	if err != OK:
		_fail(id, "load_%d" % err)
		return
	_set_state(id, "instancing")

func _poll_instance(id: String) -> void:
	var rec: Dictionary = info[id]
	var scene_path := str(registry[id]["scene"])
	var st := ResourceLoader.load_threaded_get_status(scene_path)
	if st == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		return
	if st != ResourceLoader.THREAD_LOAD_LOADED:
		_fail(id, "load_status_%d" % st)
		return
	var packed = ResourceLoader.load_threaded_get(scene_path)
	if not (packed is PackedScene):
		_fail(id, "not_a_scene")
		return
	var root: Node3D = (packed as PackedScene).instantiate()
	root.name = "District_" + id
	var o: Array = registry[id].get("origin", [0, 0, 0])
	root.position = Vector3(float(o[0]), float(o[1]), float(o[2]))
	main.world_sim.add_child(root)
	rec["root"] = root
	if rec["apron"] != null:
		(rec["apron"] as Node).queue_free()
		rec["apron"] = null
	_set_state(id, "ready")

func _fail(id: String, reason: String) -> void:
	var rec: Dictionary = info[id]
	rec["reason"] = reason
	rec["failed_at"] = _now()
	push_warning("district %s failed: %s" % [id, reason])
	_set_state(id, "failed")

## --- geometry -------------------------------------------------------------------------------------------------------

func _rect(id: String, key := "bounds") -> Rect2:
	var b: Array = registry[id].get(key, [0, 0, 0, 0])
	return Rect2(Vector2(float(b[0]), float(b[1])), Vector2(float(b[2]) - float(b[0]), float(b[3]) - float(b[1])))

func _inside(id: String, p: Vector3) -> bool:
	return _rect(id).has_point(Vector2(p.x, p.z))

func _distance(id: String, p: Vector3) -> float:
	var r := _rect(id)
	var q := Vector2(clampf(p.x, r.position.x, r.end.x), clampf(p.z, r.position.y, r.end.y))
	return q.distance_to(Vector2(p.x, p.z))

func _add_apron(id: String) -> void:
	if main == null or main.world_sim == null or not registry[id].has("apron"):
		return
	var r := _rect(id, "apron")
	var c := r.get_center()
	var apron := Node3D.new()
	apron.name = "DistrictApron_" + id
	main.world_sim.add_child(apron)
	Blocks.solid(apron, "Floor", Vector3(c.x, -0.5, c.y), Vector3(r.size.x, 1.0, r.size.y), Color("8d6f62"), Vector3.ZERO, 0.04)
	# Low walls on the three far sides, so a rider on the stand-in floor cannot roll off the world.
	var wall := Color("6b5a52")
	Blocks.solid(apron, "WallFar", Vector3(r.end.x, 0.6, c.y), Vector3(0.6, 1.2, r.size.y), wall)
	Blocks.solid(apron, "WallNorth", Vector3(c.x, 0.6, r.position.y), Vector3(r.size.x, 1.2, 0.6), wall)
	Blocks.solid(apron, "WallSouth", Vector3(c.x, 0.6, r.end.y), Vector3(r.size.x, 1.2, 0.6), wall)
	info[id]["apron"] = apron

## --- card -----------------------------------------------------------------------------------------------------------

func _show_card(id: String) -> void:
	var rec: Dictionary = info[id]
	var visit := 1
	if main != null and main.flow != null:
		visit = main.flow.save.district_visits(id) + (0 if rec["entered"] else 1)
	rec["visit"] = visit
	var data := Cards.read(str(registry[id].get("cards", "")))
	rec["card"] = Cards.pick(data, visit, str(registry[id].get("title", id)))
	rec["min_s"] = Cards.min_seconds(data)
	view.show_card(rec["card"])
	showing = id
	card_since = _now()
	_publish(id, rec["state"])

func _update_card() -> void:
	if showing == "" or not info.has(showing):
		return
	var rec: Dictionary = info[showing]
	var title := str(registry[showing].get("title", showing))
	var st := str(rec["state"])
	var frac := -1.0
	var text := ""
	match st:
		"fetching":
			if int(rec["total"]) > 0:
				frac = float(rec["bytes"]) / float(rec["total"])
				text = "STREAMING %s · %d%% · %.1f / %.1f MB" % [title, int(frac * 100.0), float(rec["bytes"]) / 1048576.0, float(rec["total"]) / 1048576.0]
			else:
				text = "STREAMING %s · %.1f MB" % [title, float(rec["bytes"]) / 1048576.0]
		"mounting", "instancing":
			frac = 0.95
			text = "BUILDING %s" % title
		"ready":
			frac = 1.0
			text = "%s · READY" % title
		"failed":
			frac = 0.0
			text = "NO SIGNAL · %s DID NOT LOAD · KEEP SKATING" % title
		_:
			text = title
	view.set_progress(frac, text)
	if (st == "ready" or st == "failed") and _now() - card_since >= float(rec.get("min_s", 4.0)):
		view.hide_card()
		showing = ""

## --- misc -----------------------------------------------------------------------------------------------------------

func _set_state(id: String, s: String) -> void:
	info[id]["state"] = s
	state_changed.emit(id, s)
	_publish(id, s)

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

func _publish(id: String, s: String) -> void:
	if not OS.has_feature("web"):
		return
	var rec: Dictionary = info.get(id, {})
	var visits := 0
	if main != null and main.flow != null:
		visits = main.flow.save.district_visits(id)
	JavaScriptBridge.eval("window.AU_DISTRICT=%s;" % JSON.stringify({
		"id": id, "state": s, "visits": visits, "card": str(rec.get("card", {}).get("id", "")),
		"tier": str(rec.get("card", {}).get("tier", "")), "reason": str(rec.get("reason", "")),
		"bytes": int(rec.get("bytes", 0)),
	}), true)
