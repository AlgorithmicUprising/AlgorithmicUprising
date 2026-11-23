extends Node
## Act I scenes 1.1 to 1.4B (Nov 20 2026, first pass): MISSION 1.1 Fine Print + CINEMATIC 1.1B The plan, MISSION 1.2
## Water Run, MISSION 1.3 Cool Roofs + CINEMATIC 1.3B First night, MISSION 1.4 Cold Row + CINEMATIC 1.4B The
## Benefactor with Zero Vision's first use (the end of the slice). A small data-driven runner: each scene in
## data/missions/act1_scenes.json is a list of steps run in order (lines, goals, topics, carry, raise, cine, card,
## hook). host = practice_run.gd (its line queue, HUD, SFX, cinematic player, save). PLACEHOLDER blockout art and
## first-pass tuning: see ACT1_NOTES.md. Text + synthesized SFX only.
##
## Saves: one mission record per scene (state, done = goals / deliveries done, checkpoint, completions, best_score,
## zero_score) and a flag per scene (a1_*_done). A reload restarts the first unfinished scene from its top.

signal finished

const JsonFile = preload("res://scripts/json_file.gd")
const Protagonist = preload("res://scripts/front/protagonist.gd")
const World = preload("res://scripts/story/story_world.gd")
const Kit = preload("res://scripts/story/act1_kit.gd")
const Blocks = preload("res://scripts/world_blocks.gd")
const Hud = preload("res://scripts/story/story_hud.gd")
const DEF_PATH := "res://data/missions/act1_scenes.json"
const LIME := Color("c8ff3a")

const PRESETS := {
	"arcade_lit": {
		"sky_top": Color("07060a"), "sky_horizon": Color("0d0a0c"), "ground_horizon": Color("0d0a0c"), "ground_bottom": Color("050404"),
		"ambient": Color("8a8f9a"), "ambient_energy": 0.3, "sun_rot": Vector3(-26, 95, 0), "sun_color": Color("ffc29a"), "sun_energy": 0.0,
	},
	"noon": {
		"sky_top": Color("9cc3e8"), "sky_horizon": Color("f2e6c8"), "ground_horizon": Color("e8d6b0"), "ground_bottom": Color("6a5a48"),
		"ambient": Color("c8b8a0"), "ambient_energy": 0.45, "sun_rot": Vector3(-72, 30, 0), "sun_color": Color("fff1d6"), "sun_energy": 1.5,
	},
	"evening": {
		"sky_top": Color("4a3a78"), "sky_horizon": Color("ff9a5a"), "ground_horizon": Color("d87a4a"), "ground_bottom": Color("3a2a2a"),
		"ambient": Color("b08a8a"), "ambient_energy": 0.35, "sun_rot": Vector3(-12, 250, 0), "sun_color": Color("ffb070"), "sun_energy": 1.0,
	},
	"night": {
		"sky_top": Color("04060e"), "sky_horizon": Color("0c1830"), "ground_horizon": Color("0c1426"), "ground_bottom": Color("020306"),
		"ambient": Color("4a6a9a"), "ambient_energy": 0.22, "sun_rot": Vector3(-40, 200, 0), "sun_color": Color("9fc8ff"), "sun_energy": 0.15,
	},
	"storm": {
		"sky_top": Color("2a2e36"), "sky_horizon": Color("4a5058"), "ground_horizon": Color("3a4048"), "ground_bottom": Color("1a1c20"),
		"ambient": Color("8a9098"), "ambient_energy": 0.4, "sun_rot": Vector3(-60, 30, 0), "sun_color": Color("b8c0cc"), "sun_energy": 0.35,
	},
	"arcade_night": {
		"sky_top": Color("04060e"), "sky_horizon": Color("0c1830"), "ground_horizon": Color("0c1426"), "ground_bottom": Color("020306"),
		"ambient": Color("8a7f9a"), "ambient_energy": 0.32, "sun_rot": Vector3(-40, 200, 0), "sun_color": Color("9fc8ff"), "sun_energy": 0.0,
	},
}

var host: Node
var def: Dictionary = {}
var scene := ""                    # "1.1" .. "1.4"; "" when idle
var step_i := -1
var step: Dictionary = {}
var state := ""                    # "" / fade / step / between / done
var state_left := 0.0
var waiting := false               # lines / cine: waiting for the queue or the cinematic
var done_goals := {}               # goal id -> true (this step)
var checkpoint := ""               # last goal done (resets put him there)
var topic_done := {}
var watch := 0.0
var spotted := 0
var bags := 0                      # 1.2: bags on his back
var melt := 0.0                    # 1.2: seconds left on this load
var budget := 0                    # 1.2: bags the money still buys
var delivered := 0                 # 1.2: bags delivered
var score := 0
var vision := false                # 1.4B: Zero Vision overlay on
var topic_i := 0
var vision_used := false
var root: Node3D                   # per-scene props (drones, crowd, hologram, strings)
var drones: Array = []             # [{node, path, i, speed}]
var overlay: ColorRect
var pilot: Dictionary = {}
var log: Array = []
var fired := {}
var keys_down := {}
var hz_t := 0.0                    # 1.5 boss phase 2: the steam vents' on/off clock
var reroute := 0.0                 # 1.5 hold the line: 0..1
var knocked := 0                   # 1.5 hold the line: drones knocked down
var spawn_left := 0.0
var spawn_i := 0
var hits := 0

func setup(h: Node) -> void:
	host = h
	var d = JsonFile.read(DEF_PATH)
	def = d if typeof(d) == TYPE_DICTIONARY else {}

func order() -> Array:
	return def.get("order", [])

func sdef(id := "") -> Dictionary:
	return def.get("scenes", {}).get(id if id != "" else scene, {})

func active() -> bool:
	return scene != "" and state != "done" and state != ""

func hides_prompts() -> bool:
	return state == "fade" or waiting

## The first scene whose flag is not set ("" = all done).
func next_scene() -> String:
	for id in order():
		if not host.flow.save.flag(str(sdef(str(id)).get("flag", ""))):
			return str(id)
	return ""

## Dev / review jump (?act1_from=1.2 on the web build, act1_from=1.2 on the command line): earlier scenes count as done.
static func jump_requested() -> String:
	var args := " ".join(OS.get_cmdline_user_args())
	if OS.has_feature("web"):
		args += " " + str(JavaScriptBridge.eval("window.location.search", true))
	var at := args.find("act1_from=")
	if at < 0:
		return ""
	return args.substr(at + 10).split("&")[0].split(" ")[0]

func mark_before(id: String) -> void:
	for s in order():
		if str(s) == id:
			return
		host.flow.save.set_flag(str(sdef(str(s)).get("flag", "")))

func start(id: String) -> void:
	teardown_props()
	scene = id
	var sd := sdef()
	if sd.is_empty():
		scene = ""
		return
	var r: Dictionary = host.flow.save.mission(str(sd.id))
	r["state"] = "active"
	r["done"] = []
	r["checkpoint"] = ""
	host.flow.save.story["current"] = str(sd.id)
	host.flow.save.story["time_of_day"] = str(sd.get("time", "day"))
	host.flow.persist()
	host.phase = "act1"
	root = Node3D.new()
	root.name = "Act1Props"
	host.main.world_sim.add_child(root)
	var dl = host.main.get("districts")
	if dl != null and str(sd.get("place", "")) != "":
		dl.arm(str(sd.place))
		dl.request(str(sd.place))
	World.apply(host.main, PRESETS.get(str(sd.get("preset", "noon")), PRESETS.noon))
	host.hud.fade_to(1.0, 0.01)
	_spawn(sd.spawn)
	host.player.input_enabled = false
	_apply_grip()
	host.hud.set_objective(str(sd.title), "")
	host.hud.set_line("")
	host.hud.phone_header("ZERO", str(sd.get("phone_sub", "")))
	if host.autopilot != null:
		host.autopilot.finished = true
		pilot = {"on": true}
	score = 0
	spotted = 0
	fired = {}
	step_i = -1
	state = "fade"
	state_left = 0.6
	_hud()
	log.append("scene:" + id)

func teardown_props() -> void:
	if root != null and is_instance_valid(root):
		root.queue_free()
	root = null
	drones = []
	_vision(false)

