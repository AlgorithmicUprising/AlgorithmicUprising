extends Node
## M1 (Nov 19 2026): story mode, P.1 Practice Run, in the current park. Idle until start(); free roam never sees it.
## Wires the player's skate events (player_controller.gd skate_event) into the mission framework (mission_runner.gd),
## the score and combo speed system (combo_meter.gd), the line (line_tracker.gd) and the barks (barks.gd), and shows it
## all through story_hud.gd, the arcade marquee and the dead CRT (story_world.gd). Zero is a VOICE (O.S.): text plus
## synthesized SFX only (story/sfx.gd). No voice audio, no music.

const Runner = preload("res://scripts/mission/mission_runner.gd")
const Combo = preload("res://scripts/mission/combo_meter.gd")
const Line = preload("res://scripts/mission/line_tracker.gd")
const Barks = preload("res://scripts/mission/barks.gd")
const World = preload("res://scripts/story/story_world.gd")
const Hud = preload("res://scripts/story/story_hud.gd")
const Sfx = preload("res://scripts/story/sfx.gd")
const JsonFile = preload("res://scripts/json_file.gd")
const Autopilot = preload("res://scripts/story/story_autopilot.gd")

const DEF_PATH := "res://data/missions/p1_practice_run.json"
const SPEED_GOAL_CHECK := 5.5
const SETTLE_S := 0.35              # pending tricks bank once he has been rolling clean this long
const CARD_S := 5.5
const LOCKED_GRINDS := ["5o", "board"]   # plan: 5-0 unlocks in 1.5, boardslide in Act II

var main: Node
var player: Node
var flow: Node
var active := false
var def := {}
var runner = Runner.new()
var combo = Combo.new()
var line = Line.new()
var barks = Barks.new()
var hud: CanvasLayer
var sfx: Node
var dressing: Node3D
var lighting := {}
var queue: Array = []               # [[speaker, text], ...]
var talk_left := 0.0
var talking := ""
var card_left := 0.0
var voice_heard := false
var face_on := false
var zero_score := 0
var best_line := 0
var settle := 0.0
var pipe_visit := ""
var pipe_scored := false
var rail_kind := ""
var prompt_shown := ""
var free_bark_clock := 0.0
var spoken: Array = []              # tests / probes: every line shown, "SPEAKER|text"
var saved_player := {}
var npc_hidden: Array = []
var autopilot: Node = null

func bind(host: Node) -> void:
	main = host
	player = host.player
	flow = host.flow
	process_mode = Node.PROCESS_MODE_PAUSABLE

func toggle() -> void:
	if active:
		stop()
	else:
		start()

func start() -> bool:
	if active or player == null:
		return false
	var data = JsonFile.read(DEF_PATH)
	if typeof(data) != TYPE_DICTIONARY:
		push_error("P.1 mission definition missing")
		return false
	def = data
	runner = Runner.new()
	var loaded: Dictionary = runner.load_def(def)
	if not bool(loaded.get("ok", false)):
		push_error("P.1 mission definition rejected: %s" % loaded)
		return false
	runner.objective_started.connect(_on_objective_started)
	runner.objective_done.connect(_on_objective_done)
	runner.save_requested.connect(_on_save)
	combo = Combo.new()
	line = Line.new()
	line.setup(PackedStringArray(def.line.steps), float(def.line.limit_s))
	barks = Barks.new()
	barks.setup(def.get("barks", {}), 1119)
	active = true
	queue.clear()
	spoken.clear()
	talk_left = 0.0
	talking = ""
	# save v2: merge mission progress from disk (free roam never reads its save back)
	flow.save.load_story_user(flow.save_path)
	var rec: Dictionary = flow.save.mission(runner.id)
	zero_score = int(rec.get("zero_score", 0))
	best_line = int(rec.get("best_score", 0))
	voice_heard = flow.save.flag("p1_voice_heard")
	face_on = flow.save.flag("p1_crt_face")
	# the world
	dressing = World.build(main.world_sim)
	lighting = World.dawn(main)
	if zero_score > 0:
		World.marquee(dressing, "ZERO SCORE\n" + Hud.fmt(zero_score))
	World.crt(dressing, false, face_on)
	hud = Hud.new()
	hud.name = "StoryHud"
	add_child(hud)
	sfx = Sfx.new()
	sfx.name = "StorySfx"
	add_child(sfx)
	_hide_free_roam(true)
	saved_player = {"spawn": player.spawn_position, "yaw": player.spawn_yaw, "locked": player.locked_grinds.duplicate()}
	player.locked_grinds = LOCKED_GRINDS.duplicate()
	if not player.skate_event.is_connected(_on_skate):
		player.skate_event.connect(_on_skate)
	flow.save.set_flag("story_started")
	if int(rec.get("completions", 0)) > 0:
		# replay: the tutorial is done; straight to the line with the board up on the marquee
		runner.from_save(rec)
		_teleport("line")
		hud.set_objective(runner.title, "Run the line: bowl, quarter, rail. Beat the Zero Score.")
		_say_all([["SYSTEM", "Practice Run (replay). T puts you back at the bowl."]])
	else:
		_teleport("yard")
		_say_all(def.get("intro", []))
		runner.start()
	_refresh_hud()
	if demo_requested():
		start_autopilot()
	return true

