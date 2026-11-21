extends Node
## MISSION P.3 Power On (Act I milestone M4, Nov 20 2026). After P.2 Run's side door: a fade into the dark Solar Arcade
## (the solar_arcade_dark district pack, armed and requested when P.2 Run starts). The INT. lines play (the CRT on the
## workbench whispers; the script's 115°F room / 98.6°F body), then Fony is on foot: find three fuses (a cabinet's coin
## box, the toolbox under the workbench, the light fixture over the tall cabinet, reached by walking up the toppled one)
## and throw the breaker ("DO NOT RECONNECT – IT TALKS.") before the drone's thermal sweep light crosses the windows.
##
## Fail rule (the breakdown's proposal): if the sweep gets to the end, the drone "finds a warm spot": short fade, the
## room resets to the last fuse found (fuses found stay found), the sweep starts over. No lives, Zero Score: none.
## Throwing the breaker ends P.3; CINEMATIC P.4 Zero (the cascade, "Hi. I'm Zero.", the ??? -> ZERO header) is next and
## not built yet, so an end card says so. Text + synthesized SFX only (pickup, breaker); no audio files.

signal finished

const JsonFile = preload("res://scripts/json_file.gd")
const Protagonist = preload("res://scripts/front/protagonist.gd")
const World = preload("res://scripts/story/story_world.gd")
const ZeroPuppet = preload("res://scripts/story/zero_puppet.gd")
const ZERO_AT := Vector3(245.6, 1.0, -26.0)     # sitting on the workbench, facing the room (-X)
const PLACEHOLDER_ZERO := ["ZeroTorso", "ZeroArm", "Jacket", "BenchCRT", "CrtFace"]
const DEF_PATH := "res://data/missions/p3_power_on.json"
const ID := "p3_power_on"
const DISTRICT := "solar_arcade_dark"
const ORDER := ["coin_box", "toolbox", "fixture"]

var host: Node                      # practice_run.gd
var def: Dictionary = {}
var state := ""                     # "" / intro / play / found / power / done
var state_left := 0.0
var sweep := 0.0                    # 0 .. 1 across the windows
var fuses := {}                     # fuse id -> true
var last_fuse := ""
var fails := 0
var fired := {}
var sweep_light: Node3D
var pilot: Dictionary = {}          # review / test autopilot
var log: Array = []
var zero: Node3D                    # CINEMATIC P.4: the cutout puppet (zero_puppet.gd)
var lit: Node3D                     # CINEMATIC P.4: the power-on lights

func setup(h: Node) -> void:
	host = h
	var d = JsonFile.read(DEF_PATH)
	def = d if typeof(d) == TYPE_DICTIONARY else {}

func active() -> bool:
	return state != "" and state != "done"

func hides_prompts() -> bool:
	return state in ["intro", "found", "power"]

func rec() -> Dictionary:
	return host.flow.save.mission(ID)

## Prefetch: the interior streams in while the player is still out on Glass Row.
static func prefetch(main: Node) -> void:
	var dl = main.get("districts")
	if dl != null:
		dl.arm(DISTRICT)
		dl.request(DISTRICT)

func start() -> void:
	var r := rec()
	fuses = {}
	for f in r.get("done", []):  # the save contract's "done" list holds the fuses found
		fuses[str(f)] = true
	last_fuse = str(r.get("checkpoint", ""))  # "checkpoint": the last fuse found (where a reset puts him)
	fails = int(r.get("fails", 0))
	fired = {}
	r["state"] = "active"
	host.flow.save.set_flag("p3_power_started")
	host.flow.save.story["current"] = ID
	host.flow.persist()
	prefetch(host.main)
	World.apply(host.main, World.INTERIOR_DARK)
	host.hud.fade_to(1.0, 0.01)
	_place_reset()
	var pl = host.player
	pl.skating = false
	pl.update_board()
	pl.input_enabled = false
	sweep = 0.0
	_sweep_light()
	host.hud.set_objective(str(def.get("title", "P.3 POWER ON")), _objective())
	state = "intro"
	state_left = float(def.get("fade_s", 0.6))
	if fuses.is_empty() and not fired.has("intro"):
		fired["intro"] = true
		host._say_all(_fill(def.lines.intro))
	_hide_found()
	log.append("start:%d" % fuses.size())

