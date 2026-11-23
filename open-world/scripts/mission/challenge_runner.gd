extends RefCounted
## Executes one challenge Dictionary. State is itself a Dictionary (to_dict),
## so a later database can store a run without a Godot Resource.

const Schema = preload("res://scripts/mission/challenge_schema.gd")
const Templates = preload("res://scripts/mission/challenge_templates.gd")

var data: Dictionary = {}
var status := "empty"
var progress: Dictionary = {}
var clock_s := 0.0
var chain := 0
var peak_chain := 0
var fails := 0
var points := 0
var rank := ""
var goal_index := 0

func load_challenge(body: Dictionary) -> Dictionary:
	var checked := Schema.validate(body)
	if not bool(checked.get("ok", false)):
		status = "empty"
		return checked
	data = body.duplicate(true)
	_reset_run()
	status = "ready"
	return {"ok": true}

func start() -> Dictionary:
	if status != "ready" and status != "clear" and status != "fail" and status != "active":
		return {"ok": false, "reason": "status"}
	if not bool(data.get("repeatable", true)) and status == "clear":
		return {"ok": false, "reason": "repeat"}
	_reset_run()
	status = "active"
	return {"ok": true, "status": status}

func tick(delta: float) -> void:
	if status == "active" and str(data.get("mechanic", "")) == "timed":
		clock_s += maxf(delta, 0.0)

func notify(event: String, info: Dictionary = {}) -> Dictionary:
	if status != "active":
		return {"ok": false, "reason": "status", "status": status}
	var mechanic := str(data.get("mechanic", ""))
	if mechanic == "timed":
		_timed(event, info)
	elif mechanic == "sneak":
		_parallel(event, info, true)
	elif mechanic == "combo":
		_combo(event, info)
	elif mechanic == "camera-prep":
		_parallel(event, info, false)
	elif mechanic == "chase":
		_chase(event, info)
	else:
		_ordered(event, info)
	return {"ok": true, "status": status, "points": points, "rank": rank, "fails": fails}

func to_dict() -> Dictionary:
	return {
		"contract": Schema.STATE_CONTRACT,
		"contract_version": Schema.VERSION,
		"challenge": data.duplicate(true),
		"status": status,
		"progress": progress.duplicate(true),
		"clock_s": clock_s,
		"chain": chain,
		"peak_chain": peak_chain,
		"fails": fails,
		"points": points,
		"rank": rank,
		"goal_index": goal_index,
	}

func from_dict(saved: Dictionary) -> Dictionary:
	if str(saved.get("contract", "")) != Schema.STATE_CONTRACT:
		return {"ok": false, "reason": "contract"}
	if int(saved.get("contract_version", -1)) != Schema.VERSION:
		return {"ok": false, "reason": "version"}
	var body = saved.get("challenge", null)
	if typeof(body) != TYPE_DICTIONARY:
		return {"ok": false, "reason": "challenge"}
	var body_dict: Dictionary = body
	var checked := load_challenge(body_dict)
	if not bool(checked.get("ok", false)):
		return checked
	status = str(saved.get("status", "ready"))
	progress = (saved.get("progress", {}) as Dictionary).duplicate(true)
	clock_s = float(saved.get("clock_s", 0.0))
	chain = int(saved.get("chain", 0))
	peak_chain = int(saved.get("peak_chain", 0))
	fails = int(saved.get("fails", 0))
	points = int(saved.get("points", 0))
	rank = str(saved.get("rank", ""))
	goal_index = int(saved.get("goal_index", 0))
	return {"ok": true}

func _reset_run() -> void:
	progress.clear()
	clock_s = 0.0
	chain = 0
	peak_chain = 0
	fails = 0
	points = 0
	rank = ""
	goal_index = 0
	for goal in data.get("goals", []):
		progress[str((goal as Dictionary).get("id", ""))] = 0

func _goals() -> Array:
	var goals = data.get("goals", [])
	return goals if typeof(goals) == TYPE_ARRAY else []