func teardown() -> void:
	teardown_props()
	if host != null and host.player != null:
		host.player.input_enabled = true
		host.player.external_move_active = false
	state = ""
	scene = ""

# ------------------------------------------------------------------ per frame

func tick(delta: float) -> void:
	if not active():
		return
	if pilot.is_empty() and host.autopilot != null:
		# the review autopilot can start after the scene (the dev jump, a reload): pick it up here
		host.autopilot.finished = true
		pilot = {"on": true}
	_fans(delta)
	_drones(delta)
	_rain_tick(delta)
	match state:
		"fade":
			state_left -= delta
			if state_left <= 0.0:
				host.hud.fade_to(0.0, 0.6)
				host.player.input_enabled = true
				_next_step()
		"step":
			_step_tick(delta)
		"between":
			state_left -= delta
			if state_left <= 0.0:
				_end_scene()
	_pilot_tick(delta)
	_hud()

func _next_step() -> void:
	var steps: Array = sdef().get("steps", [])
	step_i += 1
	done_goals = {}
	checkpoint = ""
	waiting = false
	host.hud.prompt("")
	if host.player != null:
		host.player.pad_menu = false
	topic_i = 0
	if step_i >= steps.size():
		state = "between"
		state_left = 0.4
		return
	step = steps[step_i]
	state = "step"
	if str(step.get("do", "")) in ["goals", "defend", "carry", "topics", "raise"]:
		host.player.input_enabled = true  # a hook that moved him (the Yard, the arcade at night) locks input until here
	log.append("step:%s:%d:%s" % [scene, step_i, str(step.get("do", ""))])
	if step.has("objective"):
		host.hud.set_objective(str(sdef().title), str(step.objective))
	match str(step.get("do", "")):
		"lines":
			host._say_all(_fill(step.get("lines", [])))
			waiting = true
		"cine":
			host.player.velocity = Vector3.ZERO
			waiting = host._play_cinematic(str(step.id))
			host.phase = "act1"
		"card":
			host._say_all([["CARD", str(step.text)]])
			waiting = true
		"hook":
			hook(str(step.name))
			if step.has("lines"):
				host._say_all(_fill(step.lines))
			waiting = true
		"carry":
			budget = int(step.get("budget", 48))
			bags = 0
			melt = 0.0
			delivered = 0
		"goals":
			watch = 0.0
			hz_t = 0.0
			if step.has("hook"):
				hook(str(step.hook))
			if step.has("drones"):
				_make_drones(step.drones)
		"defend":
			if step.has("hook"):
				hook(str(step.hook))
			reroute = 0.0
			knocked = 0
			hits = 0
			spawn_left = 1.0
			spawn_i = 0
			_clear_drones()
		"raise", "topics":
			pass

func _step_tick(delta: float) -> void:
	if waiting:
		if host.in_cinematic() or not host.queue.is_empty() or host.talking != "" or host.card_left > 0.0:
			return
		waiting = false
		if str(step.get("do", "")) == "raise":
			_vision(false)
		_next_step()
		return
	match str(step.get("do", "")):
		"goals":
			_goals_tick(delta)
		"topics":
			_topics_tick()
		"defend":
			_defend_tick(delta)
		"carry":
			_carry_tick(delta)
		"raise":
			host.hud.prompt(str(step.get("verb", "E  raise the phone")))
			if Input.is_action_just_pressed("interact"):
				raise_phone()

# ------------------------------------------------------------------ goals (spray, talk, reach)

func goals() -> Array:
	return step.get("goals", [])

func required_left() -> int:
	var n := 0
	for g in goals():
		if not bool(g.get("optional", false)) and not done_goals.has(str(g.id)):
			n += 1
	return n

func in_reach() -> Dictionary:
	var p: Vector3 = host.player.global_position
	for g in goals():
		if done_goals.has(str(g.id)):
			continue
		var at: Array = g.at
		if Vector2(p.x - float(at[0]), p.z - float(at[1])).length() < float(g.get("r", 1.8)) and p.y > float(g.get("min_y", -9.0)):
			return g
	return {}

func _goals_tick(delta: float) -> void:
	var fall_y := float(step.get("fall_y", -50.0))
	if host.player.global_position.y < fall_y:
		_reset("fell")
		return
	if step.has("hazards"):
		hz_t += delta
		_hazard_nodes()
	if step.has("drones") or step.has("hazards"):
		_watch_tick(delta)
	var g := in_reach()
	if g.is_empty():
		host.hud.prompt("")
		return
	if bool(g.get("auto", false)):
		complete(str(g.id))
		return
	host.hud.prompt(str(g.get("verb", "E")))
	if Input.is_action_just_pressed("interact"):
		complete(str(g.id))

## Completes a goal (E, an auto zone, the autopilot or a test).
func complete(id: String) -> bool:
	if state != "step" or waiting or done_goals.has(id):
		return false
	var g: Dictionary = {}
	for x in goals():
		if str(x.id) == id:
			g = x
	if g.is_empty():
		return false
	done_goals[id] = true
	if not bool(g.get("auto", false)):
		checkpoint = id
	var r: Dictionary = host.flow.save.mission(str(sdef().id))
	r["done"] = done_goals.keys()
	r["checkpoint"] = checkpoint
	if str(g.get("flag", "")) != "":
		host.flow.save.set_flag(str(g.flag))
	host.flow.persist()
	score += int(g.get("points", 0))
	if g.has("paint"):
		Kit.paint(_node(str(g.paint[0])), Color(str(g.paint[1])))
	if g.has("temp"):
		var tl := _node(str(g.temp[0])) as Label3D
		if tl != null:
			tl.text = str(g.temp[1])
			tl.modulate = Color("9fe8ff")
	if g.has("hide"):
		var hn := _node(str(g.hide)) as Node3D
		if hn != null:
			hn.visible = false
	if str(g.get("sfx", "")) != "":
		host.sfx.play(str(g.sfx))
	if str(g.get("toast", "")) != "":
		host.hud.toast(str(g.toast))
	if g.has("card"):
		host._say_all([["CARD", str(g.card)]])
	if g.has("lines"):
		host._say_all(_fill(g.lines))
	if str(g.get("hook", "")) != "":
		hook(str(g.hook))
	log.append("goal:" + id)
	host.hud.prompt("")
	if step.has("objective"):
		host.hud.set_objective(str(sdef().title), str(step.objective))
	if required_left() == 0:
		if step.has("done_lines"):
			host._say_all(_fill(step.done_lines))
		waiting = true
		_clear_drones()
	return true

func _reset(why: String) -> void:
	var pos: Array = sdef().spawn
	if checkpoint != "":
		for g in goals():
			if str(g.id) == checkpoint and g.has("reset"):
				pos = g.reset
	_spawn(pos)
	host.hud.toast(str(step.get("reset_toast", "BACK TO THE LAST CHECKPOINT")) if why != "spotted" else "SPOTTED")
	if why == "spotted":
		spotted += 1
		host.flow.save.mission(str(sdef().id))["fails"] = spotted
		host.sfx.play("drone_chime")
		if step.has("spotted_lines") and not fired.has("spotted"):
			fired["spotted"] = true
			host._say_all(_fill(step.spotted_lines))
	watch = 0.0
	if not pilot.is_empty():
		pilot["key"] = ""
	log.append("reset:" + why)

# ------------------------------------------------------------------ 1.4: patrols and the Watch meter

func _make_drones(list: Array) -> void:
	_clear_drones()
	for d in list:
		var n: Node3D = World.enforcement_drone(root)
		var path: Array = d.path
		n.global_position = Vector3(float(path[0][0]), float(d.get("y", 4.0)), float(path[0][1]))
		n.add_to_group("spray_target")
		drones.append({"node": n, "path": path, "i": 1, "speed": float(d.get("speed", 3.0)), "y": float(d.get("y", 4.0))})

func _clear_drones() -> void:
	for d in drones:
		if is_instance_valid(d.node):
			d.node.queue_free()
	drones = []

