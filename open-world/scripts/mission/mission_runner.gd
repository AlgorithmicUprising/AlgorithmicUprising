extends RefCounted
## M1 (Nov 19 2026): mission framework v1. Pure logic, no nodes, so headless tests drive it directly and later missions
## (P.2 Run, 1.1 Fine Print, ...) reuse it. A mission is a data file (data/missions/<id>.json, see load_def()):
##
##   required objectives run in order; the mission is "done" when the last one completes.
##   optional objectives (beat the Zero Score) stay listening after that, in any order.
##   an objective completes after `count` matching notify() calls (match = a subset of the event's info).
##   checkpoints: an objective with "checkpoint": true becomes the restart point when it starts; retry() puts the
##   player back at the start of the last one reached.
##   fail rules: "none" (P.1: bails never fail the mission) or "checkpoint" (the P.2+ proposal: fail -> restart at
##   the last checkpoint, no lives). Every rule carries a status; "proposed" rules are provisional until approved.
##   hesitation: each objective may name hesitate_s; prompt_due() turns true once the player has spent that long on it.
##   save hooks: save_requested fires with to_save() on start, objective done, checkpoint, fail and completion.
##
## States: locked (requires flags missing) -> available -> active -> done; active -> failed -> active (retry).

signal objective_started(id: String)
signal objective_done(id: String)
signal progressed(id: String, count: int, of: int)
signal mission_done(id: String)
signal mission_failed(id: String, reason: String)
signal retried(id: String, objective: String)
signal save_requested(id: String, snapshot: Dictionary)

const STATES := ["locked", "available", "active", "done", "failed"]
const FAIL_RULES := ["none", "checkpoint"]

var id := ""
var title := ""
var def := {}
var required: Array = []          # objective dicts, in order
var optional: Array = []
var state := "locked"
var index := 0                    # current required objective
var counts := {}                  # objective id -> progress
var done_ids: Array = []          # objectives completed this run (required and optional)
var checkpoint := ""              # objective id retry() returns to ("" = the first)
var time_on := 0.0                # seconds on the current required objective (hesitation clock)
var fails := 0
var completions := 0
## P.1's script: the line can be repeated and a bail is a text, not a fail. Open call (not applied): the breakdown also floated a checkpoint fail for later missions.
const P1_FAIL_RULE := "none"
var fail_rule := "none"
var fail_rule_status := "script"  # "script" (from the game script) or "proposed" (provisional, needs the user's OK)

## Validates and loads a mission definition. Returns {"ok": bool, "reason": ...}.
func load_def(data: Dictionary) -> Dictionary:
	if str(data.get("id", "")) == "":
		return {"ok": false, "reason": "id"}
	var objs = data.get("objectives", null)
	if typeof(objs) != TYPE_ARRAY or objs.is_empty():
		return {"ok": false, "reason": "objectives"}
	var fallback := P1_FAIL_RULE if str(data.get("id", "")) == "p1_practice_run" else "none"
	var rule := str(data.get("fail_rule", fallback))
	if not FAIL_RULES.has(rule):
		return {"ok": false, "reason": "fail_rule"}
	var seen := {}
	var req: Array = []
	var opt: Array = []
	for o in objs:
		if typeof(o) != TYPE_DICTIONARY or str(o.get("id", "")) == "" or str(o.get("event", "")) == "":
			return {"ok": false, "reason": "objective"}
		if seen.has(o.id):
			return {"ok": false, "reason": "duplicate_objective", "objective": o.id}
		seen[o.id] = true
		if bool(o.get("optional", false)):
			opt.append(o)
		else:
			req.append(o)
	if req.is_empty():
		return {"ok": false, "reason": "no_required"}
	def = data.duplicate(true)
	id = str(data.id)
	title = str(data.get("title", id))
	required = req
	optional = opt
	fail_rule = rule
	fail_rule_status = str(data.get("fail_rule_status", "script"))
	state = "available" if (data.get("requires", []) as Array).is_empty() else "locked"
	return {"ok": true}

## Unlock check against story flags ({"flag": true}).
func refresh_lock(flags: Dictionary) -> void:
	if state != "locked":
		return
	for f in def.get("requires", []):
		if not bool(flags.get(f, false)):
			return
	state = "available"

func start() -> bool:
	if state == "locked" or required.is_empty():
		return false
	state = "active"
	index = 0
	counts.clear()
	done_ids.clear()
	checkpoint = ""
	time_on = 0.0
	_begin()
	_save()
	return true

## Front end (Nov 19 2026): after from_save() of a mission saved mid-run, start the restored objective again (the
## checkpoint) so its spawn, lines and hesitation clock run as if the player had just reached it.
func resume() -> bool:
	if state != "active" or index >= required.size():
		return false
	counts.erase(current_id())
	time_on = 0.0
	_begin()
	_save()
	return true

