extends Node
## MISSION P.2 Run (Act I milestone M3, Nov 19 2026). After CINEMATIC P.3 Flagged ("Push."), Fony runs from the welfare
## drone and two Warden enforcement drones: out through the gap in the Yard's east fence, down the service alley behind
## Glass Row (the A1 glass_row_edge district pack, streamed in when the run starts), over the dumpster and along the
## loading dock or up the parking ramp under the drone camera, across the plaza past the Silver-tier mister kiosk, and
## down through the loose drain grate under the stairs. The culvert brings him up in the Yard's NE corner; he crosses
## to the arcade's side door and the chain falls away. P.3 Power On (M4) is not built yet: an end card says so.
##
## Rules (data/missions/p2_run.json): caught by a net -> short fade -> restart at the last checkpoint (yard, fence gap,
## plaza, culvert), no lives. Zero Score is time-based (lower wins): the first escape sets Zero's time, saved in the
## mission record in ms. Zero guides by TEXT (??? header still) and through Glass Row's screens (the face hops from the
## parking meter to the store window to the bus shelter). Text + synthesized SFX only.

signal finished(time_ms: int)

const JsonFile = preload("res://scripts/json_file.gd")
const World = preload("res://scripts/story/story_world.gd")
const Chase = preload("res://scripts/story/chase.gd")
const Protagonist = preload("res://scripts/front/protagonist.gd")
const DEF_PATH := "res://data/missions/p2_run.json"
const ID := "p2_run"
const DISTRICT := "glass_row_edge"
const SCREEN_NAMES := {"meter": "PARKING METER", "bus": "BUS SHELTER", "store": "STORE WINDOW"}
const DRONE_BARK_S := 7.5

var host: Node                      # practice_run.gd
var def: Dictionary = {}
var chase: Node
var dressing: Node3D                # fence gap pieces, the beacon, the yard search drone
var state := ""                     # "" / intro / run / caught / culvert / yard / door / done
var checkpoint := "yard"
var clock := 0.0                    # run time (s); keeps counting through restarts
var state_left := 0.0
var fired := {}                     # one-shot triggers this run
var routes := {}                    # route id -> true (taken this run)
var bark_left := DRONE_BARK_S
var bark_i := 0
var air := 0.0
var close_said := false
var screen_left := 0.0
var screen_on: Node3D
var hidden_wall: Node3D
var wall_layer := 0
var pilot: Dictionary = {}          # review / test autopilot: {route, legs, leg, clock, caught_once, log, finished}
var fails := 0
var log: Array = []                 # tests / probes: "event" strings

func setup(h: Node) -> void:
	host = h
	var d = JsonFile.read(DEF_PATH)
	def = d if typeof(d) == TYPE_DICTIONARY else {}

func active() -> bool:
	return state != "" and state != "done"

func rec() -> Dictionary:
	return host.flow.save.mission(ID)

func hides_prompts() -> bool:
	return state in ["intro", "caught", "culvert", "door"]

# ------------------------------------------------------------------ start / stop

## Starts (or resumes) the run at a checkpoint id ("" = the start).
func start(from := "") -> void:
	var r := rec()
	checkpoint = from if from != "" else "yard"
	if _cp(checkpoint).is_empty():
		checkpoint = "yard"
	state = "intro"
	state_left = float(def.get("fade_s", 0.6))
	clock = float(r.get("time_s", 0.0)) if from != "" and from != "yard" else 0.0
	fired = {}
	routes = {}
	bark_left = DRONE_BARK_S
	air = 0.0
	close_said = false
	fails = int(r.get("fails", 0))
	r["state"] = "active"
	r["checkpoint"] = checkpoint
	host.flow.save.set_flag("p2_run_started")
	host.flow.save.story["current"] = ID
	host.flow.persist()
	if dressing == null or not is_instance_valid(dressing):
		dressing = Node3D.new()
		dressing.name = "P2RunDressing"
		host.main.world_sim.add_child(dressing)
		_open_fence_gap()
		_beacon()
	if chase == null:
		chase = Chase.new()
		chase.name = "Chase"
		add_child(chase)
		chase.setup(def.get("drones", {}), host.player, dressing)
		chase.caught.connect(_on_caught)
		chase.lost.connect(_on_lost)
		chase.enforcers_in.connect(_on_enforcers)
	# the district streams in now, long before he reaches the fence gap; the apron holds the wheels meanwhile
	var dl = host.main.get("districts")
	if dl != null:
		dl.arm(DISTRICT)
		dl.request(DISTRICT)
	host.hud.fade_to(1.0, 0.01)
	host.hud.fade_alpha()
	_place(checkpoint)
	host.hud.set_objective(str(def.get("title", "P.2 RUN")), str(_cp(checkpoint).get("text", "")))
	_hud_zero()
	if checkpoint == "yard" and not fired.has("start"):
		fired["start"] = true
		var toggles: Dictionary = def.get("toggles", {})
		if bool(toggles.get("title_card", false)):
			host._say_all([["CARD", str(toggles.get("title_card_text", "MISSION P.2 · RUN"))]])
		host._say_all(_fill(def.lines.start))
	log.append("start:" + checkpoint)