func _drones(delta: float) -> void:
	for d in drones:
		var n: Node3D = d.node
		if not is_instance_valid(n) or d.has("chase"):
			continue
		if _spray_frozen(n, delta):
			continue
		var tgt: Array = d.path[d.i]
		var to := Vector3(float(tgt[0]), d.y, float(tgt[1])) - n.global_position
		if to.length() < 0.3:
			d.i = (d.i + 1) % d.path.size()
		else:
			n.global_position += to.normalized() * minf(to.length(), d.speed * delta)
			n.rotation.y = atan2(to.x, to.z)

func in_mist(p: Vector3) -> bool:
	for m in step.get("mist", []):
		if absf(p.x - float(m[0])) < float(m[2]) and absf(p.z - float(m[1])) < float(m[3]):
			return true
	return false

## Spray paint holds a patrol drone in place and takes its eyes off the player.
func _spray_frozen(n: Node3D, delta: float) -> bool:
	var left: float = float(n.get_meta("spray_left", 0.0))
	if left <= 0.0:
		return false
	n.set_meta("spray_left", maxf(0.0, left - delta))
	return true

func seen_by_drone() -> bool:
	var p: Vector3 = host.player.global_position
	if in_mist(p):
		return false
	if in_hazard(p):
		return true
	for d in drones:
		if is_instance_valid(d.node) and float(d.node.get_meta("spray_left", 0.0)) <= 0.0 and Vector2(p.x - d.node.global_position.x, p.z - d.node.global_position.z).length() < float(step.get("det_r", 6.0)):
			return true
	return false

func _watch_tick(delta: float) -> void:
	if seen_by_drone():
		watch += delta / maxf(0.2, float(step.get("fill_s", 2.5)))
	else:
		watch = maxf(0.0, watch - delta * 0.35)
	if watch >= 1.0:
		_reset("spotted")

## 1.5 boss phase 2: steam vents [x, z, r, on_s, off_s] that cycle; inside one while it blows = seen (the mist still hides).
func hazard_on(h: Array) -> bool:
	var period := float(h[3]) + float(h[4])
	return fmod(hz_t, period) < float(h[3])

func in_hazard(p: Vector3, live := true) -> bool:
	for h in step.get("hazards", []):
		if (not live or hazard_on(h)) and Vector2(p.x - float(h[0]), p.z - float(h[1])).length() < float(h[2]):
			return true
	return false

func _hazard_nodes() -> void:
	var st := _node("Steam") as Node3D
	if st != null:
		var hs: Array = step.get("hazards", [])
		st.visible = not hs.is_empty() and hazard_on(hs[0])

# ------------------------------------------------------------------ 1.5: hold the line (drones swarm the switch house)

## Drones fly in from the edges toward the switch house; touching one (on foot or board) knocks it down; one that flies
## into the tower mist loses its sensors and drops; one that reaches the house knocks the reroute back.
func _defend_tick(delta: float) -> void:
	var at: Array = step.at
	var house := Vector3(float(at[0]), 1.4, float(at[1]))
	reroute = minf(1.0, reroute + delta / float(step.get("secs", 30.0)))
	spawn_left -= delta
	var froms: Array = step.get("from", [])
	if spawn_left <= 0.0 and drones.size() < int(step.get("max", 4)) and not froms.is_empty():
		spawn_left = float(step.get("every", 3.5))
		var f: Array = froms[spawn_i % froms.size()]
		spawn_i += 1
		var n: Node3D = World.enforcement_drone(root)
		n.global_position = Vector3(float(f[0]), 6.0, float(f[1]))
		drones.append({"node": n, "path": [], "i": 0, "speed": float(step.get("speed", 2.2)), "y": 1.4, "chase": true})
	var p: Vector3 = host.player.global_position
	for d in drones.duplicate():
		var n: Node3D = d.node
		if not is_instance_valid(n):
			drones.erase(d)
			continue
		var to := house - n.global_position
		n.global_position += to.normalized() * minf(to.length(), float(d.speed) * delta)
		n.rotation.y = atan2(to.x, to.z)
		var why := ""
		if Vector2(p.x - n.global_position.x, p.z - n.global_position.z).length() < float(step.get("knock_r", 1.8)) and n.global_position.y < 3.2:
			why = "knock"
		elif in_mist(n.global_position):
			why = "mist"
		elif to.length() < 1.6:
			why = "hit"
		if why == "":
			continue
		n.queue_free()
		drones.erase(d)
		if why == "hit":
			hits += 1
			reroute = maxf(0.0, reroute - float(step.get("hit_back", 0.1)))
			host.hud.toast("THE SWITCH HOUSE IS HIT · REROUTE %d%%" % int(reroute * 100.0))
			host.sfx.play("drone_chime")
		else:
			knocked += 1
			score += int(step.get("points", 500))
			host.hud.toast("DRONE DOWN" if why == "knock" else "SENSORS FAIL IN THE MIST")
			host.sfx.play("net" if why == "knock" else "pickup")
	for b in step.get("barks", []):
		var key := "bark%s" % str(b[0])
		if reroute >= float(b[0]) and not fired.has(key):
			fired[key] = true
			host._say_all(_fill([[b[1], b[2]]]))
	if reroute >= 1.0:
		_clear_drones()
		if step.has("done_lines"):
			host._say_all(_fill(step.done_lines))
		waiting = true
		log.append("defend:done:%d:%d" % [knocked, hits])

# ------------------------------------------------------------------ 1.1: the topic menu

func _topics_tick() -> void:
	host.player.pad_menu = true
	var list: Array = step.get("topics", [])
	var open: Array = []
	for tp in list:
		if not topic_done.has(str(tp.key)):
			open.append(tp)
	if open.is_empty() or topic_i >= open.size() or topic_i < 0:
		topic_i = 0
	var text := ""
	for i in list.size():
		var tp: Dictionary = list[i]
		if topic_done.has(str(tp.key)):
			continue
		var mark := "> " if not open.is_empty() and str(open[topic_i].key) == str(tp.key) else "  "
		text += "%s%d  %s    " % [mark, i + 1, str(tp.label)]
	text += "E  " + str(step.get("done_label", "done"))
	host.hud.prompt(text)
	if Input.is_action_just_pressed("ui_down") or Input.is_action_just_pressed("ui_right"):
		topic_i = (topic_i + 1) % maxi(open.size(), 1)
	elif Input.is_action_just_pressed("ui_up") or Input.is_action_just_pressed("ui_left"):
		topic_i = (topic_i - 1 + open.size()) % maxi(open.size(), 1)
	elif not open.is_empty() and (Input.is_action_just_pressed("session_confirm") or Input.is_action_just_pressed("ui_accept")):
		ask(str(open[topic_i].key))
	for i in list.size():
		if _key_edge(KEY_1 + i):
			ask(str(list[i].key))
	if Input.is_action_just_pressed("interact"):
		ask("")

func _key_edge(k: int) -> bool:
	var down := Input.is_physical_key_pressed(k)
	var was := bool(keys_down.get(k, false))
	keys_down[k] = down
	return down and not was

## A topic by key ("" = done: take the board back).
func ask(key: String) -> bool:
	if state != "step" or waiting or str(step.get("do", "")) != "topics":
		return false
	if key == "":
		host.hud.prompt("")
		host._say_all(_fill(step.get("done_lines", [])))
		waiting = true
		log.append("topics:done:%d" % topic_done.size())
		return true
	for tp in step.get("topics", []):
		if str(tp.key) == key and not topic_done.has(key):
			topic_done[key] = true
			host._say_all(_fill(tp.lines))
			log.append("topic:" + key)
			return true
	return false

# ------------------------------------------------------------------ 1.2: carry the ice

func deliveries() -> Array:
	return step.get("deliveries", [])

func _carry_tick(delta: float) -> void:
	var p: Vector3 = host.player.global_position
	if bags > 0:
		melt -= delta
		if melt <= float(step.get("melt_s", 75.0)) * 0.3 and not fired.has("melt_bark_%d" % delivered):
			fired["melt_bark_%d" % delivered] = true
			if not fired.has("melt_bark"):
				fired["melt_bark"] = true
				host._say_all(_fill(step.get("melt_lines", [])))
		if melt <= 0.0:
			bags = 0
			host.hud.toast("THE LOAD MELTED")
			log.append("melted")
			_budget_check()
	var lk: Array = step.locker
	var near_locker := Vector2(p.x - float(lk[0]), p.z - float(lk[1])).length() < 2.6
	var dv := delivery_in_reach()
	if bags == 0 and near_locker:
		host.hud.prompt("E  take a load of ice (%d bags)" % mini(int(step.get("per_load", 8)), budget))
		if Input.is_action_just_pressed("interact"):
			take_load()
	elif bags > 0 and not dv.is_empty():
		host.hud.prompt("E  hand over the ice (%s)" % str(dv.who))
		if Input.is_action_just_pressed("interact"):
			deliver(str(dv.id))
	else:
		host.hud.prompt("")