func _need(goal: Dictionary) -> int:
	return maxi(int(goal.get("count", 1)), 1)

func _matches(goal: Dictionary, event: String, info: Dictionary) -> bool:
	if str(goal.get("event", "")) != event:
		return false
	var match = goal.get("match", {})
	if typeof(match) != TYPE_DICTIONARY:
		return true
	for key in (match as Dictionary).keys():
		if str(info.get(key, "")) != str((match as Dictionary).get(key, "")):
			return false
	return true

func _bump(goal: Dictionary) -> bool:
	var gid := str(goal.get("id", ""))
	var next := int(progress.get(gid, 0)) + 1
	progress[gid] = next
	return next >= _need(goal)

func _all_done() -> bool:
	for goal in _goals():
		var body: Dictionary = goal
		if bool(body.get("fail_on", false)):
			continue
		if int(progress.get(str(body.get("id", "")), 0)) < _need(body):
			return false
	return true

func _clear(rank_name: String) -> void:
	status = "clear"
	rank = rank_name
	points = Templates.points_for(data, rank_name if rank_name != "" else "clear")

func _fail_rule() -> String:
	var params = data.get("parameters", {})
	if typeof(params) != TYPE_DICTIONARY:
		return "none"
	return str((params as Dictionary).get("fail_rule", "none"))

func _spot_or_catch(kind: String) -> void:
	fails += 1
	if _fail_rule() == "checkpoint":
		return
	status = "fail"
	points = 0
	rank = kind

func _timed(event: String, info: Dictionary) -> void:
	if event == "caught":
		_spot_or_catch("caught")
		return
	for goal in _goals():
		var body: Dictionary = goal
		if _matches(body, event, info) and _bump(body) and _all_done():
			if info.has("time_s"):
				clock_s = float(info.get("time_s", clock_s))
			var scored := Templates.time_rank(clock_s, data.get("scoring", {}) as Dictionary)
			if scored == "":
				status = "fail"
				points = 0
				rank = "over"
			else:
				_clear(scored)
			return

func _parallel(event: String, info: Dictionary, sneak: bool) -> void:
	for goal in _goals():
		var body: Dictionary = goal
		if not _matches(body, event, info):
			continue
		if bool(body.get("fail_on", false)):
			_spot_or_catch("spotted" if sneak else "fail")
			return
		if int(progress.get(str(body.get("id", "")), 0)) >= _need(body):
			continue
		_bump(body)
		break
	if status == "active" and _all_done():
		if sneak and fails > 0:
			status = "fail"
			points = 0
			return
		_clear("clear")

func _chase(event: String, info: Dictionary) -> void:
	if event == "caught":
		_spot_or_catch("caught")
		return
	_parallel(event, info, false)

func _ordered(event: String, info: Dictionary) -> void:
	var goals := _goals()
	for goal in goals:
		var body: Dictionary = goal
		if bool(body.get("fail_on", false)) and _matches(body, event, info):
			if _fail_rule() == "none":
				return
			_spot_or_catch("fail")
			return
	if goal_index >= goals.size():
		return
	var current: Dictionary = goals[goal_index]
	if bool(current.get("fail_on", false)):
		return
	if _matches(current, event, info) and _bump(current):
		goal_index += 1
		while goal_index < goals.size() and bool((goals[goal_index] as Dictionary).get("fail_on", false)):
			goal_index += 1
		if goal_index >= goals.size():
			_clear("clear")

func _combo(event: String, info: Dictionary) -> void:
	if event == "chain":
		chain = int(info.get("chain", chain))
		peak_chain = maxi(peak_chain, chain)
		return
	if event == "bail":
		chain = 0
		return
	if event != "finish":
		return
	var scored := Templates.chain_rank(peak_chain, data.get("scoring", {}) as Dictionary)
	if scored == "":
		status = "fail"
		points = 0
		rank = "short"
	else:
		_clear(scored)