func _begin() -> void:
	var o := current()
	if bool(o.get("checkpoint", false)):
		checkpoint = str(o.id)
	objective_started.emit(current_id())

func current() -> Dictionary:
	if state == "active" and index < required.size():
		return required[index]
	return {}

func current_id() -> String:
	return str(current().get("id", ""))

func objective(oid: String) -> Dictionary:
	for o in required + optional:
		if o.id == oid:
			return o
	return {}

func is_done(oid: String) -> bool:
	return done_ids.has(oid)

## Feed one gameplay event. Returns the ids of objectives it completed (often empty).
func notify(event: String, info := {}) -> Array:
	var finished: Array = []
	if state == "active":
		var o := current()
		if not o.is_empty() and _matches(o, event, info):
			if _bump(o):
				finished.append(o.id)
				_complete_required()
	if state == "active" or state == "done":
		for o in optional:
			if done_ids.has(o.id) or not _matches(o, event, info):
				continue
			if state == "active" and bool(o.get("after_done", false)):
				continue
			if _bump(o):
				finished.append(o.id)
				objective_done.emit(o.id)
				_save()
	return finished

func tick(delta: float) -> void:
	if state == "active":
		time_on += delta

## True once the player has been on the current objective for its hesitate_s (P.1: prompts only on hesitation).
func prompt_due() -> bool:
	var o := current()
	if o.is_empty() or not o.has("hesitate_s"):
		return false
	return time_on >= float(o.hesitate_s)

## A failure (caught, overrun, ...). Under fail_rule "none" it is only counted. Returns true if the mission failed.
func fail(reason: String) -> bool:
	fails += 1
	if state != "active" or fail_rule == "none":
		return false
	state = "failed"
	mission_failed.emit(id, reason)
	_save()
	return true

## Back to the last checkpoint (or the first objective). Allowed while active, failed or done (replay).
func retry() -> bool:
	if state != "active" and state != "failed" and state != "done":
		return false
	var to := 0
	if checkpoint != "":
		for i in required.size():
			if required[i].id == checkpoint:
				to = i
	if state == "done":
		# replay keeps the completion; the optional objectives listen again
		retried.emit(id, "")
		return true
	state = "active"
	index = to
	for i in range(to, required.size()):
		counts.erase(required[i].id)
		done_ids.erase(required[i].id)
	time_on = 0.0
	retried.emit(id, current_id())
	objective_started.emit(current_id())
	_save()
	return true

func to_save() -> Dictionary:
	return {
		"state": state,
		"objective": current_id() if state == "active" or state == "failed" else "",
		"checkpoint": checkpoint,
		"done": done_ids.duplicate(),
		"completions": completions,
		"fails": fails,
	}

## Restores a saved snapshot. A mission saved mid-run resumes at its checkpoint (not mid-objective).
func from_save(snap: Dictionary) -> void:
	completions = int(snap.get("completions", 0))
	fails = int(snap.get("fails", 0))
	var s := str(snap.get("state", state))
	if s == "done" or completions > 0:
		state = "done"
		index = required.size()
		done_ids = (snap.get("done", []) as Array).duplicate()
		return
	if s == "active" or s == "failed":
		checkpoint = str(snap.get("checkpoint", ""))
		state = "active"
		index = 0
		done_ids.clear()
		counts.clear()
		for i in required.size():
			if required[i].id == checkpoint:
				index = i
				break
			done_ids.append(required[i].id)
		if checkpoint == "":
			done_ids.clear()

func _matches(o: Dictionary, event: String, info: Dictionary) -> bool:
	if str(o.event) != event:
		return false
	var want = o.get("match", {})
	if typeof(want) == TYPE_DICTIONARY:
		for k in want:
			var have = info.get(k, null)
			var w = want[k]
			if typeof(w) == TYPE_ARRAY:
				if not w.has(have):
					return false
			elif typeof(w) == TYPE_FLOAT or typeof(w) == TYPE_INT:
				# numbers are minimums
				if have == null or float(have) < float(w):
					return false
			elif str(have) != str(w):
				return false
	return true

func _bump(o: Dictionary) -> bool:
	var need := int(o.get("count", 1))
	var n := int(counts.get(o.id, 0)) + 1
	counts[o.id] = n
	progressed.emit(o.id, n, need)
	if n < need:
		return false
	done_ids.append(o.id)
	return true

func _complete_required() -> void:
	var o: Dictionary = required[index]
	objective_done.emit(o.id)
	index += 1
	time_on = 0.0
	if index >= required.size():
		state = "done"
		completions += 1
		mission_done.emit(id)
	else:
		_begin()
	_save()

func _save() -> void:
	save_requested.emit(id, to_save())