func delivery_in_reach() -> Dictionary:
	var p: Vector3 = host.player.global_position
	for dv in deliveries():
		if done_goals.has(str(dv.id)):
			continue
		if Vector2(p.x - float(dv.at[0]), p.z - float(dv.at[1])).length() < float(dv.get("r", 2.4)):
			return dv
	return {}

func take_load() -> bool:
	if bags > 0 or budget <= 0:
		return false
	bags = mini(int(step.get("per_load", 8)), budget)
	budget -= bags
	melt = float(step.get("melt_s", 75.0))
	host.sfx.play("pickup")
	host.hud.toast("ICE x%d · MELTING" % bags)
	if not fired.has("surge"):
		fired["surge"] = true
		host._say_all(_fill(step.get("surge_lines", [])))
	log.append("load:%d" % bags)
	return true

func deliver(id: String) -> bool:
	if bags <= 0 or done_goals.has(id):
		return false
	var dv: Dictionary = {}
	for x in deliveries():
		if str(x.id) == id:
			dv = x
	if dv.is_empty():
		return false
	done_goals[id] = true
	checkpoint = id
	delivered += bags
	score += bags * int(step.get("points_per_bag", 250)) + int(maxf(0.0, melt)) * 10
	var st: Dictionary = host.flow.save.story
	st["signal"] = int(st.get("signal", 0)) + bags
	var r: Dictionary = host.flow.save.mission(str(sdef().id))
	r["done"] = done_goals.keys()
	r["checkpoint"] = id
	host.flow.persist()
	host.sfx.play("pickup")
	host.hud.toast("DELIVERED %d · SIGNAL +%d" % [bags, bags])
	bags = 0
	host._say_all(_fill(dv.get("lines", [])))
	if not fired.has("signal_card"):
		fired["signal_card"] = true
		host._say_all([["CARD", str(step.get("signal_card", "SIGNAL"))]])
	log.append("deliver:" + id)
	if done_goals.size() >= deliveries().size():
		host._say_all(_fill(step.get("done_lines", [])))
		waiting = true
	return true

func on_bail() -> void:
	if str(step.get("do", "")) == "carry" and bags > 0:
		bags -= 1
		host.hud.toast("BAIL · A BAG DROPPED (%d LEFT)" % bags)
		if not fired.has("bail_bark"):
			fired["bail_bark"] = true
			host._say_all(_fill(step.get("bail_lines", [])))
		log.append("drop")
		if bags == 0:
			_budget_check()

## Budget gone and deliveries left: the run restarts from the last delivered load (the breakdown's proposal).
func _budget_check() -> void:
	var left := deliveries().size() - done_goals.size()
	if budget < left * int(step.get("per_load", 8)) and left > 0:
		budget = left * int(step.get("per_load", 8))
		host.hud.toast("OUT OF ICE MONEY · BACK TO THE LAST DELIVERY")
		var pos: Array = sdef().spawn
		for dv in deliveries():
			if str(dv.id) == checkpoint:
				pos = [float(dv.at[0]), 0.5, float(dv.at[1]) + 1.5, 0.0]
		_spawn(pos)
		spotted += 1
		log.append("budget_reset")

# ------------------------------------------------------------------ 1.4B: raise the phone (Zero Vision)

## Z / L3. Before the unlock, only the scripted raise accepts it. After, it toggles the overlay.
func toggle_vision() -> bool:
	if host == null or host.flow == null:
		return false
	if state == "step" and str(step.get("do", "")) == "raise":
		return raise_phone()
	if not host.flow.save.flag("zero_vision_unlocked"):
		return false
	_vision(not vision)
	return true

func raise_phone() -> bool:
	if state != "step" or waiting or str(step.get("do", "")) != "raise":
		return false
	host.hud.prompt("")
	_vision(true)
	_look_at_hologram()
	vision_used = true
	host.flow.save.set_flag("zero_vision_unlocked")
	host.flow.persist()
	host._say_all(_fill(step.get("lines", [])))
	waiting = true
	log.append("raise")
	return true

## Raising the phone points the camera up at the hologram (it stands 60 m tall, 80 m off, behind the towers).
func _look_at_hologram() -> void:
	var holo := root.get_node_or_null("Hologram") as Node3D if root != null and is_instance_valid(root) else null
	var pl = host.player
	if holo == null or pl == null:
		return
	var dir: Vector3 = holo.global_position - pl.global_position
	pl.camera_yaw = atan2(-dir.x, -dir.z) - pl.rotation.y
	pl.camera_pitch = 0.42

func _vision(on: bool) -> void:
	vision = on
	if host == null or host.hud == null:
		return
	if on:
		if overlay == null or not is_instance_valid(overlay):
			overlay = ColorRect.new()
			overlay.name = "ZeroVision"
			overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
			overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
			overlay.color = Color(0.0, 0.05, 0.0, 0.5)
			host.hud.add_child(overlay)
			host.hud.move_child(overlay, 0)
		overlay.visible = true
		_strings(true)
	else:
		if overlay != null and is_instance_valid(overlay):
			overlay.visible = false
		_strings(false)

## The strings: lime lines from the hologram's fingertips down to every drone, window and bike (PLACEHOLDER: a few
## hundred random endpoints, no real data).
func _strings(on: bool) -> void:
	if root == null or not is_instance_valid(root):
		return
	var old := root.get_node_or_null("Strings")
	if old != null:
		old.queue_free()
	var holo := root.get_node_or_null("Hologram") as Node3D
	if holo != null:
		for c in holo.get_children():
			if c is MeshInstance3D and not c.has_meta("eye"):
				var hm := Kit.unshaded(LIME if on else Color("2a2c30"), 0.85 if on else 0.55)
				hm.disable_fog = on
				(c as MeshInstance3D).material_override = hm
	if not on or holo == null:
		return
	# Strands are thin unshaded boxes in one MultiMesh, not GL lines: the first browser runs drew nothing with
	# ImmediateMesh PRIMITIVE_LINES on the web (Compatibility) renderer, while boxes always render.
	var mat := Kit.unshaded(LIME)
	mat.no_depth_test = true
	mat.disable_fog = true
	var box := BoxMesh.new()
	box.size = Vector3(1, 1, 1)
	box.material = mat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = box
	mm.instance_count = 600
	var rng := RandomNumberGenerator.new()
	rng.seed = 1405
	var tips: Array = []
	for c in holo.get_children():
		if c.has_meta("tip"):
			tips.append((c as Node3D).global_position)
	for i in 600:
		var a: Vector3 = tips[i % tips.size()] if not tips.is_empty() else holo.global_position
		var b := Vector3(rng.randf_range(250.0, 470.0), rng.randf_range(0.5, 30.0), rng.randf_range(-100.0, 20.0))
		if i < drones.size():
			b = drones[i].node.global_position
		elif i < 40 and host.player != null:
			# some land around Fony (not on him), so the first look always has strings crossing the frame
			var ang := rng.randf() * TAU
			b = host.player.global_position + Vector3(cos(ang), 0.0, sin(ang)) * rng.randf_range(12.0, 40.0) + Vector3(0, rng.randf_range(0.0, 4.0), 0)
		mm.set_instance_transform(i, strand(a, b))
	var mi := MultiMeshInstance3D.new()
	mi.name = "Strings"
	mi.multimesh = mm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)