## Leaves the run (story stop or slice end): the fence closes, the drones go.
func teardown() -> void:
	if chase != null:
		chase.free_all()
		chase.queue_free()
		chase = null
	_close_fence_gap()
	if dressing != null and is_instance_valid(dressing):
		dressing.queue_free()
	dressing = null
	if screen_on != null and is_instance_valid(screen_on):
		_screen_face(screen_on, false)
	screen_on = null
	if host.player != null:
		host.player.input_enabled = true
		host.player.external_move_active = false
	host.hud.fade_to(0.0, 0.01)
	if state != "done":
		state = ""

# ------------------------------------------------------------------ per frame

func tick(delta: float) -> void:
	if state == "" or state == "done":
		return
	if state != "door":
		clock += delta
	_screen_tick(delta)
	_pilot_tick(delta)
	match state:
		"intro":
			state_left -= delta
			if state_left <= 0.0:
				host.hud.fade_to(0.0, float(def.get("fade_s", 0.6)))
				host.player.input_enabled = true
				state = "yard" if checkpoint == "culvert" else "run"
				if state == "run":
					chase.begin(_cp(checkpoint).get("drones_behind", []), checkpoint != "yard")
				else:
					_yard_search_drone()
		"run":
			chase.tick(delta)
			_triggers()
			_barks(delta)
		"caught":
			state_left -= delta
			if state_left <= 0.0:
				_restart()
		"culvert":
			state_left -= delta
			if state_left <= 0.0 and host.talking == "" and host.queue.is_empty():
				_place("culvert")
				_set_checkpoint("culvert")
				_yard_search_drone()
				host.hud.fade_to(0.0, float(def.get("fade_s", 0.6)))
				host.player.input_enabled = true
				state = "yard"
		"yard":
			if _near(def.targets.door, float(def.get("door_r", 2.2))):
				_door()
		"door":
			state_left -= delta
			if state_left <= 0.0 and host.talking == "" and host.queue.is_empty():
				_finish()
	_beacon_tick()
	_hud_time()