func teardown() -> void:
	World.apply(host.main, World.DAWN)
	for n in [zero, lit]:
		if n != null and is_instance_valid(n):
			n.queue_free()
	zero = null
	lit = null
	_placeholders(true)
	if host.run != null:
		host.run._hud_zero()
	if sweep_light != null and is_instance_valid(sweep_light):
		sweep_light.queue_free()
	sweep_light = null
	if host.player != null:
		host.player.input_enabled = true
		host.player.external_move_active = false
	host.hud.fade_to(0.0, 0.01)
	host.hud.prompt("")
	if state != "done":
		state = ""

# ------------------------------------------------------------------ per frame

func tick(delta: float) -> void:
	if state == "" or state == "done":
		return
	_pilot_tick(delta)
	match state:
		"intro":
			state_left -= delta
			if state_left <= 0.0 and host.talking == "" and host.queue.is_empty():
				host.hud.fade_to(0.0, float(def.get("fade_s", 0.6)))
				host.player.input_enabled = true
				state = "play"
				log.append("play")
			elif state_left <= 0.0 and host.hud.fade_alpha() > 0.99:
				host.hud.fade_to(0.0, float(def.get("fade_s", 0.6)))
		"play":
			sweep += delta / maxf(1.0, float(def.get("sweep_s", 100.0)))
			if sweep >= 0.8 and not fired.has("sweep_close"):
				fired["sweep_close"] = true
				host._say_all(_fill(def.lines.sweep_close))
			if sweep >= 1.0:
				_found()
			else:
				_reach()
		"found":
			state_left -= delta
			if state_left <= 0.0:
				_place_reset()
				sweep = 0.0
				fired.erase("sweep_close")
				host.hud.fade_to(0.0, float(def.get("fade_s", 0.6)))
				host.player.input_enabled = true
				state = "play"
				log.append("reset:" + (last_fuse if last_fuse != "" else "start"))
		"power":
			state_left -= delta
			if state_left <= 0.0 and host.talking == "" and host.queue.is_empty():
				_finish()
	_sweep_tick()
	_hud()

## The score box shows P.3's own state (no ZERO TIME in here): the fuse count and the sweep.
func _hud() -> void:
	host.hud.zero_label.text = "FUSES  %d/3" % fuses.size()
	host.hud.best_label.text = "SWEEP  " + _bar(sweep)
	host.hud.set_line("FUSES %d/3   ·   SWEEP %s%s" % [fuses.size(), _bar(sweep), ("   ·   FOUND x%d" % fails if fails > 0 else "")])

## Font-safe (ASCII) sweep bar: [#####-----].
static func _bar(v: float) -> String:
	var n := int(clampf(v, 0.0, 1.0) * 10.0)
	return "[" + "#".repeat(n) + "-".repeat(10 - n) + "]"

## What is in reach right now: a fuse id, "breaker", or "".
func in_reach() -> String:
	var p: Vector3 = host.player.global_position
	var r := float(def.get("reach_r", 1.5))
	for id in ORDER:
		if fuses.has(id):
			continue
		var f: Dictionary = def.fuses[id]
		if Vector2(p.x - float(f.at[0]), p.z - float(f.at[1])).length() < r and p.y > float(f.get("min_y", -9.0)):
			return id
	var b: Array = def.breaker.at
	if Vector2(p.x - float(b[0]), p.z - float(b[1])).length() < r + 0.3:
		return "breaker"
	return ""

func _reach() -> void:
	var what := in_reach()
	if what == "":
		host.hud.prompt("")
		return
	if what == "breaker":
		host.hud.prompt("E  throw the breaker" if fuses.size() >= 3 else "Breaker: %d of 3 fuses" % fuses.size())
	else:
		host.hud.prompt("E  take the fuse")
	if Input.is_action_just_pressed("interact"):
		interact()

## E (or the autopilot): take the fuse in reach, or throw the breaker with all three.
func interact() -> bool:
	if state != "play":
		return false
	var what := in_reach()
	if what == "":
		return false
	if what == "breaker":
		if fuses.size() < 3:
			if not fired.has("need_fuses"):
				fired["need_fuses"] = true
				host._say_all(_fill(def.lines.need_fuses))
			return false
		_throw()
		return true
	fuses[what] = true
	last_fuse = what
	var r := rec()
	r["done"] = fuses.keys()
	r["checkpoint"] = last_fuse
	host.flow.save.set_flag("p3_fuse_" + what)
	host.flow.persist()
	host.sfx.play("pickup")
	host.hud.toast("FUSE %d/3" % fuses.size())
	host._say_all(_fill(def.fuses[what].line))
	if fuses.size() == 3:
		host._say_all(_fill(def.lines.all_fuses))
	_hide_found()
	host.hud.set_objective(str(def.get("title", "P.3 POWER ON")), _objective())
	log.append("fuse:" + what)
	return true

