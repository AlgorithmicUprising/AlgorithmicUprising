extends Node
## M1 (Nov 19 2026): story mode, P.1 Practice Run, in the current park. Idle until start(); free roam never sees it.
## Wires the player's skate events (player_controller.gd skate_event) into the mission framework (mission_runner.gd),
## the score and combo speed system (combo_meter.gd), the line (line_tracker.gd) and the barks (barks.gd), and shows it
## all through story_hud.gd, the arcade marquee and the dead CRT (story_world.gd). Text plus synthesized SFX only
## (story/sfx.gd). No voice audio, no music.
##
## Act I (Nov 19 2026, P.1 Practice Run v2 + milestone M2): Zero coaches by TEXT on Fony's phone (story_hud.gd phone
## thread, header "???" until P.4) and speaks aloud through the window CRT only a few times. After the first clean line
## he offers the deal (one breaker, thirty amps); the heat alert interrupts on the first beat of the Zero Score, 90 s
## after the deal or 15 s idle, and hands off to CINEMATIC P.2 The heat alert and CINEMATIC P.3 Flagged
## (cinematic.gd, data/missions/prologue_cinematics.json). The playable slice ends there for now; P.2 Run is M3.

const Runner = preload("res://scripts/mission/mission_runner.gd")
const Combo = preload("res://scripts/mission/combo_meter.gd")
const Line = preload("res://scripts/mission/line_tracker.gd")
const Barks = preload("res://scripts/mission/barks.gd")
const World = preload("res://scripts/story/story_world.gd")
const Hud = preload("res://scripts/story/story_hud.gd")
const Sfx = preload("res://scripts/story/sfx.gd")
const JsonFile = preload("res://scripts/json_file.gd")
const Autopilot = preload("res://scripts/story/story_autopilot.gd")
const Protagonist = preload("res://scripts/front/protagonist.gd")
const Cinematic = preload("res://scripts/story/cinematic.gd")
const TEXT_SPEAKERS := ["TEXT ???", "TEXT FONY", "TYPING ???", "TYPING FONY", "DRAFT FONY", "PHONE", "ALERT", "WAIT"]
const BLIP_S := 0.2
const IDLE_SPEED := 0.6

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
# P.1 v2 / M2
var contact := false                # Beat 0 has run: Zero has texted (bail and free-skate barks may fire)
var rail_bailed := false            # 6A played (picks 6B "Better." over 6C "Clean.")
var hesitated := {}                 # objective id -> its hesitation text was queued (once)
var deal_state := ""                # "" / queued / offered
var p2_state := ""                  # "" / armed / handoff / cinematic / done
var p2_clock := 0.0
var idle_clock := 0.0
var nudged := false
var line_text_cd := 0.0
var line_broken_said := false
var blip_left := 0.0
var bb_clock := 0.0
var phase := "p1"                   # p1 / p2_alert / p3_flagged / slice_end
var cinematic: Node = null
var p2_reason := ""                 # tests / probes: beat / timeout / idle
var p2_pending_beat := false        # beat the Zero Score while the deal was still being offered: alert right after it

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

