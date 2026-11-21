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
var vision_used := false
var root: Node3D                   # per-scene props (drones, crowd, hologram, strings)
var drones: Array = []             # [{node, path, i, speed}]
var overlay: ColorRect
var pilot: Dictionary = {}
var log: Array = []
var fired := {}
var keys_down := {}

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
	if step_i >= steps.size():
		state = "between"
		state_left = 0.4
		return
	step = steps[step_i]
	state = "step"
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
			if step.has("drones"):
				_make_drones(step.drones)
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
	if step.has("drones"):
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
		drones.append({"node": n, "path": path, "i": 1, "speed": float(d.get("speed", 3.0)), "y": float(d.get("y", 4.0))})

func _clear_drones() -> void:
	for d in drones:
		if is_instance_valid(d.node):
			d.node.queue_free()
	drones = []

func _drones(delta: float) -> void:
	for d in drones:
		var n: Node3D = d.node
		if not is_instance_valid(n):
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

func seen_by_drone() -> bool:
	var p: Vector3 = host.player.global_position
	if in_mist(p):
		return false
	for d in drones:
		if is_instance_valid(d.node) and Vector2(p.x - d.node.global_position.x, p.z - d.node.global_position.z).length() < float(step.get("det_r", 6.0)):
			return true
	return false

func _watch_tick(delta: float) -> void:
	if seen_by_drone():
		watch += delta / maxf(0.2, float(step.get("fill_s", 2.5)))
	else:
		watch = maxf(0.0, watch - delta * 0.35)
	if watch >= 1.0:
		_reset("spotted")

# ------------------------------------------------------------------ 1.1: the topic menu

func _topics_tick() -> void:
	var list: Array = step.get("topics", [])
	var text := ""
	for i in list.size():
		var tp: Dictionary = list[i]
		if not topic_done.has(str(tp.key)):
			text += "%d  %s    " % [i + 1, str(tp.label)]
	text += "E  " + str(step.get("done_label", "done"))
	host.hud.prompt(text)
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

func raise_phone() -> bool:
	if state != "step" or waiting or str(step.get("do", "")) != "raise":
		return false
	host.hud.prompt("")
	_vision(true)
	vision_used = true
	host.flow.save.set_flag("zero_vision_unlocked")
	host.flow.persist()
	host._say_all(_fill(step.get("lines", [])))
	waiting = true
	log.append("raise")
	return true

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
	var mi := MeshInstance3D.new()
	mi.name = "Strings"
	var im := ImmediateMesh.new()
	var mat := Kit.unshaded(LIME)
	mat.no_depth_test = true
	mat.disable_fog = true  # the night preset's fog swallowed them at 80 m in the first browser run
	im.surface_begin(Mesh.PRIMITIVE_LINES, mat)
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
		elif i < 80 and host.player != null:
			# some land around Fony, so the first look always has strings crossing the frame
			b = host.player.global_position + Vector3(rng.randf_range(-25.0, 25.0), rng.randf_range(0.0, 6.0), rng.randf_range(-30.0, 10.0))
		im.surface_add_vertex(a)
		im.surface_add_vertex(b)
	im.surface_end()
	mi.mesh = im
	root.add_child(mi)

# ------------------------------------------------------------------ hooks (steps and cinematics)

func hook(name: String) -> void:
	log.append("hook:" + name)
	match name:
		"board_back":
			host.flow.save.set_flag("upgrade_grip_tape")
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
	host.flow.persist()

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
				if _walk(g.get("via", []), g.at, str(g.id)):
					if not in_reach().is_empty() and str(in_reach().id) == str(g.id):
						complete(str(g.id))
				return
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
