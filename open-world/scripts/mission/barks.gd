extends RefCounted
## M1 (Nov 19 2026): event-triggered barks. Each pool is a list of entries; an entry is one line or an exchange
## ([[speaker, text], ...]). A pick never repeats the previous entry of its pool, and every pool has a cooldown.
## The RNG is seeded so tests are repeatable.

var pools := {}                     # name -> {"entries": [...], "cooldown": s, "chance": 0..1}
var since := {}                     # name -> seconds since its last bark
var last := {}                      # name -> index of its last entry
var global_gap := 4.0               # no two barks closer than this, from any pool
var since_any := 99.0
var rng := RandomNumberGenerator.new()
var fired: Array = []

func setup(data: Dictionary, seed_value := 1) -> void:
	rng.seed = seed_value
	pools.clear()
	for name in data:
		var p = data[name]
		if typeof(p) != TYPE_DICTIONARY:
			continue
		pools[name] = {"entries": p.get("entries", []), "cooldown": float(p.get("cooldown", 20.0)), "chance": float(p.get("chance", 1.0))}
		since[name] = 99.0
		last[name] = -1

func tick(delta: float) -> void:
	since_any += delta
	for k in since:
		since[k] += delta

## Returns an exchange ([[speaker, text], ...]) or [] when the pool is cooling down, empty or the roll missed.
func pick(pool: String) -> Array:
	if not pools.has(pool) or since_any < global_gap:
		return []
	var p: Dictionary = pools[pool]
	var entries: Array = p.entries
	if entries.is_empty() or float(since[pool]) < float(p.cooldown):
		return []
	if rng.randf() > float(p.chance):
		return []
	var i := rng.randi_range(0, entries.size() - 1)
	if entries.size() > 1 and i == int(last[pool]):
		i = (i + 1) % entries.size()
	last[pool] = i
	since[pool] = 0.0
	since_any = 0.0
	var e = entries[i]
	var out: Array = e if typeof(e) == TYPE_ARRAY and not e.is_empty() and typeof(e[0]) == TYPE_ARRAY else [e]
	fired.append(pool)
	return out
