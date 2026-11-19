extends Node
## M1 (Nov 19 2026), review aid: plays P.1 through the real player physics, the way tests drive it (external_move,
## request_trick, skate_toggle_pressed); nothing is teleported after the start. Armed by story_demo=1 on the command
## line or ?story=p1&story_demo=1 in the web build, so the whole Practice Run can be watched in a browser.
## Not a gameplay feature: the stick and buttons are simply pressed for you.

var story: Node
var player: Node
var legs: Array = []
var leg := 0
var clock := 0.0
var total := 0.0
var log: Array = []                 # [time, leg name, outcome]
var finished := false
var _popped := false
var _toggled := false
var _jumped := false

func setup(owner_story: Node) -> void:
	story = owner_story
	player = story.player
	legs = _plan()

func _plan() -> Array:
	var p: Array = []
	# P.1 objectives in order
	p.append({"name": "card", "do": "wait", "until": "card_gone", "t": 15.0})
	p.append({"name": "push", "do": "goto", "to": Vector2(-30, 12), "until": "objective_not:push", "t": 8.0})
	p.append({"name": "slow", "do": "stop", "until": "slow", "t": 4.0})
	p.append({"name": "kick_up", "do": "toggle", "until": "objective_not:kick_up", "t": 2.0})
	p.append({"name": "breath", "do": "wait", "t": 1.0})
	p.append({"name": "drop_on", "do": "toggle", "until": "objective_not:drop_on", "t": 2.0})
	p.append({"name": "ollie", "do": "goto", "to": Vector2(-30, 14), "trick_after": 0.6, "trick": "ollie", "until": "objective_not:ollie", "t": 6.0})
	p.append({"name": "to_quarter", "do": "goto", "to": Vector2(-38, -5), "r": 2.0, "t": 8.0})
	p.append({"name": "to_lane", "do": "goto", "to": Vector2(-45, -12), "r": 1.5, "t": 6.0})
	p.append({"name": "quarter", "do": "lane", "axis": "z", "at": -12.0, "dir": -1.0, "until": "objective_not:quarter", "t": 10.0})
	p.append({"name": "roll_back", "do": "wait", "t": 1.5})
	# the rail: a bad angle first (the voice wakes up), then a clean 50-50
	p.append({"name": "rail_setup", "do": "goto", "to": Vector2(-36, -4), "r": 2.0, "t": 8.0})
	p.append({"name": "rail_bad_start", "do": "goto", "to": Vector2(-43.5, 2.0), "r": 1.2, "t": 8.0})
	p.append({"name": "rail_bad", "do": "goto", "to": Vector2(-51.0, 8.0), "pop_rail": true, "until": "bail_or_grind", "t": 5.0})
	p.append({"name": "rail_recover", "do": "stop", "until": "skating", "t": 4.0})
	p.append({"name": "rail_back", "do": "goto", "to": Vector2(-36, 1.0), "r": 2.0, "t": 10.0})
	p.append({"name": "rail_lane_in", "do": "goto", "to": Vector2(-35, 8.2), "r": 1.2, "t": 6.0})
	p.append({"name": "rail", "do": "lane", "axis": "z", "at": 8.05, "dir": -1.0, "pop_rail": true, "until": "objective_not:rail", "t": 10.0})
	p.append({"name": "rail_off", "do": "wait", "until": "off_rail", "t": 3.0})
	p.append({"name": "listen", "do": "goto", "to": Vector2(-60, 12), "r": 2.5, "t": 3.0})
	# the line, twice: bowl, quarter, rail (the second lap adds kickflips on the flat to beat the Zero Score)
	for lap in 2:
		var flip := "flip" if lap == 1 else ""
		# the bowl's north bank tops out 0.45 m above the yard slab at z 19: hop the lip (Space) to drop in
		p.append({"name": "line%d_to_bowl" % lap, "do": "goto", "to": Vector2(-48, 15.5), "r": 1.5, "t": 10.0})
		p.append({"name": "line%d_bowl" % lap, "do": "goto", "to": Vector2(-48, 46), "r": 2.5, "jump_after": 0.0, "until": "line_at:1", "t": 8.0})
		p.append({"name": "line%d_out" % lap, "do": "goto", "to": Vector2(-44, 17), "r": 2.0, "t": 10.0})
		p.append({"name": "line%d_north" % lap, "do": "goto", "to": Vector2(-38, -5), "r": 2.0, "trick_after": 1.4, "trick": flip, "t": 10.0})
		p.append({"name": "line%d_lane" % lap, "do": "goto", "to": Vector2(-45, -12), "r": 1.5, "t": 6.0})
		p.append({"name": "line%d_quarter" % lap, "do": "lane", "axis": "z", "at": -12.0, "dir": -1.0, "until": "line_at:2", "t": 10.0})
		p.append({"name": "line%d_back" % lap, "do": "wait", "t": 1.5})
		p.append({"name": "line%d_east" % lap, "do": "goto", "to": Vector2(-36, -4), "r": 2.0, "trick_after": 1.0, "trick": flip, "t": 8.0})
		p.append({"name": "line%d_south" % lap, "do": "goto", "to": Vector2(-36, 1.0), "r": 2.0, "t": 6.0})
		p.append({"name": "line%d_lane_in" % lap, "do": "goto", "to": Vector2(-35, 8.2), "r": 1.2, "t": 6.0})
		p.append({"name": "line%d_rail" % lap, "do": "lane", "axis": "z", "at": 8.05, "dir": -1.0, "pop_rail": true, "until": "line_runs:%d" % (lap + 1), "t": 10.0})
		p.append({"name": "line%d_off" % lap, "do": "wait", "until": "off_rail", "t": 3.0})
		p.append({"name": "line%d_coast" % lap, "do": "goto", "to": Vector2(-60, 13), "r": 2.5, "t": 3.0})
	p.append({"name": "end", "do": "stop", "t": 2.0})
	return p

