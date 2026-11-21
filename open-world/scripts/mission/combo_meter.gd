extends RefCounted
## M1 (Nov 19 2026): score and the combo speed system (design pillar "Skateable"). Pure logic; story mode feeds it from
## the player's skate events and reads the two speed multipliers back every frame.
##
##   tricks add PENDING points when they start (the callout). Landing banks them: points x multiplier into the score,
##   and the meter fills from the trick points. Grinds bank when he leaves the rail cleanly, and fill the meter while on it.
##   a bail drops whatever is pending, empties the meter and resets the chain.
##   the meter holds for GRACE_S after the last landed trick, then decays at DECAY_PER_S. At 0 the chain resets.
##   while it is up: top speed x (1 + TOP_BONUS * meter), push power x (1 + PUSH_BONUS * meter).
## All numbers are first-pass tuning (provisional).

## Scaled so a plain first line (bowl, quarter, a 6 m 50-50) scores about 3,200 and the Zero Score lands near the script's
## 4,000 ("set just above whatever the player scored").
const TRICK_POINTS := {
	"OLLIE": 400,
	"KICKFLIP": 1000,
	"MELON": 800,
	"DROP IN": 600,
	"BS KICKTURN": 600,
	"BACKSIDE AIR": 1600,
}
const TRANSITION_POINTS := 400      # riding a quarter pipe above TRANSITION_MIN_PEAK (no callout)
const TRANSITION_MIN_PEAK := 0.8
const GRIND_BASE := 400
const GRIND_PER_M := 160
const FILL_PER_POINT := 1.0 / 3200.0 # meter gained per banked base point (an ollie fills 1/8)
const GRIND_FILL_PER_S := 0.12
const GRACE_S := 2.5
const DECAY_PER_S := 0.2
const TOP_BONUS := 0.35             # full meter: 9 m/s -> 12.15 m/s
const PUSH_BONUS := 0.6
const MULT_CAP := 8

var meter := 0.0                    # 0..1
var score := 0                      # banked total
var chain := 0                      # banks since the meter was last empty
var pending: Array = []             # [{"name": str, "points": int}]
var since_bank := 99.0
var grinding := false
var bails := 0
var best_bank := 0
var last_bank := {}                 # {"base": int, "mult": int, "points": int, "names": []}
var log: Array = []                 # last banks (tests / HUD)

func points_for(name: String) -> int:
	return int(TRICK_POINTS.get(name, 0))

## A trick started (or a scoring move happened). points < 0 = look it up.
func trick(name: String, points := -1) -> void:
	var p := points if points >= 0 else points_for(name)
	if p <= 0:
		return
	pending.append({"name": name, "points": p})

func grind_start() -> void:
	grinding = true

## Clean exit from a rail: one pending entry for the whole grind, banked straight away.
func grind_done(names: Array, distance_m: float) -> int:
	grinding = false
	var label := " + ".join(names) if not names.is_empty() else "GRIND"
	pending.append({"name": label, "points": GRIND_BASE + int(round(GRIND_PER_M * maxf(distance_m, 0.0)))})
	return land()

## Board down cleanly: bank everything pending. Returns the points added.
func land() -> int:
	if pending.is_empty():
		return 0
	var base := 0
	var names: Array = []
	for p in pending:
		base += int(p.points)
		names.append(p.name)
	pending.clear()
	var mult := multiplier()
	var pts := base * mult
	score += pts
	chain += 1
	meter = clampf(meter + float(base) * FILL_PER_POINT, 0.0, 1.0)
	since_bank = 0.0
	best_bank = maxi(best_bank, pts)
	last_bank = {"base": base, "mult": mult, "points": pts, "names": names}
	log.append(last_bank)
	if log.size() > 16:
		log.pop_front()
	return pts

func bail() -> void:
	pending.clear()
	grinding = false
	meter = 0.0
	chain = 0
	since_bank = 99.0
	bails += 1

func tick(delta: float) -> void:
	if grinding:
		meter = clampf(meter + GRIND_FILL_PER_S * delta, 0.0, 1.0)
		since_bank = 0.0
		return
	since_bank += delta
	if since_bank > GRACE_S and meter > 0.0:
		meter = maxf(0.0, meter - DECAY_PER_S * delta)
		if meter <= 0.0:
			chain = 0

func multiplier() -> int:
	return mini(1 + chain, MULT_CAP)

func top_speed_mult() -> float:
	return 1.0 + TOP_BONUS * meter

func push_mult() -> float:
	return 1.0 + PUSH_BONUS * meter

func reset() -> void:
	meter = 0.0
	score = 0
	chain = 0
	pending.clear()
	since_bank = 99.0
	grinding = false
	last_bank = {}
	log.clear()