func _objective() -> String:
	if fuses.size() >= 3:
		return "Throw the breaker before the sweep reaches you."
	return "Find the fuses (%d/3) before the sweep reaches you." % fuses.size()

func _found() -> void:
	state = "found"
	state_left = float(def.get("fade_s", 0.6)) + 1.2
	fails += 1
	rec()["fails"] = fails
	host.player.input_enabled = false
	host.player.velocity = Vector3.ZERO
	host.sfx.play("drone_chime")
	host.hud.toast("FOUND")
	host.hud.prompt("")
	host.hud.fade_to(1.0, float(def.get("fade_s", 0.6)))
	host.queue.clear()
	host._say_all(_fill(def.lines.found))
	host.flow.persist()
	log.append("found")

func _throw() -> void:
	state = "power"
	state_left = 1.5
	host.player.input_enabled = false
	host.player.velocity = Vector3.ZERO
	host.hud.prompt("")
	host.sfx.play("breaker")
	host.queue.clear()
	host._say_all(_fill(def.lines.throw))
	var lever := _district_node("BreakerLever") as Node3D
	if lever != null:
		lever.rotation.z = 0.9
	log.append("breaker")

func _finish() -> void:
	state = "done"
	var r := rec()
	r["state"] = "done"
	r["completions"] = int(r.get("completions", 0)) + 1
	host.flow.save.set_flag("p3_power_done")
	host.flow.persist()
	if sweep_light != null and is_instance_valid(sweep_light):
		sweep_light.visible = false
	host.player.input_enabled = true
	log.append("done")
	finished.emit()

# ------------------------------------------------------------------ the room

func _place_reset() -> void:
	var pos: Array = def.spawn.pos
	var yaw := float(def.spawn.get("yaw_deg", 180.0))
	if last_fuse != "" and def.fuses.has(last_fuse):
		pos = def.fuses[last_fuse].reset
	var pl = host.player
	pl.spawn_position = Vector3(float(pos[0]), float(pos[1]), float(pos[2]))
	pl.spawn_yaw = deg_to_rad(yaw)
	pl.respawn()
	pl.camera_yaw = 0.0
	if pl.rig != null and pl.rig.has_method("face_world"):
		pl.rig.face_world(pl.spawn_yaw)
	pl.skating = false
	pl.velocity = Vector3.ZERO
	pl.input_enabled = false

func _hide_found() -> void:
	for id in ORDER:
		var n := _district_node(str(def.fuses[id].node)) as Node3D
		if n != null:
			n.visible = not fuses.has(id)

func _district_node(name: String) -> Node:
	for c in host.main.world_sim.get_children():
		if c.has_meta("district_id") and c.get_meta("district_id") == DISTRICT:
			return c.get_node_or_null(name)
	return null

func _sweep_light() -> void:
	if sweep_light != null and is_instance_valid(sweep_light):
		return
	sweep_light = Node3D.new()
	sweep_light.name = "P3SweepLight"
	host.main.world_sim.add_child(sweep_light)
	var beam := MeshInstance3D.new()
	beam.name = "Beam"
	var m := BoxMesh.new()
	m.size = Vector3(2.4, 1.3, 0.05)
	beam.mesh = m
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.62, 0.91, 1.0)
	beam.material_override = mat
	sweep_light.add_child(beam)
	var l := SpotLight3D.new()
	l.name = "Spot"
	l.light_color = Color(0.62, 0.91, 1.0)
	l.light_energy = 3.0
	l.spot_range = 22.0
	l.spot_angle = 22.0
	l.rotation = Vector3(-0.5, 0.0, 0.0)
	sweep_light.add_child(l)

func _sweep_tick() -> void:
	if sweep_light == null or not is_instance_valid(sweep_light):
		return
	var xs: Array = def.get("sweep_x", [213.0, 247.0])
	sweep_light.position = Vector3(lerpf(float(xs[0]), float(xs[1]), clampf(sweep, 0.0, 1.0)), 3.2, -10.2)

# ------------------------------------------------------------------ lines

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

# ------------------------------------------------------------------ review / test autopilot

## Walks the room (stick only, the real physics): the coin box, the toolbox, up the toppled cabinet to the fixture,
## then the breaker. caught_once: stand still once so the sweep finds him, to show the reset.
func start_pilot(get_found := false) -> void:
	var legs := [
		[[231.5, -25.0], [230.0, -37.6, "coin_box"]],
		[[238.0, -30.0], [242.5, -24.0, "toolbox"]],
		[[236.0, -21.0], [236.0, -19.0], [236.0, -12.9, "fixture"]],
		[[236.0, -19.5], [219.0, -26.0], [214.3, -34.0, "breaker"]],
	]
	pilot = {"legs": legs, "part": 0, "leg": 0, "get_found": get_found, "found_once": false, "finished": false}