## A unit box stretched from a to b, thicker the longer it is (so far strands stay a pixel or two wide).
static func strand(a: Vector3, b: Vector3) -> Transform3D:
	var d := b - a
	var len := maxf(d.length(), 0.01)
	var w := 0.03 + len * 0.0009
	var z := d / len
	var up := Vector3.UP if absf(z.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	var x := up.cross(z).normalized()
	var y := z.cross(x).normalized()
	return Transform3D(Basis(x * w, y * w, z * len), (a + b) * 0.5)

# ------------------------------------------------------------------ hooks (steps and cinematics)

func _apply_grip() -> void:
	if host != null and host.player != null:
		host.player.grip_tape = host.flow.save.flag("upgrade_grip_tape")

func hook(name: String) -> void:
	log.append("hook:" + name)
	match name:
		"board_back":
			host.flow.save.set_flag("upgrade_grip_tape")
			_apply_grip()
		"workshop":
			host.flow.save.set_flag("workshop_unlocked")
		"bailey":
			var sh := _node("BaileySheet") as Node3D
			if sh != null:
				sh.visible = false
			Kit.paint(_node("BaileyScreen"), Color("7fe0ff"))
			host.flow.save.set_flag("cabinet_grind_the_terms")
		"crowd":
			_crowd()
		"tag":
			var bt := _node("BillboardText") as Label3D
			if bt != null:
				bt.text = "AU\nZERO X HUMANS"
				bt.modulate = LIME
			host.flow.save.set_flag("a1_billboard_tagged")
		"arcade_night":
			World.apply(host.main, PRESETS.arcade_night)
			_spawn([219.5, 0.5, -15.0, 90.0])
			host.player.input_enabled = false
			_crowd()
		"under_tower":
			_spawn([388.0, 0.5, -69.5, 180.0])
			host.player.input_enabled = false
		"broadcast":
			_hologram()
			for k in 2:
				var tl := _node("ScreenText%d" % k) as Label3D
				if tl != null:
					tl.text = "FEEDLINE LIVE\nTHE BENEFACTOR SPEAKS"
					tl.modulate = Color("ff6b5a")
			host.hud.toast("FEEDLINE LIVE · THE BENEFACTOR SPEAKS")
		"halo":
			var holo := root.get_node_or_null("Hologram") if root != null else null
			if holo != null and holo.get_node_or_null("Halo") == null:
				var h := Node3D.new()
				h.name = "Halo"
				h.position = Vector3(16.0, 50.0, 6.0)
				holo.add_child(h)
				var body := MeshInstance3D.new()
				var sm := SphereMesh.new()
				sm.radius = 1.4
				sm.height = 2.0
				body.mesh = sm
				body.material_override = Kit.unshaded(Color("f4f6ff"))
				h.add_child(body)
				var ring := MeshInstance3D.new()
				ring.name = "Ring"
				var tm := TorusMesh.new()
				tm.inner_radius = 2.2
				tm.outer_radius = 2.8
				ring.mesh = tm
				ring.material_override = Kit.unshaded(Color("9fd8ff"))
				h.add_child(ring)
		# ---- 1.5 The Breaker (+1.5B, the boss, 1.5C)
		"cameras":
			_cameras()
			_switch_house()
			for w in ["Worker1", "Worker2"]:
				var wn := _node(w) as Node3D
				if wn != null:
					wn.visible = false  # their smoke break was 1.4; their name tags filled the boss camera
		"over_fence":
			_spawn([442.0, 0.5, -60.5, 90.0])
		"switch_house":
			Kit.paint(_node("PanelScreen"), LIME)
			var pl := _node("PanelFace") as Label3D
			if pl != null:
				pl.text = "ZERO\n(on the panel)"
			host.flow.save.set_flag("a1_switch_house_plugged")
		"thermostat":
			_thermostat()
		"frost":
			_frost()
		"vent":
			pass
		"dial_heat":
			_dial("HEAT", Color("ff5a3a"))
		"dial_wild":
			_dial("HOT · COLD · HOT", Color("ffd24a"))
		"launch":
			_spawn([414.0, 6.6, -61.6, 0.0])
		"thermostat_down":
			_dial("OFF", Color("7a7f88"))
			var tm := _node("Thermostat") as Node3D
			if tm != null:
				for c in tm.get_children():
					if str(c.name).begins_with("Fan"):
						Kit.paint(c, Color("3a3f48"))
			var st := _node("Steam") as Node3D
			if st != null:
				st.visible = false
			for f in _frost_nodes():
				f.visible = false
		"capsule_away":
			var cap := _node("Capsule") as Node3D
			if cap != null:
				var tw := create_tween()
				tw.tween_property(cap, "global_position", cap.global_position + Vector3(-30.0, 60.0, -40.0), 4.0)
			host.flow.save.set_flag("a1_thermostat_beaten")
		"flats_lights":
			_flats_lights()
		# ---- 1.6 Heat Break (+1.6B The rain)
		"heat_break":
			_heat_break()
		"signal":
			host.flow.save.story["signal"] = int(host.flow.save.story.get("signal", 0)) + 5
			host.hud.toast("SIGNAL +5")
		"yard":
			_yard()
		"clouds":
			World.apply(host.main, PRESETS.storm)
			host.sfx.play("breaker")
		"rain":
			World.apply(host.main, PRESETS.storm)
			_rain()
			_rain_crowd()
		"the_yard":
			if root != null and root.get_node_or_null("TheYardSign") == null:
				Kit.sign(root, "TheYardSign", "THE YARD", Vector3(25.0, 3.6, -7.6), 0.0, Color("f4f4ee"), 120, 0.02)
			host.flow.save.set_flag("a1_the_yard_named")
	host.flow.persist()

# ------------------------------------------------------------------ 1.6 props (PLACEHOLDER blockout)

## The heat-break days in the Flats: a derelict block with solar panels to salvage, a dusty cabinet, a paint crew.
func _heat_break() -> void:
	if root.get_node_or_null("Derelict") != null:
		return
	Blocks.solid(root, "Derelict", Vector3(340.0, 2.0, -24.0), Vector3(4.0, 4.0, 6.0), Color("5a4a40"))
	var sp := Node3D.new()
	sp.name = "SalvagePanels"
	root.add_child(sp)
	for k in 2:
		var pnl := Blocks.visual(sp, "SolarPanel%d" % k, Vector3(337.9, 1.2 + k * 1.3, -24.0), Vector3(0.1, 1.0, 1.8), Color("1d3a6a"))
		pnl.rotation.z = 0.2
	Kit.sign(root, "DerelictSign", "CONDEMNED · DUSK DYNAMICS HOLDINGS", Vector3(337.9, 3.4, -24.0), -PI * 0.5, Color("e8e0d0"), 26, 0.01)
	Blocks.solid(root, "DustyCabinet", Vector3(346.0, 1.1, -34.0), Vector3(1.4, 2.2, 1.0), Color("4a3a5a"))
	Kit.sign(root, "DustyCabinetSign", "?? (dusty)", Vector3(345.28, 1.8, -34.0), -PI * 0.5, Color("ffd24a"), 28, 0.01)
	Kit.person(root, "PaintCrew0", "", Vector3(286.0, 4.0, -26.0), Color("e0b03a"), 1.7)
	Kit.person(root, "PaintCrew1", "", Vector3(294.0, 4.0, -26.0), Color("2f8f6f"), 1.7)

## The Yard, days later: shade cloth over the bowl, a water station by the gate, cots in the resistance rooms, kids on the
## quarter pipe, the new people.
func _yard() -> void:
	World.apply(host.main, PRESETS.noon)
	_spawn([32.0, 0.5, 14.0, 180.0])
	host.player.input_enabled = false
	if root.get_node_or_null("ShadeCloth") != null:
		return
	var sc := Blocks.visual(root, "ShadeCloth", Vector3(-48.0, 5.5, 49.0), Vector3(22.0, 0.06, 34.0), Color("e8d8b0"))
	sc.material_override = Kit.unshaded(Color("e8d8b0"), 0.8)
	Blocks.visual(root, "WaterStation", Vector3(52.0, 0.6, 72.0), Vector3(2.4, 1.2, 1.0), Color("3a8ad8"))
	Kit.sign(root, "WaterSign", "FREE WATER", Vector3(52.0, 1.8, 72.6), 0.0, Color("e8f4ff"), 40, 0.012)
	for k in 6:
		Blocks.visual(root, "Cot%d" % k, Vector3(-12.0 + k * 3.0, 0.3, -56.0), Vector3(0.9, 0.4, 2.0), Color("6a7a5a"))
	for k in 2:
		Kit.person(root, "KidOnQuarter%d" % k, "", Vector3(-43.5 + k * 1.5, 0.0, -10.0), [Color("d84f4f"), Color("4f8bd8")][k], 1.2)
	Kit.person(root, "Neighbor0", "NEIGHBOR (FLATS)", Vector3(25.0, 0.0, 3.0), Color("c9c2b4"), 1.7)
	Kit.person(root, "Neighbor1", "", Vector3(26.4, 0.0, 3.4), Color("b04a6a"), 1.65)
	Kit.person(root, "Teen0", "TEEN SKATER", Vector3(38.0, 0.0, 3.0), Color("e0b03a"), 1.6, PI)
	Kit.person(root, "Teen1", "TEEN SKATER", Vector3(39.4, 0.0, 3.2), Color("2f8f6f"), 1.55, PI)
	Kit.person(root, "ClinicWoman", "FREE CLINIC", Vector3(32.0, 0.0, 7.6), Color("f4f4f4"), 1.7, PI)
	Blocks.visual(root, "ClinicTable", Vector3(32.0, 0.45, 6.6), Vector3(2.0, 0.9, 0.8), Color("e8e8e8"))
	Kit.person(root, "ZeroAtDoor", "ZERO", Vector3(32.0, 0.45, -7.0), Color("3a3f48"), 1.8)
	host.flow.save.set_flag("a1_yard_grown")

## 1.6B: rain streaks (PLACEHOLDER: a few hundred thin boxes falling over the Yard).
func _rain() -> void:
	if root.get_node_or_null("Rain") != null:
		return
	var mat := Kit.unshaded(Color("cfe0ff"), 0.55)
	var box := BoxMesh.new()
	box.size = Vector3(0.03, 0.9, 0.03)
	box.material = mat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = box
	mm.instance_count = 700
	var rng := RandomNumberGenerator.new()
	rng.seed = 169
	for i in 700:
		mm.set_instance_transform(i, Transform3D(Basis(), Vector3(rng.randf_range(6.0, 58.0), rng.randf_range(0.0, 14.0), rng.randf_range(-6.0, 26.0))))
	var mi := MultiMeshInstance3D.new()
	mi.name = "Rain"
	mi.multimesh = mm
	root.add_child(mi)
	host.flow.save.set_flag("a1_rain_seen")

func _rain_tick(delta: float) -> void:
	var r := root.get_node_or_null("Rain") as MultiMeshInstance3D if root != null and is_instance_valid(root) else null
	if r == null:
		return
	var mm := r.multimesh
	for i in mm.instance_count:
		var tf := mm.get_instance_transform(i)
		tf.origin.y -= delta * 16.0
		if tf.origin.y < 0.0:
			tf.origin.y += 14.0
		mm.set_instance_transform(i, tf)

func _rain_crowd() -> void:
	if root.get_node_or_null("RainNana") != null:
		return
	var colors := [Color("d84f4f"), Color("4f8bd8"), Color("e0b03a"), Color("2f8f6f"), Color("b04a6a"), Color("c9c2b4")]
	var rng := RandomNumberGenerator.new()
	rng.seed = 1606
	for i in 14:
		Kit.person(root, "RainPerson%d" % i, "", Vector3(rng.randf_range(16.0, 48.0), 0.0, rng.randf_range(4.0, 20.0)), colors[i % colors.size()], 1.1 if i % 4 == 0 else 1.7, rng.randf() * TAU)
	Kit.person(root, "RainNana", "NANA INES", Vector3(29.0, 0.0, 2.0), Color("e6e0d0"), 1.62)
	Kit.person(root, "RainDelacroix", "MR. DELACROIX", Vector3(36.0, 0.0, 6.0), Color("c9c2b4"), 1.7)

# ------------------------------------------------------------------ 1.5 props (PLACEHOLDER blockout)

const CAMS := [[428.0, -28.0], [444.0, -30.0], [450.0, -38.0], [448.0, -64.0], [436.0, -60.0], [422.0, -48.0]]

## Six security cameras on poles around the substation; spraying one turns its lens black-and-lime.
func _cameras() -> void:
	for i in CAMS.size():
		var c: Array = CAMS[i]
		if root.get_node_or_null("CamPole%d" % i) != null:
			continue
		Blocks.visual(root, "CamPole%d" % i, Vector3(float(c[0]), 1.6, float(c[1])), Vector3(0.18, 3.2, 0.18), Color("6a7480"))
		var head := Blocks.visual(root, "Cam%d" % i, Vector3(float(c[0]), 3.3, float(c[1])), Vector3(0.6, 0.4, 0.9), Color("e8eef4"))
		Blocks.visual(head, "Lens", Vector3(0, 0, 0.46), Vector3(0.3, 0.3, 0.04), Color("ff3030")).name = "Lens"

## The maintenance switch house just south of the substation fence, with a panel for Zero.
func _switch_house() -> void:
	if root.get_node_or_null("SwitchHouse") != null:
		return
	Blocks.solid(root, "SwitchHouse", Vector3(445.0, 1.5, -61.0), Vector3(3.0, 3.0, 3.0), Color("6a7078"))
	Blocks.visual(root, "PanelScreen", Vector3(443.48, 1.6, -61.0), Vector3(0.02, 0.8, 1.2), Color("10161c"))
	var l := Kit.sign(root, "PanelFace", "SWITCH HOUSE 4B", Vector3(443.46, 2.4, -61.0), -PI * 0.5, Color("e8f4ff"), 28, 0.01)
	l.name = "PanelFace"

## 1.5B: the Thermostat, a squat walking tower of fans and pipes, the Comfort Capsule docked on top, a dial on its chest.
func _thermostat() -> void:
	if root.get_node_or_null("Thermostat") != null:
		return
	var t := Node3D.new()
	t.name = "Thermostat"
	t.position = Vector3(414.0, 0.0, -60.0)
	root.add_child(t)
	Blocks.solid(t, "Body", Vector3(0, 3.0, 0), Vector3(6.0, 6.0, 6.0), Color("aebccb"))
	for k in 4:
		Blocks.visual(t, "Leg%d" % k, Vector3(-2.4 + (k % 2) * 4.8, 0.6, -2.4 + (k / 2) * 4.8), Vector3(1.0, 1.2, 1.0), Color("4a5260"))
	for k in 4:
		Blocks.visual(t, "Fan%d" % k, Vector3(-1.5 + (k % 2) * 3.0, 4.2 - (k / 2) * 2.4, 3.02), Vector3(2.2, 2.0, 0.06), Color("9fe8ff"))
	Blocks.visual(t, "Frost", Vector3(0, 6.02, 0), Vector3(6.2, 0.06, 6.2), Color("e8f8ff"))
	var dial := Kit.sign(t, "Dial", "COLD", Vector3(0, 5.0, -3.04), PI, Color("9fe8ff"), 64, 0.02)
	dial.name = "Dial"
	Blocks.visual(t, "DialFace", Vector3(0, 5.0, -3.02), Vector3(2.4, 1.4, 0.04), Color("1a1e24"))
	for k in 3:
		var v: Vector3 = [Vector3(-3.6, 1.0, 0), Vector3(3.6, 1.0, 0), Vector3(0, 1.0, 3.6)][k]
		Blocks.visual(t, "Vent%d" % k, v, Vector3(1.2, 1.2, 1.2), Color("6fd0ff"))
		Blocks.visual(t, "Pipe%d" % k, v * 2.0 + Vector3(0, -0.4, 0), Vector3(0.5, 0.5, 0.5) + Vector3(absf(v.x), 0, absf(v.z)) * 1.6, Color("8a96a4"))
	for k in 2:
		Blocks.visual(t, "Eye%d" % k, [Vector3(0, 3.2, -3.04), Vector3(-3.04, 3.2, 1.6)][k], [Vector3(1.0, 0.5, 0.06), Vector3(0.06, 0.5, 1.0)][k], Color("ff3030"))
	var cap := Node3D.new()
	cap.name = "Capsule"
	cap.position = Vector3(0, 7.2, 0)
	t.add_child(cap)
	Blocks.visual(cap, "Shell", Vector3.ZERO, Vector3(2.6, 1.6, 2.6), Color("101216"))
	Blocks.visual(cap, "Canopy", Vector3(0, 0.6, 0), Vector3(2.0, 0.8, 2.0), Color("bfe8ff"))
	Kit.person(cap, "EgonInCapsule", "EGON DUSK", Vector3(0, -0.4, 0), Color("2a2c30"), 1.8)
	var steam := Blocks.visual(t, "Steam", Vector3(0, 2.0, 0), Vector3(14.0, 4.0, 14.0), Color(1, 1, 1))
	steam.material_override = Kit.unshaded(Color("f4f4f4"), 0.28)
	steam.visible = false
	var ramp := Blocks.visual(root, "LoadingBay", Vector3(401.0, 0.6, -62.0), Vector3(5.0, 1.2, 6.0), Color("5a6470"))
	ramp.rotation.z = 0.25
	Kit.sign(root, "BaySign", "LOADING BAY 2", Vector3(401.0, 2.6, -58.9), 0.0, Color("ffd24a"), 32, 0.01)

func _frost() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 152
	for i in 9:
		if root.get_node_or_null("FrostPatch%d" % i) != null:
			continue
		var at := Vector3(414.0 + rng.randf_range(-12.0, 12.0), 0.03, -60.0 + rng.randf_range(-10.0, 9.0))
		var f := Blocks.visual(root, "FrostPatch%d" % i, at, Vector3(rng.randf_range(2.0, 4.0), 0.04, rng.randf_range(2.0, 4.0)), Color("dff4ff"))
		f.set_meta("frost", true)

func _frost_nodes() -> Array:
	var out: Array = []
	if root == null:
		return out
	for c in root.get_children():
		if c.has_meta("frost"):
			out.append(c)
	return out

func _dial(text: String, c: Color) -> void:
	var d := _node("Thermostat/Dial") as Label3D
	if d == null and root != null:
		d = root.get_node_or_null("Thermostat/Dial") as Label3D
	if d != null:
		d.text = text
		d.modulate = c

## 1.5C, the Flats: windows light up, people on the roofs, the tagged billboard shows Zero's message.
func _flats_lights() -> void:
	var dl = host.main.get("districts")
	if dl != null:
		dl.arm("stillwater_flats")
		dl.request("stillwater_flats")
	World.apply(host.main, PRESETS.night)
	_spawn([300.0, 0.5, -38.0, 180.0])
	host.player.input_enabled = false
	for i in 4:
		var x := 282.0 + i * 16.0
		for row in 2:
			for col in 3:
				var w := Blocks.visual(root, "LitWindow%d_%d_%d" % [i, row, col], Vector3(x - 4.0 + col * 4.0, 2.0 + row * 2.4, -65.9), Vector3(1.4, 1.2, 0.04), Color("ffd98a"))
				w.material_override = Kit.unshaded(Color("ffd98a"))
		Kit.lamp(root, "FlatsGlow%d" % i, Vector3(x, 3.0, -64.0), Color("ffc870"), 1.4, 10.0)
		for k in 3:
			Kit.person(root, "Cheer%d_%d" % [i, k], "", Vector3(x - 3.0 + k * 3.0, 6.0, -68.0), [Color("d84f4f"), Color("4f8bd8"), Color("e0b03a")][k], 1.7, PI)
	var bt := _node("BillboardText") as Label3D
	if bt != null:
		bt.text = "TONIGHT'S POWER COURTESY OF COLDFRONT,\nWHO DIDN'T KNOW THEY WERE DONATING.\nSTAY COOL. THE YARD IS OPEN. – Z"
		bt.modulate = LIME
	host.flow.save.set_flag("a1_flats_lit")

func _crowd() -> void:
	if root == null:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 61
	var colors := [Color("d84f4f"), Color("4f8bd8"), Color("e0b03a"), Color("2f8f6f"), Color("b04a6a"), Color("c9c2b4")]
	for i in 24:
		var at := Vector3(rng.randf_range(219.0, 241.0), 0.0, rng.randf_range(-36.0, -18.0))
		Blocks_blanket(at, colors[i % colors.size()])
		var p := Kit.person(root, "Resident%d" % i, "", at + Vector3(0, 0.05, 0), colors[(i + 2) % colors.size()], 1.1 if i % 5 == 0 else 1.7, rng.randf() * TAU)
		if i % 5 != 0:
			p.rotation.z = PI * 0.5
			p.position.y = 0.2
	Kit.person(root, "NanaInesNight", "NANA INES", Vector3(218.0, 0.0, -16.0), Color("e6e0d0"), 1.62)
	Kit.person(root, "LittleGirl", "LITTLE GIRL", Vector3(217.2, 0.0, -14.6), Color("ff9ad0"), 1.0, PI * 0.5)
	Kit.person(root, "MrDelacroixNight", "MR. DELACROIX", Vector3(222.0, 0.0, -16.0), Color("c9c2b4"), 1.7)
	for k in 3:
		Kit.person(root, "KidAtBailey%d" % k, "", Vector3(225.5 + k, 0.0, -14.4), colors[k], 1.1, PI)
	var z = host.power.zero if host.power != null else null
	if z != null and is_instance_valid(z):
		z.global_position = Vector3(216.0, 0.0, -14.6)
		z.rotation.y = PI * 0.5

func Blocks_blanket(at: Vector3, c: Color) -> void:
	var b := MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = Vector3(1.0, 0.04, 2.0)
	b.mesh = m
	b.position = at + Vector3(0, 0.02, 0)
	b.material_override = Kit.unshaded(c.darkened(0.35))
	root.add_child(b)

## 1.4B: Egon, a hundred stories tall over the river (PLACEHOLDER: boxes, red eyes, lime fingertips).
func _hologram() -> void:
	if root == null or root.get_node_or_null("Hologram") != null:
		return
	var h := Node3D.new()
	h.name = "Hologram"
	h.position = Vector3(410.0, 0.0, -150.0)
	root.add_child(h)
	var coat := Color("2a2c30")
	var parts := [["Coat", Vector3(0, 30, 0), Vector3(14, 44, 6)], ["Collar", Vector3(0, 54, 0), Vector3(12, 6, 7)], ["Head", Vector3(0, 60, 0), Vector3(6, 7, 6)],
		["ArmL", Vector3(-11, 50, 0), Vector3(4, 4, 18)], ["ArmR", Vector3(11, 50, 0), Vector3(4, 4, 18)]]
	for pt in parts:
		var mi := MeshInstance3D.new()
		mi.name = str(pt[0])
		var bm := BoxMesh.new()
		bm.size = pt[2]
		mi.mesh = bm
		mi.position = pt[1]
		if str(pt[0]).begins_with("Arm"):
			mi.rotation.x = -0.6
		mi.material_override = Kit.unshaded(coat, 0.55)
		h.add_child(mi)
	for k in 2:
		var eye := MeshInstance3D.new()
		eye.name = "Eye%d" % k
		var em := BoxMesh.new()
		em.size = Vector3(1.0, 0.5, 0.2)
		eye.mesh = em
		eye.position = Vector3(-1.4 + k * 2.8, 61.0, 3.1)
		eye.material_override = Kit.unshaded(Color("ff2020"))
		eye.set_meta("eye", true)
		h.add_child(eye)
	for k in 10:
		var tip := MeshInstance3D.new()
		tip.name = "Tip%d" % k
		var sm := SphereMesh.new()
		sm.radius = 0.5
		sm.height = 1.0
		tip.mesh = sm
		var side := -1.0 if k < 5 else 1.0
		tip.position = Vector3(side * (10.0 + (k % 5) * 0.9), 58.0, 8.0)
		tip.material_override = Kit.unshaded(LIME)
		tip.set_meta("tip", true)
		h.add_child(tip)
	var t := Label3D.new()
	t.name = "HoloLabel"
	t.text = "THE BENEFACTOR SPEAKS"
	t.position = Vector3(0, 72, 0)
	t.pixel_size = 0.08
	t.font_size = 64
	t.modulate = Color("ff6b5a")
	t.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	h.add_child(t)

func _fans(delta: float) -> void:
	if host.power == null or host.power.lit == null:
		return
	var room: Node = _district("solar_arcade_dark")
	if room == null:
		return
	for i in 4:
		var f := room.get_node_or_null("Fan%d" % i) as Node3D
		if f != null:
			f.rotation.y += delta * 4.0

# ------------------------------------------------------------------ scene end

func _end_scene() -> void:
	var sd := sdef()
	var r: Dictionary = host.flow.save.mission(str(sd.id))
	r["state"] = "done"
	r["completions"] = int(r.get("completions", 0)) + 1
	if score > 0:
		host.flow.save.note_score(str(sd.id), score)
		r["zero_score"] = int(sd.get("zero_score", 0))
	host.flow.save.set_flag(str(sd.flag))
	host.flow.persist()
	log.append("done:" + scene)
	host.hud.prompt("")
	var nxt := next_scene()
	if nxt != "" and def.get("built", []).has(nxt):
		start(nxt)
		return
	state = "done"
	pilot = {}
	host.player.external_move_active = false
	finished.emit()

func _hud() -> void:
	var h = host.hud
	match str(step.get("do", "")) if state == "step" else "":
		"carry":
			h.zero_label.text = "ICE  %d  ·  MELT %ds" % [bags, int(ceil(maxf(0.0, melt)))] if bags > 0 else "ICE  -"
			h.best_label.text = "DELIVERED %d/%d · SIGNAL %d" % [done_goals.size(), deliveries().size(), int(host.flow.save.story.get("signal", 0))]
			h.set_line("BAGS DELIVERED %d   ·   MONEY LEFT FOR %d BAGS   ·   ZERO SCORE %s" % [delivered, budget, Hud.fmt(int(sdef().get("zero_score", 0)))])
		"goals":
			var total := 0
			for g in goals():
				if not bool(g.get("optional", false)):
					total += 1
			h.zero_label.text = "%s  %d/%d" % [str(step.get("counter", "DONE")), total - required_left(), total]
			h.best_label.text = ("WATCH  " + _bar(watch)) if step.has("drones") else ("SCORE %d" % score)
			h.set_line("")
		"defend":
			h.zero_label.text = "REROUTE  %d%%" % int(reroute * 100.0)
			h.best_label.text = "DRONES DOWN %d · HITS %d" % [knocked, hits]
			h.set_line("")
		_:
			h.zero_label.text = str(sdef().get("title", ""))
			h.best_label.text = "SIGNAL %d" % int(host.flow.save.story.get("signal", 0))

static func _bar(v: float) -> String:
	var n := int(clampf(v, 0.0, 1.0) * 10.0)
	return "[" + "#".repeat(n) + "-".repeat(10 - n) + "]"

# ------------------------------------------------------------------ helpers

func _spawn(s: Array) -> void:
	var pl = host.player
	pl.spawn_position = Vector3(float(s[0]), float(s[1]), float(s[2]))
	pl.spawn_yaw = deg_to_rad(float(s[3]) if s.size() > 3 else 0.0)
	pl.respawn()
	pl.camera_yaw = 0.0
	pl.camera_pitch = -0.18  # the default; Zero Vision tilts it up at the hologram
	if pl.rig != null and pl.rig.has_method("face_world"):
		pl.rig.face_world(pl.spawn_yaw)
	pl.skating = bool(sdef().get("skate", false)) and pilot.is_empty()
	pl.update_board()
	pl.velocity = Vector3.ZERO

func _district(id: String) -> Node:
	for c in host.main.world_sim.get_children():
		if c.has_meta("district_id") and c.get_meta("district_id") == id:
			return c
	return null

func _node(name: String) -> Node:
	var room := _district(str(sdef().get("place", "")))
	var n: Node = room.get_node_or_null(name) if room != null else null
	if n == null and root != null:
		n = root.get_node_or_null(name)
	if n == null:
		for c in host.main.world_sim.get_children():
			if c.has_meta("district_id"):
				n = c.get_node_or_null(name)
				if n != null:
					break
	return n

func handles(who: String) -> bool:
	return who == "NARRATE"

func show_line(_who: String, text: String) -> float:
	var t: String = Protagonist.text(text, Protagonist.current(get_tree()))
	host.hud.say("", "(" + t + ")")
	host.spoken.append("NARRATE|" + t)
	return clampf(1.0 + 0.04 * t.length(), 2.4, 6.0)

func _fill(lines: Array) -> Array:
	var out: Array = []
	for l in lines:
		out.append([str(l[0]), str(l[1])])
	return out

# ------------------------------------------------------------------ review / test autopilot (walks, real physics)

func _pilot_tick(_delta: float) -> void:
	if pilot.is_empty() or state != "step":
		return
	var pl = host.player
	pl.external_move_active = true
	pl.external_move = Vector2.ZERO
	if waiting or not pl.input_enabled:
		return
	match str(step.get("do", "")):
		"topics":
			pilot["wait"] = float(pilot.get("wait", 0.0)) + _delta
			if float(pilot.wait) < 0.5:
				return
			pilot.wait = 0.0
			for tp in step.get("topics", []):
				if not topic_done.has(str(tp.key)):
					ask(str(tp.key))
					return
			ask("")
		"raise":
			pilot["wait"] = float(pilot.get("wait", 0.0)) + _delta
			if float(pilot.wait) > 1.5:
				pilot.wait = 0.0
				raise_phone()
		"goals":
			for g in goals():
				if done_goals.has(str(g.id)) or (bool(g.get("optional", false)) and not bool(g.get("pilot", false))):
					continue
				if step.has("hazards") and _pilot_hold(g.at):
					return
				if _walk(g.get("via", []), g.at, str(g.id)):
					if not in_reach().is_empty() and str(in_reach().id) == str(g.id):
						complete(str(g.id))
				return
		"defend":
			var best: Dictionary = {}
			var bd := 1e9
			for d in drones:
				var hat: Array = step.at
				# only the ones closing in on the switch house (chasing far ones runs him into the halls)
				if is_instance_valid(d.node) and d.node.global_position.y < 4.5 and Vector2(d.node.global_position.x - float(hat[0]), d.node.global_position.z - float(hat[1])).length() < 9.0:
					var dd: float = pl.global_position.distance_to(d.node.global_position)
					if dd < bd:
						bd = dd
						best = d
			if not best.is_empty():
				var dp: Vector3 = best.node.global_position
				_walk([], [dp.x, dp.z], "drone")
			else:
				_walk([], step.get("guard", step.at), "guard")
		"carry":
			if bags == 0:
				var lk: Array = step.locker
				if _walk(step.get("locker_via", []), lk, "locker"):
					take_load()
				return
			for dv in deliveries():
				if done_goals.has(str(dv.id)):
					continue
				if _walk(dv.get("via", []), dv.at, str(dv.id)):
					deliver(str(dv.id))
				return

## Boss phase 2: wait outside the steam while it blows if the target is inside it.
func _pilot_hold(at: Array) -> bool:
	var tp := Vector3(float(at[0]), 0.0, float(at[1]))
	if not in_hazard(tp, false):
		return false
	var p: Vector3 = host.player.global_position
	if in_hazard(p, false):
		return false
	for h in step.get("hazards", []):
		if Vector2(p.x - float(h[0]), p.z - float(h[1])).length() > float(h[2]) + 2.0:
			continue  # not at the edge yet: keep walking
		var period := float(h[3]) + float(h[4])
		var t := fmod(hz_t, period)
		# go only at the start of an off window (enough time to get in, spray and get out)
		if t < float(h[3]) + 0.1 or t > float(h[3]) + 0.6:
			return true
	return false

## Walk the via points then the target; true when within reach of the target.
func _walk(via: Array, at: Array, key: String) -> bool:
	var pl = host.player
	if str(pilot.get("key", "")) != key:
		pilot["key"] = key
		pilot["leg"] = 0
	var pts: Array = via.duplicate()
	pts.append(at)
	var leg: int = clampi(int(pilot.leg), 0, pts.size() - 1)
	var t: Array = pts[leg]
	var to := Vector3(float(t[0]) - pl.global_position.x, 0, float(t[1]) - pl.global_position.z)
	var last := leg == pts.size() - 1
	if to.length() < (1.2 if last else 0.8):
		if last:
			return true
		pilot.leg = leg + 1
		return false
	var d := to.normalized()
	var axes: Array = pl._camera_flat_axes()
	pl.external_move = Vector2(d.dot(axes[1]), d.dot(axes[0]))
	return false