## Review aid (story_autopilot.gd): story_demo=1 on the command line, or ?story=p1&story_demo=1 on the web build.
static func demo_requested() -> bool:
	if OS.get_cmdline_user_args().has("story_demo=1"):
		return true
	return OS.has_feature("web") and "story_demo=1" in str(JavaScriptBridge.eval("window.location.search", true))

func start_autopilot() -> Node:
	if autopilot != null:
		return autopilot
	autopilot = Autopilot.new()
	autopilot.name = "StoryAutopilot"
	autopilot.setup(self)
	add_child(autopilot)
	return autopilot

func stop() -> void:
	if not active:
		return
	active = false
	if player.skate_event.is_connected(_on_skate):
		player.skate_event.disconnect(_on_skate)
	player.combo_top_mult = 1.0
	player.combo_push_mult = 1.0
	player.locked_grinds = saved_player.get("locked", [])
	player.spawn_position = saved_player.get("spawn", player.spawn_position)
	player.spawn_yaw = saved_player.get("yaw", player.spawn_yaw)
	World.restore(lighting)
	lighting = {}
	if dressing != null:
		dressing.queue_free()
		dressing = null
	if hud != null:
		hud.queue_free()
		hud = null
	if sfx != null:
		sfx.queue_free()
		sfx = null
	_hide_free_roam(false)
	if autopilot != null:
		autopilot.queue_free()
		autopilot = null
		player.external_move_active = false
		player.external_move = Vector2.ZERO
	flow.persist()

## T (provisional key): back to the current objective's spawn, or to the bowl for the line.
func retry() -> void:
	if not active:
		return
	combo.pending.clear()
	line.reset()
	runner.retry()
	var o: Dictionary = runner.current()
	_teleport(str(o.get("spawn", "line")) if not o.is_empty() else "line")

func _process(delta: float) -> void:
	if not active:
		return
	_tick_talk(delta)
	if card_left <= 0.0:
		runner.tick(delta)
	combo.tick(delta)
	barks.tick(delta)
	if line.tick(delta):
		hud.toast("LINE TIMED OUT")
	player.combo_top_mult = combo.top_speed_mult()
	player.combo_push_mult = combo.push_mult()
	var flat_v := Vector2(player.velocity.x, player.velocity.z).length()
	if player.skating and player.is_on_floor() and flat_v >= SPEED_GOAL_CHECK:
		runner.notify("speed", {"speed": flat_v})
	if main.zone_at(player.global_position) == "BOWL" and player.global_position.y < -2.0 and player.skating:
		_line_step("bowl")
	_settle(delta)
	_prompt()
	_free_barks(delta)
	_refresh_hud()
	_publish()

# ------------------------------------------------------------------ skate events