func _physics_process(delta: float) -> void:
	if finished or story == null or not story.active:
		return
	total += delta
	clock += delta
	var l: Dictionary = legs[leg]
	if OS.get_environment("AU_PILOT_DEBUG") == "1" and int(total * 60.0) % 30 == 0:
		print("pilot dbg t=%.1f leg=%s pos=%s v=%.2f floor=%s trick=%s grind=%s ramp=%s obj=%s line=%d" % [total, l.name, player.global_position.snapped(Vector3(0.01, 0.01, 0.01)), Vector2(player.velocity.x, player.velocity.z).length(), player.is_on_floor(), player.trick, player.grind != null, player.ramp_mode, story.runner.current_id(), story.line.at])
	player.external_move_active = true
	var move := Vector2.ZERO
	match str(l.do):
		"goto":
			move = _toward(Vector3(l.to.x, 0, l.to.y))
		"lane":
			var pos: Vector3 = player.global_position
			var ahead := Vector3(pos.x + float(l.dir) * 6.0, 0, float(l.at)) if l.axis == "z" else Vector3(float(l.at), 0, pos.z + float(l.dir) * 6.0)
			move = _toward(ahead)
		"toggle":
			if not _toggled:
				_toggled = true
				player.skate_toggle_pressed()
		"stop", "wait":
			move = Vector2.ZERO if l.do == "stop" else player.external_move
	player.external_move = move
	if str(l.get("trick", "")) != "" and not _popped and clock >= float(l.get("trick_after", 0.0)):
		_popped = true
		player.request_trick(str(l.trick))
	if l.has("jump_after") and not _jumped and clock >= float(l.jump_after) and player.is_on_floor():
		_jumped = true
		player.external_jump = true
	if bool(l.get("pop_rail", false)) and not _popped and _rail_pop_due():
		_popped = true
		player.request_trick("ollie")
	var done := false
	if l.has("until"):
		done = _cond(str(l.until))
	elif l.has("to"):
		done = Vector2(player.global_position.x - l.to.x, player.global_position.z - l.to.y).length() < float(l.get("r", 1.5))
	else:
		done = clock >= float(l.t)
	if l.has("to") and l.has("until") and not done and str(l.until) == "":
		done = Vector2(player.global_position.x - l.to.x, player.global_position.z - l.to.y).length() < float(l.get("r", 1.5))
	if done or clock >= float(l.t):
		log.append([snapped(total, 0.01), str(l.name), "ok" if done else "timeout"])
		leg += 1
		clock = 0.0
		_popped = false
		_toggled = false
		_jumped = false
		if leg >= legs.size():
			finished = true
			player.external_move = Vector2.ZERO
			player.external_move_active = false

## World direction -> camera-space stick (the same mapping player_controller.gd _wish() inverts).
func _toward(target: Vector3) -> Vector2:
	var d := Vector3(target.x - player.global_position.x, 0, target.z - player.global_position.z)
	if d.length() < 0.05:
		return Vector2.ZERO
	d = d.normalized()
	var axes: Array = player._camera_flat_axes()
	return Vector2(d.dot(axes[1]), d.dot(axes[0]))

## Ollie onto GrindRail (x -55.5 .. -48.5 at z 8, riding -X): pop when the crouch plus the air put him on the bar.
func _rail_pop_due() -> bool:
	if player.grind != null or not player.is_on_floor():
		return false
	var v := Vector2(player.velocity.x, player.velocity.z)
	var pos := Vector2(player.global_position.x, player.global_position.z)
	var target := Vector2(-50.0, 8.0)
	var lead := maxf(2.6, v.length() * 0.46)
	return pos.distance_to(target) < lead + 1.0 and v.dot(target - pos) > 0.0

func _cond(c: String) -> bool:
	if c == "card_gone":
		return story.card_left <= 0.0 and clock > 0.5
	if c.begins_with("objective_not:"):
		return story.runner.current_id() != c.trim_prefix("objective_not:")
	if c == "slow":
		return Vector2(player.velocity.x, player.velocity.z).length() < 0.8
	if c == "skating":
		return player.skating and player.bail_time <= 0.0 and clock > 1.2
	if c == "bail_or_grind":
		return player.trick == "bail" or player.grind != null
	if c == "off_rail":
		return player.grind == null and player.is_on_floor()
	if c.begins_with("line_at:"):
		return story.line.at == int(c.trim_prefix("line_at:"))
	if c.begins_with("line_runs:"):
		return story.line.runs >= int(c.trim_prefix("line_runs:"))
	return false