func _pilot_tick(_delta: float) -> void:
	if pilot.is_empty() or pilot.finished:
		return
	var pl = host.player
	pl.external_move_active = true
	pl.external_move = Vector2.ZERO
	if state != "play":
		if state == "found":
			pilot.found_once = true
		if state == "done" or state == "power":
			pilot.finished = state == "done"
		return
	if pilot.get_found and not pilot.found_once and fuses.size() >= 1:
		return  # wait in the open for the sweep (shows the reset)
	# the part follows the fuses found (after a reset he is back by the last one)
	pilot.part = mini(fuses.size(), 3)
	var part: Array = pilot.legs[pilot.part]
	var leg: int = clampi(int(pilot.get("leg_" + str(pilot.part), 0)), 0, part.size() - 1)
	var t: Array = part[leg]
	var to := Vector3(float(t[0]) - pl.global_position.x, 0, float(t[1]) - pl.global_position.z)
	if t.size() > 2 and in_reach() == str(t[2]):
		interact()
		return
	if to.length() < 0.6 and leg < part.size() - 1:
		pilot["leg_" + str(pilot.part)] = leg + 1
		return
	if to.length() > 0.1:
		var d := to.normalized()
		var axes: Array = pl._camera_flat_axes()
		pl.external_move = Vector2(d.dot(axes[1]), d.dot(axes[0]))

# ------------------------------------------------------------------ CINEMATIC P.4 hooks (first pass)

## After a reload past the breaker: back in the arcade by the breaker, the room still dark, P.3 done.
func enter_done() -> void:
	prefetch(host.main)
	World.apply(host.main, World.INTERIOR_DARK)
	last_fuse = ""
	fuses = {"coin_box": true, "toolbox": true, "fixture": true}
	var pl = host.player
	pl.spawn_position = Vector3(214.6, 0.5, -31.5)
	pl.spawn_yaw = deg_to_rad(180.0)
	pl.respawn()
	pl.skating = false
	pl.update_board()
	state = "done"
	_hide_found()
	_hud()

## The cascade: tubes, the token sign, the cabinets glowing through their sheets, a little cooler light.
func light_up() -> void:
	if lit != null and is_instance_valid(lit):
		return
	lit = Node3D.new()
	lit.name = "P4PowerOn"
	host.main.world_sim.add_child(lit)
	for i in 4:
		var l := OmniLight3D.new()
		l.name = "Tube%d" % i
		l.position = Vector3(218.0 + i * 9.0, 5.2, -26.0)
		l.light_color = Color("dff3ff")
		l.light_energy = 0.9
		l.omni_range = 13.0
		lit.add_child(l)
	var room := _district_room()
	if room != null:
		for c in room.get_children():
			if c.has_meta("glow"):
				var m := StandardMaterial3D.new()
				m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				m.albedo_color = Color("7fe0ff") if c.name.hash() % 2 == 0 else Color("c6ff3d")
				(c as MeshInstance3D).material_override = m
		var sign := room.get_node_or_null("TokenSign") as Label3D
		if sign != null:
			sign.modulate = Color("ffcf4a")
	if sweep_light != null and is_instance_valid(sweep_light):
		sweep_light.visible = false
	var lit_preset := World.INTERIOR_DARK.duplicate()
	lit_preset.ambient = Color("8a8f9a")
	lit_preset.ambient_energy = 0.3
	World.apply(host.main, lit_preset)
	log.append("power_on")

func zero_stage(s: String) -> void:
	if zero == null or not is_instance_valid(zero):
		zero = ZeroPuppet.new()
		host.main.world_sim.add_child(zero)
		zero.global_position = ZERO_AT
		zero.rotation.y = -PI * 0.5
	zero.stage(s)
	_placeholders(s == "off")
	log.append("zero:" + s)

func _placeholders(show: bool) -> void:
	var room := _district_room()
	if room == null:
		return
	for n in PLACEHOLDER_ZERO:
		var c := room.get_node_or_null(n) as Node3D
		if c != null:
			c.visible = show

func _district_room() -> Node:
	for c in host.main.world_sim.get_children():
		if c.has_meta("district_id") and c.get_meta("district_id") == DISTRICT:
			return c
	return null