func _on_skate(what: String, info: Dictionary) -> void:
	if not active:
		return
	if OS.get_environment("AU_PILOT_DEBUG") == "1":
		print("skate ", what, " ", info, " obj=", runner.current_id(), " pos=", player.global_position.snapped(Vector3(0.01, 0.01, 0.01)))
	match what:
		"callout":
			if str(info.get("kind", "")) == "bail":
				_bail()
			elif str(info.get("kind", "")) == "trick":
				combo.trick(str(info.get("text", "")))
		"trick_land":
			runner.notify("trick_land", {"trick": str(info.get("trick", ""))})
			_bank()
		"kick_up":
			runner.notify("kick_up", info)
		"drop_on":
			runner.notify("drop_on", info)
		"enter":
			pipe_visit = str(info.get("pipe", ""))
			pipe_scored = false
		"exit_flat":
			_quarter(float(info.get("peak", 0.0)))
			_bank()
		"lip_launch":
			_quarter(99.0)
		"qp_rolled_out":
			_quarter(99.0)
			_bank()
		"landed_transition", "landed_flat", "kickturn_end", "bs_air_land":
			_bank()
		"grind_lock":
			combo.grind_start()
			rail_kind = str(player.grind.kind) if player.grind != null and "kind" in player.grind else "rail"
		"grind_end", "grind_pop":
			var tricks: Array = player.grind_last.get("tricks", ["5050"])
			var names: Array = []
			for t in tricks:
				names.append(player.GRIND_TRICKS[t].name if player.GRIND_TRICKS.has(t) else str(t))
			var pts: int = combo.grind_done(names, float(player.grind_last.get("distance", 0.0)))
			_banked(pts)
			runner.notify("grind_clean", {"first": str(tricks[0]) if not tricks.is_empty() else "", "kind": rail_kind})
			if rail_kind == "rail":
				_line_step("rail")

func _quarter(peak: float) -> void:
	if pipe_scored:
		return
	pipe_scored = true
	if peak >= combo.TRANSITION_MIN_PEAK:
		combo.trick("TRANSITION", combo.TRANSITION_POINTS)
	runner.notify("quarter", {"peak": peak, "pipe": pipe_visit})
	_line_step("quarter")

func _bank() -> void:
	_banked(combo.land())

func _banked(pts: int) -> void:
	settle = 0.0
	if pts <= 0:
		return
	if sfx != null:
		sfx.play("bank", 1.0 + 0.06 * float(combo.multiplier() - 1))
	hud.toast("+%s  x%d" % [Hud.fmt(pts), int(combo.last_bank.get("mult", 1))])

## Fallback bank: anything still pending once he is rolling clean on the ground (no air, no rail, no bail).
func _settle(delta: float) -> void:
	if combo.pending.is_empty():
		settle = 0.0
		return
	var clean: bool = player.is_on_floor() and player.grind == null and player.ramp_mode == "" and not player.pipe_air and player.bail_time <= 0.0 and (player.trick == "" or player.trick == "land") and player.qp_state == ""
	settle = settle + delta if clean else 0.0
	if settle >= SETTLE_S:
		_bank()

func _bail() -> void:
	combo.bail()
	runner.fail("bail")
	if line.bail():
		hud.toast("LINE BROKEN")
	if sfx != null:
		sfx.play("bail")
	if runner.current_id() == "rail" and not voice_heard and _near_rail(7.0):
		voice_heard = true
		flow.save.set_flag("p1_voice_heard")
		var angle := float(player.grind_last.get("angle_deg", -1.0))
		var said := _words(int(round(angle))) if angle > 1.0 else "forty-one"
		_say_all(_fill(def.beats.rail_bail_first, {"angle": said}))
		flow.persist()
	elif voice_heard:
		_say_all(barks.pick("bail"))

func _near_rail(radius: float) -> bool:
	for node in get_tree().get_nodes_in_group("grind_rail"):
		if node is Node3D and str(node.get("kind")) == "rail" and node.global_position.distance_to(player.global_position) < radius:
			return true
	var r = main.world_sim.get_node_or_null("GrindRail")
	return r != null and r.global_position.distance_to(player.global_position) < radius

# ------------------------------------------------------------------ the line and the Zero Score