func _triggers() -> void:
	var p: Vector3 = host.player.global_position
	# checkpoints (in route order; never back)
	var order := ["yard", "fence_gap", "plaza"]
	for i in range(order.find(checkpoint) + 1, order.size()):
		var c := _cp(order[i])
		if c.has("at") and _near(c.at, float(c.get("r", 6.0))):
			_set_checkpoint(order[i])
			host.sfx.play("objective")
			host.hud.toast("CHECKPOINT")
	if not fired.has("fork") and p.x > 90.0 and p.x < 104.0 and absf(p.z - 29.0) < 7.0:
		fired["fork"] = true
		host._say_all(_fill(def.lines.fork))
	for rid in def.get("routes", {}):
		var r: Dictionary = def.routes[rid]
		var rect: Array = r.rect
		if not routes.has(rid) and p.x >= rect[0] and p.x <= rect[2] and p.z >= rect[1] and p.z <= rect[3] and p.y >= float(r.min_y):
			routes[rid] = true
			host.flow.save.discover(DISTRICT, "shortcuts", rid)
			host.flow.save.set_flag("p2_route_" + rid)
			log.append("route:" + rid)
			host.hud.toast(str(r.get("label", rid)).to_upper())
	var cam: Dictionary = def.get("camera", {})
	var cr: Array = cam.get("rect", [0, 0, 0, 0])
	if not fired.has("camera") and p.x >= cr[0] and p.x <= cr[2] and p.z >= cr[1] and p.z <= cr[3]:
		fired["camera"] = true
		chase.spot()
		host.sfx.play("alert")
		host.hud.toast("SPOTTED · DRONE CAMERA")
		host._say_all(_fill(def.lines.camera))
		log.append("camera")
	if not fired.has("plaza") and p.x > 128.0:
		fired["plaza"] = true
		host._say_all(_fill(def.lines.plaza))
	if not fired.has("kiosk") and Vector2(p.x - 150.0, p.z - 5.5).length() < 9.0:
		fired["kiosk"] = true
		_kiosk_off()
		host._say_all(_fill(def.lines.kiosk))
	if not fired.has("stairs") and p.x > 137.0:
		fired["stairs"] = true
		host._say_all(_fill(def.lines.stairs))
	if _near(def.targets.grate, float(def.get("grate_r", 1.7))):
		_culvert()
	# a big landing
	if not host.player.is_on_floor():
		air += get_process_delta_time()
	else:
		if air > 0.55 and not fired.has("land"):
			fired["land"] = true
			host._say_all(def.barks.fony_land)
		air = 0.0

func _barks(delta: float) -> void:
	bark_left -= delta
	var near: float = chase.nearest_distance()
	if not close_said and near < 6.0:
		close_said = true
		host._say_all(def.barks.fony_close)
	if bark_left <= 0.0 and host.queue.is_empty() and host.talking == "":
		bark_left = DRONE_BARK_S
		var pool: Array = def.barks.drones
		host._say_all([pool[bark_i % pool.size()]])
		bark_i += 1

# ------------------------------------------------------------------ events

func _on_caught(kind: String) -> void:
	state = "caught"
	state_left = float(def.get("fade_s", 0.6)) + 0.9
	fails += 1
	rec()["fails"] = fails
	host.player.input_enabled = false
	host.sfx.play("net")
	host.hud.toast("CAUGHT")
	host.hud.fade_to(1.0, float(def.get("fade_s", 0.6)))
	host.queue.clear()
	host._say_all(_fill(def.lines.caught))
	log.append("caught:" + kind + "@" + checkpoint)
	host.flow.persist()

func _restart() -> void:
	host.queue.clear()
	host.talk_left = 0.0
	_place(checkpoint)
	host.hud.fade_to(0.0, float(def.get("fade_s", 0.6)))
	host.player.input_enabled = true
	chase.begin(_cp(checkpoint).get("drones_behind", []), checkpoint != "yard")
	close_said = false
	state = "run"
	log.append("restart:" + checkpoint)

func _on_lost() -> void:
	if not fired.has("lost"):
		fired["lost"] = true
		host._say_all(_fill(def.lines.lost))
	log.append("lost")

func _on_enforcers() -> void:
	if not fired.has("enforcers"):
		fired["enforcers"] = true
		host.sfx.play("drone_chime")
		host._say_all(_fill(def.lines.enforcers))

func _culvert() -> void:
	state = "culvert"
	state_left = float(def.get("culvert_s", 3.2))
	chase.clear()
	host.player.input_enabled = false
	host.player.velocity = Vector3.ZERO
	# chatter goes; Zero's screen lines still play (they come up in the thread too)
	host.queue = host.queue.filter(func(q): return str(q[0]).begins_with("SCREEN "))
	host.hud.fade_to(1.0, float(def.get("fade_s", 0.6)))
	host.sfx.play("bail")
	host._say_all(_fill(def.lines.culvert))
	log.append("culvert")

func _door() -> void:
	state = "door"
	state_left = 1.0
	host.player.input_enabled = false
	host.player.velocity = Vector3.ZERO
	host.queue.clear()
	host.sfx.play("sting")
	host._say_all(_fill(def.lines.door))
	log.append("door")

