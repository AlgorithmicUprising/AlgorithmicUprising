extends Node
## Act I M2 (Nov 19 2026): a small data-driven cutscene player for the Prologue cinematics (CINEMATIC P.2 The heat
## alert, CINEMATIC P.3 Flagged) in data/missions/prologue_cinematics.json. It runs inside story mode and borrows the
## story's HUD, world dressing, SFX and player (host = practice_run.gd). Text plus synthesized SFX only.
##
## Steps are [op, args...] run in order; SAY / NARRATE / WAIT / CARD hold for a while, everything else is instant.
## Hold Enter / Space / pad A (ui_accept) for SKIP_HOLD_S to skip; a skip still applies the cinematic's end state.
## finished(id, skipped) fires at the end; the host decides what comes next.

signal finished(id: String, skipped: bool)

const World = preload("res://scripts/story/story_world.gd")
const Protagonist = preload("res://scripts/front/protagonist.gd")
const JsonFile = preload("res://scripts/json_file.gd")
const DEF_PATH := "res://data/missions/prologue_cinematics.json"
const SKIP_HOLD_S := 1.0
const BILLBOARDS := {
	"forecast": [World.BB_FORECAST, Color("9fe8ff")],
	"ad": [World.BB_AD, Color("ffb36b")],
	"emergency": [World.BB_EMERGENCY, Color("ff6b5a")],
	"postponed": [World.BB_POSTPONED, Color("ffd59a")],
}

var host: Node
var defs := {}
var id := ""
var steps: Array = []
var at := 0
var wait_left := 0.0
var playing := false
var held := 0.0
var skip_armed := false           # a skip needs a fresh hold: a key already down when the cinematic starts does not count
var time_scale := 1.0               # tests: > 1 plays the holds faster
var camera: Camera3D
var shot := "game"
var drone: Node3D
var drone_from := Vector3.ZERO
var drone_to := Vector3.ZERO
var drone_t := -1.0
var drone_leaving := false
var bob := 0.0
var billboard_key := ""
var ran: Array = []                 # tests / probes: "id:OP" for every step run
var last_skipped := false

func setup(h: Node) -> void:
	host = h
	process_mode = Node.PROCESS_MODE_PAUSABLE
	var d = JsonFile.read(DEF_PATH)
	defs = d if typeof(d) == TYPE_DICTIONARY else {}

func has_cinematic(cid: String) -> bool:
	return defs.get("cinematics", {}).has(cid)

func def(cid: String) -> Dictionary:
	return defs.get("cinematics", {}).get(cid, {})

func play(cid: String) -> bool:
	if playing or not has_cinematic(cid):
		return false
	id = cid
	steps = def(cid).get("steps", [])
	at = 0
	wait_left = 0.0
	held = 0.0
	skip_armed = not Input.is_action_pressed("ui_accept")
	playing = true
	last_skipped = false
	host.hud.skip_hint("HOLD ENTER TO SKIP")
	return true

func skip() -> void:
	if playing:
		_end(true)

func _process(delta: float) -> void:
	_drone_tick(delta)
	if not playing:
		return
	var holding := Input.is_action_pressed("ui_accept")
	if not skip_armed:
		skip_armed = not holding
		holding = false
	held = held + delta if holding else maxf(0.0, held - delta * 2.0)
	host.hud.skip_hint("HOLD ENTER TO SKIP  " + "|".repeat(int(clampf(held / SKIP_HOLD_S, 0.0, 1.0) * 10.0)))
	if held >= SKIP_HOLD_S:
		_end(true)
		return
	if wait_left > 0.0:
		wait_left -= delta * time_scale
		if wait_left > 0.0:
			return
		host.hud.hush()
		World.crt(host.dressing, false, host.face_on)
	while playing and at < steps.size() and wait_left <= 0.0:
		var op: Array = steps[at]
		at += 1
		_run(op)
	if playing and at >= steps.size() and wait_left <= 0.0:
		_end(false)