func _line_step(step: String) -> void:
	var on_line: bool = runner.current_id() == "line" or runner.state == "done"
	if not on_line:
		return
	var r: String = line.step(step, combo.score)
	if r == "step" and step != "bowl":
		hud.toast("LINE: " + step.to_upper())
	if r != "done":
		return
	var score: int = line.finish(combo.score)
	var best: bool = flow.save.note_score(runner.id, score)
	best_line = maxi(best_line, score)
	if sfx != null:
		sfx.play("objective")
	if zero_score <= 0:
		zero_score = zero_for(score, int(def.zero_score.get("round_to", 500)))
		flow.save.mission(runner.id)["zero_score"] = zero_score
		World.marquee(dressing, "ZERO SCORE\n" + Hud.fmt(zero_score))
		if sfx != null:
			sfx.play("marquee")
		hud.toast("LINE  " + Hud.fmt(score))
		_say_all(_fill(def.beats.zero_score_set, {"zero": Hud.fmt(zero_score)}))
		runner.notify("line_done", {"score": score})
		_say_all(def.beats.get("after_done", []))
	else:
		hud.toast("LINE  " + Hud.fmt(score) + ("   NEW BEST" if best else ""))
		if score > zero_score:
			var first: bool = not runner.is_done("beat_zero") and not flow.save.flag("p1_zero_beaten")
			runner.notify("line_beat", {"score": score})
			if first:
				flow.save.set_flag("p1_zero_beaten")
				_say_all(def.beats.zero_score_beaten)
	flow.persist()

## Script: "ZERO SCORE: 4,000. (The number is set just above whatever the player scored.)" Next multiple of round_to
## strictly above the first line's score (provisional rule).
static func zero_for(score: int, round_to := 500) -> int:
	return (int(floor(float(maxi(score, 0)) / float(round_to))) + 1) * round_to

# ------------------------------------------------------------------ objectives and lines

func _on_objective_started(id: String) -> void:
	var o: Dictionary = runner.objective(id)
	prompt_shown = ""
	if hud != null:
		hud.prompt("")
		hud.set_objective(runner.title, str(o.get("text", "")))
	if o.has("spawn"):
		player.spawn_position = _spawn(str(o.spawn)).pos
		player.spawn_yaw = _spawn(str(o.spawn)).yaw
	if id == "line":
		line.reset()
	_say_all(o.get("on_start", []), id)

func _on_objective_done(id: String) -> void:
	if sfx != null:
		sfx.play("objective")
	var o: Dictionary = runner.objective(id)
	_say_all(o.get("on_done", []))
	if id == "rail":
		_say_all(def.beats.rail_land_after_voice if voice_heard else def.beats.rail_land_first_try)
		voice_heard = true
		face_on = true
		flow.save.set_flag("p1_voice_heard")
		flow.save.set_flag("p1_crt_face")
		_say_all(def.beats.reveal)
		World.crt(dressing, talking.begins_with("VOICE"), face_on)
	if runner.state == "done" and hud != null:
		hud.set_objective(runner.title, "Done. Optional: beat the Zero Score (T resets to the bowl).")

func _on_save(id: String, snap: Dictionary) -> void:
	flow.save.set_mission(id, snap)
	flow.persist()

## Queue lines. Lines tagged with an objective are dropped if that objective is already done when their turn comes
## (a fast player should not hear "Rail. Fifty-fifty." after the 50-50).
func _say_all(lines: Array, for_objective := "") -> void:
	for l in lines:
		if typeof(l) == TYPE_ARRAY and l.size() >= 2:
			queue.append([str(l[0]), str(l[1]), for_objective])

func _tick_talk(delta: float) -> void:
	if card_left > 0.0:
		card_left -= delta
		if card_left <= 0.0:
			hud.card("")
		return
	if talk_left > 0.0:
		talk_left -= delta
		if talk_left > 0.0:
			return
		talking = ""
		hud.hush()
		World.crt(dressing, false, face_on)
	while not queue.is_empty() and queue[0].size() > 2 and str(queue[0][2]) != "" and runner.is_done(str(queue[0][2])):
		queue.pop_front()
	if queue.is_empty():
		return
	var next: Array = queue.pop_front()
	var who: String = next[0]
	var text: String = next[1]
	spoken.append(who + "|" + text)
	if who == "CARD":
		hud.card(text)
		card_left = CARD_S
		sfx.play("card")
		return
	talking = who
	talk_left = clampf(1.0 + 0.045 * text.length(), 1.8, 6.0)
	hud.say(who if who != "SYSTEM" else "", text if who != "MARQUEE" else "ON-SCREEN: " + text)
	if who.begins_with("VOICE"):
		World.crt(dressing, true, face_on)
		sfx.play("crt")
	elif who == "FONY":
		sfx.play("fony")
	elif who == "MARQUEE":
		sfx.play("marquee")