## resume (front end, Load Game): a mission saved mid-run picks up at its last checkpoint instead of starting over.
## The P key and ?story=p1 keep starting P.1 from the top (resume false), as in M1.
func start(resume := false) -> bool:
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
	contact = false
	rail_bailed = flow.save.flag("p1_rail_bail_said")
	hesitated = {}
	deal_state = "offered" if flow.save.flag("p1_deal_offered") else ""
	p2_state = ""
	p2_clock = 0.0
	idle_clock = 0.0
	nudged = false
	line_text_cd = 0.0
	line_broken_said = false
	blip_left = 0.0
	bb_clock = 0.0
	phase = "p1"
	p2_reason = ""
	p2_pending_beat = false
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
	cinematic = Cinematic.new()
	cinematic.name = "Cinematic"
	cinematic.setup(self)
	cinematic.finished.connect(_on_cinematic_done)
	add_child(cinematic)
	var phone: Dictionary = def.get("phone", {})
	hud.phone_set_status(str(phone.get("status", "NO SIM · Wi-Fi: YARD-PUBLIC")))
	hud.phone_header(str(phone.get("sender", "???")), str(phone.get("subline", "")))
	for l in phone.get("preloaded", []):
		hud.say_text("???", str(l[1]), false, true)
	_hide_free_roam(true)
	saved_player = {"spawn": player.spawn_position, "yaw": player.spawn_yaw, "locked": player.locked_grinds.duplicate()}
	player.locked_grinds = LOCKED_GRINDS.duplicate()
	if not player.skate_event.is_connected(_on_skate):
		player.skate_event.connect(_on_skate)
	flow.save.set_flag("story_started")
	flow.save.story["current"] = runner.id
	var saved_state := str(rec.get("state", ""))
	if int(rec.get("completions", 0)) > 0 or flow.save.flag("p2_heat_alert_seen"):
		# replay: the tutorial is done; straight to the line with the board up on the marquee
		runner.from_save(rec)
		_teleport("line")
		contact = true
		hud.set_objective(runner.title, "Run the line: bowl, quarter, rail. Beat the Zero Score.")
		if flow.save.flag("p3_flagged_seen"):
			# the playable slice ends after CINEMATIC P.3 (P.2 Run is milestone M3)
			_slice_end(false)
		elif flow.save.flag("p2_heat_alert_seen"):
			# saved between the two cinematics: the drone is still coming
			_say_all([["SYSTEM", "Loaded. The heat alert has gone out."]])
			_play_cinematic("p3_flagged")
		else:
			_say_all([["SYSTEM", "Practice Run (replay). T puts you back at the bowl."]])
			# the deal was offered (or the save predates it): the heat alert is still on its way
			deal_state = "offered"
			_arm_p2()
	elif resume and (saved_state == "active" or saved_state == "failed"):
		runner.from_save(rec)
		runner.resume()
		contact = true
		var o: Dictionary = runner.current()
		_teleport(str(o.get("spawn", "yard")))
		_say_all([["SYSTEM", "Loaded. Back at the checkpoint: %s." % str(o.get("text", ""))]])
	else:
		_teleport("yard")
		# Beat 0: P.1 starts on the intro's last frame (the first text is already in the thread)
		contact = true
		flow.save.set_flag("p1_contact")
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
	if cinematic != null:
		if cinematic.playing:
			cinematic.playing = false
		cinematic.set_shot("game")
		cinematic.queue_free()
		cinematic = null
	player.input_enabled = true
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
	flow.save.story["current"] = ""
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
	_tick_world(delta)
	if in_cinematic():
		_publish()
		return
	if card_left <= 0.0:
		runner.tick(delta)
	combo.tick(delta)
	barks.tick(delta)
	line_text_cd = maxf(0.0, line_text_cd - delta)
	if line.tick(delta):
		hud.toast("LINE TIMED OUT")
		if line_text_cd <= 0.0 and (runner.current_id() == "line" or runner.state == "done"):
			line_text_cd = float(def.get("line_text_cooldown_s", 30.0))
			_say_all(def.beats.get("line_timeout", []))
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
	_p2_trigger(delta)
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
		if not line_broken_said and runner.current_id() == "line":
			line_broken_said = true
			_say_all(def.beats.get("line_broken", []))
			return
	if sfx != null:
		sfx.play("bail")
	if runner.current_id() == "rail" and not rail_bailed and _near_rail(7.0):
		# 6A: the first rail bail gets Zero's angle text (P.1 v2; the CRT has not spoken yet)
		rail_bailed = true
		flow.save.set_flag("p1_rail_bail_said")
		var angle := float(player.grind_last.get("angle_deg", -1.0))
		var said := _words(int(round(angle))) if angle > 1.0 else "forty-one"
		_say_all(_fill(def.beats.rail_bail_first, {"angle": said}))
		flow.persist()
	elif contact:
		_say_all(barks.pick("bail", _flags()), "", "bark")

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
	_line_scored(line.finish(combo.score))