func _finish() -> void:
	state = "done"
	var ms := int(round(clock * 1000.0))
	var r := rec()
	var first := int(r.get("completions", 0)) == 0
	r["completions"] = int(r.get("completions", 0)) + 1
	r["state"] = "done"
	r["checkpoint"] = ""
	if int(r.get("best_score", 0)) <= 0 or ms < int(r.get("best_score", 0)):
		r["best_score"] = ms
	var zero := int(r.get("zero_score", 0))
	if zero <= 0:
		zero = zero_for(ms, int(def.zero_time.get("round_s", 5)), int(def.zero_time.get("min_s", 30)))
		r["zero_score"] = zero
		host._say_all(_fill(def.lines.zero_time_set, {"time": fmt_time(zero)}))
	elif ms < zero and not host.flow.save.flag("p2_zero_beaten"):
		host.flow.save.set_flag("p2_zero_beaten")
		host._say_all(_fill(def.lines.zero_time_beaten, {"time": fmt_time(ms)}))
	host.flow.save.set_flag("p2_run_done")
	host.flow.persist()
	_hud_zero()
	if chase != null:
		chase.clear()
	host.player.input_enabled = true
	log.append("done:%d%s" % [ms, ":first" if first else ""])
	finished.emit(ms)

## Zero's time: the next whole round_s below the first escape (never under min_s), in ms.
static func zero_for(ms: int, round_s := 5, min_s := 30) -> int:
	var s := int(floor(float(ms) / 1000.0 / float(round_s))) * round_s
	if s * 1000 >= ms:
		s -= round_s
	return maxi(min_s, s) * 1000

static func fmt_time(ms: int) -> String:
	var t := maxi(0, ms)
	return "%d:%02d.%d" % [t / 60000, (t / 1000) % 60, (t / 100) % 10]

# ------------------------------------------------------------------ the Yard side: fence gap, beacon, search drone

func _open_fence_gap() -> void:
	hidden_wall = host.main.world_sim.find_child("YardWallEast", true, false) as Node3D
	if hidden_wall != null:
		hidden_wall.visible = false
		if hidden_wall is CollisionObject3D:
			wall_layer = hidden_wall.collision_layer
			hidden_wall.collision_layer = 0
	var Blocks = load("res://scripts/world_blocks.gd")
	var c := Color("7a6a60")
	# the east wall in two pieces, with a 6 m gap at z 26 .. 32 behind a dumpster (Prologue only; 1.6 welds it shut)
	Blocks.solid(dressing, "EastWallNorth", Vector3(80.0, 1.8, -27.0), Vector3(1.6, 3.6, 106.0), c)
	Blocks.solid(dressing, "EastWallSouth", Vector3(80.0, 1.8, 56.0), Vector3(1.6, 3.6, 48.0), c)
	# the Yard slab stops at the wall: a strip of broken concrete through the gap so the wheels never drop
	Blocks.solid(dressing, "GapFloor", Vector3(81.0, -0.5, 29.0), Vector3(3.4, 1.0, 8.0), Color("8d6f62"), Vector3.ZERO, 0.04)
	Blocks.solid(dressing, "GapDumpster", Vector3(77.6, 0.7, 23.6), Vector3(2.6, 1.4, 1.6), Color("3f6a4a"))
	for i in 3:
		Blocks.visual(dressing, "TornFence%d" % i, Vector3(80.0, 0.6 + i * 1.1, 25.6), Vector3(0.1, 0.06, 0.8), Color("9a9a9a"))
	var lbl = Blocks.label(dressing, "GAP", Vector3(80.0, 4.2, 29.0), Color("c6ff3d"), 40)
	lbl.name = "GapLabel"

func _close_fence_gap() -> void:
	if hidden_wall != null and is_instance_valid(hidden_wall):
		hidden_wall.visible = true
		if hidden_wall is CollisionObject3D:
			hidden_wall.collision_layer = wall_layer if wall_layer != 0 else 1
	hidden_wall = null

func _beacon() -> void:
	var b := MeshInstance3D.new()
	b.name = "Beacon"
	var m := CylinderMesh.new()
	m.top_radius = 0.25
	m.bottom_radius = 0.25
	m.height = 14.0
	b.mesh = m
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.78, 1.0, 0.24, 0.35)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	b.material_override = mat
	dressing.add_child(b)