func _prompt() -> void:
	var o: Dictionary = runner.current()
	if o.is_empty() or not runner.prompt_due() or not o.has("prompt"):
		if prompt_shown != "":
			prompt_shown = ""
			hud.prompt("")
		return
	if prompt_shown == o.id:
		return
	prompt_shown = o.id
	var p: Dictionary = o.prompt
	hud.prompt("%s    [ %s ]    pad: %s" % [p.get("verb", ""), p.get("kb", ""), p.get("pad", "")])
	sfx.play("prompt")

func _free_barks(delta: float) -> void:
	if not voice_heard or not queue.is_empty() or talking != "":
		return
	free_bark_clock += delta
	if free_bark_clock < 6.0:
		return
	free_bark_clock = 0.0
	if player.skating and Vector2(player.velocity.x, player.velocity.z).length() > 4.0:
		_say_all(barks.pick("free_skate"))

func _refresh_hud() -> void:
	if hud == null:
		return
	hud.set_zero(zero_score, best_line)
	hud.set_score(combo.score, combo.meter, combo.multiplier(), combo.top_speed_mult())
	var on_line: bool = runner.current_id() == "line" or runner.state == "done"
	if on_line:
		var marks: Array = []
		for i in line.steps.size():
			marks.append(("[x] " if i < line.at else "[ ] ") + line.steps[i].to_upper())
		hud.set_line("   ".join(marks) + ("   %.0fs" % (line.limit_s - line.elapsed) if line.started() else ""))
	else:
		hud.set_line("")

# ------------------------------------------------------------------ helpers

func _spawn(key: String) -> Dictionary:
	var s: Array = def.get("spawns", {}).get(key, [-42.0, 0.5, 2.0, 1.05])
	return {"pos": Vector3(s[0], s[1], s[2]), "yaw": float(s[3])}

func _teleport(key: String) -> void:
	var s := _spawn(key)
	player.spawn_position = s.pos
	player.spawn_yaw = s.yaw
	player.respawn()
	# heading = body yaw + camera yaw (camera_yaw is relative to the body); keep the body's and zero the camera's
	player.camera_yaw = 0.0
	if player.rig != null and player.rig.has_method("face_world"):
		player.rig.face_world(s.yaw)
	player.skating = true
	player.trick = ""
	player.bail_time = 0.0
	player.update_board()

func _hide_free_roam(hide: bool) -> void:
	if main.hint_label != null:
		main.hint_label.visible = not hide
	# Zero is not awake yet in the Prologue: the old block Zero in the Resistance rooms steps out of story mode
	var npc = main.world_sim.get_node_or_null("NPCZero")
	if npc != null:
		npc.visible = not hide
		if hide and npc.is_in_group("interactable"):
			npc.remove_from_group("interactable")
			npc_hidden.append(npc)
		elif not hide and npc_hidden.has(npc):
			npc.add_to_group("interactable")
			npc_hidden.erase(npc)

static func _fill(lines: Array, values: Dictionary) -> Array:
	var out: Array = []
	for l in lines:
		var t := str(l[1])
		for k in values:
			t = t.replace("{" + k + "}", str(values[k]))
		out.append([str(l[0]), t])
	return out

static func _words(n: int) -> String:
	var ones := ["zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten", "eleven", "twelve",
		"thirteen", "fourteen", "fifteen", "sixteen", "seventeen", "eighteen", "nineteen"]
	var tens := ["", "", "twenty", "thirty", "forty", "fifty", "sixty", "seventy", "eighty", "ninety"]
	if n < 0 or n >= 100:
		return str(n)
	if n < 20:
		return ones[n]
	return tens[n / 10] + ("" if n % 10 == 0 else "-" + ones[n % 10])

func _publish() -> void:
	if not OS.has_feature("web"):
		return
	var js := "window.AU_STORY={active:true,objective:'%s',state:'%s',score:%d,meter:%s,mult:%d,zero:%d,best:%d,line:%d,talk:'%s',prompt:%s,lines:%d,pilot:'%s'};" % [
		runner.current_id(), runner.state, combo.score, snapped(combo.meter, 0.01), combo.multiplier(), zero_score, best_line,
		line.at, talking.replace("'", ""), "true" if prompt_shown != "" else "false", spoken.size(),
		(str(autopilot.legs[mini(autopilot.leg, autopilot.legs.size() - 1)].name) + ("/done" if autopilot.finished else "")) if autopilot != null else ""]
	JavaScriptBridge.eval(js, true)