func _run(op: Array) -> void:
	if op.is_empty():
		return
	var what := str(op[0])
	ran.append(id + ":" + what)
	var pname: String = Protagonist.current(get_tree())
	match what:
		"LOCK":
			host.player.input_enabled = false
			host.player.external_move = Vector2.ZERO
		"UNLOCK":
			host.player.input_enabled = true
		"LETTERBOX":
			host.hud.letterbox(bool(op[1]))
		"SHOT":
			set_shot(str(op[1]))
		"WAIT":
			wait_left = float(op[1])
		"SAY":
			var who := str(op[1])
			var text: String = Protagonist.text(str(op[2]), pname)
			host.spoken.append(who + "|" + text)
			host.hud.protagonist_tag = pname.to_upper()
			host.hud.say(Protagonist.speaker(who, pname), text)
			if who == "CRT":
				World.crt(host.dressing, true, host.face_on)
				host.sfx.play("crt")
			elif who == "FONY":
				host.sfx.play("fony")
			elif who.begins_with("WELFARE"):
				host.sfx.play("drone_chime", 1.2)
			wait_left = clampf(1.2 + 0.05 * text.length(), 2.4, 8.0)
		"NARRATE":
			var t: String = Protagonist.text(str(op[1]), pname)
			host.spoken.append("NARRATE|" + t)
			host.hud.say("", "(" + t + ")")
			wait_left = clampf(1.0 + 0.04 * t.length(), 2.2, 7.0)
		"CHIME":
			host.sfx.play("alert")
			host.hud.toast("EVERY SCREEN: THREE-TONE CHIME")
		"ALERT":
			host.hud.phone_alert(str(op[1]))
		"BILLBOARD":
			set_billboard(str(op[1]))
		"DRONE":
			drone_do(str(op[1]))
		"SFX":
			host.sfx.play(str(op[1]))
		"FLAG":
			host.flow.save.set_flag(str(op[1]))
			host.flow.persist()
		"CARD":
			host.spoken.append("CARD|" + str(op[1]))
			host.hud.card(str(op[1]))
			wait_left = float(op[2]) if op.size() > 2 else 5.0
		"CAM":
			# a fixed camera in world coordinates: ["CAM", [from x, y, z], [look x, y, z]] (P.4, inside the arcade)
			cam_at(Vector3(float(op[1][0]), float(op[1][1]), float(op[1][2])), Vector3(float(op[2][0]), float(op[2][1]), float(op[2][2])))
		"HOST":
			# a story hook: ["HOST", method, args...] (P.4: the power cascade, Zero's puppet stages, the phone header)
			if host.has_method(str(op[1])):
				host.callv(str(op[1]), op.slice(2))

func _end(skipped: bool) -> void:
	playing = false
	last_skipped = skipped
	var d := def(id)
	var es: Dictionary = d.get("end_state", {})
	if es.has("billboard") and str(es.billboard) != "":
		set_billboard(str(es.billboard))
	host.hud.phone_alert(str(es.get("alert", "")))
	if str(es.get("drone", "")) == "net":
		if drone == null:
			drone_do("enter")
			drone_t = 1.0
		drone_do("scan_on")
		drone_do("net")
	for m in es.get("host", []):
		# a skip still lands the end state (P.4: power on, Zero awake, the ZERO header)
		if host.has_method(str(m)):
			host.call(str(m))
	if str(d.get("flag", "")) != "":
		host.flow.save.set_flag(str(d.flag))
		host.flow.persist()
	wait_left = 0.0
	held = 0.0
	host.hud.hush()
	host.hud.skip_hint("")
	host.hud.letterbox(false)
	World.crt(host.dressing, false, host.face_on)
	set_shot("game")
	host.player.input_enabled = true
	finished.emit(id, skipped)

func set_billboard(key: String) -> void:
	if not BILLBOARDS.has(key):
		return
	billboard_key = key
	World.billboard(host.dressing, BILLBOARDS[key][0], "fixed", BILLBOARDS[key][1])

