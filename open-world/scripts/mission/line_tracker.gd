extends RefCounted
## M1 (Nov 19 2026): a skate line as ordered steps ("bowl" -> "quarter" -> "rail" in P.1). Reusable for later lines
## and time trials. A bail or running out of time drops the line back to step 0. Score is the combo score banked
## from the first step until the last (the caller passes the running total in).

var steps: PackedStringArray = []
var limit_s := 60.0                 # whole line, first step to last
var at := 0
var elapsed := 0.0
var start_score := 0
var runs := 0
var last_score := 0
var broken_by := ""

func setup(step_ids: PackedStringArray, limit := 60.0) -> void:
	steps = step_ids
	limit_s = limit
	reset()

func reset() -> void:
	at = 0
	elapsed = 0.0

func started() -> bool:
	return at > 0

func current() -> String:
	return steps[at] if at < steps.size() else ""

## A step event. Returns "done" when the line finished, "step" when it advanced, "" otherwise.
## Repeats of an earlier step while in the line are ignored (circle the bowl as long as you like).
func step(id: String, score_now: int) -> String:
	if at >= steps.size():
		return ""
	if id == steps[at]:
		if at == 0:
			start_score = score_now
			elapsed = 0.0
		at += 1
		if at >= steps.size():
			runs += 1
			last_score = 0
			return "done"
		return "step"
	if id == steps[0] and at > 0:
		# back at the start before finishing: the line restarts from here
		start_score = score_now
		elapsed = 0.0
		at = 1
		return "step"
	return ""

## Line score once done (pass the combo total after the last bank).
func finish(score_now: int) -> int:
	last_score = maxi(0, score_now - start_score)
	at = 0
	elapsed = 0.0
	return last_score

func tick(delta: float) -> bool:
	if at == 0:
		return false
	elapsed += delta
	if elapsed > limit_s:
		broken_by = "time"
		reset()
		return true
	return false

func bail() -> bool:
	if at == 0:
		return false
	broken_by = "bail"
	reset()
	return true