## A finished line: the first sets the Zero Score (and queues the deal); later ones may beat it (and bring the alert).
func _line_scored(score: int) -> void:
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
		if deal_state == "" and not flow.save.flag("p1_deal_offered"):
			# Beat 10: the deal, 4 s after the Zero Score lines (first run only)
			deal_state = "queued"
			flow.save.set_flag("p1_deal_offered")
			_say_all(def.beats.get("deal", []), "", "deal")
		else:
			_arm_p2()
	else:
		hud.toast("LINE  " + Hud.fmt(score) + ("   NEW BEST" if best else ""))
		if score > zero_score:
			var first: bool = not runner.is_done("beat_zero") and not flow.save.flag("p1_zero_beaten")
			runner.notify("line_beat", {"score": score})
			if first:
				flow.save.set_flag("p1_zero_beaten")
				_say_all(def.beats.zero_score_beaten)
				# Beat 12: the first beat of the Zero Score brings the heat alert (after Zero concedes)
				if p2_state == "armed" or deal_state != "":
					_fire_p2("beat")
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
		# 6B after the 6A bail texts ("Better."), 6C on a first-try landing ("Clean."): the CRT speaks aloud
		_say_all(def.beats.rail_land_after_voice if rail_bailed else def.beats.rail_land_first_try)
		voice_heard = true
		face_on = true
		flow.save.set_flag("p1_voice_heard")
		flow.save.set_flag("p1_crt_face")
		_say_all(def.beats.reveal)
		World.crt(dressing, talking == "CRT", face_on)
	if runner.state == "done" and hud != null:
		hud.set_objective(runner.title, "Done. Optional: beat the Zero Score (T resets to the bowl).")

func _on_save(id: String, snap: Dictionary) -> void:
	flow.save.set_mission(id, snap)
	flow.persist()

## Queue lines. Lines tagged with an objective are dropped if that objective is already done when their turn comes
## (a fast player should not hear "Rail. Fifty-fifty." after the 50-50).
## kind: "bark" (dropped when a hesitation text comes in), "deal" (Beat 10, watched for the P.2 trigger), "hesitate".
func _say_all(lines: Array, for_objective := "", kind := "") -> void:
	for l in lines:
		if typeof(l) == TYPE_ARRAY and l.size() >= 2:
			queue.append([str(l[0]), str(l[1]), for_objective, kind])

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
		World.crt(dressing, false, face_on, blip_left > 0.0)
	while not queue.is_empty() and queue[0].size() > 2 and str(queue[0][2]) != "" and runner.is_done(str(queue[0][2])):
		queue.pop_front()
	if in_cinematic():
		return
	if queue.is_empty():
		return
	var next: Array = queue.pop_front()
	var who: String = next[0]
	# front end: the protagonist's name is the player's chosen character name (Fony by default)
	var pname := Protagonist.current(get_tree())
	var text: String = Protagonist.text(next[1], pname)
	spoken.append(who + "|" + text)
	if who == "CARD":
		hud.card(text)
		card_left = CARD_S
		sfx.play("card")
		return
	talking = who
	if TEXT_SPEAKERS.has(who):
		_phone_line(who, text)
		return
	talk_left = clampf(1.0 + 0.045 * text.length(), 1.8, 6.0)
	hud.protagonist_tag = pname.to_upper()
	hud.say(Protagonist.speaker(who, pname) if who != "SYSTEM" else "", text if who != "MARQUEE" else "ON-SCREEN: " + text)
	if who == "CRT" or who.begins_with("VOICE"):
		World.crt(dressing, true, face_on)
		sfx.play("crt")
	elif who == "FONY":
		sfx.play("fony")
	elif who == "MARQUEE":
		sfx.play("marquee")