## The beacon stands on the next target: the gap, the fork, the plaza, the grate, then the door.
func next_target() -> Array:
	if state == "yard" or state == "door" or state == "done":
		return def.targets.door
	if checkpoint == "yard":
		return def.targets.fence_gap
	if checkpoint == "fence_gap":
		return def.targets.plaza if host.player.global_position.x > 104.0 else def.targets.fork
	return def.targets.grate

func _beacon_tick() -> void:
	var b := dressing.get_node_or_null("Beacon") as Node3D if dressing != null else null
	if b == null:
		return
	var t := next_target()
	b.global_position = Vector3(float(t[0]), 7.0, float(t[1]))
	b.visible = state in ["run", "yard"]

func _yard_search_drone() -> void:
	if dressing.get_node_or_null("SearchDrone") != null:
		return
	var d := World.welfare_drone(dressing)
	d.name = "SearchDrone"
	d.global_position = Vector3(40.0, 12.0, -60.0)
	World.drone_scan(d, true)

func _kiosk_off() -> void:
	var k := _district_node("MisterKiosk")
	if k != null:
		var mist := k.get_node_or_null("Mist") as Node3D
		if mist != null:
			mist.visible = false
		var tag := k.get_node_or_null("KioskTag") as Label3D
		if tag != null:
			tag.text = "COMFORT MIST · SILVER TIER\nSENSOR: NOT ELIGIBLE"
	log.append("kiosk_off")

func _district_node(name: String) -> Node:
	for c in host.main.world_sim.get_children():
		if c.has_meta("district_id") and str(c.get_meta("district_id")) == DISTRICT:
			return c.find_child(name, true, false)
	return null

# ------------------------------------------------------------------ Zero on Glass Row's screens

func handles(who: String) -> bool:
	return who.begins_with("SCREEN ") or who == "NARRATE"

## Shows a screen or narration line; returns how long it holds.
func show_line(who: String, text: String) -> float:
	var pname: String = Protagonist.current(get_tree())
	var t: String = Protagonist.text(text, pname)
	if who == "NARRATE":
		host.hud.say("", "(" + t + ")")
		host.spoken.append("NARRATE|" + t)
		return clampf(1.0 + 0.04 * t.length(), 2.4, 6.0)
	var key := who.trim_prefix("SCREEN ")
	host.hud.say("??? · " + str(SCREEN_NAMES.get(key, "SCREEN")), t)
	host.hud.say_text(host.hud.phone_sender, t, false, true)
	host.spoken.append("SCREEN " + key + "|" + t)
	host.sfx.play("crt")
	var s := _district_node({"meter": "ScreenMeter", "bus": "ScreenBusShelter", "store": "ScreenStore"}.get(key, "")) as Node3D
	if screen_on != null and is_instance_valid(screen_on):
		_screen_face(screen_on, false)
	screen_on = s
	if s != null:
		_screen_face(s, true)
	screen_left = 4.5
	log.append("screen:" + key + (":face" if s != null else ""))
	return clampf(1.0 + 0.045 * t.length(), 2.5, 6.0)

func _screen_face(s: Node3D, on: bool) -> void:
	var f := s.get_node_or_null("Face") as Node3D
	var a := s.get_node_or_null("Ad") as Node3D
	if f != null:
		f.visible = on
	if a != null:
		a.visible = not on

func _screen_tick(delta: float) -> void:
	if screen_left > 0.0:
		screen_left -= delta
		if screen_left <= 0.0 and screen_on != null and is_instance_valid(screen_on):
			_screen_face(screen_on, false)
			screen_on = null

# ------------------------------------------------------------------ helpers

func _cp(id: String) -> Dictionary:
	for c in def.get("checkpoints", []):
		if str(c.id) == id:
			return c
	return {}

func _set_checkpoint(id: String) -> void:
	checkpoint = id
	var r := rec()
	r["checkpoint"] = id
	r["time_s"] = clock
	host.hud.set_objective(str(def.get("title", "P.2 RUN")), str(_cp(id).get("text", "")))
	host.flow.persist()
	log.append("checkpoint:" + id)