# ------------------------------------------------------------------ camera

func cam_at(from: Vector3, look: Vector3) -> void:
	shot = "cam"
	if camera == null:
		camera = Camera3D.new()
		camera.name = "CinematicCamera"
		camera.fov = 58.0
		host.dressing.add_child(camera)
	camera.look_at_from_position(from, look, Vector3.UP)
	camera.make_current()

func set_shot(name: String) -> void:
	shot = name
	var pl: Node3D = host.player
	if name == "game" or pl == null:
		if camera != null:
			camera.queue_free()
			camera = null
		var game_cam: Camera3D = null
		if pl != null:
			game_cam = pl.get_node_or_null("CameraPivot/SpringArm/Camera") as Camera3D
		if game_cam != null:
			game_cam.make_current()
		return
	if camera == null:
		camera = Camera3D.new()
		camera.name = "CinematicCamera"
		camera.fov = 58.0
		host.dressing.add_child(camera)
	var p: Vector3 = pl.global_position
	var fwd: Vector3 = pl.camera_flat_forward()
	var right := Vector3(-fwd.z, 0.0, fwd.x)
	var from := p
	var look := p
	match name:
		"billboard":
			var dir := Vector3(World.BILLBOARD.x - p.x, 0.0, World.BILLBOARD.z - p.z).normalized()
			from = p - dir * 4.0 + Vector3(0, 1.9, 0) + Vector3(-dir.z, 0, dir.x) * 1.2
			look = World.BILLBOARD
		"fony":
			from = p + fwd * 3.2 + Vector3(0, 1.45, 0) + right * 0.6
			look = p + Vector3(0, 1.0, 0)
		"drone":
			var target: Vector3 = p + fwd * 3.2 + Vector3(0, 2.6, 0)
			if drone != null:
				target = drone_to if drone_t < 1.0 else drone.global_position
			from = p - fwd * 3.0 + Vector3(0, 1.6, 0) + right * 1.0
			look = target
		"arcade":
			from = World.CRT + Vector3(0.5, 0.35, 2.4)
			look = World.CRT
	camera.look_at_from_position(from, look, Vector3.UP)
	camera.make_current()

# ------------------------------------------------------------------ the welfare drone

func drone_do(what: String) -> void:
	var pl: Node3D = host.player
	match what:
		"enter":
			if drone == null:
				drone = World.welfare_drone(host.dressing)
			var p: Vector3 = pl.global_position
			var fwd: Vector3 = pl.camera_flat_forward()
			drone_to = p + fwd * 3.2 + Vector3(0, 2.5, 0)
			drone_from = drone_to + Vector3(12.0, 8.0, -4.0)
			drone.global_position = drone_from
			drone_t = 0.0
			drone_leaving = false
			host.sfx.play("drone_hum")
		"scan_on":
			World.drone_scan(drone, true)
		"scan_off":
			World.drone_scan(drone, false)
		"net":
			World.drone_net(drone, true)
		"leave":
			if drone != null:
				drone_from = drone.global_position
				drone_to = drone_from + Vector3(10.0, 12.0, 0.0)
				drone_t = 0.0
				drone_leaving = true

func clear_drone() -> void:
	if drone != null:
		drone.queue_free()
		drone = null
	drone_t = -1.0

func _drone_tick(delta: float) -> void:
	if drone == null:
		return
	bob += delta
	if drone_t >= 0.0 and drone_t < 1.0:
		drone_t = minf(1.0, drone_t + delta / 2.4 * time_scale)
		var e := 1.0 - pow(1.0 - drone_t, 3.0)
		drone.global_position = drone_from.lerp(drone_to, e)
		if drone_t >= 1.0 and drone_leaving:
			clear_drone()
			return
	elif drone_t >= 1.0:
		drone.global_position = drone_to + Vector3(0, 0.08 * sin(bob * 2.2), 0)
	drone.rotation.y = 0.15 * sin(bob * 0.9)