## P.1 v2 phone speakers. Texts hold at least 2.5 s (never more than one Zero text every 2.5 s while skating).
func _phone_line(who: String, text: String) -> void:
	hud.hush()
	match who:
		"WAIT":
			talk_left = float(text)
		"TEXT ???":
			hud.say_text(hud.phone_sender, text, false)
			sfx.play("text_in")
			blip_left = BLIP_S
			talk_left = clampf(0.9 + 0.035 * text.length(), 2.5, 5.0)
		"TEXT FONY":
			hud.say_text(Protagonist.current(get_tree()), text, true)
			sfx.play("text_out")
			talk_left = 1.6
		"TYPING ???", "TYPING FONY":
			hud.phone_typing_for(float(text))
			talk_left = float(text)
		"DRAFT FONY":
			hud.phone_draft(text)
			talk_left = 0.6
		"PHONE":
			hud.toast(text)
			hud.phone_open()
			talk_left = 1.8
		"ALERT":
			hud.phone_alert(text)
			sfx.play("alert")
			talk_left = 2.6
			if p2_state == "handoff":
				# CINEMATIC P.2 picks up straight from the alert
				_play_cinematic("p2_heat_alert")

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
	# P.1 v2: the first time a prompt is due, Zero's hesitation text replaces any queued bark (once per objective)
	if not hesitated.has(o.id) and o.has("hesitate_text"):
		hesitated[o.id] = true
		queue = queue.filter(func(q): return q.size() < 4 or str(q[3]) != "bark")
		var ht: Array = o.get("hesitate_text", [])
		if not ht.is_empty() and typeof(ht[0]) == TYPE_ARRAY and not ht[0].is_empty() and typeof(ht[0][0]) == TYPE_ARRAY:
			ht = ht[0]  # a list of exchanges: the first is the scripted one
		_say_all(ht, str(o.id), "hesitate")
		hud.phone_open()
	var p: Dictionary = o.prompt
	hud.prompt("%s    [ %s ]    pad: %s" % [p.get("verb", ""), p.get("kb", ""), p.get("pad", "")])
	sfx.play("prompt")

func _free_barks(delta: float) -> void:
	if not contact or not queue.is_empty() or talking != "" or p2_state == "handoff":
		return
	free_bark_clock += delta
	if free_bark_clock < 6.0:
		return
	free_bark_clock = 0.0
	if player.skating and Vector2(player.velocity.x, player.velocity.z).length() > 4.0:
		_say_all(barks.pick("free_skate", _flags()), "", "bark")

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

# ------------------------------------------------------------------ Act I: the deal, the heat alert, the cinematics

func in_cinematic() -> bool:
	return cinematic != null and cinematic.playing

func _flags() -> Dictionary:
	return {"p1_crt_face": face_on, "p1_contact": contact, "p1_voice_heard": voice_heard}

func _tick_world(delta: float) -> void:
	bb_clock += delta
	World.billboard_tick(dressing, bb_clock)
	if blip_left > 0.0:
		blip_left -= delta
		if talking != "CRT":
			World.crt(dressing, false, face_on, blip_left > 0.0)

func _arm_p2() -> void:
	if p2_state != "" or flow.save.flag("p2_heat_alert_seen"):
		return
	p2_state = "armed"
	p2_clock = 0.0
	idle_clock = 0.0