func _place(id: String) -> void:
	var c := _cp(id)
	var p: Array = c.get("pos", def.start.pos)
	var pl = host.player
	pl.spawn_position = Vector3(float(p[0]), float(p[1]), float(p[2]))
	pl.spawn_yaw = deg_to_rad(float(c.get("yaw_deg", -90.0)))
	pl.respawn()
	pl.camera_yaw = 0.0
	if pl.rig != null and pl.rig.has_method("face_world"):
		pl.rig.face_world(pl.spawn_yaw)
	pl.skating = true
	pl.trick = ""
	pl.bail_time = 0.0
	pl.update_board()
	pl.input_enabled = false

func _near(xz: Array, r: float) -> bool:
	var p: Vector3 = host.player.global_position
	return Vector2(p.x - float(xz[0]), p.z - float(xz[1])).length() < r

func _fill(lines: Array, values := {}) -> Array:
	var out: Array = []
	for l in lines:
		var t := str(l[1])
		for k in values:
			t = t.replace("{" + k + "}", str(values[k]))
		out.append([str(l[0]), t])
	return out

func _hud_time() -> void:
	host.hud.set_line("TIME  " + fmt_time(int(clock * 1000.0)) + ("   ·   CAUGHT x%d" % fails if fails > 0 else ""))

func _hud_zero() -> void:
	var r := rec()
	var z := int(r.get("zero_score", 0))
	var b := int(r.get("best_score", 0))
	host.hud.zero_label.text = "ZERO TIME  " + (fmt_time(z) if z > 0 else "—")
	host.hud.best_label.text = "BEST  " + (fmt_time(b) if b > 0 else "—")

# ------------------------------------------------------------------ review / test autopilot

## Drives the run through the real physics (stick only). route: "dock" or "ramp". get_caught: stop once at the fork
## and let the drones net him, to show the restart.
func start_pilot(route := "dock", get_caught := false) -> void:
	var legs: Array = [[78.0, 29.0], [90.0, 29.0]]
	if route == "dock":
		legs += [[96.0, 25.4], [99.5, 25.2], [110.0, 25.2], [120.5, 25.2], [126.0, 25.2]]
	else:
		legs += [[97.0, 33.6], [101.5, 33.6], [114.0, 33.6], [126.5, 33.6], [131.0, 32.0]]
	legs += [[140.0, 24.0], [150.0, 12.5], [160.0, 15.4], [165.0, 15.4]]
	pilot = {"route": route, "legs": legs, "yard": [[77.5, -40.0], [77.5, -3.5], [57.0, -3.5], [54.3, -4.6]],
		"leg": 0, "clock": 0.0, "get_caught": get_caught, "caught_once": false, "log": [], "finished": false, "stall": 0.0}

func _pilot_tick(delta: float) -> void:
	if pilot.is_empty() or pilot.finished:
		return
	var pl = host.player
	pilot.clock += delta
	if state == "done":
		pilot.finished = true
		pl.external_move_active = false
		pl.external_move = Vector2.ZERO
		return
	pl.external_move_active = true
	if state in ["intro", "caught", "culvert", "door"]:
		pl.external_move = Vector2.ZERO
		if state == "caught":
			pilot.caught_once = true
			# after the restart the legs pick up from the checkpoint
			pilot.leg = 0
		return
	var legs: Array = pilot.yard if state == "yard" else pilot.legs
	if state == "yard" and not pilot.has("in_yard"):
		pilot["in_yard"] = true
		pilot.leg = 0
	if pilot.get_caught and not pilot.caught_once and checkpoint == "fence_gap" and pl.global_position.x > 88.0:
		pl.external_move = Vector2.ZERO
		return
	# skip legs already behind him (after a restart)
	while pilot.leg < legs.size() - 1 and state == "run" and float(legs[pilot.leg][0]) < pl.global_position.x - 1.0 and float(legs[pilot.leg][0]) > 0.0:
		pilot.leg += 1
	var t: Array = legs[mini(pilot.leg, legs.size() - 1)]
	var to := Vector3(float(t[0]) - pl.global_position.x, 0, float(t[1]) - pl.global_position.z)
	if to.length() < 1.6 and pilot.leg < legs.size() - 1:
		pilot.log.append([snapped(clock, 0.1), pilot.leg, t])
		pilot.leg += 1
	if to.length() > 0.05:
		var d := to.normalized()
		var axes: Array = pl._camera_flat_axes()
		pl.external_move = Vector2(d.dot(axes[1]), d.dot(axes[0]))
