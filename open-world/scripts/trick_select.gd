extends RefCounted
## One trick button. The maneuver comes from where the board is and how long the chain is.
## Tier 0 is the first link. Tier 1 starts at chain 2, tier 2 at 4, tier 3 at 6.

const TIER_AT := [0, 2, 4, 6]

const BY_TIER := [
	{"flat": "ollie", "air": "flip", "ramp": "ollie", "grind": "5050"},
	{"flat": "flip", "air": "grab", "ramp": "bs_air", "grind": "5o"},
	{"flat": "grab", "air": "flip", "ramp": "bs_air", "grind": "board"},
	{"flat": "flip", "air": "grab", "ramp": "bs_air", "grind": "board"},
]

static func tier_for(chain: int) -> int:
	var tier := 0
	for i in TIER_AT.size():
		if chain >= TIER_AT[i]:
			tier = i
	return tier

static func pick(context: String, chain: int) -> String:
	var row: Dictionary = BY_TIER[tier_for(chain)]
	return str(row.get(context, "ollie"))