## Beat 12 (proposed rule, p2_trigger in the mission data): the first beat of the Zero Score, OR timeout_s after the
## deal, OR idle_s standing still, whichever comes first.
func _p2_trigger(delta: float) -> void:
	if deal_state == "queued":
		var left := queue.filter(func(q): return q.size() > 3 and str(q[3]) == "deal").size()
		if left == 0 and talking == "":
			deal_state = "offered"
			_arm_p2()
			if p2_pending_beat:
				_fire_p2("beat")
		return
	if p2_state != "armed":
		return
	var trig: Dictionary = def.get("p2_trigger", {})
	p2_clock += delta
	var flat_v := Vector2(player.velocity.x, player.velocity.z).length()
	idle_clock = idle_clock + delta if flat_v < IDLE_SPEED and player.grind == null and player.ramp_mode == "" else 0.0
	if not nudged and p2_clock >= float(trig.get("nudge_s", 45.0)) and not flow.save.flag("p1_zero_beaten"):
		nudged = true
		_say_all(def.beats.get("deal_nudge", []))
	if p2_clock >= float(trig.get("timeout_s", 90.0)):
		_fire_p2("timeout")
	elif idle_clock >= float(trig.get("idle_s", 15.0)):
		_fire_p2("idle")

func _fire_p2(reason: String) -> void:
	if p2_state == "handoff" or p2_state == "cinematic" or p2_state == "done" or flow.save.flag("p2_heat_alert_seen"):
		return
	if deal_state == "queued":
		# the deal is the hook for P.2-P.4: let him hear all of it, then the alert
		p2_pending_beat = true
		return
	p2_state = "handoff"
	p2_reason = reason
	# the alert takes over his phone mid-draft: queued chatter goes, the draft is wiped
	queue = queue.filter(func(q): return q.size() < 4 or (str(q[3]) != "bark" and str(q[3]) != "deal"))
	_say_all(def.beats.get("heat_alert_handoff", []), "", "handoff")

## Starts a Prologue cinematic (input locked, letterbox, cinematic camera).
func _play_cinematic(cid: String) -> bool:
	if cinematic == null:
		return false
	if hud != null:
		hud.prompt("")
	prompt_shown = ""
	var ok: bool = cinematic.play(cid)
	if ok:
		phase = "p2_alert" if cid == "p2_heat_alert" else "p3_flagged"
		p2_state = "cinematic"
	return ok

func _on_cinematic_done(cid: String, _skipped: bool) -> void:
	if cid == "p2_heat_alert":
		_play_cinematic("p3_flagged")
	elif cid == "p3_flagged":
		p2_state = "done"
		_slice_end(true)

## The end of the playable slice (for now): P.2 Run is milestone M3. The card says so, the drone goes, and the Yard
## stays open for the line.
func _slice_end(show_card: bool) -> void:
	phase = "slice_end"
	p2_state = "done"
	var se: Dictionary = cinematic.defs.get("slice_end", {}) if cinematic != null else {}
	if cinematic != null:
		cinematic.set_billboard("postponed")
		cinematic.drone_do("leave")
	if show_card:
		_say_all([["CARD", str(se.get("card", "END OF THE PLAYABLE PROLOGUE"))]])
		card_left = 0.0
	_say_all(se.get("system", []))
	if hud != null:
		hud.set_objective(runner.title, "Prologue slice complete. Next: P.2 Run (M3). Run the line as often as you like.")
	flow.save.story["prologue"] = "slice_end"
	flow.persist()

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
	var js := "window.AU_STORY={active:true,objective:'%s',state:'%s',score:%d,meter:%s,mult:%d,zero:%d,best:%d,line:%d,talk:'%s',prompt:%s,lines:%d,phase:'%s',p2:'%s',cine:'%s',deal:'%s',texts:%d,pilot:'%s'};" % [
		runner.current_id(), runner.state, combo.score, snapped(combo.meter, 0.01), combo.multiplier(), zero_score, best_line,
		line.at, talking.replace("'", ""), "true" if prompt_shown != "" else "false", spoken.size(),
		phase, p2_state, (cinematic.id if cinematic != null and cinematic.playing else ""), deal_state, hud.phone_log.size() if hud != null else 0,
		(str(autopilot.legs[mini(autopilot.leg, autopilot.legs.size() - 1)].name) + ("/done" if autopilot.finished else "")) if autopilot != null else ""]
	JavaScriptBridge.eval(js, true)
