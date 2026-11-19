extends RefCounted
## Data-driven district loading cards (M0, Nov 18 2026). Pure logic, no nodes: read a card file and pick the card for a
## visit number. File format (data/loading_cards/<district>.json, contract "au.loading_cards" v1):
##   {"contract": "au.loading_cards", "version": 1, "district": "<id>", "min_seconds": 4.0,
##    "tiers": [{"id": "intro", "from_visit": 1, "to_visit": 1, "pick": "first", "cards": [CARD, ...]}, ...]}
## A tier matches when from_visit <= visit <= to_visit (to_visit omitted or null = no upper end). The first matching tier
## wins. pick: "first" (cards[0]), "rotate" (cards[(visit - from_visit) % n]), or "random" (stable per visit).
## CARD: {"id", "title", "body", "art" (res:// image, optional), "portrait" (res:// image, optional),
##        "portrait_name" (optional), "accent" (#hex, optional)}.
## Writers and artists add tiers and cards in the JSON; no code changes.

const JsonFile = preload("res://scripts/json_file.gd")
const CONTRACT := "au.loading_cards"
const PICKS := ["first", "rotate", "random"]

static func read(path: String) -> Dictionary:
	var data = JsonFile.read(path)
	if typeof(data) != TYPE_DICTIONARY:
		return {}
	return data if validate(data).get("ok", false) else {}

static func validate(data: Dictionary) -> Dictionary:
	if str(data.get("contract", "")) != CONTRACT or int(data.get("version", -1)) != 1:
		return {"ok": false, "reason": "contract"}
	var tiers = data.get("tiers", null)
	if typeof(tiers) != TYPE_ARRAY or tiers.is_empty():
		return {"ok": false, "reason": "tiers"}
	for tier in tiers:
		if typeof(tier) != TYPE_DICTIONARY:
			return {"ok": false, "reason": "tier_type"}
		if int(tier.get("from_visit", 0)) < 1:
			return {"ok": false, "reason": "from_visit", "tier": tier.get("id", "")}
		var to = tier.get("to_visit", null)
		if to != null and int(to) < int(tier.get("from_visit", 1)):
			return {"ok": false, "reason": "to_visit", "tier": tier.get("id", "")}
		if not PICKS.has(str(tier.get("pick", "first"))):
			return {"ok": false, "reason": "pick", "tier": tier.get("id", "")}
		var cards = tier.get("cards", null)
		if typeof(cards) != TYPE_ARRAY or cards.is_empty():
			return {"ok": false, "reason": "cards", "tier": tier.get("id", "")}
		for card in cards:
			if typeof(card) != TYPE_DICTIONARY or str(card.get("title", "")) == "":
				return {"ok": false, "reason": "card", "tier": tier.get("id", "")}
	return {"ok": true}

## The card dictionary for a visit (1 = first visit), plus "tier" naming the tier it came from. Falls back to a
## title-only card when nothing matches (or the file is missing), so a district can never load without a card.
static func pick(data: Dictionary, visit: int, fallback_title := "") -> Dictionary:
	visit = maxi(1, visit)
	for tier in data.get("tiers", []):
		var from := int(tier.get("from_visit", 1))
		var to = tier.get("to_visit", null)
		if visit < from or (to != null and visit > int(to)):
			continue
		var cards: Array = tier.get("cards", [])
		var i := 0
		match str(tier.get("pick", "first")):
			"rotate":
				i = (visit - from) % cards.size()
			"random":
				var rng := RandomNumberGenerator.new()
				rng.seed = hash(str(data.get("district", "")) + ":" + str(visit))
				i = rng.randi_range(0, cards.size() - 1)
		var card: Dictionary = cards[i].duplicate(true)
		card["tier"] = str(tier.get("id", ""))
		return card
	return {"id": "fallback", "title": fallback_title, "body": "", "tier": ""}

static func min_seconds(data: Dictionary) -> float:
	return clampf(float(data.get("min_seconds", 4.0)), 0.0, 30.0)
