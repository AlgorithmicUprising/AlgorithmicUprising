extends RefCounted

const TrickSelect = preload("res://scripts/trick_select.gd")
## BOOST is a tank, separate from the score combo meter. Chained tricks fill it.
## A higher tier (longer chain) fills more. Spending it is the boost action.
## A bail ends the chain. The tank stays: boost is accumulated, not a streak bonus.

const FILL_BY_TIER := [0.08, 0.14, 0.22, 0.30]
const CHAIN_BONUS := 0.035
const CHAIN_CAP := 8
const CHAIN_WINDOW_S := 2.8
const SPEND_PER_S := 0.42
const SPEED_BONUS := 0.9

var amount := 0.0
var chain := 0
var since := 99.0
var spending := false

func tier() -> int:
	return TrickSelect.tier_for(chain)

func note_trick(tier: int) -> void:
	var t := clampi(tier, 0, FILL_BY_TIER.size() - 1)
	since = 0.0
	chain += 1
	var gain: float = FILL_BY_TIER[t] + CHAIN_BONUS * float(mini(chain, CHAIN_CAP))
	amount = clampf(amount + gain, 0.0, 1.0)

func note_grind(distance_m: float) -> void:
	note_trick(tier())
	amount = clampf(amount + clampf(distance_m, 0.0, 12.0) * 0.012, 0.0, 1.0)

func note_bail() -> void:
	chain = 0
	since = 99.0
	spending = false

func tick(delta: float) -> void:
	since += delta
	if since > CHAIN_WINDOW_S:
		chain = 0

## Drain the tank while boost is held. Returns 0..1 of how hard it is firing this frame.
func spend(delta: float, held: bool) -> float:
	if not held or amount <= 0.0 or delta <= 0.0:
		spending = false
		return 0.0
	var take := minf(amount, SPEND_PER_S * delta)
	amount -= take
	spending = true
	return clampf(take / (SPEND_PER_S * delta), 0.0, 1.0)

func speed_mult(power: float) -> float:
	return 1.0 + SPEED_BONUS * power
